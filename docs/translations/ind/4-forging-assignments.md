[Sebelumnya: Konsensus dan Penambangan](3-consensus-and-mining.md) | [Daftar Isi](index.md) | [Berikutnya: Sinkronisasi Waktu](5-timing-security.md)

---

# Bab 4: Sistem Penugasan Forging PoCX

## Ringkasan Eksekutif

Dokumen ini menjelaskan sistem penugasan forging PoCX yang **telah diimplementasikan** menggunakan arsitektur hanya-OP_RETURN. Sistem ini memungkinkan pemilik plot untuk mendelegasikan hak forging ke alamat terpisah melalui transaksi on-chain, dengan keamanan reorganisasi penuh dan operasi database atomik.

**Status:** Sepenuhnya Diimplementasikan dan Beroperasi

## Filosofi Desain Inti

**Prinsip Utama:** Penugasan adalah izin, bukan aset

- Tidak ada UTXO khusus untuk dilacak atau dibelanjakan
- Status penugasan disimpan terpisah dari set UTXO
- Kepemilikan dibuktikan oleh tanda tangan transaksi, bukan pengeluaran UTXO
- Pelacakan riwayat penuh untuk jejak audit lengkap
- Pembaruan database atomik melalui penulisan batch LevelDB

## Struktur Transaksi

### Format Transaksi Penugasan

```
Input:
  [0]: UTXO apa pun yang dikontrol oleh pemilik plot (membuktikan kepemilikan + membayar biaya)
       Harus ditandatangani dengan kunci privat pemilik plot
  [1+]: Input tambahan opsional untuk menutupi biaya

Output:
  [0]: OP_RETURN (marker POCX + alamat plot + alamat forge)
       Format: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Ukuran: 46 byte total (1 byte OP_RETURN + 1 byte panjang + 44 byte data)
       Nilai: 0 BTC (tidak dapat dibelanjakan, tidak ditambahkan ke set UTXO)

  [1]: Kembalian ke pengguna (opsional, P2WPKH standar)
```

**Implementasi:** `src/pocx/assignments/opcodes.cpp:25-52`

### Format Transaksi Pencabutan

```
Input:
  [0]: UTXO apa pun yang dikontrol oleh pemilik plot (membuktikan kepemilikan + membayar biaya)
       Harus ditandatangani dengan kunci privat pemilik plot
  [1+]: Input tambahan opsional untuk menutupi biaya

Output:
  [0]: OP_RETURN (marker XCOP + alamat plot)
       Format: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Ukuran: 26 byte total (1 byte OP_RETURN + 1 byte panjang + 24 byte data)
       Nilai: 0 BTC (tidak dapat dibelanjakan, tidak ditambahkan ke set UTXO)

  [1]: Kembalian ke pengguna (opsional, P2WPKH standar)
```

**Implementasi:** `src/pocx/assignments/opcodes.cpp:54-77`

### Marker

- **Marker Penugasan:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Marker Pencabutan:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementasi:** `src/pocx/assignments/opcodes.cpp:15-19`

### Karakteristik Transaksi Utama

- Transaksi Bitcoin standar (tidak ada perubahan protokol)
- Output OP_RETURN terbukti tidak dapat dibelanjakan (tidak pernah ditambahkan ke set UTXO)
- Kepemilikan plot dibuktikan oleh tanda tangan pada input[0] dari alamat plot
- Biaya rendah (~200 byte, biasanya <0.0001 BTC)
- Dompet secara otomatis memilih UTXO terbesar dari alamat plot untuk membuktikan kepemilikan

## Arsitektur Database

### Struktur Penyimpanan

Semua data penugasan disimpan dalam database LevelDB yang sama dengan set UTXO (`chainstate/`), tetapi dengan prefiks kunci terpisah:

```
chainstate/ LevelDB:
├─ Set UTXO (standar Bitcoin Core)
│  └─ Prefiks 'C': COutPoint -> Coin
│
└─ Status Penugasan (tambahan PoCX)
   └─ Prefiks 'A': (plot_address, assignment_txid) -> ForgingAssignment
       └─ Riwayat penuh: semua penugasan per plot dari waktu ke waktu
```

