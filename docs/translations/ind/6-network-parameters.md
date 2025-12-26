[Sebelumnya: Sinkronisasi Waktu](5-timing-security.md) | [Daftar Isi](index.md) | [Berikutnya: Referensi RPC](7-rpc-reference.md)

---

# Bab 6: Parameter Jaringan dan Konfigurasi

Referensi lengkap untuk konfigurasi jaringan Bitcoin-PoCX di semua tipe jaringan.

---

## Daftar Isi

1. [Parameter Blok Genesis](#parameter-blok-genesis)
2. [Konfigurasi Chainparams](#konfigurasi-chainparams)
3. [Parameter Konsensus](#parameter-konsensus)
4. [Coinbase dan Hadiah Blok](#coinbase-dan-hadiah-blok)
5. [Penskalaan Dinamis](#penskalaan-dinamis)
6. [Konfigurasi Jaringan](#konfigurasi-jaringan)
7. [Struktur Direktori Data](#struktur-direktori-data)

---

## Parameter Blok Genesis

### Kalkulasi Base Target

**Formula**: `genesis_base_target = 2^42 / block_time_seconds`

**Alasan**:
- Setiap nonce mewakili 256 KiB (64 byte x 4096 scoop)
- 1 TiB = 2^22 nonce (asumsi kapasitas jaringan awal)
- Kualitas minimum yang diharapkan untuk n nonce ~ 2^64 / n
- Untuk 1 TiB: E(kualitas) = 2^64 / 2^22 = 2^42
- Oleh karena itu: base_target = 2^42 / block_time

**Nilai yang Dihitung**:
- Mainnet/Testnet/Signet (120 detik): `36650387592`
- Regtest (1 detik): Menggunakan mode kalibrasi kapasitas rendah

### Pesan Genesis

Semua jaringan berbagi pesan genesis Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementasi**: `src/kernel/chainparams.cpp`

---

## Konfigurasi Chainparams

### Parameter Mainnet

**Identitas Jaringan**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Port Default**: `8888`
- **Bech32 HRP**: `pocx`

**Prefiks Alamat** (Base58):
- PUBKEY_ADDRESS: `85` (alamat dimulai dengan 'P')
- SCRIPT_ADDRESS: `90` (alamat dimulai dengan 'R')
- SECRET_KEY: `128`

**Waktu Blok**:
- **Target Waktu Blok**: `120` detik (2 menit)
- **Target Timespan**: `1209600` detik (14 hari)
- **MAX_FUTURE_BLOCK_TIME**: `15` detik

**Hadiah Blok**:
- **Subsidi Awal**: `10 BTC`
- **Interval Halving**: `1050000` blok (~4 tahun)
- **Jumlah Halving**: maksimum 64 halving

**Penyesuaian Kesulitan**:
- **Jendela Bergulir**: `24` blok
- **Penyesuaian**: Setiap blok
- **Algoritma**: Rata-rata bergerak eksponensial

**Penundaan Penugasan**:
- **Aktivasi**: `30` blok (~1 jam)
- **Pencabutan**: `720` blok (~24 jam)

### Parameter Testnet

**Identitas Jaringan**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Port Default**: `18888`
- **Bech32 HRP**: `tpocx`

**Prefiks Alamat** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Waktu Blok**:
- **Target Waktu Blok**: `120` detik
- **MAX_FUTURE_BLOCK_TIME**: `15` detik
- **Izinkan Kesulitan Minimum**: `true`

**Hadiah Blok**:
- **Subsidi Awal**: `10 BTC`
- **Interval Halving**: `1050000` blok

**Penyesuaian Kesulitan**:
- **Jendela Bergulir**: `24` blok

**Penundaan Penugasan**:
- **Aktivasi**: `30` blok (~1 jam)
- **Pencabutan**: `720` blok (~24 jam)

### Parameter Regtest

**Identitas Jaringan**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Port Default**: `18444`
- **Bech32 HRP**: `rpocx`

**Prefiks Alamat** (kompatibel Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Waktu Blok**:
- **Target Waktu Blok**: `1` detik (penambangan instan untuk pengujian)
- **Target Timespan**: `86400` detik (1 hari)
- **MAX_FUTURE_BLOCK_TIME**: `15` detik

**Hadiah Blok**:
- **Subsidi Awal**: `10 BTC`
- **Interval Halving**: `500` blok

**Penyesuaian Kesulitan**:
- **Jendela Bergulir**: `24` blok
- **Izinkan Kesulitan Minimum**: `true`
- **Tanpa Retargeting**: `true`
- **Kalibrasi Kapasitas Rendah**: `true` (menggunakan kalibrasi 16-nonce daripada 1 TiB)

**Penundaan Penugasan**:
- **Aktivasi**: `4` blok (~4 detik)
- **Pencabutan**: `8` blok (~8 detik)

### Parameter Signet

**Identitas Jaringan**:
- **Magic Bytes**: 4 byte pertama dari SHA256d(signet_challenge)
- **Port Default**: `38333`
- **Bech32 HRP**: `tpocx`

**Waktu Blok**:
- **Target Waktu Blok**: `120` detik
- **MAX_FUTURE_BLOCK_TIME**: `15` detik

**Hadiah Blok**:
- **Subsidi Awal**: `10 BTC`
- **Interval Halving**: `1050000` blok

**Penyesuaian Kesulitan**:
- **Jendela Bergulir**: `24` blok

---

## Parameter Konsensus

### Parameter Waktu

**MAX_FUTURE_BLOCK_TIME**: `15` detik
- Khusus PoCX (Bitcoin menggunakan 2 jam)
- Alasan: Waktu PoC memerlukan validasi hampir real-time
- Blok lebih dari 15 detik di masa depan ditolak

**Peringatan Offset Waktu**: `10` detik
- Operator diperingatkan ketika jam node menyimpang >10 detik dari waktu jaringan
- Tidak ada penegakan, hanya informasional

**Target Waktu Blok**:
- Mainnet/Testnet/Signet: `120` detik
- Regtest: `1` detik

**TIMESTAMP_WINDOW**: `15` detik (sama dengan MAX_FUTURE_BLOCK_TIME)

**Implementasi**: `src/chain.h`, `src/validation.cpp`

### Parameter Penyesuaian Kesulitan

**Ukuran Jendela Bergulir**: `24` blok (semua jaringan)
- Rata-rata bergerak eksponensial dari waktu blok terbaru
- Penyesuaian setiap blok
- Responsif terhadap perubahan kapasitas

**Implementasi**: `src/consensus/params.h`, logika kesulitan dalam pembuatan blok

### Parameter Sistem Penugasan

**nForgingAssignmentDelay** (penundaan aktivasi):
- Mainnet: `30` blok (~1 jam)
- Testnet: `30` blok (~1 jam)
- Regtest: `4` blok (~4 detik)

**nForgingRevocationDelay** (penundaan pencabutan):
- Mainnet: `720` blok (~24 jam)
- Testnet: `720` blok (~24 jam)
- Regtest: `8` blok (~8 detik)

**Alasan**:
- Penundaan aktivasi mencegah penugasan ulang cepat selama perlombaan blok
- Penundaan pencabutan memberikan stabilitas dan mencegah penyalahgunaan

**Implementasi**: `src/consensus/params.h`

---

## Coinbase dan Hadiah Blok

### Jadwal Subsidi Blok

**Subsidi Awal**: `10 BTC` (semua jaringan)

**Jadwal Halving**:
- Setiap `1050000` blok (mainnet/testnet)
- Setiap `500` blok (regtest)
- Berlanjut untuk maksimum 64 halving

**Progresi Halving**:
```
Halving 0: 10.00000000 BTC  (blok 0 - 1049999)
Halving 1:  5.00000000 BTC  (blok 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (blok 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (blok 3150000 - 4199999)
...
```

**Total Pasokan**: ~21 juta BTC (sama dengan Bitcoin)

### Aturan Output Coinbase

**Tujuan Pembayaran**:
- **Tanpa Penugasan**: Coinbase membayar alamat plot (proof.account_id)
- **Dengan Penugasan**: Coinbase membayar alamat forging (penanda tangan efektif)

**Format Output**: Hanya P2WPKH
- Coinbase harus membayar ke alamat SegWit v0 bech32
- Dihasilkan dari kunci publik penanda tangan efektif

**Resolusi Penugasan**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementasi**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Penskalaan Dinamis

### Batas Penskalaan

**Tujuan**: Meningkatkan kesulitan pembuatan plot seiring jaringan matang untuk mencegah inflasi kapasitas

**Struktur**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Tingkat minimum yang diterima
    uint8_t nPoCXTargetCompression;  // Tingkat yang direkomendasikan
};
```

**Hubungan**: `target = min + 1` (selalu satu tingkat di atas minimum)

### Jadwal Peningkatan Penskalaan

Tingkat penskalaan meningkat pada **jadwal eksponensial** berdasarkan interval halving:

| Periode Waktu | Tinggi Blok | Halving | Min | Target |
|---------------|-------------|---------|-----|--------|
| Tahun 0-4 | 0 hingga 1049999 | 0 | X1 | X2 |
| Tahun 4-12 | 1050000 hingga 3149999 | 1-2 | X2 | X3 |
| Tahun 12-28 | 3150000 hingga 7349999 | 3-6 | X3 | X4 |
| Tahun 28-60 | 7350000 hingga 15749999 | 7-14 | X4 | X5 |
| Tahun 60-124 | 15750000 hingga 32549999 | 15-30 | X5 | X6 |
| Tahun 124+ | 32550000+ | 31+ | X6 | X7 |

**Tinggi Kunci** (tahun -> halving -> blok):
- Tahun 4: Halving 1 pada blok 1050000
- Tahun 12: Halving 3 pada blok 3150000
- Tahun 28: Halving 7 pada blok 7350000
- Tahun 60: Halving 15 pada blok 15750000
- Tahun 124: Halving 31 pada blok 32550000

### Kesulitan Tingkat Penskalaan

**Penskalaan PoW**:
- Tingkat penskalaan X0: Baseline POC2 (teoritis)
- Tingkat penskalaan X1: Baseline XOR-transpose
- Tingkat penskalaan Xn: 2^(n-1) x pekerjaan X1 tertanam
- Setiap tingkat menggandakan pekerjaan pembuatan plot

**Penyelarasan Ekonomi**:
- Hadiah blok dipotong setengah -> kesulitan pembuatan plot meningkat
- Mempertahankan margin keamanan: biaya pembuatan plot > biaya pencarian
- Mencegah inflasi kapasitas dari peningkatan perangkat keras

### Validasi Plot

**Aturan Validasi**:
- Bukti yang dikirim harus memiliki tingkat penskalaan >= minimum
- Bukti dengan penskalaan > target diterima tetapi tidak efisien
- Bukti di bawah minimum: ditolak (PoW tidak cukup)

**Pengambilan Batas**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementasi**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Konfigurasi Jaringan

### Node Seed dan DNS Seed

**Status**: Placeholder untuk peluncuran mainnet

**Konfigurasi yang Direncanakan**:
- Node seed: TBD
- DNS seed: TBD

**Status Saat Ini** (testnet/regtest):
- Tidak ada infrastruktur seed khusus
- Koneksi peer manual didukung via `-addnode`

**Implementasi**: `src/kernel/chainparams.cpp`

### Checkpoint

**Checkpoint Genesis**: Selalu blok 0

**Checkpoint Tambahan**: Tidak ada yang dikonfigurasi saat ini

**Masa Depan**: Checkpoint akan ditambahkan seiring mainnet berkembang

---

## Konfigurasi Protokol P2P

### Versi Protokol

**Basis**: Protokol Bitcoin Core v30.0
- **Versi Protokol**: Diwarisi dari Bitcoin Core
- **Bit Layanan**: Layanan Bitcoin standar
- **Tipe Pesan**: Pesan P2P Bitcoin standar

**Ekstensi PoCX**:
- Header blok menyertakan field khusus PoCX
- Pesan blok menyertakan data bukti PoCX
- Aturan validasi menegakkan konsensus PoCX

**Kompatibilitas**: Node PoCX tidak kompatibel dengan node Bitcoin PoW (konsensus berbeda)

**Implementasi**: `src/protocol.h`, `src/net_processing.cpp`

---

## Struktur Direktori Data

### Direktori Default

**Lokasi**: `.bitcoin/` (sama dengan Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Isi Direktori

```
.bitcoin/
├── blocks/              # Data blok
│   ├── blk*.dat        # File blok
│   ├── rev*.dat        # Data undo
│   └── index/          # Indeks blok (LevelDB)
├── chainstate/         # Set UTXO + penugasan forging (LevelDB)
├── wallets/            # File dompet
│   └── wallet.dat      # Dompet default
├── bitcoin.conf        # File konfigurasi
├── debug.log           # Log debug
├── peers.dat           # Alamat peer
├── mempool.dat         # Persistensi mempool
└── banlist.dat         # Peer yang dilarang
```

### Perbedaan Utama dari Bitcoin

**Database Chainstate**:
- Standar: Set UTXO
- **Tambahan PoCX**: Status penugasan forging
- Pembaruan atomik: UTXO + penugasan diperbarui bersama
- Data undo aman-reorg untuk penugasan

**File Blok**:
- Format blok Bitcoin standar
- **Tambahan PoCX**: Diperluas dengan field bukti PoCX (account_id, seed, nonce, tanda tangan, pubkey)

### Contoh File Konfigurasi

**bitcoin.conf**:
```ini
# Pemilihan jaringan
#testnet=1
#regtest=1

# Server penambangan PoCX (diperlukan untuk miner eksternal)
miningserver=1

# Pengaturan RPC
server=1
rpcuser=username_anda
rpcpassword=password_anda
rpcallowip=127.0.0.1
rpcport=8332

# Pengaturan koneksi
listen=1
port=8888
maxconnections=125

# Target waktu blok (informasional, ditegakkan konsensus)
# 120 detik untuk mainnet/testnet
```

---

## Referensi Kode

**Chainparams**: `src/kernel/chainparams.cpp`
**Parameter Konsensus**: `src/consensus/params.h`
**Batas Kompresi**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Kalkulasi Base Target Genesis**: `src/pocx/consensus/params.cpp`
**Logika Pembayaran Coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Penyimpanan Status Penugasan**: `src/coins.h`, `src/coins.cpp` (ekstensi CCoinsViewCache)

---

## Referensi Silang

Bab terkait:
- [Bab 2: Format Plot](2-plot-format.md) - Tingkat penskalaan dalam pembuatan plot
- [Bab 3: Konsensus dan Penambangan](3-consensus-and-mining.md) - Validasi penskalaan, sistem penugasan
- [Bab 4: Penugasan Forging](4-forging-assignments.md) - Parameter penundaan penugasan
- [Bab 5: Keamanan Waktu](5-timing-security.md) - Alasan MAX_FUTURE_BLOCK_TIME

---

[Sebelumnya: Sinkronisasi Waktu](5-timing-security.md) | [Daftar Isi](index.md) | [Berikutnya: Referensi RPC](7-rpc-reference.md)
