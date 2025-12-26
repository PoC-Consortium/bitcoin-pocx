[Sebelumnya: Penugasan Forging](4-forging-assignments.md) | [Daftar Isi](index.md) | [Berikutnya: Parameter Jaringan](6-network-parameters.md)

---

# Bab 5: Sinkronisasi Waktu dan Keamanan

## Gambaran Umum

Konsensus PoCX memerlukan sinkronisasi waktu yang presisi di seluruh jaringan. Bab ini mendokumentasikan mekanisme keamanan terkait waktu, toleransi penyimpangan jam, dan perilaku defensive forging.

**Mekanisme Utama**:
- Toleransi masa depan 15 detik untuk timestamp blok
- Sistem peringatan penyimpangan jam 10 detik
- Defensive forging (anti-manipulasi jam)
- Integrasi algoritma Time Bending

---

## Daftar Isi

1. [Persyaratan Sinkronisasi Waktu](#persyaratan-sinkronisasi-waktu)
2. [Deteksi dan Peringatan Penyimpangan Jam](#deteksi-dan-peringatan-penyimpangan-jam)
3. [Mekanisme Defensive Forging](#mekanisme-defensive-forging)
4. [Analisis Ancaman Keamanan](#analisis-ancaman-keamanan)
5. [Praktik Terbaik untuk Operator Node](#praktik-terbaik-untuk-operator-node)

---

## Persyaratan Sinkronisasi Waktu

### Konstanta dan Parameter

**Konfigurasi Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 detik

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 detik
```

### Pemeriksaan Validasi

**Validasi Timestamp Blok** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Pemeriksaan monotonik: timestamp >= timestamp blok sebelumnya
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Pemeriksaan masa depan: timestamp <= sekarang + 15 detik
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Pemeriksaan deadline: waktu berlalu >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabel Dampak Penyimpangan Jam

| Offset Jam | Bisa Sinkron? | Bisa Menambang? | Status Validasi | Efek Kompetitif |
|------------|---------------|-----------------|-----------------|-----------------|
| -30 detik lambat | TIDAK - Pemeriksaan masa depan gagal | N/A | **NODE MATI** | Tidak dapat berpartisipasi |
| -14 detik lambat | Ya | Ya | Forging terlambat, lolos validasi | Kalah perlombaan |
| 0 detik sempurna | Ya | Ya | Optimal | Optimal |
| +14 detik cepat | Ya | Ya | Forging awal, lolos validasi | Menang perlombaan |
| +16 detik cepat | Ya | TIDAK - Pemeriksaan masa depan gagal | Tidak dapat mempropagasi blok | Bisa sinkron, tidak bisa menambang |

**Wawasan Utama**: Jendela 15 detik simetris untuk partisipasi (+-14.9 detik), tetapi jam cepat memberikan keuntungan kompetitif yang tidak adil dalam toleransi.

### Integrasi Time Bending

Algoritma Time Bending (detail di [Bab 3](3-consensus-and-mining.md#kalkulasi-time-bending)) mengubah deadline mentah menggunakan akar pangkat tiga:

```
time_bended_deadline = scale x (deadline_seconds)^(1/3)
```

**Interaksi dengan Penyimpangan Jam**:
- Solusi lebih baik di-forge lebih cepat (akar pangkat tiga memperkuat perbedaan kualitas)
- Penyimpangan jam mempengaruhi waktu forging relatif terhadap jaringan
- Defensive forging memastikan kompetisi berbasis kualitas meskipun ada varians waktu

---

## Deteksi dan Peringatan Penyimpangan Jam

### Sistem Peringatan

Bitcoin-PoCX memantau offset waktu antara node lokal dan peer jaringan.

**Pesan Peringatan** (ketika penyimpangan melebihi 10 detik):
> "Tanggal dan waktu komputer Anda tampaknya tidak sinkron lebih dari 10 detik dengan jaringan, ini dapat menyebabkan kegagalan konsensus PoCX. Silakan periksa jam sistem Anda."

**Implementasi**: `src/node/timeoffsets.cpp`

### Alasan Desain

**Mengapa 10 detik?**
- Memberikan buffer keamanan 5 detik sebelum batas toleransi 15 detik
- Lebih ketat dari default Bitcoin Core (10 menit)
- Sesuai untuk persyaratan waktu PoC

**Pendekatan Preventif**:
- Peringatan dini sebelum kegagalan kritis
- Memungkinkan operator untuk memperbaiki masalah secara proaktif
- Mengurangi fragmentasi jaringan dari kegagalan terkait waktu

---

## Mekanisme Defensive Forging

### Apa Itu

Defensive forging adalah perilaku penambang standar di Bitcoin-PoCX yang menghilangkan keuntungan berbasis waktu dalam produksi blok. Ketika miner Anda menerima blok pesaing pada ketinggian yang sama, ia secara otomatis memeriksa apakah Anda memiliki solusi yang lebih baik. Jika ya, ia segera mem-forge blok Anda, memastikan kompetisi berbasis kualitas daripada kompetisi berbasis manipulasi jam.

### Masalahnya

Konsensus PoCX mengizinkan blok dengan timestamp hingga 15 detik di masa depan. Toleransi ini diperlukan untuk sinkronisasi jaringan global. Namun, ini menciptakan peluang untuk manipulasi jam:

**Tanpa Defensive Forging:**
- Penambang A: Waktu benar, kualitas 800 (lebih baik), menunggu deadline yang tepat
- Penambang B: Jam cepat (+14 detik), kualitas 1000 (lebih buruk), mem-forge 14 detik lebih awal
- Hasil: Penambang B memenangkan perlombaan meskipun proof-of-capacity work inferior

**Masalahnya:** Manipulasi jam memberikan keuntungan bahkan dengan kualitas lebih buruk, merusak prinsip proof-of-capacity.

### Solusi: Pertahanan Dua Lapis

#### Lapis 1: Peringatan Penyimpangan Jam (Preventif)

Bitcoin-PoCX memantau offset waktu antara node Anda dan peer jaringan. Jika jam Anda menyimpang lebih dari 10 detik dari konsensus jaringan, Anda menerima peringatan yang memperingatkan Anda untuk memperbaiki masalah jam sebelum menyebabkan masalah.

#### Lapis 2: Defensive Forging (Reaktif)

Ketika penambang lain menerbitkan blok pada ketinggian yang sama dengan yang Anda tambang:

1. **Deteksi**: Node Anda mengidentifikasi kompetisi ketinggian yang sama
2. **Validasi**: Mengekstrak dan memvalidasi kualitas blok pesaing
3. **Perbandingan**: Memeriksa apakah kualitas Anda lebih baik
4. **Respons**: Jika lebih baik, segera mem-forge blok Anda

**Hasil:** Jaringan menerima kedua blok dan memilih yang dengan kualitas lebih baik melalui resolusi fork standar.

### Cara Kerjanya

#### Skenario: Kompetisi Ketinggian yang Sama

```
Waktu 150 detik: Penambang B (jam +10 detik) mem-forge dengan kualitas 1000
           -> Timestamp blok menunjukkan 160 detik (10 detik di masa depan)

Waktu 150 detik: Node Anda menerima blok Penambang B
           -> Mendeteksi: ketinggian sama, kualitas 1000
           -> Anda memiliki: kualitas 800 (lebih baik!)
           -> Aksi: Forge segera dengan timestamp benar (150 detik)

Waktu 152 detik: Jaringan memvalidasi kedua blok
           -> Keduanya valid (dalam toleransi 15 detik)
           -> Kualitas 800 menang (lebih rendah = lebih baik)
           -> Blok Anda menjadi chain tip
```

#### Skenario: Reorg Asli

```
Tinggi penambangan Anda 100, pesaing menerbitkan blok 99
-> Bukan kompetisi ketinggian yang sama
-> Defensive forging TIDAK terpicu
-> Penanganan reorg normal berjalan
```

### Manfaat

**Nol Insentif untuk Manipulasi Jam**
- Jam cepat hanya membantu jika Anda sudah memiliki kualitas terbaik
- Manipulasi jam menjadi tidak berguna secara ekonomi

**Kompetisi Berbasis Kualitas Ditegakkan**
- Memaksa penambang untuk bersaing pada pekerjaan proof-of-capacity yang sebenarnya
- Menjaga integritas konsensus PoCX

**Keamanan Jaringan**
- Tahan terhadap strategi gaming berbasis waktu
- Tidak memerlukan perubahan konsensus - murni perilaku penambang

**Sepenuhnya Otomatis**
- Tidak perlu konfigurasi
- Terpicu hanya saat diperlukan
- Perilaku standar di semua node Bitcoin-PoCX

### Trade-off

**Peningkatan Tingkat Orphan Minimal**
- Disengaja - blok serangan menjadi orphan
- Hanya terjadi selama upaya manipulasi jam yang sebenarnya
- Hasil alami dari resolusi fork berbasis kualitas

**Kompetisi Jaringan Singkat**
- Jaringan sebentar melihat dua blok bersaing
- Terselesaikan dalam hitungan detik melalui validasi standar
- Perilaku sama dengan penambangan simultan di Bitcoin

### Detail Teknis

**Dampak Kinerja:** Dapat diabaikan
- Terpicu hanya pada kompetisi ketinggian yang sama
- Menggunakan data dalam memori (tidak ada I/O disk)
- Validasi selesai dalam milidetik

**Penggunaan Sumber Daya:** Minimal
- ~20 baris logika inti
- Menggunakan kembali infrastruktur validasi yang ada
- Akuisisi kunci tunggal

**Kompatibilitas:** Penuh
- Tidak ada perubahan aturan konsensus
- Bekerja dengan semua fitur Bitcoin Core
- Pemantauan opsional via log debug

**Status**: Aktif di semua rilis Bitcoin-PoCX
**Pertama Diperkenalkan**: 2025-10-10

---

## Analisis Ancaman Keamanan

### Serangan Jam Cepat (Dimitigasi oleh Defensive Forging)

**Vektor Serangan**:
Penambang dengan jam **+14 detik ke depan** dapat:
1. Menerima blok secara normal (tampak lama bagi mereka)
2. Mem-forge blok segera ketika deadline berlalu
3. Menyiarkan blok yang tampak 14 detik "awal" ke jaringan
4. **Blok diterima** (dalam toleransi 15 detik)
5. **Memenangkan perlombaan** melawan penambang jujur

**Dampak Tanpa Defensive Forging**:
Keuntungan dibatasi hingga 14.9 detik (tidak cukup untuk melewati pekerjaan PoC signifikan), tetapi memberikan keunggulan konsisten dalam perlombaan blok.

**Mitigasi (Defensive Forging)**:
- Penambang jujur mendeteksi kompetisi ketinggian yang sama
- Membandingkan nilai kualitas
- Segera mem-forge jika kualitas lebih baik
- **Hasil**: Jam cepat hanya membantu jika Anda sudah memiliki kualitas terbaik
- **Insentif**: Nol - manipulasi jam menjadi tidak berguna secara ekonomi

### Kegagalan Jam Lambat (Kritis)

**Mode Kegagalan**:
Node **>15 detik terlambat** adalah bencana:
- Tidak dapat memvalidasi blok masuk (pemeriksaan masa depan gagal)
- Menjadi terisolasi dari jaringan
- Tidak dapat menambang atau sinkron

**Mitigasi**:
- Peringatan kuat pada penyimpangan 10 detik memberikan buffer 5 detik sebelum kegagalan kritis
- Operator dapat memperbaiki masalah jam secara proaktif
- Pesan kesalahan yang jelas memandu pemecahan masalah

---

## Praktik Terbaik untuk Operator Node

### Setup Sinkronisasi Waktu

**Konfigurasi yang Direkomendasikan**:
1. **Aktifkan NTP**: Gunakan Network Time Protocol untuk sinkronisasi otomatis
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Periksa status
   timedatectl status
   ```

2. **Verifikasi Akurasi Jam**: Periksa offset waktu secara teratur
   ```bash
   # Periksa status sinkronisasi NTP
   ntpq -p

   # Atau dengan chrony
   chronyc tracking
   ```

3. **Pantau Peringatan**: Perhatikan peringatan penyimpangan jam Bitcoin-PoCX di log

### Untuk Penambang

**Tidak Perlu Aksi**:
- Fitur selalu aktif
- Beroperasi secara otomatis
- Cukup jaga akurasi jam sistem Anda

**Praktik Terbaik**:
- Gunakan sinkronisasi waktu NTP
- Pantau peringatan penyimpangan jam
- Atasi peringatan dengan segera jika muncul

**Perilaku yang Diharapkan**:
- Penambangan solo: Defensive forging jarang terpicu (tidak ada kompetisi)
- Penambangan jaringan: Melindungi terhadap upaya manipulasi jam
- Operasi transparan: Sebagian besar penambang tidak menyadarinya

### Pemecahan Masalah

**Peringatan: "10 detik tidak sinkron"**
- Aksi: Periksa dan perbaiki sinkronisasi jam sistem
- Dampak: Buffer 5 detik sebelum kegagalan kritis
- Alat: NTP, chrony, systemd-timesyncd

**Kesalahan: "time-too-new" pada blok masuk**
- Penyebab: Jam Anda >15 detik lambat
- Dampak: Tidak dapat memvalidasi blok, node terisolasi
- Perbaikan: Sinkronkan jam sistem segera

**Kesalahan: Tidak dapat mempropagasi blok yang di-forge**
- Penyebab: Jam Anda >15 detik cepat
- Dampak: Blok ditolak oleh jaringan
- Perbaikan: Sinkronkan jam sistem segera

---

## Keputusan Desain dan Alasan

### Mengapa Toleransi 15 Detik?

**Alasan**:
- Waktu deadline variabel Bitcoin-PoCX kurang kritis waktu dibandingkan konsensus waktu-tetap
- 15 detik memberikan perlindungan yang memadai sambil mencegah fragmentasi jaringan

**Trade-off**:
- Toleransi lebih ketat = lebih banyak fragmentasi jaringan dari penyimpangan minor
- Toleransi lebih longgar = lebih banyak peluang untuk serangan waktu
- 15 detik menyeimbangkan keamanan dan kekokohan

### Mengapa Peringatan 10 Detik?

**Alasan**:
- Memberikan buffer keamanan 5 detik
- Lebih sesuai untuk PoC daripada default 10 menit Bitcoin
- Memungkinkan perbaikan proaktif sebelum kegagalan kritis

### Mengapa Defensive Forging?

**Masalah yang Diatasi**:
- Toleransi 15 detik memungkinkan keuntungan jam cepat
- Konsensus berbasis kualitas dapat dirusak oleh manipulasi waktu

**Manfaat Solusi**:
- Pertahanan tanpa biaya (tidak ada perubahan konsensus)
- Operasi otomatis
- Menghilangkan insentif serangan
- Menjaga prinsip proof-of-capacity

### Mengapa Tidak Ada Sinkronisasi Waktu Intra-Jaringan?

**Alasan Keamanan**:
- Bitcoin Core modern menghapus penyesuaian waktu berbasis peer
- Rentan terhadap serangan Sybil pada waktu jaringan yang dipersepsikan
- PoCX dengan sengaja menghindari mengandalkan sumber waktu internal jaringan
- Jam sistem lebih dapat dipercaya daripada konsensus peer
- Operator harus menyinkronkan menggunakan NTP atau sumber waktu eksternal yang setara
- Node memantau penyimpangan mereka sendiri dan mengeluarkan peringatan jika jam lokal menyimpang dari timestamp blok terbaru

---

## Referensi Implementasi

**File Inti**:
- Validasi waktu: `src/validation.cpp:4547-4561`
- Konstanta toleransi masa depan: `src/chain.h:31`
- Ambang peringatan: `src/node/timeoffsets.h:27`
- Pemantauan offset waktu: `src/node/timeoffsets.cpp`
- Defensive forging: `src/pocx/mining/scheduler.cpp`

**Dokumentasi Terkait**:
- Algoritma Time Bending: [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md#kalkulasi-time-bending)
- Validasi blok: [Bab 3: Validasi Blok](3-consensus-and-mining.md#validasi-blok)

---

**Dihasilkan**: 2025-10-10
**Status**: Implementasi Lengkap
**Cakupan**: Persyaratan sinkronisasi waktu, penanganan penyimpangan jam, defensive forging

---

[Sebelumnya: Penugasan Forging](4-forging-assignments.md) | [Daftar Isi](index.md) | [Berikutnya: Parameter Jaringan](6-network-parameters.md)