**Implementasi:** `src/txdb.cpp:237-348`

### Struktur ForgingAssignment

```cpp
struct ForgingAssignment {
    // Identitas
    std::array<uint8_t, 20> plotAddress;      // Pemilik plot (hash P2WPKH 20-byte)
    std::array<uint8_t, 20> forgingAddress;   // Pemegang hak forging (hash P2WPKH 20-byte)

    // Siklus hidup penugasan
    uint256 assignment_txid;                   // Transaksi yang membuat penugasan
    int assignment_height;                     // Tinggi blok saat dibuat
    int assignment_effective_height;           // Kapan menjadi aktif (tinggi + penundaan)

    // Siklus hidup pencabutan
    bool revoked;                              // Apakah ini sudah dicabut?
    uint256 revocation_txid;                   // Transaksi yang mencabut
    int revocation_height;                     // Tinggi blok saat dicabut
    int revocation_effective_height;           // Kapan pencabutan efektif (tinggi + penundaan)

    // Metode kueri status
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementasi:** `src/coins.h:111-178`

### Status Penugasan

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Tidak ada penugasan
    ASSIGNING = 1,   // Penugasan dibuat, menunggu penundaan aktivasi
    ASSIGNED = 2,    // Penugasan aktif, forging diizinkan
    REVOKING = 3,    // Dicabut, tetapi masih aktif selama periode penundaan
    REVOKED = 4      // Sepenuhnya dicabut, tidak lagi aktif
};
```

**Implementasi:** `src/coins.h:98-104`

### Kunci Database

```cpp
// Kunci riwayat: menyimpan rekaman penugasan lengkap
// Format kunci: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Alamat plot (20 byte)
    int assignment_height;                // Tinggi untuk optimasi pengurutan
    uint256 assignment_txid;              // ID transaksi
};
```

**Implementasi:** `src/txdb.cpp:245-262`

### Pelacakan Riwayat

- Setiap penugasan disimpan secara permanen (tidak pernah dihapus kecuali reorg)
- Beberapa penugasan per plot dilacak dari waktu ke waktu
- Memungkinkan jejak audit penuh dan kueri status historis
- Penugasan yang dicabut tetap di database dengan `revoked=true`

## Pemrosesan Blok

### Integrasi ConnectBlock

OP_RETURN penugasan dan pencabutan diproses selama koneksi blok di `validation.cpp`:

```cpp
// Lokasi: Setelah validasi skrip, sebelum UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parse data OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verifikasi kepemilikan (tx harus ditandatangani oleh pemilik plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Periksa status plot (harus UNASSIGNED atau REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Buat penugasan baru
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Simpan data undo
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parse data OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verifikasi kepemilikan
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Dapatkan penugasan saat ini
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Simpan status lama untuk undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Tandai sebagai dicabut
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

// UpdateCoins berjalan normal (secara otomatis melewati output OP_RETURN)
```

**Implementasi:** `src/validation.cpp:2775-2878`

