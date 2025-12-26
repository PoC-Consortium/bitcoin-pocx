[İçindekiler](index.md) | [Sonraki: Plot Formatı →](2-plot-format.md)

---

# Bölüm 1: Giriş ve Genel Bakış

## Bitcoin-PoCX Nedir?

Bitcoin-PoCX, Bitcoin Core'a **Yeni Nesil Kapasite Kanıtı (PoCX)** konsensüs desteği ekleyen bir entegrasyondur. Bitcoin Core'un mevcut mimarisini korurken, İş Kanıtının tam yerine geçen, enerji verimli bir Kapasite Kanıtı madencilik alternatifi sunar.

**Önemli Ayrım**: Bu, Bitcoin PoW ile geriye dönük uyumu olmayan **yeni bir zincirdir**. PoCX blokları, tasarım gereği PoW düğümleriyle uyumsuzdur.

---

## Proje Kimliği

- **Organizasyon**: Proof of Capacity Consortium
- **Proje Adı**: Bitcoin-PoCX
- **Tam Adı**: PoCX Entegrasyonlu Bitcoin Core
- **Durum**: Testnet Aşaması

---

## Kapasite Kanıtı Nedir?

Kapasite Kanıtı (PoC), madencilik gücünün hesaplama gücü yerine **disk alanıyla** orantılı olduğu bir konsensüs mekanizmasıdır. Madenciler, kriptografik hash'ler içeren büyük plot dosyalarını önceden oluşturur, ardından geçerli blok çözümleri bulmak için bu plot'ları kullanır.

**Enerji Verimliliği**: Plot dosyaları bir kez oluşturulur ve süresiz olarak yeniden kullanılır. Madencilik minimum CPU gücü tüketir - esas olarak disk G/Ç işlemleri.

