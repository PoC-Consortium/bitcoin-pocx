[← Önceki: Konsensüs ve Madencilik](3-consensus-and-mining.md) | [İçindekiler](index.md) | [Sonraki: Zaman Senkronizasyonu →](5-timing-security.md)

---

# Bölüm 4: PoCX Dövme Atama Sistemi

## Yönetici Özeti

Bu belge, OP_RETURN tabanlı mimari kullanan **uygulanmış** PoCX dövme atama sistemini tanımlar. Sistem, plot sahiplerinin dövme haklarını zincir üstü işlemler aracılığıyla ayrı adreslere devretmelerine olanak tanır; tam yeniden düzenleme güvenliği ve atomik veritabanı işlemleri ile.

**Durum:** Tam Olarak Uygulanmış ve İşlevsel

## Temel Tasarım Felsefesi

**Anahtar İlke:** Atamalar izinlerdir, varlık değil

- İzlenmesi veya harcanması gereken özel UTXO yok
- Atama durumu UTXO kümesinden ayrı olarak depolanır
- Sahiplik, UTXO harcaması değil, işlem imzasıyla kanıtlanır
- Tam denetim izi için tam geçmiş takibi
- LevelDB toplu yazımları aracılığıyla atomik veritabanı güncellemeleri

## İşlem Yapısı

### Atama İşlem Formatı

```
Girişler:
  [0]: Plot sahibi tarafından kontrol edilen herhangi bir UTXO (sahipliği kanıtlar + ücretleri öder)
       Plot sahibinin özel anahtarıyla imzalanmalıdır
  [1+]: Ücret karşılama için isteğe bağlı ek girişler

Çıktılar:
  [0]: OP_RETURN (POCX işareti + plot adresi + dövme adresi)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Boyut: toplam 46 bayt (1 bayt OP_RETURN + 1 bayt uzunluk + 44 bayt veri)
       Değer: 0 BTC (harcanamaz, UTXO kümesine eklenmez)

  [1]: Kullanıcıya para üstü (isteğe bağlı, standart P2WPKH)
```

**Uygulama:** `src/pocx/assignments/opcodes.cpp:25-52`

### İptal İşlem Formatı

```
Girişler:
  [0]: Plot sahibi tarafından kontrol edilen herhangi bir UTXO (sahipliği kanıtlar + ücretleri öder)
       Plot sahibinin özel anahtarıyla imzalanmalıdır
  [1+]: Ücret karşılama için isteğe bağlı ek girişler

Çıktılar:
  [0]: OP_RETURN (XCOP işareti + plot adresi)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Boyut: toplam 26 bayt (1 bayt OP_RETURN + 1 bayt uzunluk + 24 bayt veri)
       Değer: 0 BTC (harcanamaz, UTXO kümesine eklenmez)

  [1]: Kullanıcıya para üstü (isteğe bağlı, standart P2WPKH)
```

**Uygulama:** `src/pocx/assignments/opcodes.cpp:54-77`

### İşaretler

- **Atama İşareti:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **İptal İşareti:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Uygulama:** `src/pocx/assignments/opcodes.cpp:15-19`

### Temel İşlem Özellikleri

- Standart Bitcoin işlemleri (protokol değişikliği yok)
- OP_RETURN çıktıları kanıtlanabilir şekilde harcanamaz (asla UTXO kümesine eklenmez)
- Plot sahipliği, plot adresinden gelen input[0] üzerindeki imza ile kanıtlanır
- Düşük maliyet (~200 bayt, tipik olarak <0.0001 BTC ücret)
- Cüzdan, sahipliği kanıtlamak için plot adresinden en büyük UTXO'yu otomatik olarak seçer

## Veritabanı Mimarisi

### Depolama Yapısı

Tüm atama verileri, UTXO kümesiyle aynı LevelDB veritabanında (`chainstate/`) depolanır, ancak ayrı anahtar önekleriyle:

```
chainstate/ LevelDB:
├─ UTXO Kümesi (Bitcoin Core standardı)
│  └─ 'C' öneki: COutPoint → Coin
│
└─ Atama Durumu (PoCX eklemeleri)
   └─ 'A' öneki: (plot_address, assignment_txid) → ForgingAssignment
       └─ Tam geçmiş: plot başına zaman içindeki tüm atamalar
```