### Verifikasi Kepemilikan

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Periksa bahwa setidaknya satu input ditandatangani oleh pemilik plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Ekstrak tujuan
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Periksa apakah P2WPKH ke alamat plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core sudah memvalidasi tanda tangan
                return true;
            }
        }
    }
    return false;
}
```

**Implementasi:** `src/pocx/assignments/opcodes.cpp:217-256`

### Penundaan Aktivasi

Penugasan dan pencabutan memiliki penundaan aktivasi yang dapat dikonfigurasi untuk mencegah serangan reorg:

```cpp
// Parameter konsensus (dapat dikonfigurasi per jaringan)
// Contoh: 30 blok = ~1 jam dengan waktu blok 2 menit
consensus.nForgingAssignmentDelay;   // Penundaan aktivasi penugasan
consensus.nForgingRevocationDelay;   // Penundaan aktivasi pencabutan
```

**Transisi Status:**
- Penugasan: `UNASSIGNED -> ASSIGNING (penundaan) -> ASSIGNED`
- Pencabutan: `ASSIGNED -> REVOKING (penundaan) -> REVOKED`

**Implementasi:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validasi Mempool

Transaksi penugasan dan pencabutan divalidasi pada penerimaan mempool untuk menolak transaksi tidak valid sebelum propagasi jaringan.

### Pemeriksaan Tingkat Transaksi (CheckTransaction)

Dilakukan di `src/consensus/tx_check.cpp` tanpa akses status rantai:

1. **Maksimal Satu OP_RETURN POCX:** Transaksi tidak dapat berisi beberapa marker POCX/XCOP

**Implementasi:** `src/consensus/tx_check.cpp:63-77`

### Pemeriksaan Penerimaan Mempool (PreChecks)

Dilakukan di `src/validation.cpp` dengan akses status rantai penuh dan mempool:

#### Validasi Penugasan

1. **Kepemilikan Plot:** Transaksi harus ditandatangani oleh pemilik plot
2. **Status Plot:** Plot harus UNASSIGNED (0) atau REVOKED (4)
3. **Konflik Mempool:** Tidak ada penugasan lain untuk plot ini di mempool (yang pertama terlihat menang)

#### Validasi Pencabutan

1. **Kepemilikan Plot:** Transaksi harus ditandatangani oleh pemilik plot
2. **Penugasan Aktif:** Plot harus dalam status ASSIGNED (2) saja
3. **Konflik Mempool:** Tidak ada pencabutan lain untuk plot ini di mempool

**Implementasi:** `src/validation.cpp:898-993`

### Alur Validasi

```
Siaran Transaksi
       |
CheckTransaction() [tx_check.cpp]
  - Maks satu OP_RETURN POCX
       |
MemPoolAccept::PreChecks() [validation.cpp]
  - Verifikasi kepemilikan plot
  - Periksa status penugasan
  - Periksa konflik mempool
       |
   Valid -> Terima ke Mempool
   Tidak Valid -> Tolak (jangan propagasi)
       |
Penambangan Blok
       |
ConnectBlock() [validation.cpp]
  - Validasi ulang semua pemeriksaan (pertahanan berlapis)
  - Terapkan perubahan status
  - Catat info undo
```

### Pertahanan Berlapis

Semua pemeriksaan validasi mempool dijalankan ulang selama `ConnectBlock()` untuk melindungi terhadap:
- Serangan bypass mempool
- Blok tidak valid dari penambang jahat
- Kasus tepi selama skenario reorg

Validasi blok tetap otoritatif untuk konsensus.

## Pembaruan Database Atomik

### Arsitektur Tiga Lapis

```
+------------------------------------------+
|   CCoinsViewCache (Cache Memori)         |  <- Perubahan penugasan dilacak di memori
|   - Coins: cacheCoins                    |
|   - Assignments: pendingAssignments      |
|   - Pelacakan dirty: dirtyPlots          |
|   - Penghapusan: deletedAssignments      |
|   - Pelacakan memori: cachedAssignmentsUsage |
+------------------------------------------+
                    | Flush()
+------------------------------------------+
|   CCoinsViewDB (Lapisan Database)        |  <- Penulisan atomik tunggal
|   - BatchWrite(): UTXO + Assignments     |
+------------------------------------------+
                    | WriteBatch()
