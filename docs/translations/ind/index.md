# Dokumentasi Teknis Bitcoin-PoCX

**Versi**: 1.0
**Basis Bitcoin Core**: v30.0
**Status**: Fase Testnet
**Terakhir Diperbarui**: 2025-12-25

---

## Tentang Dokumentasi Ini

Ini adalah dokumentasi teknis lengkap untuk Bitcoin-PoCX, integrasi Bitcoin Core yang menambahkan dukungan konsensus Proof of Capacity generasi berikutnya (PoCX). Dokumentasi ini disusun sebagai panduan yang dapat dijelajahi dengan bab-bab yang saling terhubung mencakup semua aspek sistem.

**Target Pembaca**:
- **Operator Node**: Bab 1, 5, 6, 8
- **Penambang**: Bab 2, 3, 7
- **Pengembang**: Semua bab
- **Peneliti**: Bab 3, 4, 5

## Terjemahan

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arab](../ara/index.md) | [🇳🇱 Belanda](../nld/index.md) | [🇧🇬 Bulgaria](../bul/index.md) | [🇨🇿 Ceko](../ces/index.md) | [🇩🇰 Denmark](../dan/index.md) | [🇪🇪 Estonia](../est/index.md) |
| [🇵🇭 Filipina](../fil/index.md) | [🇫🇮 Finlandia](../fin/index.md) | [🇭🇺 Hongaria](../hun/index.md) | [🇮🇱 Ibrani](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇬🇧 Inggris](../../index.md) |
| [🇮🇹 Italia](../ita/index.md) | [🇯🇵 Jepang](../jpn/index.md) | [🇩🇪 Jerman](../deu/index.md) | [🇰🇷 Korea](../kor/index.md) | [🇱🇻 Latvia](../lav/index.md) | [🇱🇹 Lituania](../lit/index.md) |
| [🇳🇴 Norwegia](../nor/index.md) | [🇵🇱 Polandia](../pol/index.md) | [🇵🇹 Portugis](../por/index.md) | [🇫🇷 Prancis](../fra/index.md) | [🇷🇴 Rumania](../ron/index.md) | [🇷🇺 Rusia](../rus/index.md) |
| [🇷🇸 Serbia](../srp/index.md) | [🇪🇸 Spanyol](../spa/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇸🇪 Swedia](../swe/index.md) | [🇨🇳 Tionghoa](../zho/index.md) | [🇹🇷 Turki](../tur/index.md) |
| [🇺🇦 Ukraina](../ukr/index.md) | [🇻🇳 Vietnam](../vie/index.md) | [🇬🇷 Yunani](../ell/index.md) | | | |

---

## Daftar Isi

### Bagian I: Dasar-Dasar

**[Bab 1: Pendahuluan dan Gambaran Umum](1-introduction.md)**
Gambaran proyek, arsitektur, filosofi desain, fitur utama, dan perbedaan PoCX dengan Proof of Work.

**[Bab 2: Format File Plot](2-plot-format.md)**
Spesifikasi lengkap format plot PoCX termasuk optimasi SIMD, penskalaan proof-of-work, dan evolusi format dari POC1/POC2.

**[Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md)**
Spesifikasi teknis lengkap mekanisme konsensus PoCX: struktur blok, tanda tangan generasi, penyesuaian base target, proses penambangan, alur validasi, dan algoritma Time Bending.

---

### Bagian II: Fitur Lanjutan

**[Bab 4: Sistem Penugasan Forging](4-forging-assignments.md)**
Arsitektur berbasis OP_RETURN untuk mendelegasikan hak forging: struktur transaksi, desain database, mesin status, penanganan reorganisasi, dan antarmuka RPC.

**[Bab 5: Sinkronisasi Waktu dan Keamanan](5-timing-security.md)**
Toleransi penyimpangan jam, mekanisme defensive forging, perlindungan terhadap manipulasi jam, dan pertimbangan keamanan terkait waktu.

**[Bab 6: Parameter Jaringan](6-network-parameters.md)**
Konfigurasi chainparams, blok genesis, parameter konsensus, aturan coinbase, penskalaan dinamis, dan model ekonomi.

---

### Bagian III: Penggunaan dan Integrasi

**[Bab 7: Referensi Antarmuka RPC](7-rpc-reference.md)**
Referensi lengkap perintah RPC untuk penambangan, penugasan, dan kueri blockchain. Penting untuk integrasi penambang dan pool.