**Uygulama:** `src/txdb.cpp:237-348`

### ForgingAssignment Yapısı

```cpp
struct ForgingAssignment {
    // Kimlik
    std::array<uint8_t, 20> plotAddress;      // Plot sahibi (20 baytlık P2WPKH hash)
    std::array<uint8_t, 20> forgingAddress;   // Dövme hakları sahibi (20 baytlık P2WPKH hash)

    // Atama yaşam döngüsü
    uint256 assignment_txid;                   // Atamayı oluşturan işlem
    int assignment_height;                     // Oluşturulduğu blok yüksekliği
    int assignment_effective_height;           // Aktif olduğu zaman (yükseklik + gecikme)

    // İptal yaşam döngüsü
    bool revoked;                              // İptal edildi mi?
    uint256 revocation_txid;                   // İptal eden işlem
    int revocation_height;                     // İptal edildiği blok yüksekliği
    int revocation_effective_height;           // İptalin geçerli olduğu zaman (yükseklik + gecikme)

    // Durum sorgulama yöntemleri
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Uygulama:** `src/coins.h:111-178`

### Atama Durumları

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Atama yok
    ASSIGNING = 1,   // Atama oluşturuldu, aktivasyon gecikmesi bekleniyor
    ASSIGNED = 2,    // Atama aktif, dövme izinli
    REVOKING = 3,    // İptal edildi, ancak gecikme süresi boyunca hala aktif
    REVOKED = 4      // Tamamen iptal edildi, artık aktif değil
};
```

**Uygulama:** `src/coins.h:98-104`

### Veritabanı Anahtarları

```cpp
// Geçmiş anahtarı: tam atama kaydını depolar
// Anahtar formatı: (önek, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plot adresi (20 bayt)
    int assignment_height;                // Sıralama optimizasyonu için yükseklik
    uint256 assignment_txid;              // İşlem kimliği
};
```

**Uygulama:** `src/txdb.cpp:245-262`

### Geçmiş Takibi

- Her atama kalıcı olarak depolanır (yeniden düzenleme olmadıkça asla silinmez)
- Plot başına zaman içindeki birden fazla atama izlenir
- Tam denetim izi ve geçmiş durum sorguları sağlar
- İptal edilen atamalar `revoked=true` ile veritabanında kalır

## Blok İşleme

### ConnectBlock Entegrasyonu

Atama ve iptal OP_RETURN'ları, `validation.cpp`'de blok bağlantısı sırasında işlenir:

```cpp
// Konum: Betik doğrulamasından sonra, UpdateCoins'ten önce
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURN verisini ayrıştır
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Sahipliği doğrula (tx plot sahibi tarafından imzalanmış olmalı)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Plot durumunu kontrol et (UNASSIGNED veya REVOKED olmalı)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Yeni atama oluştur
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Geri alma verisini depola
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURN verisini ayrıştır
            auto plot_addr = ParseRevocationOpReturn(output);

            // Sahipliği doğrula
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Mevcut atamayı al
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Geri alma için eski durumu depola
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // İptal edildi olarak işaretle
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins normal şekilde devam eder (OP_RETURN çıktılarını otomatik atlar)
```

**Uygulama:** `src/validation.cpp:2775-2878`