**PoCX Geliştirmeleri**:
- XOR-transpose sıkıştırma saldırısı düzeltildi (POC2'de %50 zaman-bellek değiş tokuşu)
- Modern donanım için 16-nonce hizalı düzen
- Plot üretiminde ölçeklenebilir iş kanıtı (Xn ölçeklendirme seviyeleri)
- Doğrudan Bitcoin Core'a yerel C++ entegrasyonu
- Geliştirilmiş blok süresi dağılımı için Zaman Bükme algoritması

---

## Mimari Genel Bakış

### Depo Yapısı

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX entegrasyonu
│   └── src/pocx/        # PoCX uygulaması
├── pocx/                # PoCX çekirdek çatısı (alt modül, salt okunur)
└── docs/                # Bu dokümantasyon
```

### Entegrasyon Felsefesi

**Minimum Entegrasyon Yüzeyi**: Değişiklikler `/src/pocx/` dizininde izole edilmiş olup, Bitcoin Core doğrulama, madencilik ve RPC katmanlarına temiz kancalarla bağlanır.

**Özellik İşaretleme**: Tüm değişiklikler `#ifdef ENABLE_POCX` önişlemci korumalarının altındadır. Devre dışı bırakıldığında Bitcoin Core normal şekilde derlenir.

**Üst Akış Uyumluluğu**: Bitcoin Core güncellemeleriyle düzenli senkronizasyon, izole entegrasyon noktaları aracılığıyla sürdürülür.

**Yerel C++ Uygulaması**: Skaler kriptografik algoritmalar (Shabal256, scoop hesaplaması, sıkıştırma) konsensüs doğrulaması için doğrudan Bitcoin Core'a entegre edilmiştir.

---

## Temel Özellikler

### 1. Tam Konsensüs Değişimi

- **Blok Yapısı**: PoW nonce ve zorluk bitlerinin yerini PoCX'e özgü alanlar alır
  - Üretim imzası (deterministik madencilik entropisi)
  - Temel hedef (zorluğun tersi)
  - PoCX kanıtı (hesap kimliği, seed, nonce)
  - Blok imzası (plot sahipliğini kanıtlar)

- **Doğrulama**: Başlık kontrolünden blok bağlantısına kadar 5 aşamalı doğrulama hattı

- **Zorluk Ayarlaması**: Son temel hedeflerin hareketli ortalamasını kullanarak her blokta ayarlama

### 2. Zaman Bükme Algoritması

**Problem**: Geleneksel PoC blok süreleri üstel dağılım izler, hiçbir madenci iyi bir çözüm bulamadığında uzun bloklara yol açar.

**Çözüm**: Küp kök kullanarak üstel dağılımdan ki-kare dağılımına dönüşüm: `Y = ölçek × (X^(1/3))`.

**Etki**: Çok iyi çözümler daha geç döver (ağın tüm diskleri taraması için zaman tanır, hızlı blokları azaltır), zayıf çözümler iyileştirilir. Ortalama blok süresi 120 saniyede korunur, uzun bloklar azaltılır.

**Detaylar**: [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md)

### 3. Dövme Atama Sistemi

**Yetenek**: Plot sahipleri, plot sahipliğini korurken dövme haklarını başka adreslere devredebilir.

**Kullanım Alanları**:
- Havuz madenciliği (plot'lar havuz adresine atanır)
- Soğuk depolama (madencilik anahtarı plot sahipliğinden ayrı)
- Çok taraflı madencilik (paylaşılan altyapı)

**Mimari**: OP_RETURN tabanlı tasarım - özel UTXO yok, atamalar chainstate veritabanında ayrı olarak izlenir.

**Detaylar**: [Bölüm 4: Dövme Atamaları](4-forging-assignments.md)

### 4. Savunmacı Dövme

**Problem**: 15 saniyelik gelecek toleransı içinde hızlı saatler zamanlama avantajı sağlayabilir.

**Çözüm**: Aynı yükseklikte rakip bir blok alındığında, otomatik olarak yerel kalite kontrol edilir. Daha iyiyse, hemen döver.

**Etki**: Saat manipülasyonu teşvikini ortadan kaldırır - hızlı saatler yalnızca zaten en iyi çözüme sahipseniz yardımcı olur.

**Detaylar**: [Bölüm 5: Zamanlama Güvenliği](5-timing-security.md)

### 5. Dinamik Sıkıştırma Ölçeklendirmesi

**Ekonomik Uyum**: Ölçeklendirme seviyesi gereksinimleri üstel bir programa göre artar (Yıl 4, 12, 28, 60, 124 = yarılanmalar 1, 3, 7, 15, 31).

**Etki**: Blok ödülleri azaldıkça, plot üretim zorluğu artar. Plot oluşturma ve arama maliyetleri arasındaki güvenlik marjını korur.

**Önler**: Zamanla daha hızlı donanımdan kaynaklanan kapasite enflasyonunu.

**Detaylar**: [Bölüm 6: Ağ Parametreleri](6-network-parameters.md)

---

## Tasarım Felsefesi

### Kod Güvenliği

- Tüm sistemde savunmacı programlama pratikleri
- Doğrulama yollarında kapsamlı hata yönetimi
- İç içe kilit yok (kilitlenme önleme)
- Atomik veritabanı işlemleri (UTXO + atamalar birlikte)

### Modüler Mimari

- Bitcoin Core altyapısı ve PoCX konsensüsü arasında temiz ayrım
- PoCX çekirdek çatısı kriptografik primitifler sağlar
- Bitcoin Core doğrulama çatısı, veritabanı ve ağ iletişimi sağlar

### Performans Optimizasyonları

- Hızlı başarısızlık doğrulama sıralaması (önce ucuz kontroller)
- Gönderim başına tek bağlam alma (tekrarlanan cs_main edinimi yok)
- Tutarlılık için atomik veritabanı işlemleri

### Yeniden Düzenleme Güvenliği

- Atama durumu değişiklikleri için tam geri alma verisi
- Zincir ucu değişikliklerinde dövme durumu sıfırlama
- Tüm doğrulama noktalarında bayatlık tespiti

---

## PoCX'in İş Kanıtından Farkları

| Yön | Bitcoin (PoW) | Bitcoin-PoCX |
|-----|---------------|--------------|
| **Madencilik Kaynağı** | Hesaplama gücü (hash oranı) | Disk alanı (kapasite) |
| **Enerji Tüketimi** | Yüksek (sürekli hash) | Düşük (yalnızca disk G/Ç) |
| **Madencilik Süreci** | Hash < hedef olan nonce bul | Son tarih < geçen süre olan nonce bul |
| **Zorluk** | `bits` alanı, her 2016 blokta ayarlanır | `base_target` alanı, her blokta ayarlanır |
| **Blok Süresi** | ~10 dakika (üstel dağılım) | 120 saniye (zaman bükülmüş, azaltılmış varyans) |
| **Sübvansiyon** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Donanım** | ASIC'ler (uzmanlaşmış) | HDD'ler (standart donanım) |
| **Madencilik Kimliği** | Anonim | Plot sahibi veya temsilci |

---

## Sistem Gereksinimleri

### Düğüm İşletimi

**Bitcoin Core ile Aynı**:
- **CPU**: Modern x86_64 işlemci
- **Bellek**: 4-8 GB RAM
- **Depolama**: Yeni zincir, şu anda boş (2 dakikalık bloklar ve atama veritabanı nedeniyle Bitcoin'den ~4× daha hızlı büyüyebilir)
- **Ağ**: Kararlı internet bağlantısı
- **Saat**: Optimum işletim için NTP senkronizasyonu önerilir

**Not**: Düğüm işletimi için plot dosyaları GEREKLİ DEĞİLDİR.

### Madencilik Gereksinimleri

**Madencilik için ek gereksinimler**:
- **Plot Dosyaları**: `pocx_plotter` (referans uygulama) kullanılarak önceden oluşturulmuş
- **Madenci Yazılımı**: `pocx_miner` (referans uygulama) RPC üzerinden bağlanır
- **Cüzdan**: Madencilik adresi için özel anahtarlara sahip `bitcoind` veya `bitcoin-qt`. Havuz madenciliği yerel cüzdan gerektirmez.

---

## Başlarken

### 1. Bitcoin-PoCX Derleme

```bash
# Alt modüllerle birlikte klonlayın
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# PoCX etkin olarak derleyin
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detaylar**: Depo kök dizinindeki `CLAUDE.md` dosyasına bakın

### 2. Düğüm Çalıştırma

**Yalnızca düğüm**:
```bash
./build/bin/bitcoind
# veya
./build/bin/bitcoin-qt
```

**Madencilik için** (harici madenciler için RPC erişimini etkinleştirir):
```bash
./build/bin/bitcoind -miningserver
# veya
./build/bin/bitcoin-qt -server -miningserver
```

**Detaylar**: [Bölüm 6: Ağ Parametreleri](6-network-parameters.md)

### 3. Plot Dosyaları Oluşturma

PoCX formatında plot dosyaları oluşturmak için `pocx_plotter` (referans uygulama) kullanın.

**Detaylar**: [Bölüm 2: Plot Formatı](2-plot-format.md)

### 4. Madencilik Kurulumu

Düğümünüzün RPC arayüzüne bağlanmak için `pocx_miner` (referans uygulama) kullanın.

**Detaylar**: [Bölüm 7: RPC Referansı](7-rpc-reference.md) ve [Bölüm 8: Cüzdan Kılavuzu](8-wallet-guide.md)

---

## Atıf

### Plot Formatı

POC2 formatına (Burstcoin) dayalı, geliştirmeler dahil:
- Güvenlik açığı düzeltildi (XOR-transpose sıkıştırma saldırısı)
- Ölçeklenebilir iş kanıtı
- SIMD optimizeli düzen
- Seed işlevselliği

### Kaynak Projeler

- **pocx_miner**: [scavenger](https://github.com/PoC-Consortium/scavenger) tabanlı referans uygulama
- **pocx_plotter**: [engraver](https://github.com/PoC-Consortium/engraver) tabanlı referans uygulama

**Tam Atıf**: [Bölüm 2: Plot Formatı](2-plot-format.md)

---

## Teknik Spesifikasyon Özeti

- **Blok Süresi**: 120 saniye (mainnet), 1 saniye (regtest)
- **Blok Sübvansiyonu**: 10 BTC başlangıç, her 1050000 blokta yarılanma (~4 yıl)
- **Toplam Arz**: ~21 milyon BTC (Bitcoin ile aynı)
- **Gelecek Toleransı**: 15 saniye (15 saniyeye kadar ileride olan bloklar kabul edilir)
- **Saat Uyarısı**: 10 saniye (operatörleri zaman sapması konusunda uyarır)
- **Atama Gecikmesi**: 30 blok (~1 saat)
- **İptal Gecikmesi**: 720 blok (~24 saat)
- **Adres Formatı**: PoCX madencilik işlemleri ve dövme atamaları için yalnızca P2WPKH (bech32, pocx1q...)

---

## Kod Organizasyonu

**Bitcoin Core Değişiklikleri**: Çekirdek dosyalarda minimum değişiklik, `#ifdef ENABLE_POCX` ile özellik işaretli

**Yeni PoCX Uygulaması**: `src/pocx/` dizininde izole

---

## Güvenlik Değerlendirmeleri

### Zamanlama Güvenliği

- 15 saniyelik gelecek toleransı ağ parçalanmasını önler
- 10 saniyelik uyarı eşiği operatörleri saat sapması konusunda uyarır
- Savunmacı dövme saat manipülasyonu teşvikini ortadan kaldırır
- Zaman Bükme zamanlama varyansının etkisini azaltır

**Detaylar**: [Bölüm 5: Zamanlama Güvenliği](5-timing-security.md)

### Atama Güvenliği

- OP_RETURN tabanlı tasarım (UTXO manipülasyonu yok)
- İşlem imzası plot sahipliğini kanıtlar
- Aktivasyon gecikmeleri hızlı durum manipülasyonunu önler
- Tüm durum değişiklikleri için yeniden düzenleme güvenli geri alma verisi

**Detaylar**: [Bölüm 4: Dövme Atamaları](4-forging-assignments.md)

### Konsensüs Güvenliği

- Blok hash'inden imza hariç tutulmuş (değiştirilebilirliği önler)
- Sınırlı imza boyutları (DoS önler)
- Sıkıştırma sınırları doğrulaması (zayıf kanıtları önler)
- Her blokta zorluk ayarlaması (kapasite değişikliklerine duyarlı)

**Detaylar**: [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md)

---

## Ağ Durumu

**Mainnet**: Henüz başlatılmadı
**Testnet**: Test için kullanılabilir
**Regtest**: Geliştirme için tam işlevsel

**Genesis Blok Parametreleri**: [Bölüm 6: Ağ Parametreleri](6-network-parameters.md)

---

## Sonraki Adımlar

**PoCX'i Anlamak İçin**: Plot dosya yapısı ve format evrimini öğrenmek için [Bölüm 2: Plot Formatı](2-plot-format.md)'na devam edin.

**Madencilik Kurulumu İçin**: Entegrasyon detayları için [Bölüm 7: RPC Referansı](7-rpc-reference.md)'na atlayın.

**Düğüm Çalıştırmak İçin**: Yapılandırma seçenekleri için [Bölüm 6: Ağ Parametreleri](6-network-parameters.md)'ni inceleyin.

---

[İçindekiler](index.md) | [Sonraki: Plot Formatı →](2-plot-format.md)
