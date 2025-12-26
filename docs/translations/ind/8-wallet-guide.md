[Sebelumnya: Referensi RPC](7-rpc-reference.md) | [Daftar Isi](index.md)

---

# Bab 8: Panduan Dompet dan GUI Pengguna

Panduan lengkap untuk dompet Qt Bitcoin-PoCX dan manajemen penugasan forging.

---

## Daftar Isi

1. [Gambaran Umum](#gambaran-umum)
2. [Unit Mata Uang](#unit-mata-uang)
3. [Dialog Penugasan Forging](#dialog-penugasan-forging)
4. [Riwayat Transaksi](#riwayat-transaksi)
5. [Persyaratan Alamat](#persyaratan-alamat)
6. [Integrasi Penambangan](#integrasi-penambangan)
7. [Pemecahan Masalah](#pemecahan-masalah)
8. [Praktik Terbaik Keamanan](#praktik-terbaik-keamanan)

---

## Gambaran Umum

### Fitur Dompet Bitcoin-PoCX

Dompet Qt Bitcoin-PoCX (`bitcoin-qt`) menyediakan:
- Fungsionalitas dompet Bitcoin Core standar (kirim, terima, manajemen transaksi)
- **Manajer Penugasan Forging**: GUI untuk membuat/mencabut penugasan plot
- **Mode Server Penambangan**: Flag `-miningserver` mengaktifkan fitur terkait penambangan
- **Riwayat Transaksi**: Tampilan transaksi penugasan dan pencabutan

### Memulai Dompet

**Hanya Node** (tanpa penambangan):
```bash
./build/bin/bitcoin-qt
```

**Dengan Penambangan** (mengaktifkan dialog penugasan):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternatif Baris Perintah**:
```bash
./build/bin/bitcoind -miningserver
```

### Persyaratan Penambangan

**Untuk Operasi Penambangan**:
- Flag `-miningserver` diperlukan
- Dompet dengan alamat P2WPKH dan kunci privat
- Plotter eksternal (`pocx_plotter`) untuk pembuatan plot
- Miner eksternal (`pocx_miner`) untuk penambangan

**Untuk Penambangan Pool**:
- Buat penugasan forging ke alamat pool
- Dompet tidak diperlukan di server pool (pool mengelola kunci)

---

## Unit Mata Uang

### Tampilan Unit

Bitcoin-PoCX menggunakan unit mata uang **BTCX** (bukan BTC):

| Unit | Satoshi | Tampilan |
|------|---------|----------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **uBTCX** | 100 | 1000000.00 uBTCX |
| **satoshi** | 1 | 100000000 sat |

**Pengaturan GUI**: Preferensi -> Tampilan -> Unit

---

## Dialog Penugasan Forging

### Mengakses Dialog

**Menu**: `Dompet -> Penugasan Forging`
**Toolbar**: Ikon penambangan (terlihat hanya dengan flag `-miningserver`)
**Ukuran Jendela**: 600x450 piksel

### Mode Dialog

#### Mode 1: Buat Penugasan

**Tujuan**: Mendelegasikan hak forging ke pool atau alamat lain sambil mempertahankan kepemilikan plot.

**Kasus Penggunaan**:
- Penambangan pool (tugaskan ke alamat pool)
- Penyimpanan dingin (kunci penambangan terpisah dari kepemilikan plot)
- Infrastruktur bersama (delegasikan ke hot wallet)

**Persyaratan**:
- Alamat plot (P2WPKH bech32, harus memiliki kunci privat)
- Alamat forging (P2WPKH bech32, berbeda dari alamat plot)
- Dompet tidak terkunci (jika terenkripsi)
- Alamat plot memiliki UTXO yang dikonfirmasi

**Langkah-langkah**:
1. Pilih mode "Buat Penugasan"
2. Pilih alamat plot dari dropdown atau masukkan secara manual
3. Masukkan alamat forging (pool atau delegasi)
4. Klik "Kirim Penugasan" (tombol aktif ketika input valid)
5. Transaksi disiarkan segera
6. Penugasan aktif setelah `nForgingAssignmentDelay` blok:
   - Mainnet/Testnet: 30 blok (~1 jam)
   - Regtest: 4 blok (~4 detik)

**Biaya Transaksi**: Default 10x `minRelayFee` (dapat disesuaikan)

**Struktur Transaksi**:
- Input: UTXO dari alamat plot (membuktikan kepemilikan)
- Output OP_RETURN: marker `POCX` + plot_address + forging_address (46 byte)
- Output kembalian: Dikembalikan ke dompet

#### Mode 2: Cabut Penugasan

**Tujuan**: Membatalkan penugasan forging dan mengembalikan hak ke pemilik plot.

**Persyaratan**:
- Alamat plot (harus memiliki kunci privat)
- Dompet tidak terkunci (jika terenkripsi)
- Alamat plot memiliki UTXO yang dikonfirmasi

**Langkah-langkah**:
1. Pilih mode "Cabut Penugasan"
2. Pilih alamat plot
3. Klik "Kirim Pencabutan"
4. Transaksi disiarkan segera
5. Pencabutan efektif setelah `nForgingRevocationDelay` blok:
   - Mainnet/Testnet: 720 blok (~24 jam)
   - Regtest: 8 blok (~8 detik)

**Efek**:
- Alamat forging masih dapat melakukan forge selama periode penundaan
- Pemilik plot mendapatkan kembali hak setelah pencabutan selesai
- Dapat membuat penugasan baru setelahnya

**Struktur Transaksi**:
- Input: UTXO dari alamat plot (membuktikan kepemilikan)
- Output OP_RETURN: marker `XCOP` + plot_address (26 byte)
- Output kembalian: Dikembalikan ke dompet

#### Mode 3: Periksa Status Penugasan

**Tujuan**: Mengkueri status penugasan saat ini untuk alamat plot apa pun.

**Persyaratan**: Tidak ada (hanya-baca, tidak memerlukan dompet)

**Langkah-langkah**:
1. Pilih mode "Periksa Status Penugasan"
2. Masukkan alamat plot
3. Klik "Periksa Status"
4. Kotak status menampilkan status saat ini dengan detail

**Indikator Status** (berkode warna):

**Abu-abu - UNASSIGNED**
```
UNASSIGNED - Tidak ada penugasan
```

**Oranye - ASSIGNING**
```
ASSIGNING - Penugasan menunggu aktivasi
Alamat Forging: pocx1qforger...
Dibuat pada tinggi: 12000
Aktif pada tinggi: 12030 (5 blok tersisa)
```

**Hijau - ASSIGNED**
```
ASSIGNED - Penugasan aktif
Alamat Forging: pocx1qforger...
Dibuat pada tinggi: 12000
Diaktifkan pada tinggi: 12030
```

**Merah-Oranye - REVOKING**
```
REVOKING - Pencabutan menunggu
Alamat Forging: pocx1qforger... (masih aktif)
Penugasan dibuat pada tinggi: 12000
Dicabut pada tinggi: 12300
Pencabutan efektif pada tinggi: 13020 (50 blok tersisa)
```

**Merah - REVOKED**
```
REVOKED - Penugasan dicabut
Sebelumnya ditugaskan ke: pocx1qforger...
Penugasan dibuat pada tinggi: 12000
Dicabut pada tinggi: 12300
Pencabutan efektif pada tinggi: 13020
```

---

## Riwayat Transaksi

### Tampilan Transaksi Penugasan

**Tipe**: "Penugasan"
**Ikon**: Ikon penambangan (sama dengan blok yang ditambang)

**Kolom Alamat**: Alamat plot (alamat yang hak forging-nya ditugaskan)
**Kolom Jumlah**: Biaya transaksi (negatif, transaksi keluar)
**Kolom Status**: Jumlah konfirmasi (0-6+)

**Detail** (ketika diklik):
- ID Transaksi
- Alamat plot
- Alamat forging (diurai dari OP_RETURN)
- Dibuat pada tinggi
- Tinggi aktivasi
- Biaya transaksi
- Timestamp

### Tampilan Transaksi Pencabutan

**Tipe**: "Pencabutan"
**Ikon**: Ikon penambangan

**Kolom Alamat**: Alamat plot
**Kolom Jumlah**: Biaya transaksi (negatif)
**Kolom Status**: Jumlah konfirmasi

**Detail** (ketika diklik):
- ID Transaksi
- Alamat plot
- Dicabut pada tinggi
- Tinggi efektif pencabutan
- Biaya transaksi
- Timestamp

### Penyaringan Transaksi

**Filter yang Tersedia**:
- "Semua" (default, termasuk penugasan/pencabutan)
- Rentang tanggal
- Rentang jumlah
- Cari berdasarkan alamat
- Cari berdasarkan ID transaksi
- Cari berdasarkan label (jika alamat diberi label)

**Catatan**: Transaksi Penugasan/Pencabutan saat ini muncul di bawah filter "Semua". Filter tipe khusus belum diimplementasikan.

### Pengurutan Transaksi

**Urutan Pengurutan** (berdasarkan tipe):
- Generated (tipe 0)
- Received (tipe 1-3)
- Assignment (tipe 4)
- Revocation (tipe 5)
- Sent (tipe 6+)

---

## Persyaratan Alamat

### P2WPKH (SegWit v0) Saja

**Operasi forging memerlukan**:
- Alamat yang dikodekan Bech32 (dimulai dengan "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Format P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash kunci 20-byte

**TIDAK Didukung**:
- P2PKH (legacy, dimulai dengan "1")
- P2SH (wrapped SegWit, dimulai dengan "3")
- P2TR (Taproot, dimulai dengan "bc1p")

**Alasan**: Tanda tangan blok PoCX memerlukan format witness v0 spesifik untuk validasi bukti.

### Penyaringan Dropdown Alamat

**ComboBox Alamat Plot**:
- Secara otomatis diisi dengan alamat penerimaan dompet
- Menyaring alamat non-P2WPKH
- Menampilkan format: "Label (alamat)" jika diberi label, jika tidak hanya alamat
- Item pertama: "-- Masukkan alamat kustom --" untuk entri manual

**Entri Manual**:
- Memvalidasi format ketika dimasukkan
- Harus P2WPKH bech32 yang valid
- Tombol dinonaktifkan jika format tidak valid

### Pesan Kesalahan Validasi

**Kesalahan Dialog**:
- "Alamat plot harus P2WPKH (bech32)"
- "Alamat forging harus P2WPKH (bech32)"
- "Format alamat tidak valid"
- "Tidak ada koin tersedia di alamat plot. Tidak dapat membuktikan kepemilikan."
- "Tidak dapat membuat transaksi dengan dompet hanya-pantau"
- "Dompet tidak tersedia"
- "Dompet terkunci" (dari RPC)

---

## Integrasi Penambangan

### Persyaratan Setup

**Konfigurasi Node**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Persyaratan Dompet**:
- Alamat P2WPKH untuk kepemilikan plot
- Kunci privat untuk penambangan (atau alamat forging jika menggunakan penugasan)
- UTXO yang dikonfirmasi untuk pembuatan transaksi

**Alat Eksternal**:
- `pocx_plotter`: Menghasilkan file plot
- `pocx_miner`: Memindai plot dan mengirim nonce

### Alur Kerja

#### Penambangan Solo

1. **Hasilkan File Plot**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_byte> --nonces <jumlah>
   ```

2. **Mulai Node** dengan server penambangan:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigurasi Miner**:
   - Arahkan ke endpoint RPC node
   - Tentukan direktori file plot
   - Konfigurasi ID akun (dari alamat plot)

4. **Mulai Menambang**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/ke/plots
   ```

5. **Pantau**:
   - Miner memanggil `get_mining_info` setiap blok
   - Memindai plot untuk deadline terbaik
   - Memanggil `submit_nonce` ketika solusi ditemukan
   - Node memvalidasi dan mem-forge blok secara otomatis

#### Penambangan Pool

1. **Hasilkan File Plot** (sama dengan penambangan solo)

2. **Buat Penugasan Forging**:
   - Buka Dialog Penugasan Forging
   - Pilih alamat plot
   - Masukkan alamat forging pool
   - Klik "Kirim Penugasan"
   - Tunggu penundaan aktivasi (30 blok testnet)

3. **Konfigurasi Miner**:
   - Arahkan ke endpoint **pool** (bukan node lokal)
   - Pool menangani `submit_nonce` ke rantai

4. **Operasi Pool**:
   - Dompet pool memiliki kunci privat alamat forging
   - Pool memvalidasi pengiriman dari penambang
   - Pool memanggil `submit_nonce` ke blockchain
   - Pool mendistribusikan hadiah sesuai kebijakan pool

### Hadiah Coinbase

**Tanpa Penugasan**:
- Coinbase membayar alamat pemilik plot langsung
- Periksa saldo di alamat plot

**Dengan Penugasan**:
- Coinbase membayar alamat forging
- Pool menerima hadiah
- Penambang menerima bagian dari pool

**Jadwal Hadiah**:
- Awal: 10 BTCX per blok
- Halving: Setiap 1050000 blok (~4 tahun)
- Jadwal: 10 -> 5 -> 2.5 -> 1.25 -> ...

---

## Pemecahan Masalah

### Masalah Umum

#### "Dompet tidak memiliki kunci privat untuk alamat plot"

**Penyebab**: Dompet tidak memiliki alamat
**Solusi**:
- Impor kunci privat via RPC `importprivkey`
- Atau gunakan alamat plot berbeda yang dimiliki dompet

#### "Penugasan sudah ada untuk plot ini"

**Penyebab**: Plot sudah ditugaskan ke alamat lain
**Solusi**:
1. Cabut penugasan yang ada
2. Tunggu penundaan pencabutan (720 blok testnet)
3. Buat penugasan baru

#### "Format alamat tidak didukung"

**Penyebab**: Alamat bukan P2WPKH bech32
**Solusi**:
- Gunakan alamat yang dimulai dengan "pocx1q" (mainnet) atau "tpocx1q" (testnet)
- Hasilkan alamat baru jika diperlukan: `getnewaddress "" "bech32"`

#### "Biaya transaksi terlalu rendah"

**Penyebab**: Kemacetan mempool jaringan atau biaya terlalu rendah untuk relay
**Solusi**:
- Tingkatkan parameter tingkat biaya
- Tunggu mempool bersih

#### "Penugasan belum aktif"

**Penyebab**: Penundaan aktivasi belum berlalu
**Solusi**:
- Periksa status: blok tersisa hingga aktivasi
- Tunggu periode penundaan selesai

#### "Tidak ada koin tersedia di alamat plot"

**Penyebab**: Alamat plot tidak memiliki UTXO yang dikonfirmasi
**Solusi**:
1. Kirim dana ke alamat plot
2. Tunggu 1 konfirmasi
3. Coba lagi pembuatan penugasan

#### "Tidak dapat membuat transaksi dengan dompet hanya-pantau"

**Penyebab**: Dompet mengimpor alamat tanpa kunci privat
**Solusi**: Impor kunci privat lengkap, bukan hanya alamat

#### "Tab Penugasan Forging tidak terlihat"

**Penyebab**: Node dimulai tanpa flag `-miningserver`
**Solusi**: Mulai ulang dengan `bitcoin-qt -server -miningserver`

### Langkah Debug

1. **Periksa Status Dompet**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verifikasi Kepemilikan Alamat**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Periksa: "iswatchonly": false, "ismine": true
   ```

3. **Periksa Status Penugasan**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Lihat Transaksi Terbaru**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Periksa Sinkronisasi Node**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifikasi: blocks == headers (sepenuhnya tersinkronisasi)
   ```

---

## Praktik Terbaik Keamanan

### Keamanan Alamat Plot

**Manajemen Kunci**:
- Simpan kunci privat alamat plot dengan aman
- Transaksi penugasan membuktikan kepemilikan via tanda tangan
- Hanya pemilik plot yang dapat membuat/mencabut penugasan

**Cadangan**:
- Cadangkan dompet secara teratur (`dumpwallet` atau `backupwallet`)
- Simpan wallet.dat di lokasi yang aman
- Catat frasa pemulihan jika menggunakan dompet HD

### Delegasi Alamat Forging

**Model Keamanan**:
- Alamat forging menerima hadiah blok
- Alamat forging dapat menandatangani blok (penambangan)
- Alamat forging **tidak dapat** memodifikasi atau mencabut penugasan
- Pemilik plot mempertahankan kontrol penuh

**Kasus Penggunaan**:
- **Delegasi Hot Wallet**: Kunci plot di penyimpanan dingin, kunci forging di hot wallet untuk penambangan
- **Penambangan Pool**: Delegasikan ke pool, pertahankan kepemilikan plot
- **Infrastruktur Bersama**: Beberapa penambang, satu alamat forging

### Sinkronisasi Waktu Jaringan

**Pentingnya**:
- Konsensus PoCX memerlukan waktu yang akurat
- Penyimpangan jam >10 detik memicu peringatan
- Penyimpangan jam >15 detik mencegah penambangan

**Solusi**:
- Jaga jam sistem tersinkronisasi dengan NTP
- Pantau: `bitcoin-cli getnetworkinfo` untuk peringatan offset waktu
- Gunakan server NTP yang andal

### Penundaan Penugasan

**Penundaan Aktivasi** (30 blok testnet):
- Mencegah penugasan ulang cepat selama fork rantai
- Memungkinkan jaringan mencapai konsensus
- Tidak dapat dilewati

**Penundaan Pencabutan** (720 blok testnet):
- Memberikan stabilitas untuk pool penambangan
- Mencegah serangan "griefing" penugasan
- Alamat forging tetap aktif selama penundaan

### Enkripsi Dompet

**Aktifkan Enkripsi**:
```bash
bitcoin-cli encryptwallet "frasa_sandi_anda"
```

**Buka Kunci untuk Transaksi**:
```bash
bitcoin-cli walletpassphrase "frasa_sandi_anda" 300
```

**Praktik Terbaik**:
- Gunakan frasa sandi kuat (20+ karakter)
- Jangan simpan frasa sandi dalam teks biasa
- Kunci dompet setelah membuat penugasan

---

## Referensi Kode

**Dialog Penugasan Forging**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Tampilan Transaksi**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsing Transaksi**: `src/qt/transactionrecord.cpp`
**Integrasi Dompet**: `src/pocx/assignments/transactions.cpp`
**RPC Penugasan**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Utama**: `src/qt/bitcoingui.cpp`

---

## Referensi Silang

Bab terkait:
- [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md) - Proses penambangan
- [Bab 4: Penugasan Forging](4-forging-assignments.md) - Arsitektur penugasan
- [Bab 6: Parameter Jaringan](6-network-parameters.md) - Nilai penundaan penugasan
- [Bab 7: Referensi RPC](7-rpc-reference.md) - Detail perintah RPC

---

[Sebelumnya: Referensi RPC](7-rpc-reference.md) | [Daftar Isi](index.md)
