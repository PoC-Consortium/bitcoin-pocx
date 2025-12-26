# Bitcoin-PoCX: Konsensus Hemat Energi untuk Bitcoin Core

**Versi**: 2.0 Draft
**Tanggal**: Desember 2025
**Organisasi**: Proof of Capacity Consortium

---

## Abstrak

Konsensus Proof-of-Work (PoW) Bitcoin memberikan keamanan yang kokoh tetapi mengonsumsi energi yang substansial karena komputasi hash real-time yang terus-menerus. Kami mempresentasikan Bitcoin-PoCX, sebuah fork Bitcoin yang menggantikan PoW dengan Proof of Capacity (PoC), di mana penambang melakukan prakomputasi dan menyimpan set hash besar yang disimpan di disk selama plotting dan kemudian menambang dengan melakukan pencarian ringan daripada hashing berkelanjutan. Dengan menggeser komputasi dari fase penambangan ke fase plotting satu kali, Bitcoin-PoCX secara drastis mengurangi konsumsi energi sambil memungkinkan penambangan pada perangkat keras komoditas, menurunkan hambatan partisipasi dan memitigasi tekanan sentralisasi yang melekat dalam PoW yang didominasi ASIC, sambil tetap mempertahankan asumsi keamanan dan perilaku ekonomi Bitcoin.

Implementasi kami memperkenalkan beberapa inovasi utama:
(1) Format plot yang diperkeras yang menghilangkan semua serangan tradeoff waktu-memori yang diketahui dalam sistem PoC yang ada, memastikan bahwa kekuatan penambangan efektif tetap proporsional secara ketat dengan kapasitas penyimpanan yang berkomitmen;
(2) Algoritma Time-Bending, yang mengubah distribusi deadline dari eksponensial ke chi-squared, mengurangi varians waktu blok tanpa mengubah rata-rata;
(3) Mekanisme penugasan forging berbasis OP_RETURN yang memungkinkan penambangan pool non-kustodial; dan
(4) Penskalaan kompresi dinamis, yang meningkatkan kesulitan pembuatan plot selaras dengan jadwal halving untuk mempertahankan margin keamanan jangka panjang seiring peningkatan perangkat keras.

Bitcoin-PoCX mempertahankan arsitektur Bitcoin Core melalui modifikasi minimal yang ditandai dengan fitur, mengisolasi logika PoC dari kode konsensus yang ada. Sistem ini mempertahankan kebijakan moneter Bitcoin dengan menargetkan interval blok 120 detik dan menyesuaikan subsidi blok menjadi 10 BTC. Subsidi yang dikurangi mengimbangi peningkatan lima kali lipat dalam frekuensi blok, menjaga tingkat penerbitan jangka panjang selaras dengan jadwal asli Bitcoin dan mempertahankan pasokan maksimum ~21 juta.

---

## 1. Pendahuluan

### 1.1 Motivasi

Konsensus Proof-of-Work (PoW) Bitcoin telah terbukti aman selama lebih dari satu dekade, tetapi dengan biaya yang signifikan: penambang harus terus-menerus mengeluarkan sumber daya komputasi, menghasilkan konsumsi energi yang tinggi. Di luar masalah efisiensi, ada motivasi yang lebih luas: mengeksplorasi mekanisme konsensus alternatif yang mempertahankan keamanan sambil menurunkan hambatan partisipasi. PoC memungkinkan hampir semua orang dengan perangkat keras penyimpanan komoditas untuk menambang secara efektif, mengurangi tekanan sentralisasi yang terlihat dalam penambangan PoW yang didominasi ASIC.

Proof of Capacity (PoC) mencapai ini dengan menurunkan kekuatan penambangan dari komitmen penyimpanan daripada komputasi berkelanjutan. Penambang melakukan prakomputasi set hash besar yang disimpan di disk—plot—selama fase plotting satu kali. Penambangan kemudian terdiri dari pencarian ringan, secara drastis mengurangi penggunaan energi sambil mempertahankan asumsi keamanan konsensus berbasis sumber daya.

### 1.2 Integrasi dengan Bitcoin Core

Bitcoin-PoCX mengintegrasikan konsensus PoC ke dalam Bitcoin Core daripada membuat blockchain baru. Pendekatan ini memanfaatkan keamanan Bitcoin Core yang terbukti, stack jaringan yang matang, dan tooling yang diadopsi secara luas, sambil menjaga modifikasi minimal dan ditandai dengan fitur. Logika PoC diisolasi dari kode konsensus yang ada, memastikan bahwa fungsionalitas inti—validasi blok, operasi dompet, format transaksi—sebagian besar tetap tidak berubah.

### 1.3 Tujuan Desain

**Keamanan**: Mempertahankan kekokohan setara Bitcoin; serangan memerlukan kapasitas penyimpanan mayoritas.

**Efisiensi**: Mengurangi beban komputasi berkelanjutan ke tingkat I/O disk.

**Aksesibilitas**: Memungkinkan penambangan dengan perangkat keras komoditas, menurunkan hambatan masuk.

**Integrasi Minimal**: Memperkenalkan konsensus PoC dengan footprint modifikasi minimal.

---

## 2. Latar Belakang: Proof of Capacity

### 2.1 Sejarah

Proof of Capacity (PoC) diperkenalkan oleh Burstcoin pada tahun 2014 sebagai alternatif hemat energi untuk Proof-of-Work (PoW). Burstcoin mendemonstrasikan bahwa kekuatan penambangan dapat diturunkan dari penyimpanan yang berkomitmen daripada hashing real-time terus-menerus: penambang melakukan prakomputasi dataset besar ("plot") sekali dan kemudian menambang dengan membaca bagian kecil dan tetap dari mereka.

Implementasi PoC awal membuktikan konsep ini layak tetapi juga mengungkapkan bahwa format plot dan struktur kriptografis sangat penting untuk keamanan. Beberapa tradeoff waktu-memori memungkinkan penyerang untuk menambang secara efektif dengan penyimpanan lebih sedikit daripada peserta jujur. Ini menyoroti bahwa keamanan PoC bergantung pada desain plot—bukan hanya pada penggunaan penyimpanan sebagai sumber daya.

Warisan Burstcoin menetapkan PoC sebagai mekanisme konsensus praktis dan memberikan fondasi di mana PoCX dibangun.

### 2.2 Konsep Inti

Penambangan PoC didasarkan pada file plot besar yang sudah dihitung sebelumnya yang disimpan di disk. Plot ini berisi "komputasi beku": hashing mahal dilakukan sekali selama plotting, dan penambangan kemudian terdiri dari pembacaan disk ringan dan verifikasi sederhana. Elemen inti meliputi:

**Nonce:**
Unit dasar data plot. Setiap nonce berisi 4096 scoop (total 256 KiB) yang dihasilkan via Shabal256 dari alamat penambang dan indeks nonce.

