[Sebelumnya: Pendahuluan](1-introduction.md) | [Daftar Isi](index.md) | [Berikutnya: Konsensus dan Penambangan](3-consensus-and-mining.md)

---

# Bab 2: Spesifikasi Format Plot PoCX

Dokumen ini menjelaskan format plot PoCX, versi yang ditingkatkan dari format POC2 dengan keamanan yang lebih baik, optimasi SIMD, dan proof-of-work yang dapat diskalakan.

## Gambaran Format

File plot PoCX berisi nilai hash Shabal256 yang telah dihitung sebelumnya, diorganisir untuk operasi penambangan yang efisien. Mengikuti tradisi PoC sejak POC1, **semua metadata tertanam dalam nama file** - tidak ada header file.

### Ekstensi File
- **Standar**: `.pocx` (plot yang sudah selesai)
- **Sedang Diproses**: `.tmp` (selama plotting, diganti nama menjadi `.pocx` saat selesai)

## Konteks Historis dan Evolusi Kerentanan

### Format POC1 (Warisan)
**Dua Kerentanan Utama (Tradeoff Waktu-Memori):**

1. **Cacat Distribusi PoW**
   - Distribusi proof-of-work tidak seragam di seluruh scoop
   - Nomor scoop rendah dapat dihitung secara langsung
   - **Dampak**: Mengurangi persyaratan penyimpanan untuk penyerang

2. **Serangan Kompresi XOR** (50% Tradeoff Waktu-Memori)
   - Mengeksploitasi properti matematis untuk mencapai pengurangan penyimpanan 50%
   - **Dampak**: Penyerang dapat menambang dengan setengah penyimpanan yang diperlukan

**Optimasi Tata Letak**: Tata letak scoop sekuensial dasar untuk efisiensi HDD

### Format POC2 (Burstcoin)
- Cacat distribusi PoW diperbaiki
- Kerentanan XOR-transpose tetap tidak ditambal
- **Tata Letak**: Mempertahankan optimasi scoop sekuensial

### Format PoCX (Saat Ini)
- Distribusi PoW diperbaiki (diwarisi dari POC2)
- Kerentanan XOR-transpose ditambal (unik untuk PoCX)
- Tata letak SIMD/GPU yang ditingkatkan dioptimalkan untuk pemrosesan paralel dan memory coalescing
- Proof-of-work yang dapat diskalakan mencegah tradeoff waktu-memori seiring kekuatan komputasi berkembang (PoW dilakukan hanya saat membuat atau meningkatkan file plot)

## Encoding XOR-Transpose

### Masalah: 50% Tradeoff Waktu-Memori

Dalam format POC1/POC2, penyerang dapat mengeksploitasi hubungan matematis antara scoop untuk menyimpan hanya setengah data dan menghitung sisanya secara langsung selama penambangan. "Serangan kompresi XOR" ini merusak jaminan penyimpanan.

### Solusi: Pengerasan XOR-Transpose

PoCX menurunkan format penambangannya (X1) dengan menerapkan encoding XOR-transpose ke pasangan warp dasar (X0):

**Untuk membangun scoop S dari nonce N dalam warp X1:**
1. Ambil scoop S dari nonce N dari warp X0 pertama (posisi langsung)
2. Ambil scoop N dari nonce S dari warp X0 kedua (posisi transpose)
3. XOR dua nilai 64-byte untuk mendapatkan scoop X1

Langkah transpose menukar indeks scoop dan nonce. Dalam istilah matriks—di mana baris mewakili scoop dan kolom mewakili nonce—ini menggabungkan elemen pada posisi (S, N) di warp pertama dengan elemen pada (N, S) di warp kedua.

### Mengapa Ini Menghilangkan Serangan

XOR-transpose mengunci setiap scoop dengan seluruh baris dan seluruh kolom dari data X0 yang mendasarinya. Memulihkan satu scoop X1 memerlukan akses ke data yang mencakup semua 4096 indeks scoop. Setiap upaya untuk menghitung data yang hilang akan memerlukan regenerasi 4096 nonce penuh daripada satu nonce—menghilangkan struktur biaya asimetris yang dieksploitasi oleh serangan XOR.