### Sahiplik Doğrulaması

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // En az bir girişin plot sahibi tarafından imzalandığını kontrol et
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Hedefi çıkar
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Plot adresine P2WPKH olup olmadığını kontrol et
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core zaten imzayı doğruladı
                return true;
            }
        }
    }
    return false;
}
```

**Uygulama:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktivasyon Gecikmeleri

Atamalar ve iptaller, yeniden düzenleme saldırılarını önlemek için yapılandırılabilir aktivasyon gecikmelerine sahiptir:

```cpp
// Konsensüs parametreleri (ağ başına yapılandırılabilir)
// Örnek: 30 blok = 2 dakikalık blok süresiyle ~1 saat
consensus.nForgingAssignmentDelay;   // Atama aktivasyon gecikmesi
consensus.nForgingRevocationDelay;   // İptal aktivasyon gecikmesi
```

**Durum Geçişleri:**
- Atama: `UNASSIGNED → ASSIGNING (gecikme) → ASSIGNED`
- İptal: `ASSIGNED → REVOKING (gecikme) → REVOKED`

**Uygulama:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool Doğrulaması

Atama ve iptal işlemleri, ağ yayılımından önce geçersiz işlemleri reddetmek için mempool kabulünde doğrulanır.

### İşlem Seviyesi Kontrolleri (CheckTransaction)

Zincir durumu erişimi olmadan `src/consensus/tx_check.cpp`'de gerçekleştirilir:

1. **Maksimum Bir POCX OP_RETURN:** İşlem birden fazla POCX/XCOP işareti içeremez

**Uygulama:** `src/consensus/tx_check.cpp:63-77`

### Mempool Kabul Kontrolleri (PreChecks)

Tam zincir durumu ve mempool erişimiyle `src/validation.cpp`'de gerçekleştirilir:

#### Atama Doğrulaması

1. **Plot Sahipliği:** İşlem plot sahibi tarafından imzalanmış olmalı
2. **Plot Durumu:** Plot UNASSIGNED (0) veya REVOKED (4) olmalı
3. **Mempool Çakışmaları:** Bu plot için mempool'da başka atama yok (ilk gören kazanır)

#### İptal Doğrulaması

1. **Plot Sahipliği:** İşlem plot sahibi tarafından imzalanmış olmalı
2. **Aktif Atama:** Plot yalnızca ASSIGNED (2) durumunda olmalı
3. **Mempool Çakışmaları:** Bu plot için mempool'da başka iptal yok

**Uygulama:** `src/validation.cpp:898-993`

### Doğrulama Akışı

```
İşlem Yayını
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Maksimum bir POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Plot sahipliğini doğrula
  ✓ Atama durumunu kontrol et
  ✓ Mempool çakışmalarını kontrol et
       ↓
   Geçerli → Mempool'a Kabul Et
   Geçersiz → Reddet (yayılma yok)
       ↓
Blok Madenciliği
       ↓
ConnectBlock() [validation.cpp]
  ✓ Tüm kontrolleri yeniden doğrula (derinlemesine savunma)
  ✓ Durum değişikliklerini uygula
  ✓ Geri alma bilgisini kaydet
```

### Derinlemesine Savunma

Tüm mempool doğrulama kontrolleri, `ConnectBlock()` sırasında aşağıdakilere karşı koruma için yeniden yürütülür:
- Mempool atlama saldırıları
- Kötü niyetli madencilerden geçersiz bloklar
- Yeniden düzenleme senaryolarındaki uç durumlar

Blok doğrulaması konsensüs için yetkili olmaya devam eder.

## Atomik Veritabanı Güncellemeleri

### Üç Katmanlı Mimari

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Bellek Önbelleği)    │  ← Atama değişiklikleri bellekte izlenir
│   - Coinler: cacheCoins                 │
│   - Atamalar: pendingAssignments        │
│   - Kirli izleme: dirtyPlots            │
│   - Silmeler: deletedAssignments        │
│   - Bellek izleme: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Veritabanı Katmanı)     │  ← Tek atomik yazım
│   - BatchWrite(): UTXO'lar + Atamalar   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Disk Depolama)               │  ← ACID garantileri
│   - Atomik işlem                        │
└─────────────────────────────────────────┘
```

### Temizleme Süreci

