# Bitcoin-PoCX: Bitcoin Core için Enerji Verimli Konsensüs

**Sürüm**: 2.0 Taslak
**Tarih**: Aralık 2025
**Organizasyon**: Proof of Capacity Consortium

---

## Özet

Bitcoin'in İş Kanıtı (PoW) konsensüsü güçlü güvenlik sağlar, ancak sürekli gerçek zamanlı hash hesaplaması nedeniyle önemli miktarda enerji tüketir. Bitcoin-PoCX'i sunuyoruz: PoW'u Kapasite Kanıtı (PoC) ile değiştiren bir Bitcoin çatalı. Burada madenciler, plot oluşturma sırasında disk depolamalı büyük hash kümelerini önceden hesaplar ve ardından sürekli hash yerine hafif aramalar gerçekleştirerek madencilik yapar. Hesaplamayı madencilik aşamasından tek seferlik plot oluşturma aşamasına kaydırarak, Bitcoin-PoCX enerji tüketimini önemli ölçüde azaltırken, standart donanımda madenciliği mümkün kılar, katılım engellerini düşürür ve ASIC egemenliğindeki PoW'un doğasında bulunan merkezileşme baskılarını hafifletir - tüm bunları Bitcoin'in güvenlik varsayımlarını ve ekonomik davranışını koruyarak yapar.

Uygulamamız birkaç önemli yenilik sunar:
(1) Mevcut PoC sistemlerindeki tüm bilinen zaman-bellek değiş tokuşu saldırılarını ortadan kaldıran güçlendirilmiş plot formatı, etkili madencilik gücünün taahhüt edilen depolama kapasitesiyle kesinlikle orantılı kalmasını sağlar;
(2) Son tarih dağılımlarını üstelden ki-kareye dönüştüren Zaman Bükme algoritması, ortalamayı değiştirmeden blok süresi varyansını azaltır;
(3) Velayet gerektirmeyen havuz madenciliğini mümkün kılan OP_RETURN tabanlı dövme-atama mekanizması; ve
(4) Donanım geliştikçe uzun vadeli güvenlik marjlarını korumak için plot üretim zorluğunu yarılanma programlarıyla uyumlu şekilde artıran dinamik sıkıştırma ölçeklendirmesi.

Bitcoin-PoCX, minimum, özellik işaretli değişikliklerle Bitcoin Core mimarisini korur ve PoC mantığını mevcut konsensüs kodundan izole eder. Sistem, 120 saniyelik blok aralığı hedefleyerek ve blok sübvansiyonunu 10 BTC'ye ayarlayarak Bitcoin'in para politikasını korur. Azaltılmış sübvansiyon, beş kat artan blok frekansını dengeleyerek uzun vadeli ihraç oranını Bitcoin'in orijinal programıyla uyumlu tutar ve ~21 milyon maksimum arzı korur.

---

## 1. Giriş

### 1.1 Motivasyon

Bitcoin'in İş Kanıtı (PoW) konsensüsü on yılı aşkın süredir güvenli olduğunu kanıtlamıştır, ancak önemli bir maliyetle: madenciler sürekli hesaplama kaynakları harcamalı ve bu da yüksek enerji tüketimine neden olur. Verimlilik endişelerinin ötesinde, daha geniş bir motivasyon vardır: güvenliği korurken katılım engellerini düşüren alternatif konsensüs mekanizmalarını keşfetmek. PoC, standart depolama donanımına sahip neredeyse herkesin etkili şekilde madencilik yapmasını sağlayarak ASIC egemenliğindeki PoW madenciliğinde görülen merkezileşme baskılarını azaltır.

Kapasite Kanıtı (PoC), madencilik gücünü sürekli hesaplama yerine depolama taahhüdünden türeterek bunu başarır. Madenciler, tek seferlik plot oluşturma aşamasında disk depolamalı büyük hash kümeleri olan plot'ları önceden hesaplar. Madencilik daha sonra hafif aramalardan oluşur, kaynak tabanlı konsensüsün güvenlik varsayımlarını korurken enerji kullanımını önemli ölçüde azaltır.

### 1.2 Bitcoin Core ile Entegrasyon

Bitcoin-PoCX, yeni bir blok zinciri oluşturmak yerine PoC konsensüsünü Bitcoin Core'a entegre eder. Bu yaklaşım, değişiklikleri minimum ve özellik işaretli tutarken Bitcoin Core'un kanıtlanmış güvenliğinden, olgun ağ yığınından ve yaygın olarak benimsenen araçlarından yararlanır. PoC mantığı mevcut konsensüs kodundan izole edilir ve blok doğrulama, cüzdan işlemleri, işlem formatları gibi çekirdek işlevselliğin büyük ölçüde değişmeden kalmasını sağlar.

### 1.3 Tasarım Hedefleri

**Güvenlik**: Bitcoin eşdeğeri sağlamlığı korumak; saldırılar çoğunluk depolama kapasitesi gerektirir.

**Verimlilik**: Süregelen hesaplama yükünü disk G/Ç seviyelerine düşürmek.

**Erişilebilirlik**: Standart donanımla madenciliği mümkün kılarak giriş engellerini azaltmak.

**Minimum Entegrasyon**: Minimum değişiklik ayak iziyle PoC konsensüsü sunmak.

---

## 2. Arka Plan: Kapasite Kanıtı

### 2.1 Tarihçe

Kapasite Kanıtı (PoC), 2014 yılında Burstcoin tarafından İş Kanıtına (PoW) enerji verimli bir alternatif olarak tanıtıldı. Burstcoin, madencilik gücünün sürekli gerçek zamanlı hash yerine taahhüt edilmiş depolamadan türetilebileceğini gösterdi: madenciler büyük veri kümelerini ("plot'lar") bir kez önceden hesapladı ve ardından bunların küçük, sabit bölümlerini okuyarak madencilik yaptı.

Erken PoC uygulamaları konseptin uygulanabilir olduğunu kanıtladı, ancak plot formatı ve kriptografik yapının güvenlik için kritik olduğunu da ortaya koydu. Çeşitli zaman-bellek değiş tokuşları, saldırganların dürüst katılımcılardan daha az depolamayla etkili şekilde madencilik yapmasına olanak tanıdı. Bu, PoC güvenliğinin plot tasarımına bağlı olduğunu vurguladı - yalnızca depolamayı kaynak olarak kullanmaya değil.

Burstcoin'in mirası, PoC'u pratik bir konsensüs mekanizması olarak kurdu ve PoCX'in üzerine inşa ettiği temeli sağladı.

### 2.2 Temel Kavramlar

PoC madenciliği, diskte depolanan büyük, önceden hesaplanmış plot dosyalarına dayanır. Bu plot'lar "dondurulmuş hesaplama" içerir: pahalı hash işlemi plot oluşturma sırasında bir kez gerçekleştirilir ve madencilik daha sonra hafif disk okumalarından ve basit doğrulamadan oluşur. Temel elemanlar şunlardır:

**Nonce:**
Temel plot veri birimi. Her nonce, madencinin adresi ve nonce indeksinden Shabal256 ile oluşturulan 4096 scoop (toplam 256 KiB) içerir.

**Scoop:**
Bir nonce içindeki 64 baytlık segment. Her blok için ağ, önceki bloğun üretim imzasına göre bir scoop indeksini (0-4095) deterministik olarak seçer. Nonce başına yalnızca bu scoop okunmalıdır.

