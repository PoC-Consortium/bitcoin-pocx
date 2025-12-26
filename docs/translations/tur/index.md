# Bitcoin-PoCX Teknik Dokümantasyonu

**Sürüm**: 1.0
**Bitcoin Core Temeli**: v30.0
**Durum**: Testnet Aşaması
**Son Güncelleme**: 2025-12-25

---

## Bu Dokümantasyon Hakkında

Bu, Bitcoin-PoCX için kapsamlı teknik dokümantasyondur. Bitcoin-PoCX, Bitcoin Core'a Yeni Nesil Kapasite Kanıtı (PoCX) konsensüs desteği ekleyen bir entegrasyondur. Dokümantasyon, sistemin tüm yönlerini kapsayan birbirine bağlı bölümlerden oluşan, gezinilebilir bir kılavuz olarak düzenlenmiştir.

**Hedef Kitle**:
- **Düğüm Operatörleri**: Bölüm 1, 5, 6, 8
- **Madenciler**: Bölüm 2, 3, 7
- **Geliştiriciler**: Tüm bölümler
- **Araştırmacılar**: Bölüm 3, 4, 5

## Çeviriler

| | | | | | |
|---|---|---|---|---|---|
| [🇩🇪 Almanca](../deu/index.md) | [🇸🇦 Arapça](../ara/index.md) | [🇧🇬 Bulgarca](../bul/index.md) | [🇨🇿 Çekçe](../ces/index.md) | [🇨🇳 Çince](../zho/index.md) | [🇩🇰 Danca](../dan/index.md) |
| [🇪🇪 Estonca](../est/index.md) | [🇵🇭 Filipince](../fil/index.md) | [🇫🇮 Fince](../fin/index.md) | [🇫🇷 Fransızca](../fra/index.md) | [🇮🇳 Hintçe](../hin/index.md) | [🇳🇱 Hollandaca](../nld/index.md) |
| [🇮🇱 İbranice](../heb/index.md) | [🇮🇩 Endonezce](../ind/index.md) | [🇪🇸 İspanyolca](../spa/index.md) | [🇸🇪 İsveççe](../swe/index.md) | [🇮🇹 İtalyanca](../ita/index.md) | [🇯🇵 Japonca](../jpn/index.md) |
| [🇰🇷 Korece](../kor/index.md) | [🇱🇻 Letonca](../lav/index.md) | [🇱🇹 Litvanca](../lit/index.md) | [🇭🇺 Macarca](../hun/index.md) | [🇳🇴 Norveççe](../nor/index.md) | [🇵🇱 Lehçe](../pol/index.md) |
| [🇵🇹 Portekizce](../por/index.md) | [🇷🇴 Romence](../ron/index.md) | [🇷🇺 Rusça](../rus/index.md) | [🇷🇸 Sırpça](../srp/index.md) | [🇰🇪 Svahili](../swa/index.md) | [🇺🇦 Ukraynaca](../ukr/index.md) |
| [🇻🇳 Vietnamca](../vie/index.md) | [🇬🇷 Yunanca](../ell/index.md) | | | | |

---

## İçindekiler

### Bölüm I: Temel Kavramlar

**[Bölüm 1: Giriş ve Genel Bakış](1-introduction.md)**
Projeye genel bakış, mimari, tasarım felsefesi, temel özellikler ve PoCX'in İş Kanıtından farkları.

**[Bölüm 2: Plot Dosya Formatı](2-plot-format.md)**
SIMD optimizasyonu, iş kanıtı ölçeklendirmesi ve POC1/POC2'den format evrimi dahil PoCX plot formatının tam spesifikasyonu.

**[Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md)**
PoCX konsensüs mekanizmasının teknik spesifikasyonu: blok yapısı, üretim imzaları, temel hedef ayarlaması, madencilik süreci, doğrulama hattı ve zaman bükme algoritması.

---

### Bölüm II: İleri Düzey Özellikler

**[Bölüm 4: Dövme Atama Sistemi](4-forging-assignments.md)**
Dövme haklarının devri için OP_RETURN tabanlı mimari: işlem yapısı, veritabanı tasarımı, durum makinesi, yeniden düzenleme yönetimi ve RPC arayüzü.

**[Bölüm 5: Zaman Senkronizasyonu ve Güvenlik](5-timing-security.md)**
Saat sapması toleransı, savunmacı dövme mekanizması, saat manipülasyonuna karşı koruma ve zamanlama ile ilgili güvenlik değerlendirmeleri.

**[Bölüm 6: Ağ Parametreleri](6-network-parameters.md)**
Chainparams yapılandırması, genesis bloğu, konsensüs parametreleri, coinbase kuralları, dinamik ölçeklendirme ve ekonomik model.

---

### Bölüm III: Kullanım ve Entegrasyon

**[Bölüm 7: RPC Arayüzü Referansı](7-rpc-reference.md)**
Madencilik, atamalar ve blok zinciri sorguları için eksiksiz RPC komut referansı. Madenci ve havuz entegrasyonu için temel kaynak.