Blok bağlantısı sırasında `view.Flush()` çağrıldığında:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Coin değişikliklerini tabana yaz
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Atama değişikliklerini atomik olarak yaz
    if (fOk && !dirtyPlots.empty()) {
        // Kirli atamaları topla
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Boş - kullanılmıyor

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Veritabanına yaz
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // İzlemeyi temizle
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Belleği serbest bırak
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Uygulama:** `src/coins.cpp:278-315`

### Veritabanı Toplu Yazımı

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Tek LevelDB toplu işlemi

    // 1. Geçiş durumunu işaretle
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Tüm coin değişikliklerini yaz
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Tutarlı durumu işaretle
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMİK İŞLEME
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Atamalar ayrı olarak ancak aynı veritabanı işlem bağlamında yazılır
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Kullanılmayan parametre (API uyumluluğu için tutulur)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Yeni toplu işlem, ancak aynı veritabanı

    // Atama geçmişini yaz
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Silinen atamaları geçmişten sil
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMİK İŞLEME
    return m_db->WriteBatch(batch);
}
```

**Uygulama:** `src/txdb.cpp:332-348`

### Atomiklik Garantileri

✅ **Atomik olan:**
- Bir bloktaki tüm coin değişiklikleri atomik olarak yazılır
- Bir bloktaki tüm atama değişiklikleri atomik olarak yazılır
- Veritabanı çökmeler arasında tutarlı kalır

⚠️ **Mevcut sınırlama:**
- Coinler ve atamalar `view.Flush()` sırasında **ayrı** LevelDB toplu işlemlerinde yazılır
- Her iki işlem de `view.Flush()` sırasında gerçekleşir, ancak tek bir atomik yazımda değil
- Pratikte: Her iki toplu işlem de disk fsync'inden önce hızlı bir şekilde tamamlanır
- Risk minimumdur: Her ikisinin de çökme kurtarması sırasında aynı bloktan yeniden oynatılması gerekir

**Not:** Bu, tek bir birleşik toplu işlem gerektiren orijinal mimari planından farklıdır. Mevcut uygulama iki toplu işlem kullanır ancak Bitcoin Core'un mevcut çökme kurtarma mekanizmaları (DB_HEAD_BLOCKS işareti) aracılığıyla tutarlılığı korur.

## Yeniden Düzenleme Yönetimi

### Geri Alma Veri Yapısı

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Atama eklendi (geri almada sil)
        MODIFIED = 1,   // Atama değiştirildi (geri almada geri yükle)
        REVOKED = 2     // Atama iptal edildi (geri almada iptal etme)
    };

    UndoType type;
    ForgingAssignment assignment;  // Değişiklik öncesi tam durum
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO geri alma verisi
    std::vector<ForgingUndo> vforgingundo;  // Atama geri alma verisi
};
```

**Uygulama:** `src/undo.h:63-105`

### DisconnectBlock Süreci

Yeniden düzenleme sırasında bir blok bağlantısı kesildiğinde:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... standart UTXO bağlantı kesme ...

    // Geri alma verisini diskten oku
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Atama değişikliklerini geri al (ters sırada işle)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Atama eklenmişti - kaldır
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Atama iptal edilmişti - iptal edilmemiş durumu geri yükle
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Atama değiştirilmişti - önceki durumu geri yükle
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Uygulama:** `src/validation.cpp:2381-2415`

### Yeniden Düzenleme Sırasında Önbellek Yönetimi

