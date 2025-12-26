[Daftar Isi](index.md) | [Berikutnya: Format Plot](2-plot-format.md)

---

# Bab 1: Pendahuluan dan Gambaran Umum

## Apa itu Bitcoin-PoCX?

Bitcoin-PoCX adalah integrasi Bitcoin Core yang menambahkan dukungan konsensus **Proof of Capacity generasi berikutnya (PoCX)**. Ia mempertahankan arsitektur Bitcoin Core yang ada sambil mengaktifkan alternatif penambangan Proof of Capacity yang hemat energi sebagai pengganti lengkap untuk Proof of Work.

**Perbedaan Utama**: Ini adalah **rantai baru** tanpa kompatibilitas mundur dengan Bitcoin PoW. Blok PoCX tidak kompatibel dengan node PoW secara sengaja.

---

## Identitas Proyek

- **Organisasi**: Proof of Capacity Consortium
- **Nama Proyek**: Bitcoin-PoCX
- **Nama Lengkap**: Bitcoin Core dengan Integrasi PoCX
- **Status**: Fase Testnet

---

## Apa itu Proof of Capacity?

Proof of Capacity (PoC) adalah mekanisme konsensus di mana kekuatan penambangan sebanding dengan **ruang disk** daripada kekuatan komputasi. Penambang pra-menghasilkan file plot besar yang berisi hash kriptografis, kemudian menggunakan plot ini untuk menemukan solusi blok yang valid.

**Efisiensi Energi**: File plot dihasilkan sekali dan digunakan kembali tanpa batas. Penambangan mengonsumsi daya CPU minimal—terutama I/O disk.

**Peningkatan PoCX**:
- Memperbaiki serangan kompresi XOR-transpose (50% tradeoff waktu-memori di POC2)
- Tata letak selaras 16-nonce untuk perangkat keras modern
- Proof-of-work yang dapat diskalakan dalam pembuatan plot (tingkat penskalaan Xn)
- Integrasi C++ native langsung ke Bitcoin Core
- Algoritma Time Bending untuk distribusi waktu blok yang lebih baik

---

## Gambaran Arsitektur

### Struktur Repositori

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integrasi PoCX
│   └── src/pocx/        # Implementasi PoCX
├── pocx/                # Framework inti PoCX (submodule, hanya-baca)
└── docs/                # Dokumentasi ini
```

### Filosofi Integrasi

**Permukaan Integrasi Minimal**: Perubahan diisolasi di direktori `/src/pocx/` dengan hook bersih ke lapisan validasi, penambangan, dan RPC Bitcoin Core.

**Penandaan Fitur**: Semua modifikasi di bawah guard preprocessor `#ifdef ENABLE_POCX`. Bitcoin Core dibangun secara normal ketika dinonaktifkan.

**Kompatibilitas Upstream**: Sinkronisasi reguler dengan pembaruan Bitcoin Core dipertahankan melalui titik integrasi yang terisolasi.

**Implementasi C++ Native**: Algoritma kriptografis skalar (Shabal256, kalkulasi scoop, kompresi) diintegrasikan langsung ke Bitcoin Core untuk validasi konsensus.

---

## Fitur Utama

### 1. Penggantian Konsensus Lengkap

- **Struktur Blok**: Field khusus PoCX menggantikan nonce PoW dan bit kesulitan
  - Tanda tangan generasi (entropi penambangan deterministik)
  - Base target (kebalikan dari kesulitan)
  - Bukti PoCX (ID akun, seed, nonce)
  - Tanda tangan blok (membuktikan kepemilikan plot)

- **Validasi**: Alur validasi 5-tahap dari pemeriksaan header hingga koneksi blok

- **Penyesuaian Kesulitan**: Penyesuaian setiap blok menggunakan rata-rata bergerak dari base target terbaru

### 2. Algoritma Time Bending

**Masalah**: Waktu blok PoC tradisional mengikuti distribusi eksponensial, menyebabkan blok panjang ketika tidak ada penambang yang menemukan solusi yang baik.

**Solusi**: Transformasi distribusi dari eksponensial ke chi-squared menggunakan akar pangkat tiga: `Y = scale * (X^(1/3))`.

**Efek**: Solusi yang sangat baik di-forge lebih lambat (jaringan punya waktu untuk memindai semua disk, mengurangi blok cepat), solusi buruk ditingkatkan. Rata-rata waktu blok dipertahankan pada 120 detik, blok panjang berkurang.

**Detail**: [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md)

### 3. Sistem Penugasan Forging

**Kemampuan**: Pemilik plot dapat mendelegasikan hak forging ke alamat lain sambil mempertahankan kepemilikan plot.

**Kasus Penggunaan**:
- Penambangan pool (plot menugaskan ke alamat pool)
- Penyimpanan dingin (kunci penambangan terpisah dari kepemilikan plot)
- Penambangan multi-pihak (infrastruktur bersama)