**[Bölüm 8: Cüzdan ve Arayüz Kılavuzu](8-wallet-guide.md)**
Bitcoin-PoCX Qt cüzdanı kullanım kılavuzu: dövme atama penceresi, işlem geçmişi, madencilik kurulumu ve sorun giderme.

---

## Hızlı Gezinme

### Düğüm Operatörleri İçin
→ [Bölüm 1: Giriş](1-introduction.md) ile başlayın
→ Ardından [Bölüm 6: Ağ Parametreleri](6-network-parameters.md)'ni inceleyin
→ Madenciliği [Bölüm 8: Cüzdan Kılavuzu](8-wallet-guide.md) ile yapılandırın

### Madenciler İçin
→ [Bölüm 2: Plot Formatı](2-plot-format.md)'nı anlayın
→ Süreci [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md)'te öğrenin
→ [Bölüm 7: RPC Referansı](7-rpc-reference.md) ile entegrasyon yapın

### Havuz Operatörleri İçin
→ [Bölüm 4: Dövme Atamaları](4-forging-assignments.md)'nı inceleyin
→ [Bölüm 7: RPC Referansı](7-rpc-reference.md)'nı çalışın
→ Atama RPC'leri ve submit_nonce ile uygulama geliştirin

### Geliştiriciler İçin
→ Tüm bölümleri sırasıyla okuyun
→ Dokümantasyonda belirtilen kaynak dosyalarını inceleyin
→ `src/pocx/` dizin yapısını araştırın
→ Sürümleri [GUIX](../bitcoin/contrib/guix/README.md) ile oluşturun

---

## Dokümantasyon Kuralları

**Dosya Referansları**: Uygulama detayları, kaynak dosyalarına `dizin/alt_dizin/dosya.cpp:satır` formatında referans verir

**Kod Entegrasyonu**: Tüm değişiklikler `#ifdef ENABLE_POCX` ile özellik işaretlidir

**Çapraz Referanslar**: Bölümler, göreceli markdown bağlantıları ile ilgili kısımlara yönlendirir

**Teknik Seviye**: Dokümantasyon, Bitcoin Core ve C++ geliştirme konusunda aşinalık varsayar

---

## Derleme

### Geliştirme Derlemesi

```bash
# Alt modüllerle birlikte klonlayın
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# PoCX etkin olarak yapılandırın
cmake -B build -DENABLE_POCX=ON

# Derleyin
cmake --build build -j$(nproc)
```

**Derleme Varyantları**:
```bash
# Qt GUI ile
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Hata ayıklama derlemesi
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Bağımlılıklar**: Standart Bitcoin Core derleme bağımlılıkları. Platforma özel gereksinimler için [Bitcoin Core derleme dokümantasyonu](https://github.com/bitcoin/bitcoin/tree/master/doc#building)'na bakın.

### Sürüm Derlemeleri

Yeniden üretilebilir sürüm dosyaları için GUIX derleme sistemini kullanın: [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md) dosyasına bakın

---

## Ek Kaynaklar

**Depo**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Çekirdek Çatısı**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**İlgili Projeler**:
- Plotter: [engraver](https://github.com/PoC-Consortium/engraver) tabanlı
- Madenci: [scavenger](https://github.com/PoC-Consortium/scavenger) tabanlı

---

## Bu Dokümantasyonu Okuma Rehberi

**Sıralı Okuma**: Bölümler, önceki kavramlar üzerine inşa edilerek sırasıyla okunmak üzere tasarlanmıştır.

**Referans Okuma**: Doğrudan belirli konulara atlamak için içindekiler bölümünü kullanın. Her bölüm, ilgili materyallere çapraz referanslarla bağımsız bir şekilde hazırlanmıştır.

**Tarayıcı Gezinmesi**: `index.md` dosyasını bir markdown görüntüleyicide veya tarayıcıda açın. Tüm dahili bağlantılar görecelidir ve çevrimdışı çalışır.

**PDF Dışa Aktarımı**: Bu dokümantasyon, çevrimdışı okuma için tek bir PDF halinde birleştirilebilir.

---

## Proje Durumu

**Tamamlandı**: Tüm konsensüs kuralları, madencilik, atamalar ve cüzdan özellikleri uygulandı.

**Dokümantasyon Tamamlandı**: Tüm 8 bölüm tamamlandı ve kod tabanına göre doğrulandı.

**Testnet Aktif**: Şu anda topluluk testi için testnet aşamasında.

---

## Katkıda Bulunma

Dokümantasyona katkılar kabul edilmektedir. Lütfen aşağıdakileri koruyun:
- Ayrıntıdan ziyade teknik doğruluk
- Kısa ve öz açıklamalar
- Dokümantasyonda kod veya sözde kod yok (bunun yerine kaynak dosyalarına referans verin)
- Yalnızca uygulanmış özellikler (spekülatif özellikler yok)

---

## Lisans

Bitcoin-PoCX, Bitcoin Core'un MIT lisansını devralır. Depo kök dizinindeki `COPYING` dosyasına bakın.

PoCX çekirdek çatısı atfı [Bölüm 2: Plot Formatı](2-plot-format.md)'nda belgelenmiştir.

---

**Okumaya Başlayın**: [Bölüm 1: Giriş ve Genel Bakış →](1-introduction.md)
