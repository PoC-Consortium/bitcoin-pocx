[← Önceki: Zaman Senkronizasyonu](5-timing-security.md) | [İçindekiler](index.md) | [Sonraki: RPC Referansı →](7-rpc-reference.md)

---

# Bölüm 6: Ağ Parametreleri ve Yapılandırma

Tüm ağ türlerinde Bitcoin-PoCX ağ yapılandırması için eksiksiz referans.

---

## İçindekiler

1. [Genesis Blok Parametreleri](#genesis-blok-parametreleri)
2. [Chainparams Yapılandırması](#chainparams-yapılandırması)
3. [Konsensüs Parametreleri](#konsensüs-parametreleri)
4. [Coinbase ve Blok Ödülleri](#coinbase-ve-blok-ödülleri)
5. [Dinamik Ölçeklendirme](#dinamik-ölçeklendirme)
6. [Ağ Yapılandırması](#ağ-yapılandırması)
7. [Veri Dizini Yapısı](#veri-dizini-yapısı)

---

## Genesis Blok Parametreleri

### Temel Hedef Hesaplaması

**Formül**: `genesis_base_target = 2^42 / block_time_seconds`

**Gerekçe**:
- Her nonce 256 KiB'ı temsil eder (64 bayt × 4096 scoop)
- 1 TiB = 2^22 nonce (başlangıç ağ kapasitesi varsayımı)
- n nonce için beklenen minimum kalite ≈ 2^64 / n
- 1 TiB için: E(kalite) = 2^64 / 2^22 = 2^42
- Dolayısıyla: base_target = 2^42 / block_time

**Hesaplanan Değerler**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Düşük kapasite kalibrasyon modu kullanır

### Genesis Mesajı

Tüm ağlar Bitcoin genesis mesajını paylaşır:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Uygulama**: `src/kernel/chainparams.cpp`

---

## Chainparams Yapılandırması

### Mainnet Parametreleri

**Ağ Kimliği**:
- **Sihirli Baytlar**: `0xa7 0x3c 0x91 0x5e`
- **Varsayılan Port**: `8888`
- **Bech32 HRP**: `pocx`

**Adres Önekleri** (Base58):
- PUBKEY_ADDRESS: `85` (adresler 'P' ile başlar)
- SCRIPT_ADDRESS: `90` (adresler 'R' ile başlar)
- SECRET_KEY: `128`

**Blok Zamanlaması**:
- **Blok Süresi Hedefi**: `120` saniye (2 dakika)
- **Hedef Zaman Aralığı**: `1209600` saniye (14 gün)
- **MAX_FUTURE_BLOCK_TIME**: `15` saniye

**Blok Ödülleri**:
- **Başlangıç Sübvansiyonu**: `10 BTC`
- **Yarılanma Aralığı**: `1050000` blok (~4 yıl)
- **Yarılanma Sayısı**: maksimum 64 yarılanma

**Zorluk Ayarlaması**:
- **Yuvarlanan Pencere**: `24` blok
- **Ayarlama**: Her blok
- **Algoritma**: Üstel hareketli ortalama

**Atama Gecikmeleri**:
- **Aktivasyon**: `30` blok (~1 saat)
- **İptal**: `720` blok (~24 saat)

### Testnet Parametreleri

**Ağ Kimliği**:
- **Sihirli Baytlar**: `0x6d 0xf2 0x48 0xb3`
- **Varsayılan Port**: `18888`
- **Bech32 HRP**: `tpocx`

**Adres Önekleri** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Blok Zamanlaması**:
- **Blok Süresi Hedefi**: `120` saniye
- **MAX_FUTURE_BLOCK_TIME**: `15` saniye
- **Minimum Zorluk İzni**: `true`

**Blok Ödülleri**:
- **Başlangıç Sübvansiyonu**: `10 BTC`
- **Yarılanma Aralığı**: `1050000` blok

**Zorluk Ayarlaması**:
- **Yuvarlanan Pencere**: `24` blok

**Atama Gecikmeleri**:
- **Aktivasyon**: `30` blok (~1 saat)
- **İptal**: `720` blok (~24 saat)

### Regtest Parametreleri

**Ağ Kimliği**:
- **Sihirli Baytlar**: `0xfa 0xbf 0xb5 0xda`
- **Varsayılan Port**: `18444`
- **Bech32 HRP**: `rpocx`

**Adres Önekleri** (Bitcoin uyumlu):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Blok Zamanlaması**:
- **Blok Süresi Hedefi**: `1` saniye (test için anında madencilik)
- **Hedef Zaman Aralığı**: `86400` saniye (1 gün)
- **MAX_FUTURE_BLOCK_TIME**: `15` saniye

**Blok Ödülleri**:
- **Başlangıç Sübvansiyonu**: `10 BTC`
- **Yarılanma Aralığı**: `500` blok

**Zorluk Ayarlaması**:
- **Yuvarlanan Pencere**: `24` blok
- **Minimum Zorluk İzni**: `true`
- **Yeniden Hedefleme Yok**: `true`
- **Düşük Kapasite Kalibrasyonu**: `true` (1 TiB yerine 16 nonce kalibrasyonu kullanır)

**Atama Gecikmeleri**:
- **Aktivasyon**: `4` blok (~4 saniye)
- **İptal**: `8` blok (~8 saniye)

### Signet Parametreleri

**Ağ Kimliği**:
- **Sihirli Baytlar**: SHA256d(signet_challenge)'ın ilk 4 baytı
- **Varsayılan Port**: `38333`
- **Bech32 HRP**: `tpocx`

**Blok Zamanlaması**:
- **Blok Süresi Hedefi**: `120` saniye
- **MAX_FUTURE_BLOCK_TIME**: `15` saniye

**Blok Ödülleri**:
- **Başlangıç Sübvansiyonu**: `10 BTC`
- **Yarılanma Aralığı**: `1050000` blok

**Zorluk Ayarlaması**:
- **Yuvarlanan Pencere**: `24` blok

---

## Konsensüs Parametreleri

### Zamanlama Parametreleri

**MAX_FUTURE_BLOCK_TIME**: `15` saniye
- PoCX'e özgü (Bitcoin 2 saat kullanır)
- Gerekçe: PoC zamanlaması neredeyse gerçek zamanlı doğrulama gerektirir
- 15 saniyeden fazla gelecekteki bloklar reddedilir

**Zaman Ofseti Uyarısı**: `10` saniye
- Düğüm saati ağ zamanından >10s saptığında operatörler uyarılır
- Uygulama yok, yalnızca bilgilendirme

**Blok Süresi Hedefleri**:
- Mainnet/Testnet/Signet: `120` saniye
- Regtest: `1` saniye

**TIMESTAMP_WINDOW**: `15` saniye (MAX_FUTURE_BLOCK_TIME'a eşit)

**Uygulama**: `src/chain.h`, `src/validation.cpp`

### Zorluk Ayarlama Parametreleri

**Yuvarlanan Pencere Boyutu**: `24` blok (tüm ağlar)
- Son blok sürelerinin üstel hareketli ortalaması
- Her blokta ayarlama
- Kapasite değişikliklerine duyarlı

**Uygulama**: `src/consensus/params.h`, blok oluşturmada zorluk mantığı

### Atama Sistemi Parametreleri

**nForgingAssignmentDelay** (aktivasyon gecikmesi):
- Mainnet: `30` blok (~1 saat)
- Testnet: `30` blok (~1 saat)
- Regtest: `4` blok (~4 saniye)

**nForgingRevocationDelay** (iptal gecikmesi):
- Mainnet: `720` blok (~24 saat)
- Testnet: `720` blok (~24 saat)
- Regtest: `8` blok (~8 saniye)

**Gerekçe**:
- Aktivasyon gecikmesi blok yarışları sırasında hızlı yeniden atamayı önler
- İptal gecikmesi kararlılık sağlar ve kötüye kullanımı önler

**Uygulama**: `src/consensus/params.h`

---

## Coinbase ve Blok Ödülleri

### Blok Sübvansiyon Programı

**Başlangıç Sübvansiyonu**: `10 BTC` (tüm ağlar)

**Yarılanma Programı**:
- Her `1050000` blokta (mainnet/testnet)
- Her `500` blokta (regtest)
- Maksimum 64 yarılanma devam eder

**Yarılanma İlerlemesi**:
```
Yarılanma 0: 10.00000000 BTC  (bloklar 0 - 1049999)
Yarılanma 1:  5.00000000 BTC  (bloklar 1050000 - 2099999)
Yarılanma 2:  2.50000000 BTC  (bloklar 2100000 - 3149999)
Yarılanma 3:  1.25000000 BTC  (bloklar 3150000 - 4199999)
...
```

**Toplam Arz**: ~21 milyon BTC (Bitcoin ile aynı)

### Coinbase Çıktı Kuralları

**Ödeme Hedefi**:
- **Atama Yok**: Coinbase plot adresine öder (proof.account_id)
- **Atama İle**: Coinbase dövme adresine öder (etkin imzalayan)

**Çıktı Formatı**: Yalnızca P2WPKH
- Coinbase bech32 SegWit v0 adresine ödeme yapmalı
- Etkin imzalayanın açık anahtarından oluşturulur

**Atama Çözümlemesi**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Uygulama**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Dinamik Ölçeklendirme

### Ölçeklendirme Sınırları

**Amaç**: Ağ olgunlaştıkça kapasite enflasyonunu önlemek için plot üretim zorluğunu artırır

**Yapı**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Kabul edilen minimum seviye
    uint8_t nPoCXTargetCompression;  // Önerilen seviye
};
```

**İlişki**: `target = min + 1` (her zaman minimumun bir seviye üstünde)

### Ölçeklendirme Artış Programı

Ölçeklendirme seviyeleri, yarılanma aralıklarına dayalı **üstel programa** göre artar:

| Zaman Dönemi | Blok Yüksekliği | Yarılanmalar | Min | Hedef |
|--------------|-----------------|--------------|-----|-------|
| Yıl 0-4 | 0 ile 1049999 | 0 | X1 | X2 |
| Yıl 4-12 | 1050000 ile 3149999 | 1-2 | X2 | X3 |
| Yıl 12-28 | 3150000 ile 7349999 | 3-6 | X3 | X4 |
| Yıl 28-60 | 7350000 ile 15749999 | 7-14 | X4 | X5 |
| Yıl 60-124 | 15750000 ile 32549999 | 15-30 | X5 | X6 |
| Yıl 124+ | 32550000+ | 31+ | X6 | X7 |

**Anahtar Yükseklikler** (yıllar → yarılanmalar → bloklar):
- Yıl 4: Yarılanma 1, blok 1050000
- Yıl 12: Yarılanma 3, blok 3150000
- Yıl 28: Yarılanma 7, blok 7350000
- Yıl 60: Yarılanma 15, blok 15750000
- Yıl 124: Yarılanma 31, blok 32550000

### Ölçeklendirme Seviyesi Zorluğu

**PoW Ölçeklendirmesi**:
- Ölçeklendirme seviyesi X0: POC2 temel çizgisi (teorik)
- Ölçeklendirme seviyesi X1: XOR-transpose temel çizgisi
- Ölçeklendirme seviyesi Xn: 2^(n-1) × X1 işi gömülü
- Her seviye plot üretim işini iki katına çıkarır

**Ekonomik Uyum**:
- Blok ödülleri yarılanır → plot üretim zorluğu artar
- Güvenlik marjını korur: plot oluşturma maliyeti > arama maliyeti
- Donanım iyileştirmelerinden kaynaklanan kapasite enflasyonunu önler

### Plot Doğrulaması

**Doğrulama Kuralları**:
- Gönderilen kanıtlar ölçeklendirme seviyesi ≥ minimum olmalı
- Ölçeklendirme > hedef olan kanıtlar kabul edilir ancak verimsiz
- Minimum altı kanıtlar: reddedilir (yetersiz PoW)

**Sınır Alımı**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Uygulama**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Ağ Yapılandırması

### Seed Düğümler ve DNS Seed'leri

**Durum**: Mainnet lansmanı için yer tutucu

**Planlanan Yapılandırma**:
- Seed düğümler: Belirlenecek
- DNS seed'leri: Belirlenecek

**Mevcut Durum** (testnet/regtest):
- Özel seed altyapısı yok
- `-addnode` ile manuel eş bağlantıları desteklenir

**Uygulama**: `src/kernel/chainparams.cpp`

### Kontrol Noktaları

**Genesis Kontrol Noktası**: Her zaman blok 0

**Ek Kontrol Noktaları**: Şu anda yapılandırılmamış

**Gelecek**: Mainnet ilerledikçe kontrol noktaları eklenecek

---

## P2P Protokol Yapılandırması

### Protokol Sürümü

**Temel**: Bitcoin Core v30.0 protokolü
- **Protokol Sürümü**: Bitcoin Core'dan miras
- **Servis Bitleri**: Standart Bitcoin servisleri
- **Mesaj Türleri**: Standart Bitcoin P2P mesajları

**PoCX Uzantıları**:
- Blok başlıkları PoCX'e özgü alanlar içerir
- Blok mesajları PoCX kanıt verisini içerir
- Doğrulama kuralları PoCX konsensüsünü uygular

**Uyumluluk**: PoCX düğümleri Bitcoin PoW düğümleriyle uyumsuz (farklı konsensüs)

**Uygulama**: `src/protocol.h`, `src/net_processing.cpp`

---

## Veri Dizini Yapısı

### Varsayılan Dizin

**Konum**: `.bitcoin/` (Bitcoin Core ile aynı)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Dizin İçeriği

```
.bitcoin/
├── blocks/              # Blok verisi
│   ├── blk*.dat        # Blok dosyaları
│   ├── rev*.dat        # Geri alma verisi
│   └── index/          # Blok indeksi (LevelDB)
├── chainstate/         # UTXO kümesi + dövme atamaları (LevelDB)
├── wallets/            # Cüzdan dosyaları
│   └── wallet.dat      # Varsayılan cüzdan
├── bitcoin.conf        # Yapılandırma dosyası
├── debug.log           # Hata ayıklama günlüğü
├── peers.dat           # Eş adresleri
├── mempool.dat         # Mempool kalıcılığı
└── banlist.dat         # Yasaklı eşler
```

### Bitcoin'den Temel Farklar

**Chainstate Veritabanı**:
- Standart: UTXO kümesi
- **PoCX Eklemesi**: Dövme atama durumu
- Atomik güncellemeler: UTXO + atamalar birlikte güncellenir
- Atamalar için yeniden düzenleme güvenli geri alma verisi

**Blok Dosyaları**:
- Standart Bitcoin blok formatı
- **PoCX Eklemesi**: PoCX kanıt alanlarıyla genişletilmiş (account_id, seed, nonce, imza, pubkey)

### Yapılandırma Dosyası Örneği

**bitcoin.conf**:
```ini
# Ağ seçimi
#testnet=1
#regtest=1

# PoCX madencilik sunucusu (harici madenciler için gerekli)
miningserver=1

# RPC ayarları
server=1
rpcuser=kullanici_adiniz
rpcpassword=sifreniz
rpcallowip=127.0.0.1
rpcport=8332

# Bağlantı ayarları
listen=1
port=8888
maxconnections=125

# Blok süresi hedefi (bilgilendirme, konsensüs tarafından zorunlu)
# mainnet/testnet için 120 saniye
```

---

## Kod Referansları

**Chainparams**: `src/kernel/chainparams.cpp`
**Konsensüs Parametreleri**: `src/consensus/params.h`
**Sıkıştırma Sınırları**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Genesis Temel Hedef Hesaplaması**: `src/pocx/consensus/params.cpp`
**Coinbase Ödeme Mantığı**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Atama Durumu Depolama**: `src/coins.h`, `src/coins.cpp` (CCoinsViewCache uzantıları)

---

## Çapraz Referanslar

İlgili bölümler:
- [Bölüm 2: Plot Formatı](2-plot-format.md) - Plot üretiminde ölçeklendirme seviyeleri
- [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md) - Ölçeklendirme doğrulaması, atama sistemi
- [Bölüm 4: Dövme Atamaları](4-forging-assignments.md) - Atama gecikme parametreleri
- [Bölüm 5: Zamanlama Güvenliği](5-timing-security.md) - MAX_FUTURE_BLOCK_TIME gerekçesi

---

[← Önceki: Zaman Senkronizasyonu](5-timing-security.md) | [İçindekiler](index.md) | [Sonraki: RPC Referansı →](7-rpc-reference.md)