**Arsitektur**: Desain hanya OP_RETURN—tidak ada UTXO khusus, penugasan dilacak secara terpisah di database chainstate.

**Detail**: [Bab 4: Penugasan Forging](4-forging-assignments.md)

### 4. Defensive Forging

**Masalah**: Jam yang cepat dapat memberikan keuntungan waktu dalam toleransi masa depan 15 detik.

**Solusi**: Ketika menerima blok pesaing pada ketinggian yang sama, secara otomatis periksa kualitas lokal. Jika lebih baik, forge segera.

**Efek**: Menghilangkan insentif untuk manipulasi jam—jam cepat hanya membantu jika Anda sudah memiliki solusi terbaik.

**Detail**: [Bab 5: Keamanan Waktu](5-timing-security.md)

### 5. Penskalaan Kompresi Dinamis

**Penyelarasan Ekonomi**: Persyaratan tingkat penskalaan meningkat pada jadwal eksponensial (Tahun 4, 12, 28, 60, 124 = halving 1, 3, 7, 15, 31).

**Efek**: Seiring hadiah blok menurun, kesulitan pembuatan plot meningkat. Mempertahankan margin keamanan antara biaya pembuatan dan pencarian plot.

**Mencegah**: Inflasi kapasitas dari perangkat keras yang lebih cepat seiring waktu.

**Detail**: [Bab 6: Parameter Jaringan](6-network-parameters.md)

---

## Filosofi Desain

### Keamanan Kode

- Praktik pemrograman defensif di seluruh sistem
- Penanganan kesalahan komprehensif di jalur validasi
- Tidak ada kunci bersarang (pencegahan deadlock)
- Operasi database atomik (UTXO + penugasan bersama)

### Arsitektur Modular

- Pemisahan bersih antara infrastruktur Bitcoin Core dan konsensus PoCX
- Framework inti PoCX menyediakan primitif kriptografis
- Bitcoin Core menyediakan framework validasi, database, jaringan

### Optimasi Kinerja

- Urutan validasi gagal-cepat (pemeriksaan murah terlebih dahulu)
- Pengambilan konteks tunggal per pengiriman (tidak ada akuisisi cs_main berulang)
- Operasi database atomik untuk konsistensi

### Keamanan Reorganisasi

- Data undo lengkap untuk perubahan status penugasan
- Reset status forging pada perubahan chain tip
- Deteksi keusangan di semua titik validasi

---

## Perbedaan PoCX dengan Proof of Work

| Aspek | Bitcoin (PoW) | Bitcoin-PoCX |
|-------|---------------|--------------|
| **Sumber Daya Penambangan** | Kekuatan komputasi (hash rate) | Ruang disk (kapasitas) |
| **Konsumsi Energi** | Tinggi (hashing terus-menerus) | Rendah (hanya I/O disk) |
| **Proses Penambangan** | Temukan nonce dengan hash < target | Temukan nonce dengan deadline < waktu berlalu |
| **Kesulitan** | Field `bits`, disesuaikan setiap 2016 blok | Field `base_target`, disesuaikan setiap blok |
| **Waktu Blok** | ~10 menit (distribusi eksponensial) | 120 detik (time-bended, varians berkurang) |
| **Subsidi** | 50 BTC - 25 - 12.5 - ... | 10 BTC - 5 - 2.5 - ... |
| **Perangkat Keras** | ASIC (khusus) | HDD (perangkat keras komoditas) |
| **Identitas Penambangan** | Anonim | Pemilik plot atau delegasi |

---

## Persyaratan Sistem

### Operasi Node

**Sama dengan Bitcoin Core**:
- **CPU**: Prosesor x86_64 modern
- **Memori**: 4-8 GB RAM
- **Penyimpanan**: Rantai baru, saat ini kosong (dapat tumbuh ~4x lebih cepat dari Bitcoin karena blok 2 menit dan database penugasan)
- **Jaringan**: Koneksi internet yang stabil
- **Jam**: Sinkronisasi NTP direkomendasikan untuk operasi optimal

**Catatan**: File plot TIDAK diperlukan untuk operasi node.

### Persyaratan Penambangan

**Persyaratan tambahan untuk penambangan**:
- **File Plot**: Pra-dihasilkan menggunakan `pocx_plotter` (implementasi referensi)
- **Perangkat Lunak Miner**: `pocx_miner` (implementasi referensi) terhubung via RPC
- **Dompet**: `bitcoind` atau `bitcoin-qt` dengan kunci privat untuk alamat penambangan. Penambangan pool tidak memerlukan dompet lokal.

---

## Memulai

### 1. Build Bitcoin-PoCX