**Üretim İmzası:**
Önceki bloktan türetilen 256 bitlik değer. Scoop seçimi için entropi sağlar ve madencilerin gelecek scoop indekslerini tahmin etmesini önler.

**Warp:**
4096 nonce'luk (1 GiB) yapısal grup. Warp'lar, sıkıştırmaya dirençli plot formatları için ilgili birimdir.

### 2.3 Madencilik Süreci ve Kalite Hattı

PoC madenciliği, tek seferlik plot oluşturma adımı ve blok başına hafif bir rutinden oluşur:

**Tek Seferlik Kurulum:**
- Plot oluşturma: Shabal256 ile nonce'ları hesapla ve diske yaz.

**Blok Başına Madencilik:**
- Scoop seçimi: Üretim imzasından scoop indeksini belirle.
- Plot tarama: Madencinin plot'larındaki tüm nonce'lardan o scoop'u oku.

**Kalite Hattı:**
- Ham kalite: Üretim imzasıyla her scoop'u Shabal256Lite kullanarak hash'le ve 64 bitlik kalite değeri elde et (düşük daha iyi).
- Son tarih: Kaliteyi temel hedef (ağın hedef blok aralığına ulaşmasını sağlayan zorluk ayarlı parametre) kullanarak son tarihe dönüştür: `deadline = quality / base_target`
- Bükülmüş son tarih: Beklenen blok süresini korurken varyansı azaltmak için Zaman Bükme dönüşümünü uygula.

**Blok Dövme:**
En kısa (bükülmüş) son tarihe sahip madenci, o süre geçtikten sonra bir sonraki bloğu döver.

PoW'dan farklı olarak, neredeyse tüm hesaplama plot oluşturma sırasında gerçekleşir; aktif madencilik esas olarak disk bağımlı ve çok düşük güç tüketimlidir.

### 2.4 Önceki Sistemlerdeki Bilinen Güvenlik Açıkları

**POC1 Dağılım Kusuru:**
Orijinal Burstcoin POC1 formatı yapısal bir önyargı sergiledi: düşük indeksli scoop'ları anında yeniden hesaplamak, yüksek indeksli scoop'lardan önemli ölçüde daha ucuzdu. Bu, düzensiz bir zaman-bellek değiş tokuşu ortaya çıkardı, saldırganların bu scoop'lar için gereken depolamayı azaltmasına ve tüm önceden hesaplanmış verilerin eşit derecede pahalı olduğu varsayımını bozmasına olanak tanıdı.

**XOR Sıkıştırma Saldırısı (POC2):**
POC2'de, bir saldırgan herhangi bir 8192 nonce kümesini alabilir ve bunları 4096 nonce'luk iki bloka (A ve B) bölebilir. Her iki bloğu da depolamak yerine, saldırgan yalnızca türetilmiş bir yapıyı depolar: `A ⊕ transpose(B)`, burada transpose scoop ve nonce indekslerini takas eder—B bloğundaki N nonce'unun S scoop'u, S nonce'unun N scoop'u olur.

Madencilik sırasında, N nonce'unun S scoop'u gerektiğinde, saldırgan şu şekilde yeniden oluşturur:
1. (S, N) konumundaki depolanmış XOR değerini oku
2. S scoop'unu elde etmek için A bloğundan N nonce'unu hesapla
3. Transpoze edilmiş N scoop'unu elde etmek için B bloğundan S nonce'unu hesapla
4. Orijinal 64 baytlık scoop'u kurtarmak için üç değeri XOR'la

Bu, depolamayı %50 azaltırken, arama başına yalnızca iki nonce hesaplaması gerektirir - tam ön hesaplamayı zorlamak için gereken eşiğin çok altında bir maliyet. Saldırı uygulanabilirdir çünkü bir satırı (bir nonce, 4096 scoop) hesaplamak ucuzdur, oysa bir sütunu (4096 nonce boyunca tek bir scoop) hesaplamak tüm nonce'ları yeniden oluşturmayı gerektirir. Transpose yapısı bu dengesizliği ortaya çıkarır.

Bu, yapılandırılmış yeniden birleştirmeyi önleyen ve temel zaman-bellek değiş tokuşunu ortadan kaldıran bir plot formatına ihtiyaç olduğunu gösterdi. Bölüm 3.3, PoCX'in bu zayıflığı nasıl ele aldığını ve çözdüğünü açıklar.

### 2.5 PoCX'e Geçiş

Önceki PoC sistemlerinin sınırlamaları, güvenli, adil ve merkezi olmayan depolama madenciliğinin dikkatle tasarlanmış plot yapılarına bağlı olduğunu açıkça ortaya koydu. Bitcoin-PoCX bu sorunları güçlendirilmiş plot formatı, geliştirilmiş son tarih dağılımı ve merkezi olmayan havuz madenciliği mekanizmalarıyla ele alır - sonraki bölümde açıklandığı gibi.

---

## 3. PoCX Plot Formatı

### 3.1 Temel Nonce Oluşturma

Nonce, üç parametreden deterministik olarak türetilen 256 KiB'lık bir veri yapısıdır: 20 baytlık adres yükü, 32 baytlık seed ve 64 bitlik nonce indeksi.

Oluşturma, bu girdileri birleştirip ilk hash'i elde etmek için Shabal256 ile hash'leyerek başlar. Bu hash, yinelemeli genişleme sürecinin başlangıç noktası olarak hizmet eder: Shabal256 tekrar tekrar uygulanır, her adım daha önce oluşturulan verilere bağlıdır, ta ki tüm 256 KiB'lık tampon dolana kadar. Bu zincirleme süreç, plot oluşturma sırasında gerçekleştirilen hesaplama işini temsil eder.

Son difüzyon adımı, tamamlanan tamponu hash'ler ve sonucu tüm baytlarla XOR'lar. Bu, tam tamponun hesaplandığını ve madencilerin hesaplamayı kısayoldan geçemeyeceğini sağlar. Ardından PoC2 karıştırması uygulanır, her scoop'un alt ve üst yarısını takas ederek herhangi bir scoop'u kurtarmanın eşdeğer hesaplama maliyeti gerektirmesini garanti eder.

Son nonce, her biri 64 baytlık 4096 scoop'tan oluşur ve madencilikte kullanılan temel birimi oluşturur.

### 3.2 SIMD Hizalı Plot Düzeni

Modern donanımda çıktıyı maksimize etmek için, PoCX nonce verilerini diskte vektörize işlemeyi kolaylaştıracak şekilde düzenler. Her nonce'u sıralı olarak depolamak yerine, PoCX birden fazla ardışık nonce boyunca karşılık gelen 4 baytlık kelimeleri bitişik olarak hizalar. Bu, tek bir bellek alımının tüm SIMD şeritleri için veri sağlamasına, önbellek kaçırmalarını minimize etmesine ve dağıtma-toplama yükünü ortadan kaldırmasına olanak tanır.

```
Geleneksel düzen:
Nonce0: [K0][K1][K2][K3]...
Nonce1: [K0][K1][K2][K3]...
Nonce2: [K0][K1][K2][K3]...

PoCX SIMD düzeni:
Kelime0: [N0][N1][N2]...[N15]
Kelime1: [N0][N1][N2]...[N15]
Kelime2: [N0][N1][N2]...[N15]
```