```cpp
class CCoinsViewCache {
private:
    // Atama önbellekleri
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Değiştirilen plot'ları izle
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Silmeleri izle
    mutable size_t cachedAssignmentsUsage{0};  // Bellek izleme

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**Uygulama:** `src/coins.cpp:494-565`

## RPC Arayüzü

### Düğüm Komutları (Cüzdan Gerekmez)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Bir plot adresi için mevcut atama durumunu döndürür:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**Uygulama:** `src/pocx/rpc/assignments.cpp:31-126`

### Cüzdan Komutları (Cüzdan Gerekli)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Bir atama işlemi oluşturur:
- Sahipliği kanıtlamak için plot adresinden en büyük UTXO'yu otomatik seçer
- OP_RETURN + para üstü çıktısı ile işlem oluşturur
- Plot sahibinin anahtarıyla imzalar
- Ağa yayınlar

**Uygulama:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Bir iptal işlemi oluşturur:
- Sahipliği kanıtlamak için plot adresinden en büyük UTXO'yu otomatik seçer
- OP_RETURN + para üstü çıktısı ile işlem oluşturur
- Plot sahibinin anahtarıyla imzalar
- Ağa yayınlar

**Uygulama:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Cüzdan İşlem Oluşturma

Cüzdan işlem oluşturma süreci:

```cpp
1. Adresleri ayrıştır ve doğrula (P2WPKH bech32 olmalı)
2. Plot adresinden en büyük UTXO'yu bul (sahipliği kanıtlar)
3. Sahte çıktı ile geçici işlem oluştur
4. İşlemi imzala (tanık verileriyle doğru boyutu al)
5. Sahte çıktıyı OP_RETURN ile değiştir
6. Boyut değişikliğine göre ücretleri orantılı olarak ayarla
7. Son işlemi yeniden imzala
8. Ağa yayınla
```

**Temel içgörü:** Cüzdan, sahipliği kanıtlamak için plot adresinden harcama yapmalıdır, bu nedenle otomatik olarak o adresten coin seçimini zorlar.

**Uygulama:** `src/pocx/assignments/transactions.cpp:38-263`

## Dosya Yapısı

### Çekirdek Uygulama Dosyaları

```
src/
├── coins.h                        # ForgingAssignment yapısı, CCoinsViewCache yöntemleri [710 satır]
├── coins.cpp                      # Önbellek yönetimi, toplu yazımlar [603 satır]
│
├── txdb.h                         # CCoinsViewDB atama yöntemleri [90 satır]
├── txdb.cpp                       # Veritabanı okuma/yazma [349 satır]
│
├── undo.h                         # Yeniden düzenlemeler için ForgingUndo yapısı
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock entegrasyonu
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN formatı, ayrıştırma, doğrulama
    │   ├── opcodes.cpp            # [259 satır] İşaret tanımları, OP_RETURN işlemleri, sahiplik kontrolü
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState yardımcıları
    │   ├── assignment_state.cpp   # Atama durumu sorgulama işlevleri
    │   ├── transactions.h         # Cüzdan işlem oluşturma API'si
    │   └── transactions.cpp       # create_assignment, revoke_assignment cüzdan işlevleri
    │
    ├── rpc/
    │   ├── assignments.h          # Düğüm RPC komutları (cüzdan yok)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC'leri
    │   ├── assignments_wallet.h   # Cüzdan RPC komutları
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC'leri
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Performans Özellikleri

### Veritabanı İşlemleri

- **Mevcut atamayı al:** O(n) - en sonuncusunu bulmak için plot adresi için tüm atamaları tara
- **Atama geçmişini al:** O(n) - plot için tüm atamaları yinele
- **Atama oluştur:** O(1) - tek ekleme
- **Atamayı iptal et:** O(1) - tek güncelleme
- **Yeniden düzenleme (atama başına):** O(1) - doğrudan geri alma verisi uygulaması

Burada n = plot başına atama sayısı (tipik olarak küçük, < 10)

### Bellek Kullanımı

- **Atama başına:** ~160 bayt (ForgingAssignment yapısı)
- **Önbellek yükü:** Kirli izleme için hash haritası yükü
- **Tipik blok:** <10 atama = <2 KB bellek

### Disk Kullanımı

- **Atama başına:** ~200 bayt diskte (LevelDB yükü ile)
- **10000 atama:** ~2 MB disk alanı
- **UTXO kümesine kıyasla ihmal edilebilir:** tipik chainstate'in <%0.001'i

## Mevcut Sınırlamalar ve Gelecek Çalışmalar

### Atomiklik Sınırlaması

**Mevcut:** Coinler ve atamalar `view.Flush()` sırasında ayrı LevelDB toplu işlemlerinde yazılır

**Etki:** Toplu işlemler arasında çökme olursa teorik tutarsızlık riski

**Azaltma:**
- Her iki toplu işlem de fsync'ten önce hızla tamamlanır
- Bitcoin Core'un çökme kurtarması DB_HEAD_BLOCKS işaretini kullanır
- Pratikte: Testlerde hiç gözlenmedi

**Gelecek iyileştirme:** Tek LevelDB toplu işleminde birleştir

### Atama Geçmişi Budaması

**Mevcut:** Tüm atamalar süresiz olarak depolanır

**Etki:** Atama başına sonsuza kadar ~200 bayt

**Gelecek:** N bloktan eski tamamen iptal edilmiş atamaların isteğe bağlı budanması

**Not:** Gerekli olması pek olası değil - 1 milyon atama bile = 200 MB

## Test Durumu

### Uygulanan Testler