```bash
# Clone dengan submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build dengan PoCX diaktifkan
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detail**: Lihat `CLAUDE.md` di root repositori

### 2. Jalankan Node

**Hanya node**:
```bash
./build/bin/bitcoind
# atau
./build/bin/bitcoin-qt
```

**Untuk penambangan** (mengaktifkan akses RPC untuk miner eksternal):
```bash
./build/bin/bitcoind -miningserver
# atau
./build/bin/bitcoin-qt -server -miningserver
```

**Detail**: [Bab 6: Parameter Jaringan](6-network-parameters.md)

### 3. Hasilkan File Plot

Gunakan `pocx_plotter` (implementasi referensi) untuk menghasilkan file plot format PoCX.

**Detail**: [Bab 2: Format Plot](2-plot-format.md)

### 4. Setup Penambangan

Gunakan `pocx_miner` (implementasi referensi) untuk terhubung ke antarmuka RPC node Anda.

**Detail**: [Bab 7: Referensi RPC](7-rpc-reference.md) dan [Bab 8: Panduan Dompet](8-wallet-guide.md)

---

## Atribusi

### Format Plot

Berbasis format POC2 (Burstcoin) dengan peningkatan:
- Memperbaiki celah keamanan (serangan kompresi XOR-transpose)
- Proof-of-work yang dapat diskalakan
- Tata letak yang dioptimalkan SIMD
- Fungsionalitas seed

### Proyek Sumber

- **pocx_miner**: Implementasi referensi berbasis [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementasi referensi berbasis [engraver](https://github.com/PoC-Consortium/engraver)

**Atribusi Lengkap**: [Bab 2: Format Plot](2-plot-format.md)

---

## Ringkasan Spesifikasi Teknis

- **Waktu Blok**: 120 detik (mainnet), 1 detik (regtest)
- **Subsidi Blok**: 10 BTC awal, halving setiap 1050000 blok (~4 tahun)
- **Total Pasokan**: ~21 juta BTC (sama dengan Bitcoin)
- **Toleransi Masa Depan**: 15 detik (blok hingga 15 detik ke depan diterima)
- **Peringatan Jam**: 10 detik (memperingatkan operator tentang penyimpangan waktu)
- **Penundaan Penugasan**: 30 blok (~1 jam)
- **Penundaan Pencabutan**: 720 blok (~24 jam)
- **Format Alamat**: P2WPKH (bech32, pocx1q...) saja untuk operasi penambangan PoCX dan penugasan forging

---

## Organisasi Kode

**Modifikasi Bitcoin Core**: Perubahan minimal pada file inti, ditandai dengan fitur menggunakan `#ifdef ENABLE_POCX`

**Implementasi PoCX Baru**: Terisolasi di direktori `src/pocx/`

---

## Pertimbangan Keamanan

### Keamanan Waktu

- Toleransi masa depan 15 detik mencegah fragmentasi jaringan
- Ambang peringatan 10 detik memperingatkan operator tentang penyimpangan jam
- Defensive forging menghilangkan insentif untuk manipulasi jam
- Time Bending mengurangi dampak varians waktu

**Detail**: [Bab 5: Keamanan Waktu](5-timing-security.md)

### Keamanan Penugasan

- Desain hanya OP_RETURN (tidak ada manipulasi UTXO)
- Tanda tangan transaksi membuktikan kepemilikan plot
- Penundaan aktivasi mencegah manipulasi status cepat
- Data undo aman-reorganisasi untuk semua perubahan status

**Detail**: [Bab 4: Penugasan Forging](4-forging-assignments.md)

### Keamanan Konsensus

- Tanda tangan dikecualikan dari hash blok (mencegah maleabilitas)
- Ukuran tanda tangan terbatas (mencegah DoS)
- Validasi batas kompresi (mencegah bukti lemah)
- Penyesuaian kesulitan setiap blok (responsif terhadap perubahan kapasitas)

**Detail**: [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md)

---

## Status Jaringan

**Mainnet**: Belum diluncurkan
**Testnet**: Tersedia untuk pengujian
**Regtest**: Berfungsi penuh untuk pengembangan

**Parameter Blok Genesis**: [Bab 6: Parameter Jaringan](6-network-parameters.md)

---

## Langkah Selanjutnya

**Untuk Memahami PoCX**: Lanjutkan ke [Bab 2: Format Plot](2-plot-format.md) untuk mempelajari struktur file plot dan evolusi format.

**Untuk Setup Penambangan**: Langsung ke [Bab 7: Referensi RPC](7-rpc-reference.md) untuk detail integrasi.

**Untuk Menjalankan Node**: Tinjau [Bab 6: Parameter Jaringan](6-network-parameters.md) untuk opsi konfigurasi.

---

[Daftar Isi](index.md) | [Berikutnya: Format Plot](2-plot-format.md)