Akibatnya, menyimpan warp X1 penuh menjadi satu-satunya strategi yang layak secara komputasi untuk penambang.

## Struktur Metadata Nama File

Semua metadata plot dikodekan dalam nama file menggunakan format persis ini:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Komponen Nama File

1. **ACCOUNT_PAYLOAD** (40 karakter heksadesimal)
   - Payload akun 20-byte mentah sebagai hex huruf besar
   - Independen jaringan (tanpa ID jaringan atau checksum)
   - Contoh: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 karakter heksadesimal)
   - Nilai seed 32-byte sebagai hex huruf kecil
   - **Baru di PoCX**: Seed acak 32-byte dalam nama file menggantikan penomoran nonce berurutan — mencegah tumpang tindih plot
   - Contoh: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (angka desimal)
   - **Unit ukuran BARU di PoCX**: Menggantikan ukuran berbasis nonce dari POC1/POC2
   - **Desain tahan XOR-transpose**: Setiap warp = tepat 4096 nonce (ukuran partisi yang diperlukan untuk transformasi tahan XOR-transpose)
   - **Ukuran**: 1 warp = 1073741824 byte = 1 GiB (unit yang nyaman)
   - Contoh: `1024` (plot 1 TiB = 1024 warp)

4. **SCALING** (desimal dengan awalan X)
   - Tingkat penskalaan sebagai `X{level}`
   - Nilai lebih tinggi = lebih banyak proof-of-work diperlukan
   - Contoh: `X4` (2^4 = 16x kesulitan POC2)

### Contoh Nama File
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Tata Letak File dan Struktur Data

### Organisasi Hierarkis
```
File Plot (TANPA HEADER)
├── Scoop 0
│   ├── Warp 0 (Semua nonce untuk scoop/warp ini)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Konstanta dan Ukuran

| Konstanta        | Ukuran                    | Deskripsi                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Output hash Shabal256 tunggal                    |
| **SCOOP\_SIZE** | 64 B (2 x HASH\_SIZE)  | Pasangan hash yang dibaca dalam satu putaran penambangan |
| **NUM\_SCOOPS** | 4096 (2^12)             | Scoop per nonce; satu dipilih per putaran        |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Semua scoop dari satu nonce (unit terkecil PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Unit terkecil di PoCX                           |

### Tata Letak File Plot yang Dioptimalkan SIMD

PoCX mengimplementasikan pola akses nonce yang sadar-SIMD yang memungkinkan pemrosesan vektor
dari beberapa nonce secara bersamaan. Ini dibangun di atas konsep dari [penelitian optimasi
POC2x16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) untuk memaksimalkan throughput memori dan efisiensi SIMD.

---

#### Tata Letak Sekuensial Tradisional

Penyimpanan nonce secara sekuensial:

```
[Nonce 0: Data Scoop] [Nonce 1: Data Scoop] [Nonce 2: Data Scoop] ...
```

Ketidakefisienan SIMD: Setiap jalur SIMD membutuhkan word yang sama di seluruh nonce:

```
Word 0 dari Nonce 0 -> offset 0
Word 0 dari Nonce 1 -> offset 512
Word 0 dari Nonce 2 -> offset 1024
...
```

Akses scatter-gather mengurangi throughput.

---

#### Tata Letak yang Dioptimalkan SIMD PoCX

PoCX menyimpan **posisi word di 16 nonce** secara bersebelahan:

```
Cache Line (64 byte):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**Diagram ASCII**