**Scoop:**
Segmen 64-byte di dalam nonce. Untuk setiap blok, jaringan secara deterministik memilih indeks scoop (0-4095) berdasarkan tanda tangan generasi blok sebelumnya. Hanya scoop ini per nonce yang harus dibaca.

**Tanda Tangan Generasi:**
Nilai 256-bit yang diturunkan dari blok sebelumnya. Ini menyediakan entropi untuk pemilihan scoop dan mencegah penambang memprediksi indeks scoop masa depan.

**Warp:**
Grup struktural dari 4096 nonce (1 GiB). Warp adalah unit yang relevan untuk format plot tahan kompresi.

### 2.3 Proses Penambangan dan Pipeline Kualitas

Penambangan PoC terdiri dari langkah plotting satu kali dan rutinitas ringan per-blok:

**Setup Satu Kali:**
- Pembuatan plot: Hitung nonce via Shabal256 dan tulis ke disk.

**Penambangan Per-Blok:**
- Pemilihan scoop: Tentukan indeks scoop dari tanda tangan generasi.
- Pemindaian plot: Baca scoop tersebut dari semua nonce dalam plot penambang.

**Pipeline Kualitas:**
- Kualitas mentah: Hash setiap scoop dengan tanda tangan generasi menggunakan Shabal256Lite untuk mendapatkan nilai kualitas 64-bit (lebih rendah lebih baik).
- Deadline: Konversi kualitas menjadi deadline menggunakan base target (parameter yang disesuaikan kesulitan yang memastikan jaringan mencapai interval blok yang ditargetkan): `deadline = quality / base_target`
- Deadline bended: Terapkan transformasi Time-Bending untuk mengurangi varians sambil mempertahankan waktu blok yang diharapkan.

**Forging Blok:**
Penambang dengan deadline (bended) terpendek mem-forge blok berikutnya setelah waktu tersebut berlalu.

Tidak seperti PoW, hampir semua komputasi terjadi selama plotting; penambangan aktif terutama terikat disk dan sangat rendah daya.

### 2.4 Kerentanan yang Diketahui dalam Sistem Sebelumnya

**Cacat Distribusi POC1:**
Format POC1 Burstcoin asli menunjukkan bias struktural: scoop indeks rendah secara signifikan lebih murah untuk dihitung ulang secara langsung daripada scoop indeks tinggi. Ini memperkenalkan tradeoff waktu-memori non-seragam, memungkinkan penyerang untuk mengurangi penyimpanan yang diperlukan untuk scoop tersebut dan merusak asumsi bahwa semua data yang sudah dihitung sebelumnya sama mahalnya.

**Serangan Kompresi XOR (POC2):**
Dalam POC2, penyerang dapat mengambil set 8192 nonce dan mempartisinya menjadi dua blok dari 4096 nonce (A dan B). Alih-alih menyimpan kedua blok, penyerang hanya menyimpan struktur turunan: `A XOR transpose(B)`, di mana transpose menukar indeks scoop dan nonce—scoop S dari nonce N di blok B menjadi scoop N dari nonce S.

Selama penambangan, ketika scoop S dari nonce N diperlukan, penyerang merekonstruksinya dengan:
1. Membaca nilai XOR yang disimpan pada posisi (S, N)
2. Menghitung nonce N dari blok A untuk mendapatkan scoop S
3. Menghitung nonce S dari blok B untuk mendapatkan scoop transpose N
4. XOR ketiga nilai untuk memulihkan scoop 64-byte asli

Ini mengurangi penyimpanan sebesar 50%, sementara hanya memerlukan dua komputasi nonce per pencarian—biaya jauh di bawah ambang yang diperlukan untuk menegakkan prakomputasi penuh. Serangan ini layak karena menghitung baris (satu nonce, 4096 scoop) tidak mahal, sedangkan menghitung kolom (satu scoop di 4096 nonce) akan memerlukan regenerasi semua nonce. Struktur transpose mengekspos ketidakseimbangan ini.

Ini mendemonstrasikan kebutuhan akan format plot yang mencegah rekombinasi terstruktur tersebut dan menghilangkan tradeoff waktu-memori yang mendasarinya. Bagian 3.3 menjelaskan bagaimana PoCX mengatasi dan menyelesaikan kelemahan ini.

### 2.5 Transisi ke PoCX

Keterbatasan sistem PoC sebelumnya memperjelas bahwa penambangan penyimpanan yang aman, adil, dan terdesentralisasi bergantung pada struktur plot yang direkayasa dengan hati-hati. Bitcoin-PoCX mengatasi masalah ini dengan format plot yang diperkeras, distribusi deadline yang ditingkatkan, dan mekanisme untuk penambangan pool terdesentralisasi—dijelaskan di bagian berikutnya.

---

## 3. Format Plot PoCX

### 3.1 Konstruksi Nonce Dasar

Nonce adalah struktur data 256 KiB yang diturunkan secara deterministik dari tiga parameter: payload alamat 20-byte, seed 32-byte, dan indeks nonce 64-bit.

Konstruksi dimulai dengan menggabungkan input ini dan melakukan hash dengan Shabal256 untuk menghasilkan hash awal. Hash ini berfungsi sebagai titik awal untuk proses ekspansi iteratif: Shabal256 diterapkan berulang kali, dengan setiap langkah bergantung pada data yang sudah dihasilkan sebelumnya, sampai seluruh buffer 256 KiB terisi. Proses berantai ini mewakili pekerjaan komputasi yang dilakukan selama plotting.

Langkah difusi akhir melakukan hash buffer yang sudah selesai dan XOR hasilnya di semua byte. Ini memastikan bahwa seluruh buffer telah dihitung dan penambang tidak dapat memotong kalkulasi. Shuffle PoC2 kemudian diterapkan, menukar bagian bawah dan atas dari setiap scoop untuk menjamin bahwa semua scoop memerlukan upaya komputasi yang setara.

Nonce akhir terdiri dari 4096 scoop masing-masing 64 byte dan membentuk unit fundamental yang digunakan dalam penambangan.

### 3.2 Tata Letak Plot Selaras SIMD

Untuk memaksimalkan throughput pada perangkat keras modern, PoCX mengorganisir data nonce di disk untuk memfasilitasi pemrosesan vektor. Alih-alih menyimpan setiap nonce secara sekuensial, PoCX menyelaraskan word 4-byte yang sesuai di beberapa nonce berurutan secara bersebelahan. Ini memungkinkan pengambilan memori tunggal untuk menyediakan data untuk semua jalur SIMD, meminimalkan cache miss dan menghilangkan overhead scatter-gather.