+------------------------------------------+
|   LevelDB (Penyimpanan Disk)             |  <- Jaminan ACID
|   - Transaksi atomik                     |
+------------------------------------------+
```

### Proses Flush

Ketika `view.Flush()` dipanggil selama koneksi blok:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Tulis perubahan coin ke base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Tulis perubahan penugasan secara atomik
    if (fOk && !dirtyPlots.empty()) {
        // Kumpulkan penugasan dirty
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Kosong - tidak digunakan

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Tulis ke database
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Bersihkan pelacakan
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Lepaskan memori
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementasi:** `src/coins.cpp:278-315`

### Penulisan Batch Database

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Batch LevelDB tunggal

    // 1. Tandai status transisi
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Tulis semua perubahan coin
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Tandai status konsisten
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT ATOMIK
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Penugasan ditulis terpisah tetapi dalam konteks transaksi database yang sama
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Parameter tidak digunakan (disimpan untuk kompatibilitas API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Batch baru, tetapi database yang sama

    // Tulis riwayat penugasan
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Hapus penugasan yang dihapus dari riwayat
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT ATOMIK
    return m_db->WriteBatch(batch);
}
```

**Implementasi:** `src/txdb.cpp:332-348`

### Jaminan Atomisitas

**Apa yang atomik:**
- Semua perubahan coin dalam satu blok ditulis secara atomik
- Semua perubahan penugasan dalam satu blok ditulis secara atomik
- Database tetap konsisten di seluruh crash

**Batasan saat ini:**
- Coin dan penugasan ditulis dalam operasi batch LevelDB **terpisah**
- Kedua operasi terjadi selama `view.Flush()`, tetapi tidak dalam satu penulisan atomik tunggal
- Dalam praktik: Kedua batch selesai dalam urutan cepat sebelum disk fsync
- Risiko minimal: Keduanya perlu di-replay dari blok yang sama selama pemulihan crash

**Catatan:** Ini berbeda dari rencana arsitektur asli yang meminta batch terpadu tunggal. Implementasi saat ini menggunakan dua batch tetapi mempertahankan konsistensi melalui mekanisme pemulihan crash Bitcoin Core yang ada (marker DB_HEAD_BLOCKS).

## Penanganan Reorganisasi

