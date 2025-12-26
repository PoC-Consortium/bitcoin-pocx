[← Önceki: Giriş](1-introduction.md) | [İçindekiler](index.md) | [Sonraki: Konsensüs ve Madencilik →](3-consensus-and-mining.md)

---

# Bölüm 2: PoCX Plot Format Spesifikasyonu

Bu belge, geliştirilmiş güvenlik, SIMD optimizasyonları ve ölçeklenebilir iş kanıtı ile POC2 formatının geliştirilmiş bir sürümü olan PoCX plot formatını tanımlar.

## Format Genel Bakış

PoCX plot dosyaları, verimli madencilik işlemleri için düzenlenmiş, önceden hesaplanmış Shabal256 hash değerlerini içerir. POC1'den bu yana PoC geleneğini takip ederek, **tüm metadata dosya adına gömülüdür** - dosya başlığı yoktur.

### Dosya Uzantısı
- **Standart**: `.pocx` (tamamlanmış plot'lar)
- **Devam Eden**: `.tmp` (plot oluşturma sırasında, tamamlandığında `.pocx` olarak yeniden adlandırılır)

## Tarihsel Bağlam ve Güvenlik Açığı Evrimi

### POC1 Formatı (Eski)
**İki Büyük Güvenlik Açığı (Zaman-Bellek Değiş Tokuşları):**

1. **PoW Dağılım Kusuru**
   - Scoop'lar arasında düzensiz iş kanıtı dağılımı
   - Düşük scoop numaraları anında hesaplanabiliyordu
   - **Etki**: Saldırganlar için azaltılmış depolama gereksinimleri

2. **XOR Sıkıştırma Saldırısı** (%50 Zaman-Bellek Değiş Tokuşu)
   - %50 depolama azaltımı elde etmek için matematiksel özellikleri istismar etti
   - **Etki**: Saldırganlar gerekli depolamanın yarısıyla madencilik yapabiliyordu

**Düzen Optimizasyonu**: HDD verimliliği için temel sıralı scoop düzeni

### POC2 Formatı (Burstcoin)
- ✅ **PoW dağılım kusuru düzeltildi**
- ❌ **XOR-transpose güvenlik açığı yamalı kalmadı**
- **Düzen**: Sıralı scoop optimizasyonu korundu

### PoCX Formatı (Güncel)
- ✅ **PoW dağılımı düzeltildi** (POC2'den miras)
- ✅ **XOR-transpose güvenlik açığı yamalandı** (PoCX'e özgü)
- ✅ **Gelişmiş SIMD/GPU düzeni** paralel işleme ve bellek birleştirme için optimize edildi
- ✅ **Ölçeklenebilir iş kanıtı** hesaplama gücü arttıkça zaman-bellek değiş tokuşlarını önler (PoW yalnızca plot dosyaları oluşturulurken veya yükseltilirken gerçekleştirilir)

## XOR-Transpose Kodlaması

### Sorun: %50 Zaman-Bellek Değiş Tokuşu

POC1/POC2 formatlarında, saldırganlar verilerin yalnızca yarısını depolayıp geri kalanını madencilik sırasında anında hesaplamak için scoop'lar arasındaki matematiksel ilişkiyi istismar edebiliyordu. Bu "XOR sıkıştırma saldırısı" depolama garantisini zayıflattı.

### Çözüm: XOR-Transpose Güçlendirme

PoCX, temel warp çiftlerine (X0) XOR-transpose kodlaması uygulayarak madencilik formatını (X1) türetir:

**Bir X1 warp'ında N nonce'unun S scoop'unu oluşturmak için:**
1. İlk X0 warp'ından N nonce'unun S scoop'unu alın (doğrudan konum)
2. İkinci X0 warp'ından S nonce'unun N scoop'unu alın (transpoze konum)
3. X1 scoop'unu elde etmek için iki 64 baytlık değeri XOR'layın

Transpoze adımı scoop ve nonce indekslerini takas eder. Matris terimleriyle - satırlar scoop'ları, sütunlar nonce'ları temsil eder - ilk warp'taki (S, N) konumundaki elemanı ikincideki (N, S) konumundaki elemanla birleştirir.

### Bu Saldırıyı Neden Ortadan Kaldırır

XOR-transpose, her scoop'u temel X0 verisinin bir satırı ve bir sütununun tamamıyla kilitler. Tek bir X1 scoop'unu kurtarmak, tüm 4096 scoop indeksini kapsayan verilere erişim gerektirir. Eksik verileri hesaplamaya yönelik herhangi bir girişim, tek bir nonce yerine 4096 tam nonce'un yeniden oluşturulmasını gerektirir - XOR saldırısı tarafından istismar edilen asimetrik maliyet yapısını ortadan kaldırır.

Sonuç olarak, tam X1 warp'ını depolamak madenciler için hesaplama açısından tek geçerli strateji haline gelir.

## Dosya Adı Metadata Yapısı

Tüm plot metadata'sı dosya adında bu kesin format kullanılarak kodlanır:

```
{HESAP_YÜKÜ}_{SEED}_{WARP'LAR}_{ÖLÇEKLENDİRME}.pocx
```

### Dosya Adı Bileşenleri

1. **HESAP_YÜKÜ** (40 onaltılık karakter)
   - Ham 20 baytlık hesap yükü, büyük harfli onaltılık olarak
   - Ağdan bağımsız (ağ kimliği veya sağlama toplamı yok)
   - Örnek: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 onaltılık karakter)
   - 32 baytlık seed değeri, küçük harfli onaltılık olarak
   - **PoCX'te Yeni**: Dosya adında rastgele 32 baytlık seed, ardışık nonce numaralandırmasının yerini alır — plot örtüşmelerini önler
   - Örnek: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARP'LAR** (ondalık sayı)
   - **PoCX'te YENİ boyut birimi**: POC1/POC2'den nonce tabanlı boyutlandırmanın yerini alır
   - **XOR-transpose dirençli tasarım**: Her warp = tam 4096 nonce (XOR-transpose dirençli dönüşüm için gereken bölüm boyutu)
   - **Boyut**: 1 warp = 1073741824 bayt = 1 GiB (kullanışlı birim)
   - Örnek: `1024` (1 TiB plot = 1024 warp)

4. **ÖLÇEKLENDİRME** (X önekli ondalık)
   - `X{seviye}` olarak ölçeklendirme seviyesi
   - Daha yüksek değerler = daha fazla iş kanıtı gerekli
   - Örnek: `X4` (2^4 = 16× POC2 zorluğu)

### Örnek Dosya Adları
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Dosya Düzeni ve Veri Yapısı

### Hiyerarşik Organizasyon
```
Plot Dosyası (BAŞLIK YOK)
├── Scoop 0
│   ├── Warp 0 (Bu scoop/warp için tüm nonce'lar)
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

### Sabitler ve Boyutlar

| Sabit          | Boyut                   | Açıklama                                        |
| -------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE** | 32 B                    | Tek Shabal256 hash çıktısı                      |
| **SCOOP\_SIZE**| 64 B (2 × HASH\_SIZE)   | Bir madencilik turunda okunan hash çifti        |
| **NUM\_SCOOPS**| 4096 (2¹²)              | Nonce başına scoop; her turda bir tanesi seçilir|
| **NONCE\_SIZE**| 262144 B (256 KiB)      | Bir nonce'un tüm scoop'ları (PoC1/PoC2 en küçük birim)|
| **WARP\_SIZE** | 1073741824 B (1 GiB)    | PoCX'te en küçük birim                          |

### SIMD Optimizeli Plot Dosya Düzeni

PoCX, birden fazla nonce'un aynı anda vektörize işlenmesini sağlayan SIMD farkındalığına sahip nonce erişim deseni uygular. Bellek çıktısını ve SIMD verimliliğini maksimize etmek için [POC2×16 optimizasyon araştırması](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) konseptleri üzerine inşa edilmiştir.

---

#### Geleneksel Sıralı Düzen

Nonce'ların sıralı depolanması:

```
[Nonce 0: Scoop Verisi] [Nonce 1: Scoop Verisi] [Nonce 2: Scoop Verisi] ...
```

SIMD verimsizliği: Her SIMD şeridi, nonce'lar arasında aynı kelimeye ihtiyaç duyar:

```
Nonce 0'dan Kelime 0 -> ofset 0
Nonce 1'den Kelime 0 -> ofset 512
Nonce 2'den Kelime 0 -> ofset 1024
...
```

Dağıtma-toplama erişimi çıktıyı azaltır.

---

#### PoCX SIMD Optimizeli Düzeni

PoCX, **16 nonce arasındaki kelime konumlarını** bitişik olarak depolar:

```
Önbellek Satırı (64 bayt):

Kelime0_N0 Kelime0_N1 Kelime0_N2 ... Kelime0_N15
Kelime1_N0 Kelime1_N1 Kelime1_N2 ... Kelime1_N15
...
```

**ASCII Diyagramı**

```
Geleneksel düzen:

Nonce0: [K0][K1][K2][K3]...
Nonce1: [K0][K1][K2][K3]...
Nonce2: [K0][K1][K2][K3]...

PoCX düzeni:

Kelime0: [N0][N1][N2][N3]...[N15]
Kelime1: [N0][N1][N2][N3]...[N15]
Kelime2: [N0][N1][N2][N3]...[N15]
```

---

#### Bellek Erişim Faydaları

- Tek önbellek satırı tüm SIMD şeritlerini besler.
- Dağıtma-toplama işlemlerini ortadan kaldırır.
- Önbellek kaçırmasını azaltır.
- Vektörize hesaplama için tamamen sıralı bellek erişimi.
- GPU'lar da 16-nonce hizalamasından faydalanır, önbellek verimliliğini maksimize eder.

---

#### SIMD Ölçeklendirme

| SIMD       | Vektör Genişliği* | Nonce'lar | Önbellek Satırı Başına İşlem Döngüsü |
|------------|-------------------|-----------|-------------------------------------|
| SSE2/AVX   | 128-bit           | 4         | 4 döngü                             |
| AVX2       | 256-bit           | 8         | 2 döngü                             |
| AVX512     | 512-bit           | 16        | 1 döngü                             |

\* Tamsayı işlemleri için

---



## İş Kanıtı Ölçeklendirmesi

### Ölçeklendirme Seviyeleri
- **X0**: XOR-transpose kodlaması olmadan temel nonce'lar (teorik, madencilik için kullanılmaz)
- **X1**: XOR-transpose temel çizgisi - ilk güçlendirilmiş format (1× iş)
- **X2**: 2× X1 işi (2 warp arasında XOR)
- **X3**: 4× X1 işi (4 warp arasında XOR)
- **...**
- **Xn**: 2^(n-1) × X1 işi gömülü

### Faydalar
- **Ayarlanabilir PoW zorluğu**: Daha hızlı donanıma ayak uydurmak için hesaplama gereksinimlerini artırır
- **Format uzun ömürlülüğü**: Zaman içinde madencilik zorluğunun esnek ölçeklenmesini sağlar

### Plot Yükseltme / Geriye Dönük Uyumluluk

Ağ PoW (İş Kanıtı) ölçeğini 1 artırdığında, mevcut plot'lar aynı efektif plot boyutunu korumak için yükseltme gerektirir. Temelde, hesabınıza aynı katkıyı sağlamak için artık plot dosyalarınızda iki kat PoW'a ihtiyacınız var.

İyi haber şu ki, plot dosyalarınızı oluştururken tamamladığınız PoW kaybolmaz - mevcut dosyalara sadece ek PoW eklemeniz gerekir. Yeniden plot oluşturmaya gerek yok.

Alternatif olarak, yükseltmeden mevcut plot'larınızı kullanmaya devam edebilirsiniz, ancak bunların artık hesabınıza yönelik önceki efektif boyutlarının yalnızca %50'sini katkıda bulunacağını unutmayın. Madencilik yazılımınız bir plot dosyasını anında ölçeklendirebilir.

## Eski Formatlarla Karşılaştırma

| Özellik | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW Dağılımı | ❌ Kusurlu | ✅ Düzeltildi | ✅ Düzeltildi |
| XOR-Transpose Direnci | ❌ Güvenlik Açığı | ❌ Güvenlik Açığı | ✅ Düzeltildi |
| SIMD Optimizasyonu | ❌ Yok | ❌ Yok | ✅ Gelişmiş |
| GPU Optimizasyonu | ❌ Yok | ❌ Yok | ✅ Optimize |
| Ölçeklenebilir İş Kanıtı | ❌ Yok | ❌ Yok | ✅ Evet |
| Seed Desteği | ❌ Yok | ❌ Yok | ✅ Evet |

PoCX formatı, tüm bilinen güvenlik açıklarını giderirken modern donanım için önemli performans iyileştirmeleri sağlayan, Kapasite Kanıtı plot formatlarında güncel son teknolojiyi temsil eder.

## Referanslar ve İleri Okuma

- **POC1/POC2 Geçmişi**: [Burstcoin Madencilik Genel Bakış](https://www.burstcoin.community/burstcoin-mining/) - Geleneksel Kapasite Kanıtı madencilik formatları için kapsamlı kılavuz
- **POC2×16 Araştırması**: [CIP Duyurusu: POC2×16 - Yeni optimizeli plot formatı](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - PoCX'e ilham veren orijinal SIMD optimizasyon araştırması
- **Shabal Hash Algoritması**: [Saphir Projesi: Shabal, NIST'in Kriptografik Hash Algoritma Yarışmasına Bir Başvuru](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - PoC madenciliğinde kullanılan Shabal256 algoritmasının teknik spesifikasyonu

---

[← Önceki: Giriş](1-introduction.md) | [İçindekiler](index.md) | [Sonraki: Konsensüs ve Madencilik →](3-consensus-and-mining.md)