Bu düzen, konsensüs doğrulaması için basit skaler erişim deseni korurken hem CPU hem de GPU madencilerine fayda sağlar, yüksek çıktılı, paralelleştirilmiş scoop değerlendirmesi sağlar. Madenciliğin CPU hesaplaması yerine depolama bant genişliğiyle sınırlı kalmasını sağlar ve Kapasite Kanıtının düşük güç doğasını korur.

### 3.3 Warp Yapısı ve XOR-Transpose Kodlaması

Warp, PoCX'te temel depolama birimidir ve 4096 nonce'tan (1 GiB) oluşur. X0 olarak adlandırılan sıkıştırılmamış format, Bölüm 3.1'deki yapı tarafından üretildiği gibi temel nonce'ları içerir.

**XOR-Transpose Kodlaması (X1)**

Önceki PoC sistemlerinde bulunan yapısal zaman-bellek değiş tokuşlarını ortadan kaldırmak için, PoCX, X0 warp çiftlerine XOR-transpose kodlaması uygulayarak güçlendirilmiş madencilik formatı X1'i türetir.

Bir X1 warp'ında N nonce'unun S scoop'unu oluşturmak için:

1. İlk X0 warp'ından N nonce'unun S scoop'unu al (doğrudan konum)
2. İkinci X0 warp'ından S nonce'unun N scoop'unu al (transpoze konum)
3. X1 scoop'unu elde etmek için iki 64 baytlık değeri XOR'la

Transpose adımı scoop ve nonce indekslerini takas eder. Matris terimleriyle - satırlar scoop'ları, sütunlar nonce'ları temsil eder - ilk warp'taki (S, N) konumundaki elemanı ikincideki (N, S) konumundaki elemanla birleştirir.

**Bu Sıkıştırma Saldırı Yüzeyini Neden Ortadan Kaldırır**

XOR-transpose, her scoop'u temel X0 verisinin bir satırı ve bir sütununun tamamıyla kilitler. Tek bir X1 scoop'unu kurtarmak bu nedenle tüm 4096 scoop indeksini kapsayan verilere erişim gerektirir. Eksik verileri hesaplamaya yönelik herhangi bir girişim, tek bir nonce yerine 4096 tam nonce'un yeniden oluşturulmasını gerektirir - POC2 için XOR saldırısı tarafından istismar edilen asimetrik maliyet yapısını ortadan kaldırır (Bölüm 2.4).

Sonuç olarak, tam X1 warp'ını depolamak madenciler için hesaplama açısından tek geçerli strateji haline gelir ve önceki tasarımlarda istismar edilen zaman-bellek değiş tokuşunu kapatır.

### 3.4 Disk Düzeni

PoCX plot dosyaları birçok ardışık X1 warp'ından oluşur. Madencilik sırasında operasyonel verimliliği maksimize etmek için, her dosya içindeki veriler scoop'a göre düzenlenir: her warp'tan tüm scoop 0 verileri sıralı olarak depolanır, ardından tüm scoop 1 verileri gelir ve scoop 4095'e kadar devam eder.

Bu **scoop-sıralı düzenleme**, madencilerin seçilen bir scoop için gereken tüm veriyi tek bir sıralı disk erişiminde okumasına olanak tanır, arama sürelerini minimize eder ve standart depolama cihazlarında çıktıyı maksimize eder.

Bölüm 3.3'ün XOR-transpose kodlamasıyla birleştirildiğinde, bu düzen dosyanın hem **yapısal olarak güçlendirilmiş** hem de **operasyonel olarak verimli** olmasını sağlar: sıralı scoop düzenlemesi optimal disk G/Ç'yi desteklerken, SIMD hizalı bellek düzenleri (bkz. Bölüm 3.2) yüksek çıktılı, paralelleştirilmiş scoop değerlendirmesine olanak tanır.

### 3.5 İş Kanıtı Ölçeklendirmesi (Xn)

PoCX, gelişen donanım performansına uyum sağlamak için Xn ile gösterilen ölçeklendirme seviyeleri kavramı aracılığıyla ölçeklenebilir ön hesaplama uygular. Temel X1 formatı, ilk XOR-transpose güçlendirilmiş warp yapısını temsil eder.

Her Xn ölçeklendirme seviyesi, X1'e göre her warp'a gömülen iş kanıtını üstel olarak artırır: Xn seviyesinde gereken iş, X1'in 2^(n-1) katıdır. Xn'den Xn+1'e geçiş, temel plot boyutunu değiştirmeden kademeli olarak daha fazla iş kanıtı gömerek bitişik warp çiftleri arasında XOR uygulamaya operasyonel olarak eşdeğerdir.

Daha düşük ölçeklendirme seviyelerinde oluşturulan mevcut plot dosyaları madencilik için hala kullanılabilir, ancak daha düşük gömülü iş kanıtını yansıtarak blok üretimine orantılı olarak daha az katkıda bulunurlar. Bu mekanizma, PoCX plot'larının zaman içinde güvenli, esnek ve ekonomik olarak dengeli kalmasını sağlar.

### 3.6 Seed İşlevselliği

Seed parametresi, manuel koordinasyon olmadan adres başına birden fazla örtüşmeyen plot'a olanak tanır.

**Problem (POC2)**: Madenciler, örtüşmeden kaçınmak için plot dosyaları arasında nonce aralıklarını manuel olarak izlemek zorundaydı. Örtüşen nonce'lar, madencilik gücünü artırmadan depolamayı boşa harcar.

**Çözüm**: Her `(adres, seed)` çifti bağımsız bir anahtar alanı tanımlar. Farklı seed'lere sahip plot'lar, nonce aralıklarından bağımsız olarak asla örtüşmez. Madenciler koordinasyon olmadan plot'ları serbestçe oluşturabilir.

---

## 4. Kapasite Kanıtı Konsensüsü

PoCX, Bitcoin'in Nakamoto konsensüsünü depolama bağlı kanıt mekanizmasıyla genişletir. Tekrarlanan hash'leme için enerji harcamak yerine, madenciler büyük miktarda önceden hesaplanmış veri olan plot'ları diske taahhüt eder. Blok üretimi sırasında, bu verinin küçük, tahmin edilemez bir bölümünü bulmalı ve bir kanıta dönüştürmelidirler. Beklenen zaman penceresinde en iyi kanıtı sağlayan madenci, bir sonraki bloğu dövme hakkını kazanır.

Bu bölüm, PoCX'in blok metadatasını nasıl yapılandırdığını, tahmin edilemezliği nasıl türettiğini ve statik depolamayı güvenli, düşük varyanslı bir konsensüs mekanizmasına nasıl dönüştürdüğünü açıklar.

### 4.1 Blok Yapısı

PoCX, tanıdık Bitcoin tarzı blok başlığını korur, ancak kapasite tabanlı madencilik için gereken ek konsensüs alanları sunar. Bu alanlar toplu olarak bloğu madencinin depolanan plot'una, ağın zorluğuna ve her madencilik zorluğunu tanımlayan kriptografik entropiye bağlar.

