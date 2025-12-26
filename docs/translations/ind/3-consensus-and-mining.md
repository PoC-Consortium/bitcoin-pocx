[Sebelumnya: Format Plot](2-plot-format.md) | [Daftar Isi](index.md) | [Berikutnya: Penugasan Forging](4-forging-assignments.md)

---

# Bab 3: Proses Konsensus dan Penambangan Bitcoin-PoCX

Spesifikasi teknis lengkap mekanisme konsensus dan proses penambangan PoCX (Proof of Capacity generasi berikutnya) yang terintegrasi ke dalam Bitcoin Core.

---

## Daftar Isi

1. [Gambaran Umum](#gambaran-umum)
2. [Arsitektur Konsensus](#arsitektur-konsensus)
3. [Proses Penambangan](#proses-penambangan)
4. [Validasi Blok](#validasi-blok)
5. [Sistem Penugasan](#sistem-penugasan)
6. [Propagasi Jaringan](#propagasi-jaringan)
7. [Detail Teknis](#detail-teknis)

---

## Gambaran Umum

Bitcoin-PoCX mengimplementasikan mekanisme konsensus Proof of Capacity murni sebagai pengganti lengkap untuk Proof of Work Bitcoin. Ini adalah rantai baru tanpa persyaratan kompatibilitas mundur.

**Properti Utama:**
- **Hemat Energi:** Penambangan menggunakan file plot yang sudah dihasilkan sebelumnya daripada hashing komputasi
- **Deadline Time Bended:** Transformasi distribusi (eksponensial ke chi-squared) mengurangi blok panjang, meningkatkan rata-rata waktu blok
- **Dukungan Penugasan:** Pemilik plot dapat mendelegasikan hak forging ke alamat lain
- **Integrasi C++ Native:** Algoritma kriptografis diimplementasikan dalam C++ untuk validasi konsensus

**Alur Penambangan:**
```
Miner Eksternal -> get_mining_info -> Hitung Nonce -> submit_nonce ->
Antrian Forger -> Tunggu Deadline -> Forging Blok -> Propagasi Jaringan ->
Validasi Blok -> Ekstensi Rantai
```

---

## Arsitektur Konsensus

### Struktur Blok

Blok PoCX memperluas struktur blok Bitcoin dengan field konsensus tambahan:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plot (32 byte)
    std::array<uint8_t, 20> account_id;       // Alamat plot (hash160 20-byte)
    uint32_t compression;                     // Tingkat penskalaan (1-255)
    uint64_t nonce;                           // Nonce penambangan (64-bit)
    uint64_t quality;                         // Kualitas yang diklaim (output hash PoC)
};

class CBlockHeader {
    // Field Bitcoin standar
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Field konsensus PoCX (menggantikan nBits dan nNonce)
    int nHeight;                              // Tinggi blok (validasi bebas konteks)
    uint256 generationSignature;              // Tanda tangan generasi (entropi penambangan)
    uint64_t nBaseTarget;                     // Parameter kesulitan (kebalikan kesulitan)
    PoCXProof pocxProof;                      // Bukti penambangan

    // Field tanda tangan blok
    std::array<uint8_t, 33> vchPubKey;        // Kunci publik terkompresi (33 byte)
    std::array<uint8_t, 65> vchSignature;     // Tanda tangan kompak (65 byte)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaksi
};
```

**Catatan:** Tanda tangan (`vchSignature`) dikecualikan dari komputasi hash blok untuk mencegah maleabilitas.

**Implementasi:** `src/primitives/block.h`

### Tanda Tangan Generasi

Tanda tangan generasi menciptakan entropi penambangan dan mencegah serangan prakomputasi.

**Kalkulasi:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Blok Genesis:** Menggunakan tanda tangan generasi awal yang di-hardcode

**Implementasi:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Kesulitan)

Base target adalah kebalikan dari kesulitan - nilai lebih tinggi berarti penambangan lebih mudah.

**Algoritma Penyesuaian:**
- Target waktu blok: 120 detik (mainnet), 1 detik (regtest)
- Interval penyesuaian: Setiap blok
- Menggunakan rata-rata bergerak dari base target terbaru
- Dibatasi untuk mencegah ayunan kesulitan ekstrem

**Implementasi:** `src/consensus/params.h`, penyesuaian kesulitan dalam pembuatan blok

### Tingkat Penskalaan

PoCX mendukung proof-of-work yang dapat diskalakan dalam file plot melalui tingkat penskalaan (Xn).

**Batas Dinamis:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Tingkat minimum yang diterima
    uint8_t nPoCXTargetCompression;  // Tingkat yang direkomendasikan
};
```

**Jadwal Peningkatan Penskalaan:**
- Interval eksponensial: Tahun 4, 12, 28, 60, 124 (halving 1, 3, 7, 15, 31)
- Tingkat penskalaan minimum meningkat 1
- Tingkat penskalaan target meningkat 1
- Mempertahankan margin keamanan antara pembuatan plot dan biaya pencarian
- Tingkat penskalaan maksimum: 255

**Implementasi:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Proses Penambangan

### 1. Pengambilan Informasi Penambangan

**Perintah RPC:** `get_mining_info`

**Proses:**
1. Panggil `GetNewBlockContext(chainman)` untuk mengambil status blockchain saat ini
2. Hitung batas kompresi dinamis untuk tinggi saat ini
3. Kembalikan parameter penambangan

**Respons:**
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

**Implementasi:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Catatan:**
- Tidak ada kunci yang ditahan selama generasi respons
- Akuisisi konteks menangani `cs_main` secara internal
- `block_hash` disertakan untuk referensi tetapi tidak digunakan dalam validasi

### 2. Penambangan Eksternal

**Tanggung jawab miner eksternal:**
1. Baca file plot dari disk
2. Hitung scoop berdasarkan tanda tangan generasi dan tinggi
3. Temukan nonce dengan deadline terbaik
4. Kirim ke node via `submit_nonce`

**Format File Plot:**
- Berbasis format POC2 (Burstcoin)
- Ditingkatkan dengan perbaikan keamanan dan peningkatan skalabilitas
- Lihat atribusi di `CLAUDE.md`

**Implementasi Miner:** Eksternal (contoh, berbasis Scavenger)

### 3. Pengiriman dan Validasi Nonce

**Perintah RPC:** `submit_nonce`

**Parameter:**
```
height, generation_signature, account_id, seed, nonce, quality (opsional)
```

**Alur Validasi (Urutan yang Dioptimalkan):**

#### Langkah 1: Validasi Format Cepat
```cpp
// Account ID: 40 karakter hex = 20 byte
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 karakter hex = 32 byte
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Langkah 2: Akuisisi Konteks
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Mengembalikan: height, generation_signature, base_target, block_hash
```

**Penguncian:** `cs_main` ditangani secara internal, tidak ada kunci yang ditahan di thread RPC

#### Langkah 3: Validasi Konteks
```cpp
// Pemeriksaan tinggi
if (height != context.height) reject;

// Pemeriksaan tanda tangan generasi
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Langkah 4: Verifikasi Dompet
```cpp
// Tentukan penanda tangan efektif (mempertimbangkan penugasan)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Periksa apakah node memiliki kunci privat untuk penanda tangan efektif
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Dukungan Penugasan:** Pemilik plot dapat menugaskan hak forging ke alamat lain. Dompet harus memiliki kunci untuk penanda tangan efektif, tidak harus pemilik plot.

#### Langkah 5: Validasi Bukti
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 byte
    block_height,
    nonce,
    seed,                // 32 byte
    min_compression,
    max_compression,
    &result             // Output: quality, deadline
);
```

**Algoritma:**
1. Dekode tanda tangan generasi dari hex
2. Hitung kualitas terbaik dalam rentang kompresi menggunakan algoritma yang dioptimalkan SIMD
3. Validasi kualitas memenuhi persyaratan kesulitan
4. Kembalikan nilai kualitas mentah

**Implementasi:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Langkah 6: Kalkulasi Time Bending
```cpp
// Deadline yang disesuaikan kesulitan mentah (detik)
uint64_t deadline_seconds = quality / base_target;

// Waktu forge Time Bended (detik)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Formula Time Bending:**
```
Y = scale * (X^(1/3))
di mana:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ~ 0.892979511
```

**Tujuan:** Mengubah distribusi eksponensial ke chi-squared. Solusi yang sangat baik di-forge lebih lambat (jaringan punya waktu untuk memindai disk), solusi buruk ditingkatkan. Mengurangi blok panjang, mempertahankan rata-rata 120 detik.

**Implementasi:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Langkah 7: Pengiriman Forger
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // BUKAN deadline - dihitung ulang di forger
    height,
    generation_signature
);
```

**Desain Berbasis Antrian:**
- Pengiriman selalu berhasil (ditambahkan ke antrian)
- RPC segera kembali
- Thread pekerja memproses secara asinkron

**Implementasi:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Pemrosesan Antrian Forger

**Arsitektur:**
- Thread pekerja persisten tunggal
- Antrian pengiriman FIFO
- Status forging bebas kunci (hanya thread pekerja)
- Tidak ada kunci bersarang (pencegahan deadlock)

**Loop Utama Thread Pekerja:**
```cpp
while (!shutdown) {
    // 1. Periksa pengiriman yang diantri
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Tunggu deadline atau pengiriman baru
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logika ProcessSubmission:**
```cpp
1. Dapatkan konteks segar: GetNewBlockContext(*chainman)

2. Pemeriksaan keusangan (buang diam-diam):
   - Ketidakcocokan tinggi -> buang
   - Ketidakcocokan tanda tangan generasi -> buang
   - Hash blok tip berubah (reorg) -> reset status forging

3. Perbandingan kualitas:
   - Jika quality >= current_best -> buang

4. Hitung deadline Time Bended:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Perbarui status forging:
   - Batalkan forging yang ada (jika lebih baik ditemukan)
   - Simpan: account_id, seed, nonce, quality, deadline
   - Hitung: forge_time = block_time + deadline_seconds
   - Simpan hash tip untuk deteksi reorg
```

**Implementasi:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Tunggu Deadline dan Forging Blok

**WaitForDeadlineOrNewSubmission:**

**Kondisi Tunggu:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Ketika Deadline Tercapai - Validasi Konteks Segar:**
```cpp
1. Dapatkan konteks saat ini: GetNewBlockContext(*chainman)

2. Validasi tinggi:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validasi tanda tangan generasi:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Kasus tepi base target:
   if (forging_base_target != current_base_target) {
       // Hitung ulang deadline dengan base target baru
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Tunggu lagi
   }

5. Semua valid -> ForgeBlock()
```

**Proses ForgeBlock:**

```cpp
1. Tentukan penanda tangan efektif (dukungan penugasan):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Buat skrip coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Bayar penanda tangan efektif

3. Buat template blok:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Tambahkan bukti PoCX:
   block.pocxProof.account_id = plot_address;    // Alamat plot asli
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Hitung ulang merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Tandatangani blok:
   // Gunakan kunci penanda tangan efektif (mungkin berbeda dari pemilik plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Kirim ke rantai:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Penanganan hasil:
   if (accepted) {
       log_success();
       reset_forging_state();  // Siap untuk blok berikutnya
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementasi:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Keputusan Desain Utama:**
- Coinbase membayar penanda tangan efektif (menghormati penugasan)
- Bukti berisi alamat plot asli (untuk validasi)
- Tanda tangan dari kunci penanda tangan efektif (bukti kepemilikan)
- Pembuatan template menyertakan transaksi mempool secara otomatis

---

## Validasi Blok

### Alur Validasi Blok Masuk

Ketika blok diterima dari jaringan atau dikirim secara lokal, ia menjalani validasi dalam beberapa tahap:

### Tahap 1: Validasi Header (CheckBlockHeader)

**Validasi Bebas Konteks:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validasi PoCX (ketika ENABLE_POCX didefinisikan):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validasi tanda tangan dasar (belum ada dukungan penugasan)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validasi Tanda Tangan Dasar:**
1. Periksa keberadaan field pubkey dan tanda tangan
2. Validasi ukuran pubkey (33 byte terkompresi)
3. Validasi ukuran tanda tangan (65 byte kompak)
4. Pulihkan pubkey dari tanda tangan: `pubkey.RecoverCompact(hash, signature)`
5. Verifikasi pubkey yang dipulihkan cocok dengan pubkey yang disimpan

**Implementasi:** `src/validation.cpp:CheckBlockHeader()`
**Logika Tanda Tangan:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Tahap 2: Validasi Blok (CheckBlock)

**Validasi:**
- Kebenaran merkle root
- Validitas transaksi
- Persyaratan coinbase
- Batas ukuran blok
- Aturan konsensus Bitcoin standar

**Implementasi:** `src/consensus/validation.cpp:CheckBlock()`

### Tahap 3: Validasi Header Kontekstual (ContextualCheckBlockHeader)

**Validasi Khusus PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Langkah 1: Validasi tanda tangan generasi
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Langkah 2: Validasi base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Langkah 3: Validasi proof of capacity
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

    // Langkah 4: Verifikasi waktu deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Langkah Validasi:**
1. **Tanda Tangan Generasi:** Harus cocok dengan nilai yang dihitung dari blok sebelumnya
2. **Base Target:** Harus cocok dengan kalkulasi penyesuaian kesulitan
3. **Tingkat Penskalaan:** Harus memenuhi minimum jaringan (`compression >= min_compression`)
4. **Klaim Kualitas:** Kualitas yang dikirim harus cocok dengan kualitas yang dihitung dari bukti
5. **Proof of Capacity:** Validasi bukti kriptografis (dioptimalkan SIMD)
6. **Waktu Deadline:** Deadline time-bended (`poc_time`) harus <= waktu berlalu

**Implementasi:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Tahap 4: Koneksi Blok (ConnectBlock)

**Validasi Kontekstual Penuh:**

```cpp
#ifdef ENABLE_POCX
    // Validasi tanda tangan yang diperluas dengan dukungan penugasan
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validasi Tanda Tangan yang Diperluas:**
1. Lakukan validasi tanda tangan dasar
2. Ekstrak ID akun dari pubkey yang dipulihkan
3. Dapatkan penanda tangan efektif untuk alamat plot: `GetEffectiveSigner(plot_address, height, view)`
4. Verifikasi akun pubkey cocok dengan penanda tangan efektif

**Logika Penugasan:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Kembalikan penanda tangan yang ditugaskan
    }

    return plotAddress;  // Tidak ada penugasan - pemilik plot menandatangani
}
```

**Implementasi:**
- Koneksi: `src/validation.cpp:ConnectBlock()`
- Validasi yang diperluas: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logika penugasan: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Tahap 5: Aktivasi Rantai

**Alur ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Validasi dan simpan ke disk
    2. ActivateBestChain -> Perbarui chain tip jika ini rantai terbaik
    3. Beritahu jaringan tentang blok baru
}
```

**Implementasi:** `src/validation.cpp:ProcessNewBlock()`

### Ringkasan Validasi

**Jalur Validasi Lengkap:**
```
Terima Blok
    |
CheckBlockHeader (tanda tangan dasar)
    |
CheckBlock (transaksi, merkle)
    |
ContextualCheckBlockHeader (gen sig, base target, bukti PoC, deadline)
    |
ConnectBlock (tanda tangan diperluas dengan penugasan, transisi status)
    |
ActivateBestChain (penanganan reorg, ekstensi rantai)
    |
Propagasi Jaringan
```

---

## Sistem Penugasan

### Gambaran Umum

Penugasan memungkinkan pemilik plot untuk mendelegasikan hak forging ke alamat lain sambil mempertahankan kepemilikan plot.

**Kasus Penggunaan:**
- Penambangan pool (plot menugaskan ke alamat pool)
- Penyimpanan dingin (kunci penambangan terpisah dari kepemilikan plot)
- Penambangan multi-pihak (infrastruktur bersama)

### Arsitektur Penugasan

**Desain Hanya OP_RETURN:**
- Penugasan disimpan dalam output OP_RETURN (tanpa UTXO)
- Tidak ada persyaratan pengeluaran (tidak ada dust, tidak ada biaya untuk menyimpan)
- Dilacak di status diperluas CCoinsViewCache
- Diaktifkan setelah periode penundaan (default: 4 blok)

**Status Penugasan:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Tidak ada penugasan
    ASSIGNING = 1,   // Penugasan menunggu aktivasi (periode penundaan)
    ASSIGNED = 2,    // Penugasan aktif, forging diizinkan
    REVOKING = 3,    // Pencabutan menunggu (periode penundaan, masih aktif)
    REVOKED = 4      // Pencabutan selesai, penugasan tidak lagi aktif
};
```

### Membuat Penugasan

**Format Transaksi:**
```cpp
Transaction {
    inputs: [any]  // Membuktikan kepemilikan alamat plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Aturan Validasi:**
1. Input harus ditandatangani oleh pemilik plot (membuktikan kepemilikan)
2. OP_RETURN berisi data penugasan yang valid
3. Plot harus UNASSIGNED atau REVOKED
4. Tidak ada penugasan duplikat yang tertunda di mempool
5. Biaya transaksi minimum dibayar

**Aktivasi:**
- Penugasan menjadi ASSIGNING pada tinggi konfirmasi
- Menjadi ASSIGNED setelah periode penundaan (4 blok regtest, 30 blok mainnet)
- Penundaan mencegah penugasan ulang cepat selama perlombaan blok

**Implementasi:** `src/script/forging_assignment.h`, validasi di ConnectBlock

### Mencabut Penugasan

**Format Transaksi:**
```cpp
Transaction {
    inputs: [any]  // Membuktikan kepemilikan alamat plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efek:**
- Transisi status segera ke REVOKED
- Pemilik plot dapat segera melakukan forge
- Dapat membuat penugasan baru setelahnya

### Validasi Penugasan Selama Penambangan

**Penentuan Penanda Tangan Efektif:**
```cpp
// Dalam validasi submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Dalam forging blok
coinbase_script = P2WPKH(effective_signer);  // Hadiah masuk ke sini

// Dalam tanda tangan blok
signature = effective_signer_key.SignCompact(hash);  // Harus menandatangani dengan penanda tangan efektif
```

**Validasi Blok:**
```cpp
// Dalam VerifyPoCXBlockCompactSignature (diperluas)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Properti Utama:**
- Bukti selalu berisi alamat plot asli
- Tanda tangan harus dari penanda tangan efektif
- Coinbase membayar penanda tangan efektif
- Validasi menggunakan status penugasan pada tinggi blok

---

## Propagasi Jaringan

### Pengumuman Blok

**Protokol P2P Bitcoin Standar:**
1. Blok yang di-forge dikirim via `ProcessNewBlock()`
2. Blok divalidasi dan ditambahkan ke rantai
3. Notifikasi jaringan: `GetMainSignals().BlockConnected()`
4. Lapisan P2P menyiarkan blok ke peer

**Implementasi:** net_processing Bitcoin Core standar

### Relay Blok

**Compact Blocks (BIP 152):**
- Digunakan untuk propagasi blok yang efisien
- Hanya ID transaksi yang dikirim awalnya
- Peer meminta transaksi yang hilang

**Relay Blok Penuh:**
- Fallback ketika compact block gagal
- Data blok lengkap ditransmisikan

### Reorganisasi Rantai

**Penanganan Reorg:**
```cpp
// Di thread pekerja forger
if (current_tip_hash != stored_tip_hash) {
    // Reorganisasi rantai terdeteksi
    reset_forging_state();
    log("Chain tip berubah, mereset forging");
}
```

**Tingkat Blockchain:**
- Penanganan reorg Bitcoin Core standar
- Rantai terbaik ditentukan oleh chainwork
- Blok yang terputus dikembalikan ke mempool

---

## Detail Teknis

### Pencegahan Deadlock

**Pola Deadlock ABBA (Dicegah):**
```
Thread A: cs_main -> cs_wallet
Thread B: cs_wallet -> cs_main
```

**Solusi:**
1. **submit_nonce:** Nol penggunaan cs_main
   - `GetNewBlockContext()` menangani penguncian secara internal
   - Semua validasi sebelum pengiriman forger

2. **Forger:** Arsitektur berbasis antrian
   - Thread pekerja tunggal (tidak ada thread join)
   - Konteks segar pada setiap akses
   - Tidak ada kunci bersarang

3. **Pemeriksaan dompet:** Dilakukan sebelum operasi mahal
   - Penolakan awal jika tidak ada kunci tersedia
   - Terpisah dari akses status blockchain

### Optimasi Kinerja

**Validasi Gagal-Cepat:**
```cpp
1. Pemeriksaan format (segera)
2. Validasi konteks (ringan)
3. Verifikasi dompet (lokal)
4. Validasi bukti (SIMD mahal)
```

**Pengambilan Konteks Tunggal:**
- Satu panggilan `GetNewBlockContext()` per pengiriman
- Cache hasil untuk beberapa pemeriksaan
- Tidak ada akuisisi cs_main berulang

**Efisiensi Antrian:**
- Struktur pengiriman ringan
- Tidak ada base_target/deadline dalam antrian (dihitung ulang segar)
- Footprint memori minimal

### Penanganan Keusangan

**Desain Forger "Bodoh":**
- Tidak ada langganan event blockchain
- Validasi malas saat diperlukan
- Pembuangan diam untuk pengiriman usang

**Manfaat:**
- Arsitektur sederhana
- Tidak ada sinkronisasi kompleks
- Robust terhadap kasus tepi

**Kasus Tepi yang Ditangani:**
- Perubahan tinggi -> buang
- Perubahan tanda tangan generasi -> buang
- Perubahan base target -> hitung ulang deadline
- Reorg -> reset status forging

### Detail Kriptografis

**Tanda Tangan Generasi:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash Tanda Tangan Blok:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Format Tanda Tangan Kompak:**
- 65 byte: [recovery_id][r][s]
- Memungkinkan pemulihan kunci publik
- Digunakan untuk efisiensi ruang

**Account ID:**
- HASH160 20-byte dari kunci publik terkompresi
- Cocok dengan format alamat Bitcoin (P2PKH, P2WPKH)

### Peningkatan Masa Depan

**Batasan yang Didokumentasikan:**
1. Tidak ada metrik kinerja (tingkat pengiriman, distribusi deadline)
2. Tidak ada kategorisasi kesalahan detail untuk penambang
3. Kueri status forger terbatas (deadline saat ini, kedalaman antrian)

**Potensi Peningkatan:**
- RPC untuk status forger
- Metrik untuk efisiensi penambangan
- Logging yang ditingkatkan untuk debugging
- Dukungan protokol pool

---

## Referensi Kode

**Implementasi Inti:**
- Antarmuka RPC: `src/pocx/rpc/mining.cpp`
- Antrian Forger: `src/pocx/mining/scheduler.cpp`
- Validasi Konsensus: `src/pocx/consensus/validation.cpp`
- Validasi Bukti: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Validasi Blok: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logika Penugasan: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Manajemen Konteks: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Struktur Data:**
- Format Blok: `src/primitives/block.h`
- Parameter Konsensus: `src/consensus/params.h`
- Pelacakan Penugasan: `src/coins.h` (ekstensi CCoinsViewCache)

---

## Lampiran: Spesifikasi Algoritma

### Formula Time Bending

**Definisi Matematis:**
```
deadline_seconds = quality / base_target  (mentah)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

di mana:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ~ 0.892979511
```

**Implementasi:**
- Aritmetika fixed-point (format Q42)
- Kalkulasi akar pangkat tiga hanya integer
- Dioptimalkan untuk aritmetika 256-bit

### Kalkulasi Kualitas

**Proses:**
1. Hasilkan scoop dari tanda tangan generasi dan tinggi
2. Baca data plot untuk scoop yang dihitung
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Uji tingkat penskalaan dari min ke max
5. Kembalikan kualitas terbaik yang ditemukan

**Penskalaan:**
- Level X0: Baseline POC2 (teoritis)
- Level X1: Baseline XOR-transpose
- Level Xn: 2^(n-1) x pekerjaan X1 tertanam
- Penskalaan lebih tinggi = lebih banyak pekerjaan pembuatan plot

### Penyesuaian Base Target

**Penyesuaian setiap blok:**
1. Hitung rata-rata bergerak dari base target terbaru
2. Hitung rentang waktu aktual vs rentang waktu target untuk jendela bergulir
3. Sesuaikan base target secara proporsional
4. Batasi untuk mencegah ayunan ekstrem

**Formula:**
```
avg_base_target = moving_average(base target terbaru)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Dokumentasi ini mencerminkan implementasi konsensus PoCX lengkap per Oktober 2025.*

---

[Sebelumnya: Format Plot](2-plot-format.md) | [Daftar Isi](index.md) | [Berikutnya: Penugasan Forging](4-forging-assignments.md)