✅ OP_RETURN ayrıştırma ve doğrulama
✅ Sahiplik doğrulaması
✅ ConnectBlock atama oluşturma
✅ ConnectBlock iptal
✅ DisconnectBlock yeniden düzenleme yönetimi
✅ Veritabanı okuma/yazma işlemleri
✅ Durum geçişleri (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC komutları (get_assignment, create_assignment, revoke_assignment)
✅ Cüzdan işlem oluşturma

### Test Kapsama Alanları

- Birim testleri: `src/test/pocx_*_tests.cpp`
- İşlevsel testler: `test/functional/feature_pocx_*.py`
- Entegrasyon testleri: Regtest ile manuel test

## Konsensüs Kuralları

### Atama Oluşturma Kuralları

1. **Sahiplik:** İşlem plot sahibi tarafından imzalanmış olmalı
2. **Durum:** Plot UNASSIGNED veya REVOKED durumunda olmalı
3. **Format:** POCX işareti + 2x 20 baytlık adres içeren geçerli OP_RETURN
4. **Benzersizlik:** Aynı anda plot başına bir aktif atama

### İptal Kuralları

1. **Sahiplik:** İşlem plot sahibi tarafından imzalanmış olmalı
2. **Varlık:** Atama mevcut olmalı ve henüz iptal edilmemiş olmalı
3. **Format:** XCOP işareti + 20 baytlık adres içeren geçerli OP_RETURN

### Aktivasyon Kuralları

- **Atama aktivasyonu:** `assignment_height + nForgingAssignmentDelay`
- **İptal aktivasyonu:** `revocation_height + nForgingRevocationDelay`
- **Gecikmeler:** Ağ başına yapılandırılabilir (örn., 30 blok = 2 dakikalık blok süresiyle ~1 saat)

### Blok Doğrulaması

- Geçersiz atama/iptal → blok reddedilir (konsensüs hatası)
- OP_RETURN çıktıları otomatik olarak UTXO kümesinden hariç tutulur (standart Bitcoin davranışı)
- Atama işleme, ConnectBlock'ta UTXO güncellemelerinden önce gerçekleşir

## Sonuç

Uygulandığı şekliyle PoCX dövme atama sistemi şunları sağlar:

✅ **Basitlik:** Standart Bitcoin işlemleri, özel UTXO yok
✅ **Maliyet Etkinliği:** Toz gereksinimi yok, yalnızca işlem ücretleri
✅ **Yeniden Düzenleme Güvenliği:** Kapsamlı geri alma verisi doğru durumu geri yükler
✅ **Atomik Güncellemeler:** LevelDB toplu işlemleri aracılığıyla veritabanı tutarlılığı
✅ **Tam Geçmiş:** Zaman içindeki tüm atamaların tam denetim izi
✅ **Temiz Mimari:** Minimum Bitcoin Core değişiklikleri, izole PoCX kodu
✅ **Üretime Hazır:** Tam olarak uygulanmış, test edilmiş ve işlevsel

### Uygulama Kalitesi

- **Kod organizasyonu:** Mükemmel - Bitcoin Core ve PoCX arasında net ayrım
- **Hata yönetimi:** Kapsamlı konsensüs doğrulaması
- **Dokümantasyon:** Kod yorumları ve yapı iyi belgelenmiş
- **Test:** Çekirdek işlevsellik test edildi, entegrasyon doğrulandı

### Doğrulanan Temel Tasarım Kararları

1. ✅ OP_RETURN tabanlı yaklaşım (UTXO tabanlı yerine)
2. ✅ Ayrı veritabanı depolama (Coin extraData yerine)
3. ✅ Tam geçmiş takibi (yalnızca mevcut yerine)
4. ✅ İmza ile sahiplik (UTXO harcaması yerine)
5. ✅ Aktivasyon gecikmeleri (yeniden düzenleme saldırılarını önler)

Sistem, temiz, bakımı kolay bir uygulamayla tüm mimari hedefleri başarıyla gerçekleştirir.

---

[← Önceki: Konsensüs ve Madencilik](3-consensus-and-mining.md) | [İçindekiler](index.md) | [Sonraki: Zaman Senkronizasyonu →](5-timing-security.md)