Yüksek düzeyde, bir PoCX bloğu şunları içerir: bağlamsal doğrulamayı basitleştirmek için açıkça kaydedilen blok yüksekliği; her bloğu öncekine bağlayan taze entropi kaynağı olan üretim imzası; ters biçimde ağ zorluğunu temsil eden temel hedef (daha yüksek değerler daha kolay madencilik anlamına gelir); madencinin plot'unu, plot oluşturma sırasında kullanılan sıkıştırma seviyesini, seçilen nonce'u ve bundan türetilen kaliteyi tanımlayan PoCX kanıtı; ve bloğu dövmek için kullanılan kapasitenin kontrolünü (veya atanmış bir dövme anahtarının) kanıtlayan imza anahtarı ve imza.

Kanıt, doğrulayıcıların zorluğu yeniden hesaplaması, seçilen scoop'u doğrulaması ve ortaya çıkan kaliteyi onaylaması için gereken tüm konsensüs ilgili bilgileri gömer. Blok yapısını yeniden tasarlamak yerine genişleterek, PoCX, temelde farklı bir madencilik işi kaynağını etkinleştirirken kavramsal olarak Bitcoin'le uyumlu kalır.

### 4.2 Üretim İmzası Zinciri

Üretim imzası, güvenli Kapasite Kanıtı madenciliği için gereken tahmin edilemezliği sağlar. Her blok, üretim imzasını önceki bloğun imzasından ve imzalayanından türetir, madencilerin gelecek zorlukları önceden tahmin etmesini veya avantajlı plot bölgelerini önceden hesaplamasını engeller:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Bu, kriptografik olarak güçlü, madenciye bağlı entropi değerleri dizisi üretir. Bir madencinin açık anahtarı önceki blok yayınlanana kadar bilinmediğinden, hiçbir katılımcı gelecek scoop seçimlerini tahmin edemez. Bu, seçici ön hesaplamayı veya stratejik plot oluşturmayı önler ve her bloğun gerçekten taze madencilik işi sunmasını sağlar.

### 4.3 Dövme Süreci

PoCX'te madencilik, depolanan verileri tamamen üretim imzası tarafından yönlendirilen bir kanıta dönüştürmekten oluşur. Süreç deterministik olsa da, imzanın tahmin edilemezliği madencilerin önceden hazırlanamayacağını ve depolanan plot'larına tekrar tekrar erişmesi gerektiğini sağlar.

**Zorluk Türetme (Scoop Seçimi):** Madenci, 0-4095 aralığında bir scoop indeksi elde etmek için mevcut üretim imzasını blok yüksekliğiyle hash'ler. Bu indeks, depolanan her nonce'un hangi 64 baytlık segmentinin kanıta katılacağını belirler. Üretim imzası önceki bloğun imzalayanına bağlı olduğundan, scoop seçimi yalnızca blok yayını anında bilinir hale gelir.

**Kanıt Değerlendirmesi (Kalite Hesaplaması):** Bir plot'taki her nonce için, madenci seçilen scoop'u alır ve bir kalite elde etmek için üretim imzasıyla hash'ler - büyüklüğü madencinin rekabetçiliğini belirleyen 64 bitlik değer. Düşük kalite daha iyi kanıta karşılık gelir.

**Son Tarih Oluşumu (Zaman Bükme):** Ham son tarih kaliteyle orantılı ve temel hedefle ters orantılıdır. Eski PoC tasarımlarında, bu son tarihler ek güvenlik sağlamayan uzun kuyruk gecikmeleri üreten yüksek çarpık üstel dağılım izledi. PoCX, ham son tarihi Zaman Bükme (Bölüm 4.4) kullanarak dönüştürür, varyansı azaltır ve tahmin edilebilir blok aralıkları sağlar. Bükülmüş son tarih geçtikten sonra, madenci kanıtı gömerek ve etkin dövme anahtarıyla imzalayarak bir blok döver.

### 4.4 Zaman Bükme

Kapasite Kanıtı üstel dağılımlı son tarihler üretir. Kısa bir süreden sonra - tipik olarak birkaç düzine saniye - her madenci zaten en iyi kanıtını belirlemiştir ve ek bekleme süresi güvenlik değil yalnızca gecikme katkısı sağlar.

Zaman Bükme, küp kök dönüşümü uygulayarak dağılımı yeniden şekillendirir:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Ölçek faktörü, varyansı önemli ölçüde azaltırken beklenen blok süresini (120 saniye) korur. Kısa son tarihler genişletilerek blok yayılımı ve ağ güvenliği iyileştirilir. Uzun son tarihler sıkıştırılarak aykırı değerlerin zinciri geciktirmesi önlenir.

![Blok Süresi Dağılımları](blocktime_distributions.svg)

Zaman Bükme, temel kanıtın bilgi içeriğini korur. Madenciler arasındaki rekabetçiliği değiştirmez; yalnızca daha düzgün, daha tahmin edilebilir blok aralıkları üretmek için bekleme süresini yeniden tahsis eder. Uygulama, tüm platformlarda deterministik sonuçlar sağlamak için sabit noktalı aritmetik (Q42 formatı) ve 256 bitlik tamsayılar kullanır.

### 4.5 Zorluk Ayarlaması

PoCX, blok üretimini ters zorluk ölçüsü olan temel hedef kullanarak düzenler. Beklenen blok süresi `quality / base_target` oranıyla orantılıdır, bu nedenle temel hedefi artırmak blok oluşturmayı hızlandırırken azaltmak zinciri yavaşlatır.

Zorluk, son bloklar arasındaki ölçülen süreyi hedef aralıkla karşılaştırarak her blokta ayarlanır. Bu sık ayarlama gereklidir çünkü depolama kapasitesi hızla eklenebilir veya kaldırılabilir - Bitcoin'in hash gücünün aksine, daha yavaş değişir.

Ayarlama iki yol gösterici kısıtlamayı takip eder: **Kademlilik** - blok başına değişiklikler salınımları veya manipülasyonu önlemek için sınırlandırılmıştır (maksimum ±%20); **Sertleştirme** - temel hedef genesis değerini asla aşamaz, ağın zorluğu orijinal güvenlik varsayımlarının altına düşürmesini önler.

### 4.6 Blok Geçerliliği

PoCX'te bir blok, konsensüs durumuyla tutarlı doğrulanabilir depolama türetilmiş kanıt sunduğunda geçerlidir. Doğrulayıcılar bağımsız olarak scoop seçimini yeniden hesaplar, gönderilen nonce ve plot metadatasından beklenen kaliteyi türetir, Zaman Bükme dönüşümünü uygular ve madencinin beyan edilen zamanda bloğu dövmeye uygun olduğunu onaylar.

Özellikle, geçerli bir blok şunları gerektirir: son tarih ana bloktan bu yana geçmiş olmalı; gönderilen kalite kanıt için hesaplanan kaliteyle eşleşmeli; ölçeklendirme seviyesi ağ minimumunu karşılamalı; üretim imzası beklenen değerle eşleşmeli; temel hedef beklenen değerle eşleşmeli; blok imzası etkin imzalayandan gelmeli; ve coinbase etkin imzalayanın adresine ödeme yapmalı.

---

## 5. Dövme Atamaları

### 5.1 Motivasyon

Dövme atamaları, plot sahiplerinin plot'larının sahipliğini asla bırakmadan blok dövme yetkisini devretmelerine olanak tanır. Bu mekanizma, PoCX'in güvenlik garantilerini korurken havuz madenciliği ve soğuk depolama kurulumlarını mümkün kılar.

