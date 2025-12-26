[← Önceki: Dövme Atamaları](4-forging-assignments.md) | [İçindekiler](index.md) | [Sonraki: Ağ Parametreleri →](6-network-parameters.md)

---

# Bölüm 5: Zaman Senkronizasyonu ve Güvenlik

## Genel Bakış

PoCX konsensüsü, ağ genelinde hassas zaman senkronizasyonu gerektirir. Bu bölüm, zamanla ilgili güvenlik mekanizmalarını, saat sapması toleransını ve savunmacı dövme davranışını belgelemektedir.

**Temel Mekanizmalar**:
- Blok zaman damgaları için 15 saniyelik gelecek toleransı
- 10 saniyelik saat sapması uyarı sistemi
- Savunmacı dövme (saat manipülasyonuna karşı)
- Zaman Bükme algoritması entegrasyonu

---

## İçindekiler

1. [Zaman Senkronizasyonu Gereksinimleri](#zaman-senkronizasyonu-gereksinimleri)
2. [Saat Sapması Tespiti ve Uyarılar](#saat-sapması-tespiti-ve-uyarılar)
3. [Savunmacı Dövme Mekanizması](#savunmacı-dövme-mekanizması)
4. [Güvenlik Tehdit Analizi](#güvenlik-tehdit-analizi)
5. [Düğüm Operatörleri İçin En İyi Uygulamalar](#düğüm-operatörleri-i̇çin-en-i̇yi-uygulamalar)

---

## Zaman Senkronizasyonu Gereksinimleri

### Sabitler ve Parametreler

**Bitcoin-PoCX Yapılandırması:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 saniye

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 saniye
```

### Doğrulama Kontrolleri

**Blok Zaman Damgası Doğrulaması** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monoton kontrol: zaman damgası >= önceki blok zaman damgası
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Gelecek kontrolü: zaman damgası <= şimdi + 15 saniye
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Son tarih kontrolü: geçen süre >= son tarih
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Saat Sapması Etki Tablosu

| Saat Ofseti | Senkronize Olabilir mi? | Madencilik Yapabilir mi? | Doğrulama Durumu | Rekabet Etkisi |
|-------------|-------------------------|--------------------------|------------------|----------------|
| -30s yavaş | HAYIR - Gelecek kontrolü başarısız | Yok | **ÖLÜ DÜĞÜM** | Katılamaz |
| -14s yavaş | Evet | Evet | Geç dövme, doğrulamayı geçer | Yarışları kaybeder |
| 0s mükemmel | Evet | Evet | Optimal | Optimal |
| +14s hızlı | Evet | Evet | Erken dövme, doğrulamayı geçer | Yarışları kazanır |
| +16s hızlı | Evet | HAYIR - Gelecek kontrolü başarısız | Blokları yayamaz | Senkronize olabilir, madencilik yapamaz |

**Önemli İçgörü**: 15 saniyelik pencere katılım için simetriktir (±14.9s), ancak hızlı saatler tolerans dahilinde haksız rekabet avantajı sağlar.

### Zaman Bükme Entegrasyonu

Zaman Bükme algoritması ([Bölüm 3](3-consensus-and-mining.md#zaman-bükme-hesaplaması)'te detaylı) küp kök kullanarak ham son tarihleri dönüştürür:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Saat Sapması ile Etkileşim**:
- Daha iyi çözümler daha erken döver (küp kök kalite farklarını büyütür)
- Saat sapması, dövme süresini ağa göre etkiler
- Savunmacı dövme, zamanlama varyansına rağmen kalite tabanlı rekabeti sağlar

---

## Saat Sapması Tespiti ve Uyarılar

### Uyarı Sistemi

Bitcoin-PoCX, yerel düğüm ile ağ eşleri arasındaki zaman ofsetini izler.

**Uyarı Mesajı** (sapma 10 saniyeyi aştığında):
> "Bilgisayarınızın tarih ve saati ağla 10 saniyeden fazla senkronize dışı görünüyor, bu PoCX konsensüs hatasına yol açabilir. Lütfen sistem saatinizi kontrol edin."

**Uygulama**: `src/node/timeoffsets.cpp`

### Tasarım Gerekçesi

**Neden 10 saniye?**
- 15 saniyelik tolerans sınırından önce 5 saniyelik güvenlik tamponu sağlar
- Bitcoin Core'un varsayılanından (10 dakika) daha sıkı
- PoC zamanlama gereksinimleri için uygun

**Önleyici Yaklaşım**:
- Kritik hatadan önce erken uyarı
- Operatörlerin sorunları proaktif olarak düzeltmesine olanak tanır
- Zamanla ilgili hatalardan kaynaklanan ağ parçalanmasını azaltır

---

## Savunmacı Dövme Mekanizması

### Nedir

Savunmacı dövme, Bitcoin-PoCX'te blok üretiminde zamanlama tabanlı avantajları ortadan kaldıran standart bir madenci davranışıdır. Madenciciniz aynı yükseklikte rakip bir blok aldığında, daha iyi bir çözümünüz olup olmadığını otomatik olarak kontrol eder. Varsa, bloğunuzu hemen döver, saat manipülasyonu tabanlı rekabet yerine kalite tabanlı rekabeti sağlar.

### Problem

PoCX konsensüsü, 15 saniyeye kadar gelecekteki zaman damgalarına sahip bloklara izin verir. Bu tolerans, küresel ağ senkronizasyonu için gereklidir. Ancak, saat manipülasyonu için bir fırsat yaratır:

**Savunmacı Dövme Olmadan:**
- Madenci A: Doğru zaman, kalite 800 (daha iyi), uygun son tarihi bekler
- Madenci B: Hızlı saat (+14s), kalite 1000 (daha kötü), 14 saniye erken döver
- Sonuç: Madenci B, düşük kapasite kanıtı işine rağmen yarışı kazanır

**Sorun:** Saat manipülasyonu, daha kötü kaliteyle bile avantaj sağlar, kapasite kanıtı ilkesini zayıflatır.

### Çözüm: İki Katmanlı Savunma

#### Katman 1: Saat Sapması Uyarısı (Önleyici)

Bitcoin-PoCX, düğümünüz ile ağ eşleri arasındaki zaman ofsetini izler. Saatiniz ağ konsensüsünden 10 saniyeden fazla sapıyorsa, saat sorunlarını sorun olmadan önce düzeltmeniz için sizi uyaran bir uyarı alırsınız.

#### Katman 2: Savunmacı Dövme (Reaktif)

Başka bir madenci madencilik yaptığınız aynı yükseklikte bir blok yayınladığında:

1. **Tespit**: Düğümünüz aynı yükseklik rekabetini tanımlar
2. **Doğrulama**: Rakip bloğun kalitesini çıkarır ve doğrular
3. **Karşılaştırma**: Kalitenizin daha iyi olup olmadığını kontrol eder
4. **Yanıt**: Daha iyiyse, bloğunuzu hemen döver

**Sonuç:** Ağ her iki bloğu da alır ve standart çatal çözümü yoluyla daha iyi kaliteye sahip olanı seçer.

### Nasıl Çalışır

#### Senaryo: Aynı Yükseklik Rekabeti

```
Zaman 150s: Madenci B (saat +10s) kalite 1000 ile döver
           → Blok zaman damgası 160s gösterir (10s gelecekte)

Zaman 150s: Düğümünüz Madenci B'nin bloğunu alır
           → Tespit: aynı yükseklik, kalite 1000
           → Sizde var: kalite 800 (daha iyi!)
           → Eylem: Doğru zaman damgasıyla (150s) hemen döv

Zaman 152s: Ağ her iki bloğu da doğrular
           → Her ikisi de geçerli (15s tolerans dahilinde)
           → Kalite 800 kazanır (düşük = daha iyi)
           → Bloğunuz zincir ucu olur
```

#### Senaryo: Gerçek Yeniden Düzenleme

```
Madencilik yüksekliğiniz 100, rakip blok 99 yayınlıyor
→ Aynı yükseklik rekabeti değil
→ Savunmacı dövme TETİKLENMEZ
→ Normal yeniden düzenleme işleme devam eder
```

### Faydalar

**Saat Manipülasyonu İçin Sıfır Teşvik**
- Hızlı saatler yalnızca zaten en iyi kaliteye sahipseniz yardımcı olur
- Saat manipülasyonu ekonomik olarak anlamsız hale gelir

**Kalite Tabanlı Rekabet Uygulanır**
- Madencileri gerçek kapasite kanıtı işi üzerinden rekabete zorlar
- PoCX konsensüs bütünlüğünü korur

**Ağ Güvenliği**
- Zamanlama tabanlı oyun stratejilerine dirençli
- Konsensüs değişikliği gerekmez - saf madenci davranışı

**Tamamen Otomatik**
- Yapılandırma gerekmez
- Yalnızca gerektiğinde tetiklenir
- Tüm Bitcoin-PoCX düğümlerinde standart davranış

### Ödünleşimler

**Minimum Yetim Oranı Artışı**
- Kasıtlı - saldırı blokları yetim kalır
- Yalnızca gerçek saat manipülasyonu girişimleri sırasında gerçekleşir
- Kalite tabanlı çatal çözümünün doğal sonucu

**Kısa Ağ Rekabeti**
- Ağ kısa süreliğine iki rakip blok görür
- Standart doğrulama ile saniyeler içinde çözülür
- Bitcoin'de eşzamanlı madencilikle aynı davranış

### Teknik Detaylar

**Performans Etkisi:** İhmal edilebilir
- Yalnızca aynı yükseklik rekabetinde tetiklenir
- Bellek içi veri kullanır (disk G/Ç yok)
- Doğrulama milisaniyeler içinde tamamlanır

**Kaynak Kullanımı:** Minimum
- ~20 satır çekirdek mantık
- Mevcut doğrulama altyapısını yeniden kullanır
- Tek kilit edinimi

**Uyumluluk:** Tam
- Konsensüs kuralı değişikliği yok
- Tüm Bitcoin Core özellikleriyle çalışır
- Hata ayıklama günlükleri aracılığıyla isteğe bağlı izleme

**Durum**: Tüm Bitcoin-PoCX sürümlerinde aktif
**İlk Tanıtım**: 2025-10-10

---

## Güvenlik Tehdit Analizi

### Hızlı Saat Saldırısı (Savunmacı Dövme ile Azaltılmış)

**Saldırı Vektörü**:
**+14s ileri** saate sahip bir madenci:
1. Blokları normal şekilde alır (kendilerine eski görünür)
2. Son tarih geçtiğinde blokları hemen döver
3. Ağa 14s "erken" görünen blokları yayınlar
4. **Bloklar kabul edilir** (15s tolerans dahilinde)
5. Dürüst madencilere karşı **yarışları kazanır**

**Savunmacı Dövme Olmadan Etki**:
Avantaj 14.9 saniye ile sınırlıdır (önemli PoC işini atlamak için yeterli değil), ancak blok yarışlarında tutarlı üstünlük sağlar.

**Azaltma (Savunmacı Dövme)**:
- Dürüst madenciler aynı yükseklik rekabetini tespit eder
- Kalite değerlerini karşılaştırır
- Kalite daha iyiyse hemen döver
- **Sonuç**: Hızlı saat yalnızca zaten en iyi kaliteye sahipseniz yardımcı olur
- **Teşvik**: Sıfır - saat manipülasyonu ekonomik olarak anlamsız hale gelir

### Yavaş Saat Hatası (Kritik)

**Hata Modu**:
**>15s geride** bir düğüm felakettir:
- Gelen blokları doğrulayamaz (gelecek kontrolü başarısız)
- Ağdan izole olur
- Madencilik veya senkronizasyon yapamaz

**Azaltma**:
- 10s sapma uyarısı, kritik hatadan önce 5 saniyelik tampon sağlar
- Operatörler saat sorunlarını proaktif olarak düzeltebilir
- Net hata mesajları sorun gidermeye rehberlik eder

---

## Düğüm Operatörleri İçin En İyi Uygulamalar

### Zaman Senkronizasyonu Kurulumu

**Önerilen Yapılandırma**:
1. **NTP'yi Etkinleştir**: Otomatik senkronizasyon için Ağ Zaman Protokolü kullanın
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Durumu kontrol et
   timedatectl status
   ```

2. **Saat Doğruluğunu Doğrula**: Zaman ofsetini düzenli olarak kontrol edin
   ```bash
   # NTP senkronizasyon durumunu kontrol et
   ntpq -p

   # Veya chrony ile
   chronyc tracking
   ```

3. **Uyarıları İzle**: Günlüklerde Bitcoin-PoCX saat sapması uyarılarını izleyin

### Madenciler İçin

**Eylem Gerekmez**:
- Özellik her zaman aktif
- Otomatik olarak çalışır
- Sadece sistem saatinizi doğru tutun

**En İyi Uygulamalar**:
- NTP zaman senkronizasyonu kullanın
- Saat sapması uyarılarını izleyin
- Görünürlerse uyarıları derhal ele alın

**Beklenen Davranış**:
- Solo madencilik: Savunmacı dövme nadiren tetiklenir (rekabet yok)
- Ağ madenciliği: Saat manipülasyonu girişimlerine karşı korur
- Şeffaf işleyiş: Çoğu madenci fark etmez

### Sorun Giderme

**Uyarı: "10 saniye senkronize dışı"**
- Eylem: Sistem saat senkronizasyonunu kontrol et ve düzelt
- Etki: Kritik hatadan önce 5 saniyelik tampon
- Araçlar: NTP, chrony, systemd-timesyncd

**Hata: Gelen bloklarda "time-too-new"**
- Neden: Saatiniz >15 saniye yavaş
- Etki: Blokları doğrulayamaz, düğüm izole
- Düzeltme: Sistem saatini hemen senkronize et

**Hata: Dövülen blokları yayamıyor**
- Neden: Saatiniz >15 saniye hızlı
- Etki: Bloklar ağ tarafından reddedilir
- Düzeltme: Sistem saatini hemen senkronize et

---

## Tasarım Kararları ve Gerekçeler

### Neden 15 Saniyelik Tolerans?

**Gerekçe**:
- Bitcoin-PoCX değişken son tarih zamanlaması, sabit zamanlı konsensüsten daha az zaman açısından kritik
- 15s ağ parçalanmasını önlerken yeterli koruma sağlar

**Ödünleşimler**:
- Daha sıkı tolerans = küçük sapmalardan daha fazla ağ parçalanması
- Daha gevşek tolerans = zamanlama saldırıları için daha fazla fırsat
- 15s güvenlik ve sağlamlığı dengeler

### Neden 10 Saniyelik Uyarı?

**Gerekçe**:
- 5 saniyelik güvenlik tamponu sağlar
- PoC için Bitcoin'in 10 dakikalık varsayılanından daha uygun
- Kritik hatadan önce proaktif düzeltmelere olanak tanır

### Neden Savunmacı Dövme?

**Ele Alınan Problem**:
- 15 saniyelik tolerans hızlı saat avantajı sağlar
- Kalite tabanlı konsensüs zamanlama manipülasyonu ile zayıflatılabilir

**Çözüm Faydaları**:
- Sıfır maliyetli savunma (konsensüs değişikliği yok)
- Otomatik işleyiş
- Saldırı teşvikini ortadan kaldırır
- Kapasite kanıtı ilkelerini korur

### Neden Ağ İçi Zaman Senkronizasyonu Yok?

**Güvenlik Gerekçesi**:
- Modern Bitcoin Core eş tabanlı zaman ayarlamasını kaldırdı
- Algılanan ağ zamanı üzerinde Sybil saldırılarına karşı savunmasız
- PoCX kasıtlı olarak ağ içi zaman kaynaklarına güvenmekten kaçınır
- Sistem saati eş konsensüsünden daha güvenilir
- Operatörler NTP veya eşdeğer harici zaman kaynağı kullanarak senkronize olmalı
- Düğümler kendi sapmalarını izler ve yerel saat son blok zaman damgalarından sapıyorsa uyarı verir

---

## Uygulama Referansları

**Çekirdek Dosyalar**:
- Zaman doğrulaması: `src/validation.cpp:4547-4561`
- Gelecek toleransı sabiti: `src/chain.h:31`
- Uyarı eşiği: `src/node/timeoffsets.h:27`
- Zaman ofseti izleme: `src/node/timeoffsets.cpp`
- Savunmacı dövme: `src/pocx/mining/scheduler.cpp`

**İlgili Dokümantasyon**:
- Zaman Bükme algoritması: [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md#zaman-bükme-hesaplaması)
- Blok doğrulama: [Bölüm 3: Blok Doğrulama](3-consensus-and-mining.md#blok-doğrulama)

---

**Oluşturulma Tarihi**: 2025-10-10
**Durum**: Tam Uygulama
**Kapsam**: Zaman senkronizasyonu gereksinimleri, saat sapması yönetimi, savunmacı dövme

---

[← Önceki: Dövme Atamaları](4-forging-assignments.md) | [İçindekiler](index.md) | [Sonraki: Ağ Parametreleri →](6-network-parameters.md)