```
Tata letak tradisional:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Tata letak PoCX:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Manfaat Akses Memori

- Satu cache line menyediakan semua jalur SIMD.
- Menghilangkan operasi scatter-gather.
- Mengurangi cache miss.
- Akses memori sepenuhnya sekuensial untuk komputasi vektor.
- GPU juga mendapat manfaat dari penyelarasan 16-nonce, memaksimalkan efisiensi cache.

---

#### Penskalaan SIMD

| SIMD       | Lebar Vektor* | Nonce | Siklus Pemrosesan per Cache Line |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 siklus                        |
| AVX2       | 256-bit       | 8      | 2 siklus                        |
| AVX512     | 512-bit       | 16     | 1 siklus                        |

\* Untuk operasi integer

---



## Penskalaan Proof-of-Work

### Tingkat Penskalaan
- **X0**: Nonce dasar tanpa encoding XOR-transpose (teoritis, tidak digunakan untuk penambangan)
- **X1**: Baseline XOR-transpose—format pertama yang diperkeras (1x pekerjaan)
- **X2**: 2x pekerjaan X1 (XOR di 2 warp)
- **X3**: 4x pekerjaan X1 (XOR di 4 warp)
- **...**
- **Xn**: 2^(n-1) x pekerjaan X1 tertanam

### Manfaat
- **Kesulitan PoW yang dapat disesuaikan**: Meningkatkan persyaratan komputasi untuk mengikuti perangkat keras yang lebih cepat
- **Keawetan format**: Memungkinkan penskalaan fleksibel kesulitan penambangan dari waktu ke waktu

### Upgrade Plot / Kompatibilitas Mundur

Ketika jaringan meningkatkan skala PoW (Proof of Work) sebesar 1, plot yang ada memerlukan upgrade untuk mempertahankan ukuran plot efektif yang sama. Pada dasarnya, Anda sekarang membutuhkan dua kali PoW dalam file plot Anda untuk mencapai kontribusi yang sama ke akun Anda.

Kabar baiknya adalah PoW yang telah Anda selesaikan saat membuat file plot tidak hilang—Anda hanya perlu menambahkan PoW tambahan ke file yang ada. Tidak perlu plotting ulang.

Alternatifnya, Anda dapat terus menggunakan plot Anda saat ini tanpa upgrade, tetapi perhatikan bahwa sekarang mereka hanya akan berkontribusi 50% dari ukuran efektif sebelumnya terhadap akun Anda. Perangkat lunak penambangan Anda dapat menskalakan file plot secara langsung.

## Perbandingan dengan Format Warisan

| Fitur | POC1 | POC2 | PoCX |
|---------|------|------|------|
| Distribusi PoW | Cacat | Diperbaiki | Diperbaiki |
| Ketahanan XOR-Transpose | Rentan | Rentan | Diperbaiki |
| Optimasi SIMD | Tidak ada | Tidak ada | Lanjutan |
| Optimasi GPU | Tidak ada | Tidak ada | Dioptimalkan |
| Proof-of-Work yang Dapat Diskalakan | Tidak ada | Tidak ada | Ya |
| Dukungan Seed | Tidak ada | Tidak ada | Ya |

Format PoCX mewakili state-of-the-art saat ini dalam format plot Proof of Capacity, mengatasi semua kerentanan yang diketahui sambil memberikan peningkatan kinerja yang signifikan untuk perangkat keras modern.

## Referensi dan Bacaan Lanjutan

- **Latar Belakang POC1/POC2**: [Gambaran Penambangan Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Panduan komprehensif untuk format Proof of Capacity tradisional
- **Penelitian POC2x16**: [Pengumuman CIP: POC2x16 - Format plot baru yang dioptimalkan](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Penelitian optimasi SIMD asli yang menginspirasi PoCX
- **Algoritma Hash Shabal**: [Proyek Saphir: Shabal, Pengajuan ke Kompetisi Algoritma Hash Kriptografis NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Spesifikasi teknis algoritma Shabal256 yang digunakan dalam penambangan PoC

---

[Sebelumnya: Pendahuluan](1-introduction.md) | [Daftar Isi](index.md) | [Berikutnya: Konsensus dan Penambangan](3-consensus-and-mining.md)