Havuz madenciliğinde, plot sahipleri havuzun kendi adlarına blok dövmesine yetki verebilir. Havuz blokları birleştirir ve ödülleri dağıtır, ancak plot'ların kendisi üzerinde asla velayet kazanmaz. Devir herhangi bir zamanda geri alınabilir ve plot sahipleri yeniden plot oluşturmadan havuzdan ayrılmakta veya yapılandırmaları değiştirmekte özgürdür.

Atamalar ayrıca soğuk ve sıcak anahtarlar arasında temiz bir ayrımı destekler. Plot'u kontrol eden özel anahtar çevrimdışı kalabilirken, ayrı bir dövme anahtarı - çevrimiçi bir makinede depolanan - blok üretir. Dövme anahtarının ele geçirilmesi bu nedenle yalnızca dövme yetkisini tehlikeye atar, sahipliği değil. Plot güvende kalır ve atama iptal edilebilir, güvenlik açığı hemen kapatılır.

Dövme atamaları böylece, depolanan kapasite üzerindeki kontrolün asla aracılara devredilmemesi ilkesini korurken operasyonel esneklik sağlar.

### 5.2 Atama Protokolü

Atamalar, UTXO kümesinin gereksiz büyümesini önlemek için OP_RETURN işlemleri aracılığıyla beyan edilir. Atama işlemi, plot adresini ve o plot'un kapasitesini kullanarak blok üretmeye yetkili dövme adresini belirtir. İptal işlemi yalnızca plot adresini içerir. Her iki durumda da, plot sahibi işlemin harcama girdisini imzalayarak kontrolü kanıtlar.