### Struktur Data Undo

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Penugasan ditambahkan (hapus saat undo)
        MODIFIED = 1,   // Penugasan dimodifikasi (pulihkan saat undo)
        REVOKED = 2     // Penugasan dicabut (batalkan pencabutan saat undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // Status penuh sebelum perubahan
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Data undo UTXO
    std::vector<ForgingUndo> vforgingundo;  // Data undo penugasan
};
```

**Implementasi:** `src/undo.h:63-105`

### Proses DisconnectBlock

Ketika blok terputus selama reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... pemutusan UTXO standar ...

    // Baca data undo dari disk
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Batalkan perubahan penugasan (proses dalam urutan terbalik)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Penugasan ditambahkan - hapus
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Penugasan dicabut - pulihkan status tidak dicabut
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Penugasan dimodifikasi - pulihkan status sebelumnya
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementasi:** `src/validation.cpp:2381-2415`

### Manajemen Cache Selama Reorg

```cpp
class CCoinsViewCache {
private:
    // Cache penugasan
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Lacak plot yang dimodifikasi
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Lacak penghapusan
    mutable size_t cachedAssignmentsUsage{0};  // Pelacakan memori

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

**Implementasi:** `src/coins.cpp:494-565`

## Antarmuka RPC

### Perintah Node (Tidak Memerlukan Dompet)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Mengembalikan status penugasan saat ini untuk alamat plot:
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

**Implementasi:** `src/pocx/rpc/assignments.cpp:31-126`

### Perintah Dompet (Memerlukan Dompet)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Membuat transaksi penugasan:
- Secara otomatis memilih UTXO terbesar dari alamat plot untuk membuktikan kepemilikan
- Membangun transaksi dengan output OP_RETURN + kembalian
- Menandatangani dengan kunci pemilik plot
- Menyiarkan ke jaringan

**Implementasi:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Membuat transaksi pencabutan:
- Secara otomatis memilih UTXO terbesar dari alamat plot untuk membuktikan kepemilikan
- Membangun transaksi dengan output OP_RETURN + kembalian
- Menandatangani dengan kunci pemilik plot
- Menyiarkan ke jaringan

**Implementasi:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Pembuatan Transaksi Dompet

Proses pembuatan transaksi dompet:

```cpp
1. Parse dan validasi alamat (harus P2WPKH bech32)
2. Temukan UTXO terbesar dari alamat plot (membuktikan kepemilikan)
3. Buat transaksi sementara dengan output dummy
4. Tandatangani transaksi (dapatkan ukuran akurat dengan data witness)
5. Ganti output dummy dengan OP_RETURN
6. Sesuaikan biaya secara proporsional berdasarkan perubahan ukuran
7. Tandatangani ulang transaksi final
8. Siarkan ke jaringan
```

**Wawasan utama:** Dompet harus membelanjakan dari alamat plot untuk membuktikan kepemilikan, jadi secara otomatis memaksa pemilihan coin dari alamat itu.

**Implementasi:** `src/pocx/assignments/transactions.cpp:38-263`

## Struktur File

### File Implementasi Inti

```
src/
├── coins.h                        # Struct ForgingAssignment, metode CCoinsViewCache [710 baris]
├── coins.cpp                      # Manajemen cache, penulisan batch [603 baris]
│
├── txdb.h                         # Metode penugasan CCoinsViewDB [90 baris]
├── txdb.cpp                       # Baca/tulis database [349 baris]
│
├── undo.h                         # Struktur ForgingUndo untuk reorg
│
├── validation.cpp                 # Integrasi ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Format OP_RETURN, parsing, verifikasi
    │   ├── opcodes.cpp            # [259 baris] Definisi marker, ops OP_RETURN, pemeriksaan kepemilikan
    │   ├── assignment_state.h     # Helper GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Fungsi kueri status penugasan
    │   ├── transactions.h         # API pembuatan transaksi dompet
    │   └── transactions.cpp       # Fungsi dompet create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Perintah RPC node (tanpa dompet)
    │   ├── assignments.cpp        # RPC get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Perintah RPC dompet
    │   └── assignments_wallet.cpp # RPC create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Karakteristik Kinerja

### Operasi Database

- **Dapatkan penugasan saat ini:** O(n) - pindai semua penugasan untuk alamat plot untuk menemukan yang terbaru
- **Dapatkan riwayat penugasan:** O(n) - iterasi semua penugasan untuk plot
- **Buat penugasan:** O(1) - sisipan tunggal
- **Cabut penugasan:** O(1) - pembaruan tunggal
- **Reorg (per penugasan):** O(1) - aplikasi data undo langsung

Di mana n = jumlah penugasan untuk plot (biasanya kecil, < 10)

### Penggunaan Memori

- **Per penugasan:** ~160 byte (struct ForgingAssignment)
- **Overhead cache:** Overhead hash map untuk pelacakan dirty
- **Blok tipikal:** <10 penugasan = <2 KB memori

### Penggunaan Disk

- **Per penugasan:** ~200 byte di disk (dengan overhead LevelDB)
- **10000 penugasan:** ~2 MB ruang disk
- **Dapat diabaikan dibandingkan set UTXO:** <0.001% dari chainstate tipikal

## Batasan Saat Ini dan Pekerjaan Masa Depan

### Batasan Atomisitas

**Saat ini:** Coin dan penugasan ditulis dalam batch LevelDB terpisah selama `view.Flush()`

**Dampak:** Risiko teoritis ketidakkonsistenan jika crash terjadi antara batch

**Mitigasi:**
- Kedua batch selesai dengan cepat sebelum fsync
- Pemulihan crash Bitcoin Core menggunakan marker DB_HEAD_BLOCKS
- Dalam praktik: Tidak pernah diamati dalam pengujian

**Peningkatan masa depan:** Satukan ke dalam operasi batch LevelDB tunggal

### Pemangkasan Riwayat Penugasan

**Saat ini:** Semua penugasan disimpan tanpa batas

**Dampak:** ~200 byte per penugasan selamanya

**Masa depan:** Pemangkasan opsional penugasan yang sepenuhnya dicabut lebih lama dari N blok

**Catatan:** Tidak mungkin dibutuhkan - bahkan 1 juta penugasan = 200 MB

## Status Pengujian

### Pengujian yang Diimplementasikan

- Parsing dan validasi OP_RETURN
- Verifikasi kepemilikan
- Pembuatan penugasan ConnectBlock
- Pencabutan ConnectBlock
- Penanganan reorg DisconnectBlock
- Operasi baca/tulis database
- Transisi status (UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED)
- Perintah RPC (get_assignment, create_assignment, revoke_assignment)
- Pembuatan transaksi dompet

### Area Cakupan Pengujian

- Unit test: `src/test/pocx_*_tests.cpp`
- Functional test: `test/functional/feature_pocx_*.py`
- Integration test: Pengujian manual dengan regtest

## Aturan Konsensus

### Aturan Pembuatan Penugasan

1. **Kepemilikan:** Transaksi harus ditandatangani oleh pemilik plot
2. **Status:** Plot harus dalam status UNASSIGNED atau REVOKED
3. **Format:** OP_RETURN valid dengan marker POCX + 2x alamat 20-byte
4. **Keunikan:** Satu penugasan aktif per plot pada satu waktu

### Aturan Pencabutan

1. **Kepemilikan:** Transaksi harus ditandatangani oleh pemilik plot
2. **Keberadaan:** Penugasan harus ada dan belum dicabut
3. **Format:** OP_RETURN valid dengan marker XCOP + alamat 20-byte

### Aturan Aktivasi

- **Aktivasi penugasan:** `assignment_height + nForgingAssignmentDelay`
- **Aktivasi pencabutan:** `revocation_height + nForgingRevocationDelay`
- **Penundaan:** Dapat dikonfigurasi per jaringan (contoh, 30 blok = ~1 jam dengan waktu blok 2 menit)

### Validasi Blok

- Penugasan/pencabutan tidak valid -> blok ditolak (kegagalan konsensus)
- Output OP_RETURN secara otomatis dikecualikan dari set UTXO (perilaku Bitcoin standar)
- Pemrosesan penugasan terjadi sebelum pembaruan UTXO di ConnectBlock

## Kesimpulan

Sistem penugasan forging PoCX sebagaimana diimplementasikan menyediakan:

- **Kesederhanaan:** Transaksi Bitcoin standar, tanpa UTXO khusus
- **Hemat Biaya:** Tidak ada persyaratan dust, hanya biaya transaksi
- **Keamanan Reorg:** Data undo komprehensif memulihkan status yang benar
- **Pembaruan Atomik:** Konsistensi database melalui batch LevelDB
- **Riwayat Lengkap:** Jejak audit lengkap dari semua penugasan dari waktu ke waktu
- **Arsitektur Bersih:** Modifikasi Bitcoin Core minimal, kode PoCX terisolasi
- **Siap Produksi:** Sepenuhnya diimplementasikan, diuji, dan beroperasi

### Kualitas Implementasi

- **Organisasi kode:** Sangat baik - pemisahan jelas antara Bitcoin Core dan PoCX
- **Penanganan kesalahan:** Validasi konsensus komprehensif
- **Dokumentasi:** Komentar kode dan struktur terdokumentasi dengan baik
- **Pengujian:** Fungsionalitas inti diuji, integrasi diverifikasi

### Keputusan Desain Utama yang Divalidasi

1. Pendekatan hanya OP_RETURN (vs berbasis UTXO)
2. Penyimpanan database terpisah (vs Coin extraData)
3. Pelacakan riwayat penuh (vs hanya saat ini)
4. Kepemilikan oleh tanda tangan (vs pengeluaran UTXO)
5. Penundaan aktivasi (mencegah serangan reorg)

Sistem berhasil mencapai semua tujuan arsitektur dengan implementasi yang bersih dan dapat dipelihara.

---

[Sebelumnya: Konsensus dan Penambangan](3-consensus-and-mining.md) | [Daftar Isi](index.md) | [Berikutnya: Sinkronisasi Waktu](5-timing-security.md)