```
Tata letak tradisional:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Tata letak SIMD PoCX:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Tata letak ini menguntungkan penambang CPU dan GPU, memungkinkan evaluasi scoop yang di-throughput tinggi dan diparalelkan sambil mempertahankan pola akses skalar sederhana untuk verifikasi konsensus. Ini memastikan bahwa penambangan dibatasi oleh bandwidth penyimpanan daripada komputasi CPU, mempertahankan sifat rendah daya dari Proof of Capacity.

### 3.3 Struktur Warp dan Encoding XOR-Transpose

Warp adalah unit penyimpanan fundamental dalam PoCX, terdiri dari 4096 nonce (1 GiB). Format tidak terkompresi, disebut sebagai X0, berisi nonce dasar persis seperti yang dihasilkan oleh konstruksi di Bagian 3.1.

**Encoding XOR-Transpose (X1)**

Untuk menghilangkan tradeoff waktu-memori struktural yang ada dalam sistem PoC sebelumnya, PoCX menurunkan format penambangan yang diperkeras, X1, dengan menerapkan encoding XOR-transpose ke pasangan warp X0.

Untuk membangun scoop S dari nonce N dalam warp X1:

1. Ambil scoop S dari nonce N dari warp X0 pertama (posisi langsung)
2. Ambil scoop N dari nonce S dari warp X0 kedua (posisi transpose)
3. XOR dua nilai 64-byte untuk mendapatkan scoop X1

Langkah transpose menukar indeks scoop dan nonce. Dalam istilah matriks—di mana baris mewakili scoop dan kolom mewakili nonce—ini menggabungkan elemen pada posisi (S, N) di warp pertama dengan elemen pada (N, S) di warp kedua.

**Mengapa Ini Menghilangkan Permukaan Serangan Kompresi**

XOR-transpose mengunci setiap scoop dengan seluruh baris dan seluruh kolom dari data X0 yang mendasarinya. Memulihkan satu scoop X1 oleh karena itu memerlukan akses ke data yang mencakup semua 4096 indeks scoop. Setiap upaya untuk menghitung data yang hilang akan memerlukan regenerasi 4096 nonce penuh, daripada satu nonce—menghilangkan struktur biaya asimetris yang dieksploitasi oleh serangan XOR untuk POC2 (Bagian 2.4).

Akibatnya, menyimpan warp X1 penuh menjadi satu-satunya strategi yang layak secara komputasi untuk penambang, menutup tradeoff waktu-memori yang dieksploitasi dalam desain sebelumnya.

### 3.4 Tata Letak Disk

File plot PoCX terdiri dari banyak warp X1 berurutan. Untuk memaksimalkan efisiensi operasional selama penambangan, data dalam setiap file diorganisir berdasarkan scoop: semua data scoop 0 dari setiap warp disimpan secara sekuensial, diikuti oleh semua data scoop 1, dan seterusnya, hingga scoop 4095.

**Pengurutan sekuensial scoop** ini memungkinkan penambang untuk membaca data lengkap yang diperlukan untuk scoop yang dipilih dalam satu akses disk sekuensial, meminimalkan waktu seek dan memaksimalkan throughput pada perangkat penyimpanan komoditas.

Dikombinasikan dengan encoding XOR-transpose dari Bagian 3.3, tata letak ini memastikan bahwa file **diperkeras secara struktural** dan **efisien secara operasional**: pengurutan scoop sekuensial mendukung I/O disk optimal, sementara tata letak memori selaras SIMD (lihat Bagian 3.2) memungkinkan evaluasi scoop yang di-throughput tinggi dan diparalelkan.

### 3.5 Penskalaan Proof-of-Work (Xn)

PoCX mengimplementasikan prakomputasi yang dapat diskalakan melalui konsep tingkat penskalaan, dilambangkan Xn, untuk beradaptasi dengan kinerja perangkat keras yang berkembang. Format baseline X1 mewakili struktur warp pertama yang diperkeras XOR-transpose.

Setiap tingkat penskalaan Xn meningkatkan proof-of-work yang tertanam dalam setiap warp secara eksponensial relatif terhadap X1: pekerjaan yang diperlukan pada tingkat Xn adalah 2^(n-1) kali X1. Transisi dari Xn ke Xn+1 secara operasional setara dengan menerapkan XOR di pasangan warp yang berdekatan, secara bertahap menanamkan lebih banyak proof-of-work tanpa mengubah ukuran plot yang mendasarinya.

File plot yang ada yang dibuat pada tingkat penskalaan lebih rendah masih dapat digunakan untuk penambangan, tetapi mereka berkontribusi pekerjaan yang proporsional lebih sedikit terhadap pembuatan blok, mencerminkan proof-of-work tertanam yang lebih rendah. Mekanisme ini memastikan bahwa plot PoCX tetap aman, fleksibel, dan seimbang secara ekonomi dari waktu ke waktu.

### 3.6 Fungsionalitas Seed

Parameter seed memungkinkan beberapa plot yang tidak tumpang tindih per alamat tanpa koordinasi manual.

**Masalah (POC2)**: Penambang harus melacak rentang nonce secara manual di seluruh file plot untuk menghindari tumpang tindih. Nonce yang tumpang tindih membuang penyimpanan tanpa meningkatkan kekuatan penambangan.

**Solusi**: Setiap pasangan `(alamat, seed)` mendefinisikan keyspace independen. Plot dengan seed berbeda tidak pernah tumpang tindih, terlepas dari rentang nonce. Penambang dapat membuat plot dengan bebas tanpa koordinasi.

---

## 4. Konsensus Proof of Capacity

PoCX memperluas konsensus Nakamoto Bitcoin dengan mekanisme bukti yang terikat penyimpanan. Alih-alih mengeluarkan energi untuk hashing berulang, penambang berkomitmen pada sejumlah besar data yang sudah dihitung sebelumnya—plot—ke disk. Selama pembuatan blok, mereka harus menemukan bagian kecil dan tidak dapat diprediksi dari data ini dan mengubahnya menjadi bukti. Penambang yang memberikan bukti terbaik dalam jendela waktu yang diharapkan mendapatkan hak untuk mem-forge blok berikutnya.

Bab ini menjelaskan bagaimana PoCX menyusun metadata blok, menurunkan ketidakprediktabilan, dan mengubah penyimpanan statis menjadi mekanisme konsensus yang aman dan rendah varians.

### 4.1 Struktur Blok

PoCX mempertahankan header blok bergaya Bitcoin yang familiar tetapi memperkenalkan field konsensus tambahan yang diperlukan untuk penambangan berbasis kapasitas. Field-field ini secara kolektif mengikat blok ke plot penambang yang disimpan, kesulitan jaringan, dan entropi kriptografis yang mendefinisikan setiap tantangan penambangan.

Pada tingkat tinggi, blok PoCX berisi: tinggi blok, dicatat secara eksplisit untuk menyederhanakan validasi kontekstual; tanda tangan generasi, sumber entropi segar yang menghubungkan setiap blok ke pendahulunya; base target, mewakili kesulitan jaringan dalam bentuk terbalik (nilai lebih tinggi sesuai dengan penambangan lebih mudah); bukti PoCX, mengidentifikasi plot penambang, tingkat kompresi yang digunakan selama plotting, nonce yang dipilih, dan kualitas yang diturunkan darinya; dan kunci penanda tangan dan tanda tangan, membuktikan kontrol atas kapasitas yang digunakan untuk mem-forge blok (atau kunci forging yang ditugaskan).

Bukti menanamkan semua informasi yang relevan konsensus yang diperlukan oleh validator untuk menghitung ulang tantangan, memverifikasi scoop yang dipilih, dan mengkonfirmasi kualitas yang dihasilkan. Dengan memperluas daripada mendesain ulang struktur blok, PoCX tetap selaras secara konseptual dengan Bitcoin sambil memungkinkan sumber pekerjaan penambangan yang secara fundamental berbeda.

### 4.2 Rantai Tanda Tangan Generasi

Tanda tangan generasi menyediakan ketidakprediktabilan yang diperlukan untuk penambangan Proof of Capacity yang aman. Setiap blok menurunkan tanda tangan generasinya dari tanda tangan dan penanda tangan blok sebelumnya, memastikan bahwa penambang tidak dapat mengantisipasi tantangan masa depan atau melakukan prakomputasi wilayah plot yang menguntungkan:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Ini menghasilkan urutan nilai entropi yang kuat secara kriptografis dan bergantung pada penambang. Karena kunci publik penambang tidak diketahui sampai blok sebelumnya dipublikasikan, tidak ada peserta yang dapat memprediksi pemilihan scoop masa depan. Ini mencegah prakomputasi selektif atau plotting strategis dan memastikan bahwa setiap blok memperkenalkan pekerjaan penambangan yang benar-benar segar.

### 4.3 Proses Forging

Penambangan di PoCX terdiri dari mengubah data yang disimpan menjadi bukti yang sepenuhnya didorong oleh tanda tangan generasi. Meskipun prosesnya deterministik, ketidakprediktabilan tanda tangan memastikan bahwa penambang tidak dapat mempersiapkan sebelumnya dan harus berulang kali mengakses plot yang disimpan.

**Derivasi Tantangan (Pemilihan Scoop):** Penambang melakukan hash tanda tangan generasi saat ini dengan tinggi blok untuk mendapatkan indeks scoop dalam rentang 0-4095. Indeks ini menentukan segmen 64-byte mana dari setiap nonce yang disimpan yang berpartisipasi dalam bukti. Karena tanda tangan generasi bergantung pada penanda tangan blok sebelumnya, pemilihan scoop menjadi diketahui hanya pada saat publikasi blok.

**Evaluasi Bukti (Kalkulasi Kualitas):** Untuk setiap nonce dalam plot, penambang mengambil scoop yang dipilih dan melakukan hash bersama dengan tanda tangan generasi untuk mendapatkan kualitas—nilai 64-bit yang besarnya menentukan daya saing penambang. Kualitas lebih rendah sesuai dengan bukti yang lebih baik.

**Pembentukan Deadline (Time Bending):** Deadline mentah proporsional dengan kualitas dan berbanding terbalik dengan base target. Dalam desain PoC warisan, deadline ini mengikuti distribusi eksponensial yang sangat miring, menghasilkan penundaan ekor panjang yang tidak memberikan keamanan tambahan. PoCX mengubah deadline mentah menggunakan Time Bending (Bagian 4.4), mengurangi varians dan memastikan interval blok yang dapat diprediksi. Setelah deadline bended berlalu, penambang mem-forge blok dengan menanamkan bukti dan menandatanganinya dengan kunci forging efektif.

### 4.4 Time Bending

Proof of Capacity menghasilkan deadline yang terdistribusi eksponensial. Setelah periode singkat—biasanya beberapa puluh detik—setiap penambang sudah mengidentifikasi bukti terbaik mereka, dan waktu tunggu tambahan hanya berkontribusi pada latensi, bukan keamanan.

Time Bending membentuk ulang distribusi dengan menerapkan transformasi akar pangkat tiga:

`deadline_bended = scale x (quality / base_target)^(1/3)`

Faktor skala mempertahankan waktu blok yang diharapkan (120 detik) sambil secara dramatis mengurangi varians. Deadline pendek diperluas, meningkatkan propagasi blok dan keamanan jaringan. Deadline panjang dikompresi, mencegah outlier dari menunda rantai.

![Distribusi Waktu Blok](blocktime_distributions.svg)

Time Bending mempertahankan konten informasional dari bukti yang mendasarinya. Ini tidak memodifikasi daya saing antar penambang; ini hanya merealokasi waktu tunggu untuk menghasilkan interval blok yang lebih halus dan lebih dapat diprediksi. Implementasi menggunakan aritmetika fixed-point (format Q42) dan integer 256-bit untuk memastikan hasil deterministik di semua platform.

### 4.5 Penyesuaian Kesulitan

PoCX mengatur produksi blok menggunakan base target, ukuran kesulitan terbalik. Waktu blok yang diharapkan proporsional dengan rasio `quality / base_target`, jadi meningkatkan base target mempercepat pembuatan blok sementara menurunkannya memperlambat rantai.

Kesulitan menyesuaikan setiap blok menggunakan waktu terukur antara blok terbaru dibandingkan dengan interval target. Penyesuaian yang sering ini diperlukan karena kapasitas penyimpanan dapat ditambahkan atau dihapus dengan cepat—tidak seperti hashpower Bitcoin, yang berubah lebih lambat.

Penyesuaian mengikuti dua batasan panduan: **Gradualitas**—perubahan per-blok dibatasi (maksimum +-20%) untuk menghindari osilasi atau manipulasi; **Pengerasan**—base target tidak dapat melebihi nilai genesisnya, mencegah jaringan dari pernah menurunkan kesulitan di bawah asumsi keamanan asli.

### 4.6 Validitas Blok

Blok di PoCX valid ketika menyajikan bukti turunan penyimpanan yang dapat diverifikasi yang konsisten dengan status konsensus. Validator secara independen menghitung ulang pemilihan scoop, menurunkan kualitas yang diharapkan dari nonce yang dikirim dan metadata plot, menerapkan transformasi Time Bending, dan mengkonfirmasi bahwa penambang berhak mem-forge blok pada waktu yang dinyatakan.

Secara spesifik, blok yang valid memerlukan: deadline telah berlalu sejak blok induk; kualitas yang dikirim cocok dengan kualitas yang dihitung untuk bukti; tingkat penskalaan memenuhi minimum jaringan; tanda tangan generasi cocok dengan nilai yang diharapkan; base target cocok dengan nilai yang diharapkan; tanda tangan blok berasal dari penanda tangan efektif; dan coinbase membayar ke alamat penanda tangan efektif.

---

## 5. Penugasan Forging

### 5.1 Motivasi

Penugasan forging memungkinkan pemilik plot untuk mendelegasikan otoritas forging blok tanpa pernah melepaskan kepemilikan plot mereka. Mekanisme ini memungkinkan penambangan pool dan setup penyimpanan dingin sambil mempertahankan jaminan keamanan PoCX.

Dalam penambangan pool, pemilik plot dapat mengotorisasi pool untuk mem-forge blok atas nama mereka. Pool menyusun blok dan mendistribusikan hadiah, tetapi tidak pernah mendapatkan kustodi atas plot itu sendiri. Delegasi dapat dibatalkan kapan saja, dan pemilik plot tetap bebas untuk meninggalkan pool atau mengubah konfigurasi tanpa plotting ulang.

Penugasan juga mendukung pemisahan bersih antara kunci dingin dan panas. Kunci privat yang mengontrol plot dapat tetap offline, sementara kunci forging terpisah—disimpan di mesin online—menghasilkan blok. Kompromi kunci forging oleh karena itu hanya mengkompromikan otoritas forging, bukan kepemilikan. Plot tetap aman dan penugasan dapat dicabut, menutup celah keamanan segera.

Penugasan forging dengan demikian memberikan fleksibilitas operasional sambil mempertahankan prinsip bahwa kontrol atas kapasitas yang disimpan tidak boleh ditransfer ke perantara.

### 5.2 Protokol Penugasan

Penugasan dideklarasikan melalui transaksi OP_RETURN untuk menghindari pertumbuhan set UTXO yang tidak perlu. Transaksi penugasan menentukan alamat plot dan alamat forging yang diotorisasi untuk menghasilkan blok menggunakan kapasitas plot tersebut. Transaksi pencabutan hanya berisi alamat plot. Dalam kedua kasus, pemilik plot membuktikan kontrol dengan menandatangani input pengeluaran transaksi.

Setiap penugasan berkembang melalui urutan status yang didefinisikan dengan baik (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Setelah transaksi penugasan dikonfirmasi, sistem memasuki fase aktivasi singkat. Penundaan ini—30 blok, kira-kira satu jam—memastikan stabilitas selama perlombaan blok dan mencegah switching cepat adversarial dari identitas forging. Setelah periode aktivasi ini berakhir, penugasan menjadi aktif dan tetap demikian sampai pemilik plot mengeluarkan pencabutan.

Pencabutan bertransisi ke periode penundaan yang lebih lama yaitu 720 blok, kira-kira satu hari. Selama waktu ini, alamat forging sebelumnya tetap aktif. Penundaan yang lebih lama ini memberikan stabilitas operasional untuk pool, mencegah "lompat penugasan" strategis dan memberikan penyedia infrastruktur cukup kepastian untuk beroperasi secara efisien. Setelah penundaan pencabutan berakhir, pencabutan selesai, dan pemilik plot bebas untuk menunjuk kunci forging baru.

Status penugasan dipertahankan dalam struktur lapisan konsensus yang paralel dengan set UTXO dan mendukung data undo untuk penanganan reorganisasi rantai yang aman.

### 5.3 Aturan Validasi

Untuk setiap blok, validator menentukan penanda tangan efektif—alamat yang harus menandatangani blok dan menerima hadiah coinbase. Penanda tangan ini hanya bergantung pada status penugasan pada tinggi blok.

Jika tidak ada penugasan atau penugasan belum menyelesaikan fase aktivasinya, pemilik plot tetap menjadi penanda tangan efektif. Setelah penugasan menjadi aktif, alamat forging yang ditugaskan harus menandatangani. Selama pencabutan, alamat forging terus menandatangani sampai penundaan pencabutan berakhir. Hanya setelah itu otoritas kembali ke pemilik plot.

Validator menegakkan bahwa tanda tangan blok diproduksi oleh penanda tangan efektif, bahwa coinbase membayar ke alamat yang sama, dan bahwa semua transisi mengikuti penundaan aktivasi dan pencabutan yang ditentukan. Hanya pemilik plot yang dapat membuat atau mencabut penugasan; kunci forging tidak dapat memodifikasi atau memperpanjang izin mereka sendiri.

Penugasan forging oleh karena itu memperkenalkan delegasi fleksibel tanpa memperkenalkan kepercayaan. Kepemilikan kapasitas yang mendasarinya selalu tetap tertambat secara kriptografis ke pemilik plot, sementara otoritas forging dapat didelegasikan, dirotasi, atau dicabut sesuai kebutuhan operasional yang berkembang.

---

## 6. Penskalaan Dinamis

Seiring perangkat keras berkembang, biaya menghitung plot menurun relatif terhadap membaca pekerjaan yang sudah dihitung sebelumnya dari disk. Tanpa langkah pencegahan, penyerang pada akhirnya dapat menghasilkan bukti secara langsung lebih cepat daripada penambang membaca pekerjaan yang disimpan, merusak model keamanan Proof of Capacity.

Untuk mempertahankan margin keamanan yang dimaksud, PoCX mengimplementasikan jadwal penskalaan: tingkat penskalaan minimum yang diperlukan untuk plot meningkat dari waktu ke waktu. Setiap tingkat penskalaan Xn, seperti dijelaskan di Bagian 3.5, menanamkan proof-of-work yang secara eksponensial lebih banyak dalam struktur plot, memastikan bahwa penambang terus berkomitmen pada sumber daya penyimpanan yang substansial bahkan ketika komputasi menjadi lebih murah.

Jadwal selaras dengan insentif ekonomi jaringan, khususnya halving hadiah blok. Seiring hadiah per blok menurun, tingkat minimum secara bertahap meningkat, mempertahankan keseimbangan antara upaya plotting dan potensi penambangan:

| Periode | Tahun | Halving | Min Penskalaan | Pengali Pekerjaan Plot |
|---------|-------|---------|----------------|------------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2x baseline |
| Epoch 1 | 4-12 | 1-2 | X2 | 4x baseline |
| Epoch 2 | 12-28 | 3-6 | X3 | 8x baseline |
| Epoch 3 | 28-60 | 7-14 | X4 | 16x baseline |
| Epoch 4 | 60-124 | 15-30 | X5 | 32x baseline |
| Epoch 5 | 124+ | 31+ | X6 | 64x baseline |

Penambang secara opsional dapat mempersiapkan plot yang melebihi minimum saat ini sebanyak satu tingkat, memungkinkan mereka untuk merencanakan ke depan dan menghindari upgrade segera ketika jaringan bertransisi ke epoch berikutnya. Langkah opsional ini tidak memberikan keuntungan tambahan dalam hal probabilitas blok—ini hanya memungkinkan transisi operasional yang lebih mulus.

Blok yang berisi bukti di bawah tingkat penskalaan minimum untuk tinggi mereka dianggap tidak valid. Validator memeriksa tingkat penskalaan yang dideklarasikan dalam bukti terhadap persyaratan jaringan saat ini selama validasi konsensus, memastikan bahwa semua penambang yang berpartisipasi memenuhi ekspektasi keamanan yang berkembang.

---

## 7. Arsitektur Penambangan

PoCX memisahkan operasi kritis konsensus dari tugas intensif sumber daya penambangan, memungkinkan keamanan dan efisiensi. Node mempertahankan blockchain, memvalidasi blok, mengelola mempool, dan mengekspos antarmuka RPC. Miner eksternal menangani penyimpanan plot, pembacaan scoop, kalkulasi kualitas, dan manajemen deadline. Pemisahan ini menjaga logika konsensus sederhana dan dapat diaudit sambil memungkinkan penambang untuk mengoptimalkan throughput disk.

### 7.1 Antarmuka RPC Penambangan

Penambang berinteraksi dengan node melalui set panggilan RPC minimal. RPC get_mining_info menyediakan tinggi blok saat ini, tanda tangan generasi, base target, deadline target, dan rentang tingkat penskalaan plot yang dapat diterima. Menggunakan informasi ini, penambang menghitung nonce kandidat. RPC submit_nonce memungkinkan penambang untuk mengirim solusi yang diusulkan, termasuk identifier plot, indeks nonce, tingkat penskalaan, dan akun penambang. Node mengevaluasi pengiriman dan merespons dengan deadline yang dihitung jika bukti valid.

### 7.2 Scheduler Forging

Node mempertahankan scheduler forging, yang melacak pengiriman masuk dan hanya menyimpan solusi terbaik untuk setiap tinggi blok. Nonce yang dikirim diantri dengan perlindungan bawaan terhadap flooding pengiriman atau serangan denial-of-service. Scheduler menunggu sampai deadline yang dihitung berakhir atau solusi superior tiba, pada titik mana ia menyusun blok, menandatanganinya menggunakan kunci forging efektif, dan mempublikasikannya ke jaringan.

### 7.3 Defensive Forging

Untuk mencegah serangan waktu atau insentif untuk manipulasi jam, PoCX mengimplementasikan defensive forging. Jika blok pesaing tiba untuk tinggi yang sama, scheduler membandingkan solusi lokal dengan blok baru. Jika kualitas lokal superior, node mem-forge segera daripada menunggu deadline asli. Ini memastikan bahwa penambang tidak dapat memperoleh keuntungan hanya dengan menyesuaikan jam lokal; solusi terbaik selalu menang, menjaga keadilan dan keamanan jaringan.

---

## 8. Analisis Keamanan

### 8.1 Model Ancaman

PoCX memodelkan adversari dengan kemampuan substansial tetapi terbatas. Penyerang dapat mencoba membanjiri jaringan dengan transaksi tidak valid, blok cacat, atau bukti palsu untuk menguji jalur validasi. Mereka dapat dengan bebas memanipulasi jam lokal mereka dan dapat mencoba mengeksploitasi kasus tepi dalam perilaku konsensus seperti penanganan timestamp, dinamika penyesuaian kesulitan, atau aturan reorganisasi. Adversari juga diharapkan untuk menyelidiki peluang untuk menulis ulang sejarah melalui fork rantai yang ditargetkan.

Model mengasumsikan bahwa tidak ada pihak tunggal yang mengontrol mayoritas kapasitas penyimpanan jaringan total. Seperti halnya mekanisme konsensus berbasis sumber daya, penyerang kapasitas 51% dapat secara sepihak mereorganisasi rantai; batasan fundamental ini tidak spesifik untuk PoCX. PoCX juga mengasumsikan bahwa penyerang tidak dapat menghitung data plot lebih cepat daripada penambang jujur dapat membacanya dari disk. Jadwal penskalaan (Bagian 6) memastikan bahwa celah komputasi yang diperlukan untuk keamanan tumbuh dari waktu ke waktu seiring peningkatan perangkat keras.

Bagian berikut memeriksa setiap kelas serangan utama secara detail dan menjelaskan langkah pencegahan yang dibangun ke dalam PoCX.

### 8.2 Serangan Kapasitas

Seperti PoW, penyerang dengan kapasitas mayoritas dapat menulis ulang sejarah (serangan 51%). Mencapai ini memerlukan memperoleh footprint penyimpanan fisik lebih besar dari jaringan jujur—usaha yang mahal dan menuntut secara logistik. Setelah perangkat keras diperoleh, biaya operasi rendah, tetapi investasi awal menciptakan insentif ekonomi yang kuat untuk berperilaku jujur: merusak rantai akan merusak nilai basis aset penyerang sendiri.

PoC juga menghindari masalah nothing-at-stake yang terkait dengan PoS. Meskipun penambang dapat memindai plot terhadap beberapa fork yang bersaing, setiap pemindaian mengonsumsi waktu nyata—biasanya pada urutan puluhan detik per rantai. Dengan interval blok 120 detik, ini secara inheren membatasi penambangan multi-fork, dan mencoba menambang banyak fork secara bersamaan menurunkan kinerja pada semuanya. Penambangan fork oleh karena itu tidak tanpa biaya; ini secara fundamental dibatasi oleh throughput I/O.

Bahkan jika perangkat keras masa depan memungkinkan pemindaian plot hampir instan (contoh, SSD kecepatan tinggi), penyerang masih akan menghadapi persyaratan sumber daya fisik yang substansial untuk mengontrol mayoritas kapasitas jaringan, membuat serangan gaya 51% mahal dan menantang secara logistik.

Akhirnya, serangan kapasitas jauh lebih sulit untuk disewa daripada serangan hashpower. Komputasi GPU dapat diperoleh sesuai permintaan dan diarahkan ke rantai PoW mana pun secara instan. Sebaliknya, PoC memerlukan perangkat keras fisik, plotting yang memakan waktu, dan operasi I/O yang berkelanjutan. Batasan ini membuat serangan jangka pendek dan oportunistik jauh kurang layak.

### 8.3 Serangan Waktu

Waktu memainkan peran yang lebih kritis dalam Proof of Capacity daripada dalam Proof of Work. Dalam PoW, timestamp terutama mempengaruhi penyesuaian kesulitan; dalam PoC, mereka menentukan apakah deadline penambang telah berlalu dan dengan demikian apakah blok memenuhi syarat untuk forging. Deadline diukur relatif terhadap timestamp blok induk, tetapi jam lokal node digunakan untuk menilai apakah blok masuk terlalu jauh di masa depan. Untuk alasan ini PoCX menegakkan toleransi timestamp yang ketat: blok tidak boleh menyimpang lebih dari 15 detik dari jam lokal node (dibandingkan dengan jendela 2 jam Bitcoin). Batas ini bekerja di kedua arah—blok terlalu jauh di masa depan ditolak, dan node dengan jam lambat mungkin salah menolak blok masuk yang valid.

Node oleh karena itu harus menyinkronkan jam mereka menggunakan NTP atau sumber waktu yang setara. PoCX dengan sengaja menghindari mengandalkan sumber waktu internal jaringan untuk mencegah penyerang memanipulasi waktu jaringan yang dipersepsikan. Node memantau penyimpangan mereka sendiri dan mengeluarkan peringatan jika jam lokal mulai menyimpang dari timestamp blok terbaru.

Akselerasi jam—menjalankan jam lokal cepat untuk mem-forge sedikit lebih awal—hanya memberikan manfaat marjinal. Dalam toleransi yang diizinkan, defensive forging (Bagian 7.3) memastikan bahwa penambang dengan solusi lebih baik akan segera mempublikasikan setelah melihat blok awal yang inferior. Jam cepat hanya membantu penambang mempublikasikan solusi yang sudah menang beberapa detik lebih awal; itu tidak dapat mengubah bukti inferior menjadi yang menang.

Upaya untuk memanipulasi kesulitan via timestamp dibatasi oleh cap penyesuaian per-blok +-20% dan jendela bergulir 24 blok, mencegah penambang dari secara bermakna mempengaruhi kesulitan melalui permainan waktu jangka pendek.

### 8.4 Serangan Tradeoff Waktu-Memori

Tradeoff waktu-memori mencoba mengurangi persyaratan penyimpanan dengan menghitung ulang bagian plot sesuai permintaan. Sistem Proof of Capacity sebelumnya rentan terhadap serangan seperti itu, terutama cacat ketidakseimbangan scoop POC1 dan serangan kompresi XOR-transpose POC2 (Bagian 2.4). Keduanya mengeksploitasi asimetri dalam seberapa mahal untuk meregenerasi bagian tertentu dari data plot, memungkinkan adversari untuk memotong penyimpanan sambil hanya membayar penalti komputasi kecil. Juga, format plot alternatif untuk PoC2 menderita kelemahan TMTO serupa; contoh menonjol adalah Chia, yang format plotnya dapat dikurangi secara sewenang-wenang dengan faktor lebih besar dari 4.

PoCX menghilangkan permukaan serangan ini sepenuhnya melalui konstruksi nonce dan format warp-nya. Dalam setiap nonce, langkah difusi akhir melakukan hash buffer yang sepenuhnya dihitung dan XOR hasilnya di semua byte, memastikan bahwa setiap bagian buffer bergantung pada setiap bagian lainnya dan tidak dapat dipersingkat. Setelah itu, shuffle PoC2 menukar bagian bawah dan atas dari setiap scoop, menyamakan biaya komputasi untuk memulihkan scoop apa pun.

PoCX lebih lanjut menghilangkan serangan kompresi XOR-transpose POC2 dengan menurunkan format X1 yang diperkeras, di mana setiap scoop adalah XOR dari posisi langsung dan transpose di pasangan warp; ini mengunci setiap scoop dengan seluruh baris dan seluruh kolom dari data X0 yang mendasarinya, membuat rekonstruksi memerlukan ribuan nonce penuh dan dengan demikian menghilangkan tradeoff waktu-memori asimetris sepenuhnya.

Akibatnya, menyimpan plot penuh adalah satu-satunya strategi yang layak secara komputasi untuk penambang. Tidak ada shortcut yang diketahui—apakah plotting parsial, regenerasi selektif, kompresi terstruktur, atau pendekatan compute-storage hybrid—memberikan keuntungan yang bermakna. PoCX memastikan bahwa penambangan tetap terikat penyimpanan secara ketat dan bahwa kapasitas mencerminkan komitmen fisik nyata.

### 8.5 Serangan Penugasan

PoCX menggunakan mesin status deterministik untuk mengatur semua penugasan plot-ke-forger. Setiap penugasan berkembang melalui status yang didefinisikan dengan baik—UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED—dengan penundaan aktivasi dan pencabutan yang ditegakkan. Ini memastikan bahwa penambang tidak dapat secara instan mengubah penugasan untuk menipu sistem atau dengan cepat mengalihkan otoritas forging.

Karena semua transisi memerlukan bukti kriptografis—secara spesifik, tanda tangan oleh pemilik plot yang dapat diverifikasi terhadap input UTXO—jaringan dapat mempercayai legitimasi setiap penugasan. Upaya untuk melewati mesin status atau memalsukan penugasan secara otomatis ditolak selama validasi konsensus. Serangan replay juga dicegah oleh perlindungan replay transaksi bergaya Bitcoin standar, memastikan bahwa setiap aksi penugasan secara unik terikat ke input yang valid dan belum dibelanjakan.

Kombinasi governance mesin status, penundaan yang ditegakkan, dan bukti kriptografis membuat kecurangan berbasis penugasan praktis tidak mungkin: penambang tidak dapat membajak penugasan, melakukan penugasan ulang cepat selama perlombaan blok, atau menghindari jadwal pencabutan.

### 8.6 Keamanan Tanda Tangan

Tanda tangan blok di PoCX berfungsi sebagai tautan kritis antara bukti dan kunci forging efektif, memastikan bahwa hanya penambang yang diotorisasi yang dapat menghasilkan blok yang valid.

Untuk mencegah serangan maleabilitas, tanda tangan dikecualikan dari komputasi hash blok. Ini menghilangkan risiko tanda tangan malleable yang dapat merusak validasi atau memungkinkan serangan penggantian blok.

Untuk memitigasi vektor denial-of-service, ukuran tanda tangan dan kunci publik ditetapkan—65 byte untuk tanda tangan kompak dan 33 byte untuk kunci publik terkompresi—mencegah penyerang dari menggelembungkan blok untuk memicu kehabisan sumber daya atau memperlambat propagasi jaringan.

---

## 9. Implementasi

PoCX diimplementasikan sebagai ekstensi modular ke Bitcoin Core, dengan semua kode yang relevan terkandung dalam subdirektori khususnya sendiri dan diaktifkan melalui flag fitur. Desain ini menjaga integritas kode asli, memungkinkan PoCX untuk diaktifkan atau dinonaktifkan dengan bersih, yang menyederhanakan pengujian, audit, dan tetap sinkron dengan perubahan upstream.

Integrasi hanya menyentuh poin penting yang diperlukan untuk mendukung Proof of Capacity. Header blok telah diperluas untuk menyertakan field khusus PoCX, dan validasi konsensus telah diadaptasi untuk memproses bukti berbasis penyimpanan bersama pemeriksaan Bitcoin tradisional. Sistem forging, bertanggung jawab untuk mengelola deadline, penjadwalan, dan pengiriman penambang, sepenuhnya terkandung dalam modul PoCX, sementara ekstensi RPC mengekspos fungsionalitas penambangan dan penugasan ke klien eksternal. Untuk pengguna, antarmuka dompet telah ditingkatkan untuk mengelola penugasan melalui transaksi OP_RETURN, memungkinkan interaksi mulus dengan fitur konsensus baru.

Semua operasi kritis konsensus diimplementasikan dalam C++ deterministik tanpa dependensi eksternal, memastikan konsistensi lintas platform. Shabal256 digunakan untuk hashing, sementara Time Bending dan kalkulasi kualitas mengandalkan aritmetika fixed-point dan operasi 256-bit. Operasi kriptografis seperti verifikasi tanda tangan memanfaatkan library secp256k1 Bitcoin Core yang ada.

Dengan mengisolasi fungsionalitas PoCX dengan cara ini, implementasi tetap dapat diaudit, dapat dipelihara, dan sepenuhnya kompatibel dengan pengembangan Bitcoin Core yang berkelanjutan, mendemonstrasikan bahwa mekanisme konsensus terikat penyimpanan yang secara fundamental baru dapat hidup berdampingan dengan basis kode proof-of-work yang matang tanpa mengganggu integritas atau kegunaannya.

---

## 10. Parameter Jaringan

PoCX dibangun di atas infrastruktur jaringan Bitcoin dan menggunakan kembali framework parameter rantainya. Untuk mendukung penambangan berbasis kapasitas, interval blok, penanganan penugasan, dan penskalaan plot, beberapa parameter telah diperluas atau ditimpa. Ini termasuk target waktu blok, subsidi awal, jadwal halving, penundaan aktivasi dan pencabutan penugasan, serta identifier jaringan seperti magic bytes, port, dan prefiks Bech32. Lingkungan testnet dan regtest lebih lanjut menyesuaikan parameter ini untuk memungkinkan iterasi cepat dan pengujian kapasitas rendah.

Tabel di bawah merangkum pengaturan mainnet, testnet, dan regtest yang dihasilkan, menyoroti bagaimana PoCX mengadaptasi parameter inti Bitcoin ke model konsensus terikat penyimpanan.

### 10.1 Mainnet

| Parameter | Nilai |
|-----------|-------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Port default | 8888 |
| Bech32 HRP | `pocx` |
| Target waktu blok | 120 detik |
| Subsidi awal | 10 BTC |
| Interval halving | 1050000 blok (~4 tahun) |
| Total pasokan | ~21 juta BTC |
| Aktivasi penugasan | 30 blok |
| Pencabutan penugasan | 720 blok |
| Jendela bergulir | 24 blok |

### 10.2 Testnet

| Parameter | Nilai |
|-----------|-------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Port default | 18888 |
| Bech32 HRP | `tpocx` |
| Target waktu blok | 120 detik |
| Parameter lain | Sama dengan mainnet |

### 10.3 Regtest

| Parameter | Nilai |
|-----------|-------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Port default | 18444 |
| Bech32 HRP | `rpocx` |
| Target waktu blok | 1 detik |
| Interval halving | 500 blok |
| Aktivasi penugasan | 4 blok |
| Pencabutan penugasan | 8 blok |
| Mode kapasitas rendah | Diaktifkan (plot ~4 MB) |

---

## 11. Karya Terkait

Selama bertahun-tahun, beberapa proyek blockchain dan konsensus telah mengeksplorasi model penambangan berbasis penyimpanan atau hybrid. PoCX dibangun di atas keturunan ini sambil memperkenalkan peningkatan dalam keamanan, efisiensi, dan kompatibilitas.

**Burstcoin / Signum.** Burstcoin memperkenalkan sistem Proof-of-Capacity (PoC) praktis pertama pada tahun 2014, mendefinisikan konsep inti seperti plot, nonce, scoop, dan penambangan berbasis deadline. Penerusnya, terutama Signum (sebelumnya Burstcoin), memperluas ekosistem dan akhirnya berkembang menjadi apa yang dikenal sebagai Proof-of-Commitment (PoC+), menggabungkan komitmen penyimpanan dengan staking opsional untuk mempengaruhi kapasitas efektif. PoCX mewarisi fondasi penambangan berbasis penyimpanan dari proyek-proyek ini, tetapi berbeda secara signifikan melalui format plot yang diperkeras (encoding XOR-transpose), penskalaan pekerjaan plot dinamis, perataan deadline ("Time Bending"), dan sistem penugasan fleksibel—semuanya sambil berlabuh dalam basis kode Bitcoin Core daripada mempertahankan fork jaringan standalone.

**Chia.** Chia mengimplementasikan Proof of Space and Time, menggabungkan bukti penyimpanan berbasis disk dengan komponen waktu yang ditegakkan via Verifiable Delay Functions (VDF). Desainnya mengatasi kekhawatiran tertentu tentang penggunaan ulang bukti dan pembuatan tantangan segar, berbeda dari PoC klasik. PoCX tidak mengadopsi model bukti berlabuh waktu itu; sebaliknya, ia mempertahankan konsensus terikat penyimpanan dengan interval yang dapat diprediksi, dioptimalkan untuk kompatibilitas jangka panjang dengan ekonomi UTXO dan tooling turunan Bitcoin.

**Spacemesh.** Spacemesh mengusulkan skema Proof-of-Space-Time (PoST) menggunakan topologi jaringan berbasis DAG (mesh). Dalam model ini, peserta harus secara berkala membuktikan bahwa penyimpanan yang dialokasikan tetap utuh dari waktu ke waktu, daripada mengandalkan dataset tunggal yang sudah dihitung sebelumnya. PoCX, sebaliknya, memverifikasi komitmen penyimpanan pada waktu blok saja—dengan format plot yang diperkeras dan validasi bukti yang ketat—menghindari overhead bukti penyimpanan berkelanjutan sambil mempertahankan efisiensi dan desentralisasi.

---

## 12. Kesimpulan

Bitcoin-PoCX mendemonstrasikan bahwa konsensus hemat energi dapat diintegrasikan ke dalam Bitcoin Core sambil mempertahankan properti keamanan dan model ekonomi. Kontribusi utama meliputi encoding XOR-transpose (memaksa penyerang untuk menghitung 4096 nonce per pencarian, menghilangkan serangan kompresi), algoritma Time Bending (transformasi distribusi mengurangi varians waktu blok), sistem penugasan forging (delegasi berbasis OP_RETURN memungkinkan penambangan pool non-kustodial), penskalaan dinamis (selaras dengan halving untuk mempertahankan margin keamanan), dan integrasi minimal (kode yang ditandai fitur diisolasi dalam direktori khusus).

Sistem saat ini dalam fase testnet. Kekuatan penambangan berasal dari kapasitas penyimpanan daripada hash rate, mengurangi konsumsi energi dengan beberapa orde magnitude sambil mempertahankan model ekonomi Bitcoin yang terbukti.

---

## Referensi

Bitcoin Core. *Repositori Bitcoin Core.* https://github.com/bitcoin/bitcoin

Burstcoin. *Dokumentasi Teknis Proof of Capacity.* 2014.

NIST. *Kompetisi SHA-3: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Dokumentasi Protokol Spacemesh.* 2021.

PoC Consortium. *Framework PoCX.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Integrasi Bitcoin-PoCX.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lisensi**: MIT
**Organisasi**: Proof of Capacity Consortium
**Status**: Fase Testnet