**[Bab 8: Panduan Dompet dan GUI](8-wallet-guide.md)**
Panduan pengguna untuk dompet Qt Bitcoin-PoCX: dialog penugasan forging, riwayat transaksi, pengaturan penambangan, dan pemecahan masalah.

---

## Navigasi Cepat

### Untuk Operator Node
- Mulai dengan [Bab 1: Pendahuluan](1-introduction.md)
- Kemudian tinjau [Bab 6: Parameter Jaringan](6-network-parameters.md)
- Konfigurasikan penambangan dengan [Bab 8: Panduan Dompet](8-wallet-guide.md)

### Untuk Penambang
- Pahami [Bab 2: Format Plot](2-plot-format.md)
- Pelajari prosesnya di [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md)
- Integrasikan menggunakan [Bab 7: Referensi RPC](7-rpc-reference.md)

### Untuk Operator Pool
- Tinjau [Bab 4: Penugasan Forging](4-forging-assignments.md)
- Pelajari [Bab 7: Referensi RPC](7-rpc-reference.md)
- Implementasikan menggunakan RPC penugasan dan submit_nonce

### Untuk Pengembang
- Baca semua bab secara berurutan
- Referensi silang file implementasi yang dicatat di seluruh dokumen
- Periksa struktur direktori `src/pocx/`
- Bangun rilis dengan [GUIX](../bitcoin/contrib/guix/README.md)

---

## Konvensi Dokumentasi

**Referensi File**: Detail implementasi merujuk pada file sumber sebagai `path/ke/file.cpp:baris`

**Integrasi Kode**: Semua perubahan ditandai dengan fitur menggunakan `#ifdef ENABLE_POCX`

**Referensi Silang**: Bab-bab menautkan ke bagian terkait menggunakan tautan markdown relatif

**Tingkat Teknis**: Dokumentasi mengasumsikan keakraban dengan Bitcoin Core dan pengembangan C++

---

## Membangun

### Build Pengembangan

```bash
# Clone dengan submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfigurasi dengan PoCX diaktifkan
cmake -B build -DENABLE_POCX=ON

# Build
cmake --build build -j$(nproc)
```

**Varian Build**:
```bash
# Dengan GUI Qt
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Build debug
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dependensi**: Dependensi build Bitcoin Core standar. Lihat [dokumentasi build Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) untuk persyaratan spesifik platform.

### Build Rilis

Untuk biner rilis yang dapat direproduksi, gunakan sistem build GUIX: Lihat [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Sumber Daya Tambahan

**Repositori**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework Inti PoCX**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Proyek Terkait**:
- Plotter: Berbasis [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Berbasis [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Cara Membaca Dokumentasi Ini

**Membaca Berurutan**: Bab-bab dirancang untuk dibaca secara berurutan, dibangun di atas konsep sebelumnya.

**Membaca Referensi**: Gunakan daftar isi untuk langsung menuju topik tertentu. Setiap bab berdiri sendiri dengan referensi silang ke materi terkait.

**Navigasi Browser**: Buka `index.md` di penampil markdown atau browser. Semua tautan internal bersifat relatif dan berfungsi secara offline.

**Ekspor PDF**: Dokumentasi ini dapat digabungkan menjadi satu PDF untuk pembacaan offline.

---

## Status Proyek

**Fitur Lengkap**: Semua aturan konsensus, penambangan, penugasan, dan fitur dompet telah diimplementasikan.

**Dokumentasi Lengkap**: Semua 8 bab lengkap dan diverifikasi terhadap basis kode.

**Testnet Aktif**: Saat ini dalam fase testnet untuk pengujian komunitas.

---

## Berkontribusi

Kontribusi pada dokumentasi sangat diterima. Harap pertahankan:
- Akurasi teknis di atas verbositas
- Penjelasan singkat dan langsung ke inti
- Tidak ada kode atau pseudo-code dalam dokumentasi (rujuk file sumber sebagai gantinya)
- Hanya yang sudah diimplementasikan (tidak ada fitur spekulatif)

---

## Lisensi

Bitcoin-PoCX mewarisi lisensi MIT dari Bitcoin Core. Lihat `COPYING` di root repositori.

Atribusi framework inti PoCX didokumentasikan di [Bab 2: Format Plot](2-plot-format.md).

---

**Mulai Membaca**: [Bab 1: Pendahuluan dan Gambaran Umum](1-introduction.md)
