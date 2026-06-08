[Sebelumnya: Parameter Jaringan](6-network-parameters.md) | [Daftar Isi](index.md) | [Berikutnya: Panduan Dompet](8-wallet-guide.md)

---

# Bab 7: Referensi Antarmuka RPC

Referensi lengkap untuk perintah RPC Bitcoin-PoCX, termasuk RPC penambangan, manajemen penugasan, dan RPC blockchain yang dimodifikasi.

---

## Daftar Isi

1. [Konfigurasi](#konfigurasi)
2. [RPC Penambangan PoCX](#rpc-penambangan-pocx)
3. [RPC Penugasan](#rpc-penugasan)
4. [RPC Blockchain yang Dimodifikasi](#rpc-blockchain-yang-dimodifikasi)
5. [RPC yang Dinonaktifkan](#rpc-yang-dinonaktifkan)
6. [Contoh Integrasi](#contoh-integrasi)

---

## Konfigurasi

### Mining RPCs

Mining RPCs are always available when compiled with `ENABLE_POCX=ON`. Standard RPC authentication is required. Mining RPCs are rate-limited by queue capacity.

**Implementation**: `src/pocx/rpc/mining.cpp`

### get_mining_info

**Kategori**: mining
**Memerlukan Dompet**: Tidak

**Tujuan**: Mengembalikan parameter penambangan saat ini yang diperlukan untuk miner eksternal untuk memindai file plot dan menghitung deadline.

**Parameter**: Tidak ada

**Nilai Kembalian**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 karakter
  "base_target": 36650387592,                // numerik
  "height": 12345,                           // numerik, tinggi blok berikutnya
  "block_hash": "def456...",                 // hex, blok sebelumnya
  "target_quality": 18446744073709551615,    // uint64_max (semua solusi diterima)
  "minimum_compression_level": 1,            // numerik
  "target_compression_level": 2              // numerik
}
```

**Deskripsi Field**:
- `generation_signature`: Entropi penambangan deterministik untuk tinggi blok ini
- `base_target`: Kesulitan saat ini (lebih tinggi = lebih mudah)
- `height`: Tinggi blok yang harus ditargetkan penambang
- `block_hash`: Hash blok sebelumnya (informasional)
- `target_quality`: Ambang kualitas (saat ini uint64_max, tanpa penyaringan)
- `minimum_compression_level`: Kompresi minimum yang diperlukan untuk validasi
- `target_compression_level`: Kompresi yang direkomendasikan untuk penambangan optimal

**Kode Kesalahan**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node masih menyinkronkan

**Contoh**:
```bash
bitcoin-cli get_mining_info
```

**Implementasi**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategori**: mining
**Memerlukan Dompet**: Ya (untuk kunci privat)

**Tujuan**: Mengirim solusi penambangan PoCX. Memvalidasi bukti, mengantri untuk forging time-bended, dan secara otomatis membuat blok pada waktu yang dijadwalkan.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (tepat 40 karakter hex = 20 byte; alamat tidak diterima)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Nilai Kembalian** (sukses):
```json
{
  "raw_quality": 120,       // kualitas mentah dari validasi bukti
  "poc_time": 45            // waktu forge time-bended dalam detik
}
```

Tidak ada field `accepted`. Saat ditolak, RPC **tidak** mengembalikan objek JSON — melainkan melempar `JSONRPCError` (lihat Kode Kesalahan di bawah).

**Langkah Validasi**:
1. **Validasi Format** (gagal-cepat):
   - Account ID: tepat 40 karakter hex
   - Seed: tepat 64 karakter hex
2. **Validasi Konteks**:
   - Block hash must match current tip
   - Tinggi harus cocok dengan tip saat ini + 1
   - Tanda tangan generasi harus cocok dengan yang saat ini
   - Base target must match current
3. **Verifikasi Dompet**:
   - Tentukan penanda tangan efektif (periksa penugasan aktif)
   - Verifikasi dompet memiliki kunci privat untuk penanda tangan efektif
4. **Validasi Bukti** (mahal):
   - Validasi bukti PoCX dengan batas kompresi
   - Hitung kualitas mentah
5. **Pengiriman Scheduler**:
   - Antri nonce untuk forging time-bended
   - Blok akan dibuat secara otomatis pada forge_time

**Kode Kesalahan** (dilempar sebagai `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Format tidak valid (account_id, seed) atau ketidakcocokan tinggi (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Ketidakcocokan tanda tangan generasi atau validasi bukti gagal
- `RPC_INVALID_ADDRESS_OR_KEY`: Tidak ada kunci privat untuk penanda tangan efektif
- `RPC_WALLET_UNLOCK_NEEDED`: Dompet yang menyimpan kunci penanda tangan efektif terkunci (buka dengan `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Antrian pengiriman penuh
- `RPC_INTERNAL_ERROR`: Gagal menginisialisasi scheduler PoCX

**Kode Kesalahan Validasi Bukti**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Contoh**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Catatan**:
- Pengiriman bersifat asinkron - RPC segera kembali, blok di-forge kemudian
- Time Bending menunda solusi yang baik untuk memungkinkan pemindaian plot seluruh jaringan
- Sistem penugasan: jika plot ditugaskan, dompet harus memiliki kunci alamat forging
- Batas kompresi disesuaikan secara dinamis berdasarkan tinggi blok

**Implementasi**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC Penugasan

### get_assignment

**Kategori**: mining
**Memerlukan Dompet**: Tidak

**Tujuan**: Kueri status penugasan forging untuk alamat plot. Hanya-baca, tidak memerlukan dompet.

**Parameter**:
1. `plot_address` (string, wajib) - Alamat plot (format P2WPKH bech32)
2. `height` (numerik, opsional) - Tinggi blok untuk dikueri (default: tip saat ini)

**Nilai Kembalian** (tidak ada penugasan):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Nilai Kembalian** (penugasan aktif):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Nilai Kembalian** (mencabut):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Status Penugasan**:
- `UNASSIGNED`: Tidak ada penugasan
- `ASSIGNING`: Tx penugasan dikonfirmasi, penundaan aktivasi sedang berlangsung
- `ASSIGNED`: Penugasan aktif, hak forging didelegasikan
- `REVOKING`: Tx pencabutan dikonfirmasi, masih aktif hingga penundaan berlalu
- `REVOKED`: Pencabutan selesai, hak forging dikembalikan ke pemilik plot

**Kode Kesalahan**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Alamat tidak valid atau bukan P2WPKH (bech32)

**Contoh**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementasi**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategori**: wallet
**Memerlukan Dompet**: Ya (harus dimuat dan tidak terkunci)

**Tujuan**: Membuat transaksi penugasan forging untuk mendelegasikan hak forging ke alamat lain (contoh, pool penambangan).

**Parameter**:
1. `plot_address` (string, wajib) - Alamat pemilik plot (harus memiliki kunci privat, P2WPKH bech32)
2. `forging_address` (string, wajib) - Alamat untuk menugaskan hak forging (P2WPKH bech32)
3. `fee_rate` (numerik, opsional) - Tingkat biaya dalam BTCX/kvB (default: `0` → estimasi biaya minimum standar dompet; default 10x minRelayFee hanya berlaku untuk dialog GUI Qt, bukan RPC ini)

**Nilai Kembalian**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Persyaratan**:
- Dompet dimuat dan tidak terkunci
- Kunci privat untuk plot_address ada di dompet
- Kedua alamat harus P2WPKH (format bech32: pocx1q... mainnet, tpocx1q... testnet)
- Alamat plot harus memiliki UTXO yang dikonfirmasi (membuktikan kepemilikan)
- Plot tidak boleh memiliki penugasan aktif (gunakan revoke terlebih dahulu)

**Struktur Transaksi**:
- Input: UTXO dari alamat plot (membuktikan kepemilikan)
- Output: skrip OP_RETURN (46 byte) = opcode `OP_RETURN` + panjang push 1 byte + payload data 44 byte (marker `POCX` 4 + plot_address 20 + forging_address 20)
- Output: Kembalian dikembalikan ke dompet

**Aktivasi**:
- Penugasan menjadi ASSIGNING pada konfirmasi
- Becomes ASSIGNED after `nForgingAssignmentDelay` blocks
- Penundaan mencegah penugasan ulang cepat selama fork rantai

**Kode Kesalahan**:
- `RPC_WALLET_NOT_FOUND`: Tidak ada dompet tersedia
- `RPC_WALLET_UNLOCK_NEEDED`: Dompet terenkripsi dan terkunci
- `RPC_WALLET_ERROR`: Pembuatan transaksi gagal
- `RPC_INVALID_ADDRESS_OR_KEY`: Format alamat tidak valid

**Contoh**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementasi**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategori**: wallet
**Memerlukan Dompet**: Ya (harus dimuat dan tidak terkunci)

**Tujuan**: Mencabut penugasan forging yang ada, mengembalikan hak forging ke pemilik plot.

**Parameter**:
1. `plot_address` (string, wajib) - Alamat plot (harus memiliki kunci privat, P2WPKH bech32)
2. `fee_rate` (numerik, opsional) - Tingkat biaya dalam BTCX/kvB (default: `0` → estimasi biaya minimum standar dompet; default 10x minRelayFee hanya berlaku untuk dialog GUI Qt, bukan RPC ini)

**Nilai Kembalian**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Persyaratan**:
- Dompet dimuat dan tidak terkunci
- Kunci privat untuk plot_address ada di dompet
- Alamat plot harus P2WPKH (format bech32)
- Alamat plot harus memiliki UTXO yang dikonfirmasi

**Struktur Transaksi**:
- Input: UTXO dari alamat plot (membuktikan kepemilikan)
- Output: skrip OP_RETURN (26 byte) = opcode `OP_RETURN` + panjang push 1 byte + payload data 24 byte (marker `XCOP` 4 + plot_address 20)
- Output: Kembalian dikembalikan ke dompet

**Efek**:
- Status segera bertransisi ke REVOKING
- Alamat forging masih dapat melakukan forge selama periode penundaan
- Menjadi REVOKED setelah `nForgingRevocationDelay` blok
- Pemilik plot dapat melakukan forge setelah pencabutan efektif
- Dapat membuat penugasan baru setelah pencabutan selesai

**Kode Kesalahan**:
- `RPC_WALLET_NOT_FOUND`: Tidak ada dompet tersedia
- `RPC_WALLET_UNLOCK_NEEDED`: Dompet terenkripsi dan terkunci
- `RPC_WALLET_ERROR`: Pembuatan transaksi gagal

**Contoh**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Catatan**:
- Idempoten: dapat mencabut bahkan jika tidak ada penugasan aktif
- Tidak dapat membatalkan pencabutan setelah dikirim

**Implementasi**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPC Blockchain yang Dimodifikasi

### getdifficulty

**Modifikasi PoCX**:
- **Kalkulasi**: `reference_base_target / current_base_target`
- **Referensi**: Kapasitas jaringan 1 TiB (base_target = 36650387592)
- **Interpretasi**: Estimasi kapasitas penyimpanan jaringan dalam TiB
  - Contoh: `1.0` = ~1 TiB
  - Contoh: `1024.0` = ~1 PiB
- **Perbedaan dari PoW**: Mewakili kapasitas, bukan kekuatan hash

**Contoh**:
```bash
bitcoin-cli getdifficulty
# Mengembalikan: 2048.5 (jaringan ~2 PiB)
```

**Implementasi**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Field Tambahan PoCX**:
- `time_since_last_block` (numerik) - Detik sejak blok sebelumnya (menggantikan mediantime)
- `poc_time` (numerik) - Waktu forge time-bended dalam detik
- `base_target` (numerik) - Base target kesulitan PoCX
- `generation_signature` (string hex) - Tanda tangan generasi
- `pocx_proof` (objek):
  - `account_id` (string) - Plot account as bech32 address
  - `seed` (string hex) - Seed plot (32 byte)
  - `nonce` (numerik) - Nonce penambangan
  - `compression` (numerik) - Tingkat penskalaan yang digunakan
  - `quality` (numerik) - Nilai kualitas yang diklaim
- `pubkey` (string hex) - Kunci publik penanda tangan blok (33 byte)
- `signer_address` (string) - Alamat penanda tangan blok
- `signature` (string hex) - Tanda tangan blok (65 byte)

**Field yang Dihapus PoCX**:
- `mediantime` - Dihapus (diganti oleh time_since_last_block)

**Contoh**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementasi**: `src/rpc/blockchain.cpp`

---

### getblock

**Modifikasi PoCX**: Sama dengan getblockheader, ditambah data transaksi lengkap

**Contoh**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose dengan detail tx
```

**Implementasi**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Field Tambahan PoCX**:
- `base_target` (numerik) - Base target saat ini
- `generation_signature` (string hex) - Tanda tangan generasi saat ini

**Field yang Dimodifikasi PoCX**:
- `difficulty` - Menggunakan kalkulasi PoCX (berbasis kapasitas)

**Field yang Dihapus PoCX**:
- `mediantime` - Dihapus

**Contoh**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementasi**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Field Tambahan PoCX**:
- `generation_signature` (string hex) - Untuk penambangan pool
- `base_target` (numerik) - Untuk penambangan pool

**Field yang Dihapus PoCX**:
- `target` - Dihapus (khusus PoW)
- `noncerange` - Dihapus (khusus PoW)
- `bits` - Dihapus (khusus PoW)

**Catatan**:
- Masih menyertakan data transaksi lengkap untuk konstruksi blok
- Digunakan oleh server pool untuk penambangan terkoordinasi

**Contoh**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementasi**: `src/rpc/mining.cpp`

---

## RPC yang Dinonaktifkan

RPC khusus PoW berikut **dinonaktifkan** dalam mode PoCX:

### getnetworkhashps
- **Alasan**: Hash rate tidak berlaku untuk Proof of Capacity
- **Alternatif**: Gunakan `getdifficulty` untuk estimasi kapasitas jaringan

### getmininginfo
- **Alasan**: Mengembalikan informasi khusus PoW
- **Alternatif**: Gunakan `get_mining_info` (khusus PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Contoh Integrasi

### Integrasi Miner Eksternal

**Loop Penambangan Dasar**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Loop penambangan
while True:
    # 1. Dapatkan parameter penambangan
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Pindai file plot (implementasi eksternal)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Kirim solusi terbaik (melempar JSONRPCError saat ditolak)
    try:
        result = rpc_call("submit_nonce", [
            info["block_hash"],
            height,
            gen_sig,
            base_target,
            best_nonce["account_id"],
            best_nonce["seed"],
            best_nonce["nonce"],
            best_nonce["compression"],
            best_nonce["raw_quality"]
        ])
        print(f"Solusi diterima! Kualitas: {result['raw_quality']}, "
              f"Waktu forge: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Ditolak: {e}")

    # 4. Tunggu blok berikutnya
    time.sleep(10)  # Interval polling
```

---

### Pola Integrasi Pool

**Alur Kerja Server Pool**:
1. Penambang membuat penugasan forging ke alamat pool
2. Pool menjalankan dompet dengan kunci alamat forging
3. Pool memanggil `get_mining_info` dan mendistribusikan ke penambang
4. Penambang mengirim solusi via pool (bukan langsung ke rantai)
5. Pool memvalidasi dan memanggil `submit_nonce` dengan kunci pool
6. Pool mendistribusikan hadiah sesuai kebijakan pool

**Manajemen Penugasan**:
```bash
# Penambang membuat penugasan (dari dompet penambang)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Tunggu aktivasi (30 blok mainnet)

# Pool memeriksa status penugasan
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool sekarang dapat mengirim nonce untuk plot ini
# (dompet pool harus memiliki kunci privat pocx1qpool...)
```

---

### Kueri Block Explorer

**Mengkueri Data Blok PoCX**:
```bash
# Dapatkan blok terbaru
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Dapatkan detail blok dengan bukti PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Ekstrak field khusus PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Mendeteksi Transaksi Penugasan**:
```bash
# Pindai transaksi untuk OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Periksa marker penugasan (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Penanganan Kesalahan

### Pola Kesalahan Umum

**Ketidakcocokan Tinggi** (dilempar `RPC_INVALID_PARAMETER`, kode -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Solusi**: Ambil ulang info penambangan, rantai sudah maju

**Ketidakcocokan Tanda Tangan Generasi** (dilempar `RPC_VERIFY_REJECTED`, kode -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Solusi**: Ambil ulang info penambangan, blok baru tiba

**Tidak Ada Kunci Privat**:
```json
{
  "code": -5,
  "message": "Tidak ada kunci privat tersedia untuk penanda tangan efektif"
}
```
**Solusi**: Impor kunci untuk alamat plot atau forging

**Aktivasi Penugasan Tertunda**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solusi**: Tunggu penundaan aktivasi berlalu

---

## Referensi Kode

**RPC Penambangan**: `src/pocx/rpc/mining.cpp`
**RPC Penugasan**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC Blockchain**: `src/rpc/blockchain.cpp`
**Validasi Bukti**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Status Penugasan**: `src/pocx/assignments/assignment_state.cpp`
**Pembuatan Transaksi**: `src/pocx/assignments/transactions.cpp`

---

## Referensi Silang

Bab terkait:
- [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md) - Detail proses penambangan
- [Bab 4: Penugasan Forging](4-forging-assignments.md) - Arsitektur sistem penugasan
- [Bab 6: Parameter Jaringan](6-network-parameters.md) - Nilai penundaan penugasan
- [Bab 8: Panduan Dompet](8-wallet-guide.md) - GUI untuk manajemen penugasan

---

[Sebelumnya: Parameter Jaringan](6-network-parameters.md) | [Daftar Isi](index.md) | [Berikutnya: Panduan Dompet](8-wallet-guide.md)