Her atama, iyi tanımlanmış durumlar dizisinde ilerler (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Atama işlemi onaylandıktan sonra, sistem kısa bir aktivasyon aşamasına girer. Bu gecikme - 30 blok, yaklaşık bir saat - blok yarışları sırasında kararlılık sağlar ve dövme kimliklerinin düşmanca hızlı değiştirilmesini önler. Bu aktivasyon süresi sona erdikten sonra, atama aktif hale gelir ve plot sahibi iptal yapana kadar öyle kalır.

İptaller yaklaşık bir gün olan 720 blokluk daha uzun bir gecikme süresine geçer. Bu süre boyunca, önceki dövme adresi aktif kalır. Bu daha uzun gecikme, havuzlar için operasyonel kararlılık sağlar, stratejik "atama atlamasını" önler ve altyapı sağlayıcılarına verimli şekilde çalışmak için yeterli kesinlik verir. İptal gecikmesi sona erdikten sonra, iptal tamamlanır ve plot sahibi yeni bir dövme anahtarı belirleme özgürlüğüne kavuşur.

Atama durumu, UTXO kümesine paralel bir konsensüs katmanı yapısında tutulur ve zincir yeniden düzenlemelerinin güvenli şekilde yönetilmesi için geri alma verilerini destekler.

### 5.3 Doğrulama Kuralları

Her blok için, doğrulayıcılar etkin imzalayanı belirler - bloğu imzalaması ve coinbase ödülünü alması gereken adres. Bu imzalayan yalnızca blok yüksekliğindeki atama durumuna bağlıdır.

Atama yoksa veya atama henüz aktivasyon aşamasını tamamlamamışsa, plot sahibi etkin imzalayan olarak kalır. Atama aktif hale geldiğinde, atanmış dövme adresi imzalamalıdır. İptal sırasında, dövme adresi iptal gecikmesi sona erene kadar imzalamaya devam eder. Ancak o zaman yetki plot sahibine döner.

Doğrulayıcılar, blok imzasının etkin imzalayandan üretildiğini, coinbase'in aynı adrese ödeme yaptığını ve tüm geçişlerin öngörülen aktivasyon ve iptal gecikmelerini takip ettiğini zorlar. Yalnızca plot sahibi atama oluşturabilir veya iptal edebilir; dövme anahtarları kendi izinlerini değiştiremez veya genişletemez.

Dövme atamaları böylece güven gerektirmeden esnek devir sunar. Temel kapasitenin sahipliği her zaman kriptografik olarak plot sahibine bağlı kalırken, dövme yetkisi operasyonel ihtiyaçlar geliştikçe devredilir, döndürülür veya iptal edilir.

---

## 6. Dinamik Ölçeklendirme

Donanım geliştikçe, plot hesaplama maliyeti diskten önceden hesaplanmış iş okumaya göre azalır. Karşı önlemler olmadan, saldırganlar sonunda depolanan işi okuyan madencilerden daha hızlı anında kanıt üretebilir ve Kapasite Kanıtının güvenlik modelini zayıflatabilir.

Amaçlanan güvenlik marjını korumak için, PoCX bir ölçeklendirme programı uygular: plot'lar için gereken minimum ölçeklendirme seviyesi zamanla artar. Bölüm 3.5'te açıklandığı gibi her Xn ölçeklendirme seviyesi, plot yapısı içinde üstel olarak daha fazla iş kanıtı gömer, hesaplama ucuzlaştıkça bile madencilerin önemli depolama kaynakları taahhüt etmeye devam etmesini sağlar.

Program, ağın ekonomik teşvikleriyle, özellikle blok ödülü yarılanmalarıyla uyumludur. Blok başına ödül azaldıkça, minimum seviye kademeli olarak artar, plot çabası ile madencilik potansiyeli arasındaki dengeyi korur:

| Dönem | Yıllar | Yarılanmalar | Min Ölçeklendirme | Plot İşi Çarpanı |
|-------|--------|--------------|-------------------|------------------|
| Dönem 0 | 0-4 | 0 | X1 | 2× temel |
| Dönem 1 | 4-12 | 1-2 | X2 | 4× temel |
| Dönem 2 | 12-28 | 3-6 | X3 | 8× temel |
| Dönem 3 | 28-60 | 7-14 | X4 | 16× temel |
| Dönem 4 | 60-124 | 15-30 | X5 | 32× temel |
| Dönem 5 | 124+ | 31+ | X6 | 64× temel |

Madenciler isteğe bağlı olarak mevcut minimumun bir seviye üstünde plot'lar hazırlayabilir, bu da önceden planlamalarına ve ağ bir sonraki döneme geçtiğinde anında yükseltmelerden kaçınmalarına olanak tanır. Bu isteğe bağlı adım, blok olasılığı açısından ek avantaj sağlamaz - yalnızca daha düzgün bir operasyonel geçişe izin verir.

Yükseklikleri için minimum ölçeklendirme seviyesinin altında kanıt içeren bloklar geçersiz kabul edilir. Doğrulayıcılar, konsensüs doğrulaması sırasında kanıttaki beyan edilen ölçeklendirme seviyesini mevcut ağ gereksinimine göre kontrol eder, tüm katılımcı madencilerin gelişen güvenlik beklentilerini karşılamasını sağlar.

---

## 7. Madencilik Mimarisi

PoCX, konsensüs kritik işlemleri madenciliğin kaynak yoğun görevlerinden ayırır, hem güvenlik hem de verimlilik sağlar. Düğüm, blok zincirini korur, blokları doğrular, mempool'u yönetir ve bir RPC arayüzü sunar. Harici madenciler plot depolama, scoop okuma, kalite hesaplama ve son tarih yönetimini ele alır. Bu ayrım, konsensüs mantığını basit ve denetlenebilir tutarken madencilerin disk çıktısı için optimize etmesine olanak tanır.

### 7.1 Madencilik RPC Arayüzü

Madenciler, düğümle minimum RPC çağrıları kümesi aracılığıyla etkileşime girer. get_mining_info RPC'si mevcut blok yüksekliğini, üretim imzasını, temel hedefi, hedef son tarihi ve kabul edilebilir plot ölçeklendirme seviyelerini sağlar. Bu bilgileri kullanarak, madenciler aday nonce'ları hesaplar. submit_nonce RPC'si, madencilerin plot tanımlayıcısı, nonce indeksi, ölçeklendirme seviyesi ve madenci hesabı dahil önerilen bir çözüm göndermelerine olanak tanır. Düğüm, gönderimi değerlendirir ve kanıt geçerliyse hesaplanan son tarihle yanıt verir.

### 7.2 Dövme Zamanlayıcısı

Düğüm, gelen gönderimleri izleyen ve her blok yüksekliği için yalnızca en iyi çözümü tutan bir dövme zamanlayıcısı tutar. Gönderilen nonce'lar, gönderim taşması veya hizmet reddi saldırılarına karşı yerleşik korumalarla kuyruğa alınır. Zamanlayıcı, hesaplanan son tarih sona erene veya daha üstün bir çözüm gelene kadar bekler, bu noktada bir blok birleştirir, etkin dövme anahtarıyla imzalar ve ağa yayınlar.

### 7.3 Savunmacı Dövme

Zamanlama saldırılarını veya saat manipülasyonu teşviklerini önlemek için, PoCX savunmacı dövme uygular. Aynı yükseklik için rakip bir blok gelirse, zamanlayıcı yerel çözümü yeni blokla karşılaştırır. Yerel kalite üstünse, düğüm orijinal son tarihi beklemek yerine hemen döver. Bu, madencilerin yalnızca yerel saatleri ayarlayarak avantaj elde edememesini sağlar; en iyi çözüm her zaman galip gelir, adaleti ve ağ güvenliğini korur.

---

## 8. Güvenlik Analizi

### 8.1 Tehdit Modeli

PoCX, önemli ancak sınırlı yeteneklere sahip düşmanları modeller. Saldırganlar, doğrulama yollarını stres testi yapmak için geçersiz işlemler, hatalı biçimlendirilmiş bloklar veya sahte kanıtlarla ağı aşırı yüklemeye çalışabilir. Yerel saatlerini serbestçe manipüle edebilir ve zaman damgası yönetimi, zorluk ayarlama dinamikleri veya yeniden düzenleme kuralları gibi konsensüs davranışındaki uç durumları istismar etmeye çalışabilirler. Düşmanların ayrıca hedefli zincir çatalları aracılığıyla geçmişi yeniden yazma fırsatlarını araştırması beklenir.

Model, hiçbir tarafın toplam ağ depolama kapasitesinin çoğunluğunu kontrol etmediğini varsayar. Herhangi bir kaynak tabanlı konsensüs mekanizmasında olduğu gibi, %51 kapasite saldırganı zinciri tek taraflı olarak yeniden düzenleyebilir; bu temel sınırlama PoCX'e özgü değildir. PoCX ayrıca saldırganların plot verilerini dürüst madencilerin diskten okuyabildiğinden daha hızlı hesaplayamayacağını varsayar. Ölçeklendirme programı (Bölüm 6), donanım geliştikçe güvenlik için gereken hesaplama boşluğunun zamanla büyümesini sağlar.

Takip eden bölümler her ana saldırı sınıfını ayrıntılı olarak inceler ve PoCX'e yerleşik karşı önlemleri açıklar.

### 8.2 Kapasite Saldırıları

PoW gibi, çoğunluk kapasiteye sahip bir saldırgan geçmişi yeniden yazabilir (%51 saldırısı). Bunu başarmak, dürüst ağdan daha büyük fiziksel depolama ayak izi edinmeyi gerektirir - pahalı ve lojistik olarak zorlu bir girişim. Donanım edinildikten sonra işletme maliyetleri düşüktür, ancak başlangıç yatırımı dürüst davranmak için güçlü bir ekonomik teşvik yaratır: zinciri zayıflatmak saldırganın kendi varlık tabanının değerine zarar verir.

PoC ayrıca PoS ile ilişkili stake-at-nothing sorununu önler. Madenciler birden fazla rakip çatala karşı plot'ları tarayabilse de, her tarama gerçek zaman tüketir - tipik olarak zincir başına onlarca saniye mertebesinde. 120 saniyelik blok aralığıyla bu, çoklu çatal madenciliğini doğası gereği sınırlar ve birçok çatalı aynı anda madencilik yapmaya çalışmak hepsindeki performansı düşürür. Çatal madenciliği bu nedenle maliyetsiz değildir; temelden G/Ç çıktısıyla kısıtlanmıştır.

Gelecek donanım neredeyse anlık plot taramaya izin verse bile (örn., yüksek hızlı SSD'ler), bir saldırgan ağ kapasitesinin çoğunluğunu kontrol etmek için hala önemli fiziksel kaynak gereksinimiyle karşı karşıya kalır, bu da %51 tarzı saldırıyı pahalı ve lojistik olarak zorlaştırır.

Son olarak, kapasite saldırıları kiralamak hash gücü saldırılarından çok daha zordur. GPU hesaplama talep üzerine edinilebilir ve anında herhangi bir PoW zincirine yönlendirilebilir. Buna karşılık, PoC fiziksel donanım, zaman yoğun plot oluşturma ve süregelen G/Ç işlemleri gerektirir. Bu kısıtlamalar, kısa vadeli, fırsatçı saldırıları çok daha az uygulanabilir kılar.

### 8.3 Zamanlama Saldırıları

Zamanlama, Kapasite Kanıtında İş Kanıtından daha kritik bir rol oynar. PoW'da, zaman damgaları esas olarak zorluk ayarlamasını etkiler; PoC'da, bir madencinin son tarihinin geçip geçmediğini ve dolayısıyla bir bloğun dövmeye uygun olup olmadığını belirler. Son tarihler ana bloğun zaman damgasına göre ölçülür, ancak gelen bir bloğun çok uzak gelecekte olup olmadığına karar vermek için düğümün yerel saati kullanılır. Bu nedenle PoCX sıkı bir zaman damgası toleransı uygular: bloklar düğümün yerel saatinden 15 saniyeden fazla sapmamalıdır (Bitcoin'in 2 saatlik penceresine kıyasla). Bu sınır her iki yönde de çalışır - çok uzak gelecekteki bloklar reddedilir ve yavaş saatlere sahip düğümler geçerli gelen blokları yanlış şekilde reddedebilir.

Düğümler bu nedenle saatlerini NTP veya eşdeğer bir zaman kaynağı kullanarak senkronize etmelidir. PoCX, saldırganların algılanan ağ zamanını manipüle etmesini önlemek için kasıtlı olarak ağ içi zaman kaynaklarına güvenmekten kaçınır. Düğümler kendi sapmalarını izler ve yerel saat son blok zaman damgalarından sapmaya başlarsa uyarı verir.

Saat hızlandırma - biraz daha erken dövmek için hızlı yerel saat çalıştırma - yalnızca marjinal fayda sağlar. İzin verilen tolerans dahilinde, savunmacı dövme (Bölüm 7.3), daha iyi çözüme sahip bir madencinin düşük erken bloğu gördüğünde hemen yayınlamasını sağlar. Hızlı saat, bir madencinin zaten kazanan çözümü yalnızca birkaç saniye erken yayınlamasına yardımcı olur; düşük bir kanıtı kazanana dönüştüremez.

Zaman damgaları aracılığıyla zorluğu manipüle etme girişimleri, blok başına ±%20 ayarlama sınırı ve 24 blokluk yuvarlanan pencere ile sınırlandırılır, madencilerin kısa vadeli zamanlama oyunları aracılığıyla zorluğu anlamlı şekilde etkilemesini önler.

### 8.4 Zaman-Bellek Değiş Tokuşu Saldırıları

Zaman-bellek değiş tokuşları, plot'un bazı kısımlarını talep üzerine yeniden hesaplayarak depolama gereksinimlerini azaltmaya çalışır. Önceki Kapasite Kanıtı sistemleri bu tür saldırılara karşı savunmasızdı, özellikle POC1 scoop-dengesizlik kusuru ve POC2 XOR-transpose sıkıştırma saldırısı (Bölüm 2.4). Her ikisi de plot verilerinin belirli bölümlerini yeniden oluşturmanın ne kadar pahalı olduğundaki asimetrileri istismar ederek, düşmanların yalnızca küçük hesaplama cezası ödeyerek depolamayı kesmesine olanak tanıdı. Ayrıca, PoC2'ye alternatif plot formatları da benzer TMTO zayıflıklarından muzdariptir; öne çıkan bir örnek, plot formatı 4'ten büyük bir faktörle keyfi olarak azaltılabilen Chia'dır.

PoCX, nonce yapısı ve warp formatı aracılığıyla bu saldırı yüzeylerini tamamen ortadan kaldırır. Her nonce içinde, son difüzyon adımı tam hesaplanmış tamponu hash'ler ve sonucu tüm baytlarla XOR'lar, tamponun her parçasının diğer her parçaya bağlı olmasını ve kısayollanamayacağını sağlar. Ardından, PoC2 karıştırması her scoop'un alt ve üst yarısını takas ederek herhangi bir scoop'u kurtarmanın hesaplama maliyetini eşitler.

PoCX ayrıca, her scoop'un eşleştirilmiş warp'lar arasında doğrudan ve transpoze bir konumun XOR'u olduğu güçlendirilmiş X1 formatını türeterek POC2 XOR-transpose sıkıştırma saldırısını ortadan kaldırır; bu, her scoop'u temel X0 verisinin bir satırı ve bir sütununun tamamıyla kilitler, yeniden yapılandırmayı binlerce tam nonce gerektirmesini sağlar ve böylece asimetrik zaman-bellek değiş tokuşunu tamamen ortadan kaldırır.

Sonuç olarak, tam plot'u depolamak madenciler için hesaplama açısından tek geçerli stratejidir. Kısmi plot oluşturma, seçici yeniden oluşturma, yapılandırılmış sıkıştırma veya hibrit hesaplama-depolama yaklaşımları gibi bilinen hiçbir kısayol anlamlı avantaj sağlamaz. PoCX, madenciliğin kesinlikle depolama bağımlı kalmasını ve kapasitenin gerçek, fiziksel taahhüdü yansıtmasını sağlar.

### 8.5 Atama Saldırıları

PoCX, tüm plot-dövücü atamalarını yönetmek için deterministik durum makinesi kullanır. Her atama, zorunlu aktivasyon ve iptal gecikmeleriyle iyi tanımlanmış durumlardan geçer - UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED. Bu, bir madencinin sistemi aldatmak için atamaları anında değiştirmesini veya dövme yetkisini hızla değiştirmesini önler.

Tüm geçişler kriptografik kanıt gerektirdiğinden - özellikle, girdi UTXO'ya karşı doğrulanabilir plot sahibi imzaları - ağ her atamanın meşruiyetine güvenebilir. Durum makinesini atlama veya atama sahteleme girişimleri konsensüs doğrulaması sırasında otomatik olarak reddedilir. Yeniden oynatma saldırıları da standart Bitcoin tarzı işlem yeniden oynatma korumaları ile önlenir, her atama eyleminin benzersiz şekilde geçerli, harcanmamış girdiye bağlı olmasını sağlar.

Durum makinesi yönetişimi, zorunlu gecikmeler ve kriptografik kanıt kombinasyonu, atama tabanlı hileleri pratikte imkansız kılar: madenciler atamaları ele geçiremez, blok yarışları sırasında hızlı yeniden atama yapamaz veya iptal programlarını atlatamaz.

### 8.6 İmza Güvenliği

PoCX'te blok imzaları, bir kanıt ile etkin dövme anahtarı arasında kritik bağlantı görevi görerek yalnızca yetkili madencilerin geçerli bloklar üretebilmesini sağlar.

Değiştirilebilirlik saldırılarını önlemek için, imzalar blok hash hesaplamasından hariç tutulur. Bu, doğrulamayı zayıflatabilecek veya blok değiştirme saldırılarına olanak tanıyabilecek değiştirilebilir imza risklerini ortadan kaldırır.

Hizmet reddi vektörlerini azaltmak için, imza ve açık anahtar boyutları sabittir - kompakt imzalar için 65 bayt ve sıkıştırılmış açık anahtarlar için 33 bayt - saldırganların kaynak tükenmesini tetiklemek veya ağ yayılımını yavaşlatmak için blokları şişirmesini önler.

---

## 9. Uygulama

PoCX, Bitcoin Core'a modüler uzantı olarak uygulanmıştır, tüm ilgili kod kendi özel alt dizininde bulunur ve özellik bayrağı aracılığıyla etkinleştirilir. Bu tasarım orijinal kodun bütünlüğünü koruyarak PoCX'in temiz şekilde etkinleştirilmesini veya devre dışı bırakılmasını sağlar, test, denetim ve üst akış değişiklikleriyle senkronizasyonu basitleştirir.

Entegrasyon yalnızca Kapasite Kanıtını desteklemek için gerekli temel noktlara dokunur. Blok başlığı PoCX'e özgü alanları içerecek şekilde genişletilmiştir ve konsensüs doğrulaması, geleneksel Bitcoin kontrolleriyle birlikte depolama tabanlı kanıtları işlemek için uyarlanmıştır. Son tarihler, zamanlama ve madenci gönderimlerini yönetmekten sorumlu dövme sistemi tamamen PoCX modüllerinde bulunurken, RPC uzantıları madencilik ve atama işlevselliğini harici istemcilere sunar. Kullanıcılar için, cüzdan arayüzü OP_RETURN işlemleri aracılığıyla atamaları yönetmek üzere geliştirilmiştir, yeni konsensüs özellikleriyle sorunsuz etkileşim sağlar.

Tüm konsensüs kritik işlemler, harici bağımlılıklar olmadan deterministik C++'ta uygulanmıştır ve platformlar arası tutarlılığı sağlar. Shabal256 hash için kullanılırken, Zaman Bükme ve kalite hesaplaması sabit noktalı aritmetik ve 256 bitlik işlemlere dayanır. İmza doğrulama gibi kriptografik işlemler Bitcoin Core'un mevcut secp256k1 kütüphanesinden yararlanır.

PoCX işlevselliğini bu şekilde izole ederek, uygulama denetlenebilir, bakımı kolay ve süregelen Bitcoin Core geliştirmesiyle tam uyumlu kalır, temelden yeni depolama bağımlı konsensüs mekanizmasının olgun iş kanıtı kod tabanıyla bütünlüğünü veya kullanılabilirliğini bozmadan bir arada var olabileceğini gösterir.

---

## 10. Ağ Parametreleri

PoCX, Bitcoin'in ağ altyapısı üzerine inşa eder ve zincir parametre çerçevesini yeniden kullanır. Kapasite tabanlı madencilik, blok aralıkları, atama yönetimi ve plot ölçeklendirmesini desteklemek için çeşitli parametreler genişletilmiş veya geçersiz kılınmıştır. Bu, blok süresi hedefi, başlangıç sübvansiyonu, yarılanma programı, atama aktivasyon ve iptal gecikmeleri ile sihirli baytlar, portlar ve Bech32 önekleri gibi ağ tanımlayıcılarını içerir. Testnet ve regtest ortamları, hızlı yineleme ve düşük kapasite testi sağlamak için bu parametreleri daha da ayarlar.

Aşağıdaki tablolar, PoCX'in Bitcoin'in çekirdek parametrelerini depolama bağımlı konsensüs modeline nasıl uyarladığını vurgulayarak ortaya çıkan mainnet, testnet ve regtest ayarlarını özetler.

### 10.1 Mainnet

| Parametre | Değer |
|-----------|-------|
| Sihirli baytlar | `0xa7 0x3c 0x91 0x5e` |
| Varsayılan port | 8888 |
| Bech32 HRP | `pocx` |
| Blok süresi hedefi | 120 saniye |
| Başlangıç sübvansiyonu | 10 BTC |
| Yarılanma aralığı | 1050000 blok (~4 yıl) |
| Toplam arz | ~21 milyon BTC |
| Atama aktivasyonu | 30 blok |
| Atama iptali | 720 blok |
| Yuvarlanan pencere | 24 blok |

### 10.2 Testnet

| Parametre | Değer |
|-----------|-------|
| Sihirli baytlar | `0x6d 0xf2 0x48 0xb3` |
| Varsayılan port | 18888 |
| Bech32 HRP | `tpocx` |
| Blok süresi hedefi | 120 saniye |
| Diğer parametreler | Mainnet ile aynı |

### 10.3 Regtest

| Parametre | Değer |
|-----------|-------|
| Sihirli baytlar | `0xfa 0xbf 0xb5 0xda` |
| Varsayılan port | 18444 |
| Bech32 HRP | `rpocx` |
| Blok süresi hedefi | 1 saniye |
| Yarılanma aralığı | 500 blok |
| Atama aktivasyonu | 4 blok |
| Atama iptali | 8 blok |
| Düşük kapasite modu | Etkin (~4 MB plot'lar) |

---

## 11. İlgili Çalışmalar

Yıllar içinde, çeşitli blok zinciri ve konsensüs projeleri depolama tabanlı veya hibrit madencilik modellerini araştırmıştır. PoCX, güvenlik, verimlilik ve uyumlulukta iyileştirmeler sunarken bu soy üzerine inşa eder.

**Burstcoin / Signum.** Burstcoin, 2014 yılında ilk pratik Kapasite Kanıtı (PoC) sistemini tanıttı, plot'lar, nonce'lar, scoop'lar ve son tarih tabanlı madencilik gibi temel kavramları tanımladı. Halefleri, özellikle Signum (eski adıyla Burstcoin), ekosistemi genişletti ve sonunda depolama taahhüdünü etkin kapasiteyi etkilemek için isteğe bağlı stake ile birleştiren Taahhüt Kanıtı (PoC+) olarak bilinen yapıya evrildi. PoCX, bu projelerden depolama tabanlı madencilik temelini devralır, ancak güçlendirilmiş plot formatı (XOR-transpose kodlaması), dinamik plot-işi ölçeklendirmesi, son tarih yumuşatma ("Zaman Bükme") ve esnek atama sistemi aracılığıyla önemli ölçüde farklılaşır - tümü bağımsız ağ çatalı yerine Bitcoin Core kod tabanına dayalıdır.

**Chia.** Chia, disk tabanlı depolama kanıtlarını Doğrulanabilir Gecikme Fonksiyonları (VDF'ler) aracılığıyla zorlanan bir zaman bileşeniyle birleştiren Alan ve Zaman Kanıtını uygular. Tasarımı, klasik PoC'dan farklı olarak kanıt yeniden kullanımı ve taze zorluk üretimi konusundaki belirli endişeleri ele alır. PoCX, bu zaman bağlantılı kanıt modelini benimsemez; bunun yerine UTXO ekonomileri ve Bitcoin türevli araçlarla uzun vadeli uyumluluk için optimize edilmiş, tahmin edilebilir aralıklarla depolama bağımlı konsensüsü korur.

**Spacemesh.** Spacemesh, DAG tabanlı (mesh) ağ topolojisi kullanan bir Alan-Zaman Kanıtı (PoST) şeması önerir. Bu modelde, katılımcılar tek bir önceden hesaplanmış veri kümesine güvenmek yerine tahsis edilen depolamanın zaman içinde bozulmadan kaldığını periyodik olarak kanıtlamalıdır. PoCX ise buna karşın yalnızca blok zamanında depolama taahhüdünü doğrular - güçlendirilmiş plot formatları ve titiz kanıt doğrulaması ile - sürekli depolama kanıtlarının yükünü önlerken verimlilik ve merkeziyetsizliği korur.

---

## 12. Sonuç

Bitcoin-PoCX, güvenlik özellikleri ve ekonomik modeli korurken enerji verimli konsensüsün Bitcoin Core'a entegre edilebileceğini gösterir. Temel katkılar arasında XOR-transpose kodlaması (saldırganları arama başına 4096 nonce hesaplamaya zorlar, sıkıştırma saldırısını ortadan kaldırır), Zaman Bükme algoritması (dağılım dönüşümü blok süresi varyansını azaltır), dövme atama sistemi (OP_RETURN tabanlı devir velayet gerektirmeyen havuz madenciliğini mümkün kılar), dinamik ölçeklendirme (güvenlik marjlarını korumak için yarılanmalarla uyumlu) ve minimum entegrasyon (özel dizinde izole özellik işaretli kod) yer alır.

Sistem şu anda testnet aşamasındadır. Madencilik gücü hash oranı yerine depolama kapasitesinden türetilir, Bitcoin'in kanıtlanmış ekonomik modelini korurken enerji tüketimini büyük ölçüde azaltır.

---

## Referanslar

Bitcoin Core. *Bitcoin Core Deposu.* https://github.com/bitcoin/bitcoin

Burstcoin. *Kapasite Kanıtı Teknik Dokümantasyonu.* 2014.

NIST. *SHA-3 Yarışması: Shabal.* 2008.

Cohen, B., Pietrzak, K. *Chia Ağı Blok Zinciri.* 2019.

Spacemesh. *Spacemesh Protokol Dokümantasyonu.* 2021.

PoC Consortium. *PoCX Çatısı.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Entegrasyonu.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lisans**: MIT
**Organizasyon**: Proof of Capacity Consortium
**Durum**: Testnet Aşaması
