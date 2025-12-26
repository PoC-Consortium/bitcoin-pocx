[← Önceki: Plot Formatı](2-plot-format.md) | [İçindekiler](index.md) | [Sonraki: Dövme Atamaları →](4-forging-assignments.md)

---

# Bölüm 3: Bitcoin-PoCX Konsensüs ve Madencilik Süreci

Bitcoin Core'a entegre PoCX (Yeni Nesil Kapasite Kanıtı) konsensüs mekanizması ve madencilik sürecinin eksiksiz teknik spesifikasyonu.

---

## İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Konsensüs Mimarisi](#konsensüs-mimarisi)
3. [Madencilik Süreci](#madencilik-süreci)
4. [Blok Doğrulama](#blok-doğrulama)
5. [Atama Sistemi](#atama-sistemi)
6. [Ağ Yayılımı](#ağ-yayılımı)
7. [Teknik Detaylar](#teknik-detaylar)

---

## Genel Bakış

Bitcoin-PoCX, Bitcoin'in İş Kanıtının tam yerine geçen saf Kapasite Kanıtı konsensüs mekanizması uygular. Bu, geriye dönük uyumluluk gereksinimleri olmayan yeni bir zincirdir.

**Temel Özellikler:**
- **Enerji Verimli:** Madencilik, hesaplama hash'lemesi yerine önceden oluşturulmuş plot dosyalarını kullanır
- **Zaman Bükülmüş Son Tarihler:** Dağılım dönüşümü (üstel→ki-kare) uzun blokları azaltır, ortalama blok sürelerini iyileştirir
- **Atama Desteği:** Plot sahipleri dövme haklarını başka adreslere devredebilir
- **Yerel C++ Entegrasyonu:** Konsensüs doğrulaması için C++'ta uygulanan kriptografik algoritmalar

**Madencilik Akışı:**
```
Harici Madenci → get_mining_info → Nonce Hesapla → submit_nonce →
Dövücü Kuyruğu → Son Tarih Bekleme → Blok Dövme → Ağ Yayılımı →
Blok Doğrulama → Zincir Uzatma
```

---

## Konsensüs Mimarisi

### Blok Yapısı

PoCX blokları, Bitcoin'in blok yapısını ek konsensüs alanlarıyla genişletir:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot seed'i (32 bayt)
    std::array<uint8_t, 20> account_id;       // Plot adresi (20 baytlık hash160)
    uint32_t compression;                     // Ölçeklendirme seviyesi (1-255)
    uint64_t nonce;                           // Madencilik nonce'u (64-bit)
    uint64_t quality;                         // Talep edilen kalite (PoC hash çıktısı)
};

class CBlockHeader {
    // Standart Bitcoin alanları
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX konsensüs alanları (nBits ve nNonce yerine geçer)
    int nHeight;                              // Blok yüksekliği (bağlamsız doğrulama)
    uint256 generationSignature;              // Üretim imzası (madencilik entropisi)
    uint64_t nBaseTarget;                     // Zorluk parametresi (ters zorluk)
    PoCXProof pocxProof;                      // Madencilik kanıtı

    // Blok imza alanları
    std::array<uint8_t, 33> vchPubKey;        // Sıkıştırılmış açık anahtar (33 bayt)
    std::array<uint8_t, 65> vchSignature;     // Kompakt imza (65 bayt)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // İşlemler
};
```

**Not:** İmza (`vchSignature`) değiştirilebilirliği önlemek için blok hash hesaplamasından hariç tutulur.

**Uygulama:** `src/primitives/block.h`

### Üretim İmzası

Üretim imzası, madencilik entropisi oluşturur ve ön hesaplama saldırılarını önler.

**Hesaplama:**
```
generationSignature = SHA256(önceki_generationSignature || önceki_madenci_pubkey)
```

**Genesis Bloğu:** Sabit kodlanmış bir başlangıç üretim imzası kullanır

**Uygulama:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Temel Hedef (Zorluk)

Temel hedef zorluğun tersidir - daha yüksek değerler daha kolay madencilik anlamına gelir.

**Ayarlama Algoritması:**
- Hedef blok süresi: 120 saniye (mainnet), 1 saniye (regtest)
- Ayarlama aralığı: Her blok
- Son temel hedeflerin hareketli ortalamasını kullanır
- Aşırı zorluk dalgalanmalarını önlemek için sınırlandırılmış

**Uygulama:** `src/consensus/params.h`, blok oluşturmada zorluk mantığı

### Ölçeklendirme Seviyeleri

PoCX, ölçeklendirme seviyeleri (Xn) aracılığıyla plot dosyalarında ölçeklenebilir iş kanıtını destekler.

**Dinamik Sınırlar:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Kabul edilen minimum seviye
    uint8_t nPoCXTargetCompression;  // Önerilen seviye
};
```

**Ölçeklendirme Artış Programı:**
- Üstel aralıklar: Yıl 4, 12, 28, 60, 124 (yarılanmalar 1, 3, 7, 15, 31)
- Minimum ölçeklendirme seviyesi 1 artar
- Hedef ölçeklendirme seviyesi 1 artar
- Plot oluşturma ve arama maliyetleri arasında güvenlik marjını korur
- Maksimum ölçeklendirme seviyesi: 255

**Uygulama:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Madencilik Süreci

### 1. Madencilik Bilgisi Alımı

**RPC Komutu:** `get_mining_info`

**Süreç:**
1. Mevcut blok zinciri durumunu almak için `GetNewBlockContext(chainman)` çağır
2. Mevcut yükseklik için dinamik sıkıştırma sınırlarını hesapla
3. Madencilik parametrelerini döndür

**Yanıt:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Uygulama:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Notlar:**
- Yanıt üretimi sırasında kilit tutulmaz
- Bağlam edinimi `cs_main`'i dahili olarak yönetir
- `block_hash` referans için dahildir ancak doğrulamada kullanılmaz

### 2. Harici Madencilik

**Harici madenci sorumlulukları:**
1. Diskten plot dosyalarını oku
2. Üretim imzası ve yüksekliğe göre scoop hesapla
3. En iyi son tarihe sahip nonce'u bul
4. `submit_nonce` ile düğüme gönder

**Plot Dosya Formatı:**
- POC2 formatına (Burstcoin) dayalı
- Güvenlik düzeltmeleri ve ölçeklenebilirlik iyileştirmeleriyle geliştirilmiş
- `CLAUDE.md`'de atıf bakın

**Madenci Uygulaması:** Harici (örn., Scavenger tabanlı)

### 3. Nonce Gönderimi ve Doğrulama

**RPC Komutu:** `submit_nonce`

**Parametreler:**
```
height, generation_signature, account_id, seed, nonce, quality (isteğe bağlı)
```

**Doğrulama Akışı (Optimize Sıralama):**

#### Adım 1: Hızlı Format Doğrulaması
```cpp
// Hesap Kimliği: 40 hex karakter = 20 bayt
if (account_id.length() != 40 || !IsHex(account_id)) reddet;

// Seed: 64 hex karakter = 32 bayt
if (seed.length() != 64 || !IsHex(seed)) reddet;
```

#### Adım 2: Bağlam Edinimi
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Döndürür: height, generation_signature, base_target, block_hash
```

**Kilitleme:** `cs_main` dahili olarak yönetilir, RPC iş parçacığında kilit tutulmaz

#### Adım 3: Bağlam Doğrulaması
```cpp
// Yükseklik kontrolü
if (height != context.height) reddet;

// Üretim imzası kontrolü
if (submitted_gen_sig != context.generation_signature) reddet;
```

#### Adım 4: Cüzdan Doğrulaması
```cpp
// Etkin imzalayanı belirle (atamaları dikkate alarak)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Düğümün etkin imzalayan için özel anahtara sahip olup olmadığını kontrol et
if (!HaveAccountKey(effective_signer, wallet)) reddet;
```

**Atama Desteği:** Plot sahibi dövme haklarını başka bir adrese atamış olabilir. Cüzdan, plot sahibi için değil, etkin imzalayan için anahtara sahip olmalıdır.

#### Adım 5: Kanıt Doğrulaması
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bayt
    block_height,
    nonce,
    seed,                // 32 bayt
    min_compression,
    max_compression,
    &result             // Çıktı: quality, deadline
);
```

**Algoritma:**
1. Üretim imzasını hex'ten çöz
2. SIMD optimize algoritmalar kullanarak sıkıştırma aralığında en iyi kaliteyi hesapla
3. Kalitenin zorluk gereksinimlerini karşıladığını doğrula
4. Ham kalite değerini döndür

**Uygulama:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Adım 6: Zaman Bükme Hesaplaması
```cpp
// Ham zorluk ayarlı son tarih (saniye)
uint64_t deadline_seconds = quality / base_target;

// Zaman Bükülmüş dövme süresi (saniye)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Zaman Bükme Formülü:**
```
Y = scale * (X^(1/3))
burada:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Amaç:** Üstel dağılımı ki-kare dağılımına dönüştürür. Çok iyi çözümler daha geç döver (ağın diskleri taraması için zaman tanır), zayıf çözümler iyileştirilir. Uzun blokları azaltır, 120s ortalamasını korur.

**Uygulama:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Adım 7: Dövücü Gönderimi
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // Son tarih DEĞİL - dövücüde yeniden hesaplanır
    height,
    generation_signature
);
```

**Kuyruk Tabanlı Tasarım:**
- Gönderim her zaman başarılı olur (kuyruğa eklenir)
- RPC hemen döner
- İşçi iş parçacığı asenkron olarak işler

**Uygulama:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Dövücü Kuyruk İşleme

**Mimari:**
- Tek kalıcı işçi iş parçacığı
- FIFO gönderim kuyruğu
- Kilitsiz dövme durumu (yalnızca işçi iş parçacığı)
- İç içe kilit yok (kilitlenme önleme)

**İşçi İş Parçacığı Ana Döngüsü:**
```cpp
while (!shutdown) {
    // 1. Kuyrukta gönderim var mı kontrol et
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Son tarih veya yeni gönderim bekle
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission Mantığı:**
```cpp
1. Taze bağlam al: GetNewBlockContext(*chainman)

2. Bayatlık kontrolleri (sessiz atma):
   - Yükseklik uyuşmazlığı → at
   - Üretim imzası uyuşmazlığı → at
   - Uç blok hash'i değişti (yeniden düzenleme) → dövme durumunu sıfırla

3. Kalite karşılaştırması:
   - quality >= current_best ise → at

4. Zaman Bükülmüş son tarihi hesapla:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Dövme durumunu güncelle:
   - Mevcut dövmeyi iptal et (daha iyisi bulunduysa)
   - Depola: account_id, seed, nonce, quality, deadline
   - Hesapla: forge_time = block_time + deadline_seconds
   - Yeniden düzenleme tespiti için uç hash'i depola
```

**Uygulama:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Son Tarih Bekleme ve Blok Dövme

**WaitForDeadlineOrNewSubmission:**

**Bekleme Koşulları:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Son Tarih Ulaşıldığında - Taze Bağlam Doğrulaması:**
```cpp
1. Mevcut bağlamı al: GetNewBlockContext(*chainman)

2. Yükseklik doğrulaması:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Üretim imzası doğrulaması:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Temel hedef uç durumu:
   if (forging_base_target != current_base_target) {
       // Yeni temel hedefle son tarihi yeniden hesapla
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Tekrar bekle
   }

5. Tümü geçerli → ForgeBlock()
```

**ForgeBlock Süreci:**

```cpp
1. Etkin imzalayanı belirle (atama desteği):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Coinbase betiği oluştur:
   coinbase_script = P2WPKH(effective_signer);  // Etkin imzalayana öder

3. Blok şablonu oluştur:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX kanıtı ekle:
   block.pocxProof.account_id = plot_address;    // Orijinal plot adresi
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Merkle kökünü yeniden hesapla:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Bloğu imzala:
   // Etkin imzalayanın anahtarını kullan (plot sahibinden farklı olabilir)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Zincire gönder:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Sonuç işleme:
   if (accepted) {
       log_success();
       reset_forging_state();  // Sonraki blok için hazır
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Uygulama:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Temel Tasarım Kararları:**
- Coinbase etkin imzalayana öder (atamalara saygı gösterir)
- Kanıt orijinal plot adresini içerir (doğrulama için)
- İmza etkin imzalayanın anahtarından (sahiplik kanıtı)
- Şablon oluşturma mempool işlemlerini otomatik olarak dahil eder

---

## Blok Doğrulama

### Gelen Blok Doğrulama Akışı

Ağdan veya yerel olarak bir blok alındığında, birden fazla aşamada doğrulamaya tabi tutulur:

### Aşama 1: Başlık Doğrulaması (CheckBlockHeader)

**Bağlamsız Doğrulama:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX Doğrulaması (ENABLE_POCX tanımlı olduğunda):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Temel imza doğrulaması (henüz atama desteği yok)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Temel İmza Doğrulaması:**
1. Pubkey ve imza alanlarının varlığını kontrol et
2. Pubkey boyutunu doğrula (33 bayt sıkıştırılmış)
3. İmza boyutunu doğrula (65 bayt kompakt)
4. İmzadan pubkey kurtar: `pubkey.RecoverCompact(hash, signature)`
5. Kurtarılan pubkey'in depolanan pubkey ile eşleştiğini doğrula

**Uygulama:** `src/validation.cpp:CheckBlockHeader()`
**İmza Mantığı:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Aşama 2: Blok Doğrulaması (CheckBlock)

**Doğrulananlar:**
- Merkle kökü doğruluğu
- İşlem geçerliliği
- Coinbase gereksinimleri
- Blok boyut sınırları
- Standart Bitcoin konsensüs kuralları

**Uygulama:** `src/consensus/validation.cpp:CheckBlock()`

### Aşama 3: Bağlamsal Başlık Doğrulaması (ContextualCheckBlockHeader)

**PoCX'e Özgü Doğrulama:**

```cpp
#ifdef ENABLE_POCX
    // Adım 1: Üretim imzasını doğrula
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Adım 2: Temel hedefi doğrula
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Adım 3: Kapasite kanıtını doğrula
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Adım 4: Son tarih zamanlamasını doğrula
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Doğrulama Adımları:**
1. **Üretim İmzası:** Önceki bloktan hesaplanan değerle eşleşmeli
2. **Temel Hedef:** Zorluk ayarlama hesaplamasıyla eşleşmeli
3. **Ölçeklendirme Seviyesi:** Ağ minimumunu karşılamalı (`compression >= min_compression`)
4. **Kalite Talebi:** Gönderilen kalite, kanıttan hesaplanan kaliteyle eşleşmeli
5. **Kapasite Kanıtı:** Kriptografik kanıt doğrulaması (SIMD optimize)
6. **Son Tarih Zamanlaması:** Zaman bükülmüş son tarih (`poc_time`) ≤ geçen süre olmalı

**Uygulama:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Aşama 4: Blok Bağlantısı (ConnectBlock)

**Tam Bağlamsal Doğrulama:**

```cpp
#ifdef ENABLE_POCX
    // Atama desteği ile genişletilmiş imza doğrulaması
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Genişletilmiş İmza Doğrulaması:**
1. Temel imza doğrulaması gerçekleştir
2. Kurtarılan pubkey'den hesap kimliği çıkar
3. Plot adresi için etkin imzalayanı al: `GetEffectiveSigner(plot_address, height, view)`
4. Pubkey hesabının etkin imzalayanla eşleştiğini doğrula

**Atama Mantığı:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Atanmış imzalayanı döndür
    }

    return plotAddress;  // Atama yok - plot sahibi imzalar
}
```

**Uygulama:**
- Bağlantı: `src/validation.cpp:ConnectBlock()`
- Genişletilmiş doğrulama: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Atama mantığı: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Aşama 5: Zincir Aktivasyonu

**ProcessNewBlock Akışı:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Doğrula ve diske depola
    2. ActivateBestChain → En iyi zincir ise zincir ucunu güncelle
    3. Ağa yeni bloğu bildir
}
```

**Uygulama:** `src/validation.cpp:ProcessNewBlock()`

### Doğrulama Özeti

**Tam Doğrulama Yolu:**
```
Blok Al
    ↓
CheckBlockHeader (temel imza)
    ↓
CheckBlock (işlemler, merkle)
    ↓
ContextualCheckBlockHeader (üretim imzası, temel hedef, PoC kanıtı, son tarih)
    ↓
ConnectBlock (atamalarla genişletilmiş imza, durum geçişleri)
    ↓
ActivateBestChain (yeniden düzenleme yönetimi, zincir uzatma)
    ↓
Ağ Yayılımı
```

---

## Atama Sistemi

### Genel Bakış

Atamalar, plot sahiplerinin plot sahipliğini korurken dövme haklarını başka adreslere devretmelerine olanak tanır.

**Kullanım Alanları:**
- Havuz madenciliği (plot'lar havuz adresine atanır)
- Soğuk depolama (madencilik anahtarı plot sahipliğinden ayrı)
- Çok taraflı madencilik (paylaşılan altyapı)

### Atama Mimarisi

**OP_RETURN Tabanlı Tasarım:**
- Atamalar OP_RETURN çıktılarında depolanır (UTXO yok)
- Harcama gereksinimleri yok (toz yok, tutma için ücret yok)
- CCoinsViewCache genişletilmiş durumunda izlenir
- Gecikme süresinden sonra aktive olur (varsayılan: 4 blok)

**Atama Durumları:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Atama yok
    ASSIGNING = 1,   // Atama aktivasyon bekleniyor (gecikme süresi)
    ASSIGNED = 2,    // Atama aktif, dövme izinli
    REVOKING = 3,    // İptal bekleniyor (gecikme süresi, hala aktif)
    REVOKED = 4      // İptal tamamlandı, atama artık aktif değil
};
```

### Atama Oluşturma

**İşlem Formatı:**
```cpp
Transaction {
    inputs: [any]  // Plot adresinin sahipliğini kanıtlar
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Doğrulama Kuralları:**
1. Giriş plot sahibi tarafından imzalanmış olmalı (sahipliği kanıtlar)
2. OP_RETURN geçerli atama verisi içermeli
3. Plot UNASSIGNED veya REVOKED olmalı
4. Mempool'da bekleyen yinelenen atama yok
5. Minimum işlem ücreti ödenmiş

**Aktivasyon:**
- Atama, onay yüksekliğinde ASSIGNING olur
- Gecikme süresinden sonra ASSIGNED olur (4 blok regtest, 30 blok mainnet)
- Gecikme, blok yarışları sırasında hızlı yeniden atamaları önler

**Uygulama:** `src/script/forging_assignment.h`, ConnectBlock'ta doğrulama

### Atama İptali

**İşlem Formatı:**
```cpp
Transaction {
    inputs: [any]  // Plot adresinin sahipliğini kanıtlar
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Etki:**
- REVOKED durumuna anında geçiş
- Plot sahibi hemen dövebilir
- Ardından yeni atama oluşturulabilir

### Madencilik Sırasında Atama Doğrulaması

**Etkin İmzalayan Belirleme:**
```cpp
// submit_nonce doğrulamasında
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reddet;

// Blok dövmede
coinbase_script = P2WPKH(effective_signer);  // Ödül buraya gider

// Blok imzasında
signature = effective_signer_key.SignCompact(hash);  // Etkin imzalayanla imzalamalı
```

**Blok Doğrulaması:**
```cpp
// VerifyPoCXBlockCompactSignature'da (genişletilmiş)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reddet;
```

**Temel Özellikler:**
- Kanıt her zaman orijinal plot adresini içerir
- İmza etkin imzalayandan olmalı
- Coinbase etkin imzalayana öder
- Doğrulama, blok yüksekliğindeki atama durumunu kullanır

---

## Ağ Yayılımı

### Blok Duyurusu

**Standart Bitcoin P2P Protokolü:**
1. Dövülen blok `ProcessNewBlock()` ile gönderilir
2. Blok doğrulanır ve zincire eklenir
3. Ağ bildirimi: `GetMainSignals().BlockConnected()`
4. P2P katmanı bloğu eşlere yayınlar

**Uygulama:** Standart Bitcoin Core net_processing

### Blok İletimi

**Kompakt Bloklar (BIP 152):**
- Verimli blok yayılımı için kullanılır
- Başlangıçta yalnızca işlem kimlikleri gönderilir
- Eşler eksik işlemleri talep eder

**Tam Blok İletimi:**
- Kompakt bloklar başarısız olduğunda yedek
- Tam blok verisi iletilir

### Zincir Yeniden Düzenlemeleri

**Yeniden Düzenleme Yönetimi:**
```cpp
// Dövücü işçi iş parçacığında
if (current_tip_hash != stored_tip_hash) {
    // Zincir yeniden düzenlemesi tespit edildi
    reset_forging_state();
    log("Zincir ucu değişti, dövme sıfırlanıyor");
}
```

**Blok Zinciri Seviyesinde:**
- Standart Bitcoin Core yeniden düzenleme yönetimi
- En iyi zincir chainwork ile belirlenir
- Bağlantısı kesilen bloklar mempool'a döner

---

## Teknik Detaylar

### Kilitlenme Önleme

**ABBA Kilitlenme Deseni (Önlendi):**
```
İş Parçacığı A: cs_main → cs_wallet
İş Parçacığı B: cs_wallet → cs_main
```

**Çözüm:**
1. **submit_nonce:** Sıfır cs_main kullanımı
   - `GetNewBlockContext()` kilitlemeyi dahili olarak yönetir
   - Dövücü gönderimine kadar tüm doğrulama

2. **Dövücü:** Kuyruk tabanlı mimari
   - Tek işçi iş parçacığı (iş parçacığı birleştirme yok)
   - Her erişimde taze bağlam
   - İç içe kilit yok

3. **Cüzdan kontrolleri:** Pahalı işlemlerden önce gerçekleştirilir
   - Anahtar mevcut değilse erken ret
   - Blok zinciri durum erişiminden ayrı

### Performans Optimizasyonları

**Hızlı Başarısızlık Doğrulaması:**
```cpp
1. Format kontrolleri (anında)
2. Bağlam doğrulaması (hafif)
3. Cüzdan doğrulaması (yerel)
4. Kanıt doğrulaması (pahalı SIMD)
```

**Tek Bağlam Alma:**
- Gönderim başına bir `GetNewBlockContext()` çağrısı
- Birden fazla kontrol için sonuçları önbellekle
- Tekrarlanan cs_main edinimi yok

**Kuyruk Verimliliği:**
- Hafif gönderim yapısı
- Kuyrukta base_target/deadline yok (taze yeniden hesaplanır)
- Minimum bellek ayak izi

### Bayatlık Yönetimi

**"Sade" Dövücü Tasarımı:**
- Blok zinciri olay abonelikleri yok
- Gerektiğinde tembel doğrulama
- Bayat gönderimlerin sessiz atılması

**Faydalar:**
- Basit mimari
- Karmaşık senkronizasyon yok
- Uç durumlara karşı dayanıklı

**Yönetilen Uç Durumlar:**
- Yükseklik değişiklikleri → at
- Üretim imzası değişiklikleri → at
- Temel hedef değişiklikleri → son tarihi yeniden hesapla
- Yeniden düzenlemeler → dövme durumunu sıfırla

### Kriptografik Detaylar

**Üretim İmzası:**
```cpp
SHA256(önceki_generation_signature || önceki_madenci_pubkey_33bayt)
```

**Blok İmza Hash'i:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakt İmza Formatı:**
- 65 bayt: [recovery_id][r][s]
- Açık anahtar kurtarmaya izin verir
- Alan verimliliği için kullanılır

**Hesap Kimliği:**
- Sıkıştırılmış açık anahtarın 20 baytlık HASH160'ı
- Bitcoin adres formatlarıyla eşleşir (P2PKH, P2WPKH)

### Gelecek Geliştirmeler

**Belgelenmiş Sınırlamalar:**
1. Performans metrikleri yok (gönderim oranları, son tarih dağılımları)
2. Madenciler için detaylı hata kategorilendirmesi yok
3. Sınırlı dövücü durum sorgulama (mevcut son tarih, kuyruk derinliği)

**Olası İyileştirmeler:**
- Dövücü durumu için RPC
- Madencilik verimliliği metrikleri
- Hata ayıklama için gelişmiş günlükleme
- Havuz protokol desteği

---

## Kod Referansları

**Çekirdek Uygulamalar:**
- RPC Arayüzü: `src/pocx/rpc/mining.cpp`
- Dövücü Kuyruğu: `src/pocx/mining/scheduler.cpp`
- Konsensüs Doğrulaması: `src/pocx/consensus/validation.cpp`
- Kanıt Doğrulaması: `src/pocx/consensus/pocx.cpp`
- Zaman Bükme: `src/pocx/algorithms/time_bending.cpp`
- Blok Doğrulaması: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Atama Mantığı: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Bağlam Yönetimi: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Veri Yapıları:**
- Blok Formatı: `src/primitives/block.h`
- Konsensüs Parametreleri: `src/consensus/params.h`
- Atama İzleme: `src/coins.h` (CCoinsViewCache genişletmeleri)

---

## Ek: Algoritma Spesifikasyonları

### Zaman Bükme Formülü

**Matematiksel Tanım:**
```
deadline_seconds = quality / base_target  (ham)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

burada:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Uygulama:**
- Sabit noktalı aritmetik (Q42 formatı)
- Yalnızca tamsayı küp kök hesaplaması
- 256-bit aritmetik için optimize

### Kalite Hesaplaması

**Süreç:**
1. Üretim imzası ve yükseklikten scoop oluştur
2. Hesaplanan scoop için plot verisini oku
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Min'den maks'a ölçeklendirme seviyelerini test et
5. Bulunan en iyi kaliteyi döndür

**Ölçeklendirme:**
- Seviye X0: POC2 temel çizgisi (teorik)
- Seviye X1: XOR-transpose temel çizgisi
- Seviye Xn: 2^(n-1) × X1 işi gömülü
- Daha yüksek ölçeklendirme = daha fazla plot üretim işi

### Temel Hedef Ayarlaması

**Her blokta ayarlama:**
1. Son temel hedeflerin hareketli ortalamasını hesapla
2. Yuvarlanan pencere için hedef zaman aralığına karşı gerçek zaman aralığını hesapla
3. Temel hedefi orantılı olarak ayarla
4. Aşırı dalgalanmaları önlemek için sınırla

**Formül:**
```
avg_base_target = moving_average(son temel hedefler)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Bu dokümantasyon, Ekim 2025 itibarıyla tam PoCX konsensüs uygulamasını yansıtmaktadır.*

---

[← Önceki: Plot Formatı](2-plot-format.md) | [İçindekiler](index.md) | [Sonraki: Dövme Atamaları →](4-forging-assignments.md)
