[← Önceki: RPC Referansı](7-rpc-reference.md) | [İçindekiler](index.md)

---

# Bölüm 8: Cüzdan ve Arayüz Kullanım Kılavuzu

Bitcoin-PoCX Qt cüzdanı ve dövme atama yönetimi için eksiksiz kılavuz.

---

## İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Para Birimi Birimleri](#para-birimi-birimleri)
3. [Dövme Atama Penceresi](#dövme-atama-penceresi)
4. [İşlem Geçmişi](#işlem-geçmişi)
5. [Adres Gereksinimleri](#adres-gereksinimleri)
6. [Madencilik Entegrasyonu](#madencilik-entegrasyonu)
7. [Sorun Giderme](#sorun-giderme)
8. [Güvenlik En İyi Uygulamaları](#güvenlik-en-i̇yi-uygulamaları)

---

## Genel Bakış

### Bitcoin-PoCX Cüzdan Özellikleri

Bitcoin-PoCX Qt cüzdanı (`bitcoin-qt`) şunları sağlar:
- Standart Bitcoin Core cüzdan işlevselliği (gönderme, alma, işlem yönetimi)
- **Dövme Atama Yöneticisi**: Plot atamalarını oluşturma/iptal etme için GUI
- **Madencilik Sunucu Modu**: `-miningserver` bayrağı madencilikle ilgili özellikleri etkinleştirir
- **İşlem Geçmişi**: Atama ve iptal işlemi görüntüleme

### Cüzdanı Başlatma

**Yalnızca Düğüm** (madencilik yok):
```bash
./build/bin/bitcoin-qt
```

**Madencilik İle** (atama penceresini etkinleştirir):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Komut Satırı Alternatifi**:
```bash
./build/bin/bitcoind -miningserver
```

### Madencilik Gereksinimleri

**Madencilik İşlemleri İçin**:
- `-miningserver` bayrağı gerekli
- P2WPKH adresleri ve özel anahtarlara sahip cüzdan
- Plot üretimi için harici plotter (`pocx_plotter`)
- Madencilik için harici madenci (`pocx_miner`)

**Havuz Madenciliği İçin**:
- Havuz adresine dövme ataması oluştur
- Havuz sunucusunda cüzdan gerekmez (havuz anahtarları yönetir)

---

## Para Birimi Birimleri

### Birim Görüntüleme

Bitcoin-PoCX **BTCX** para birimi birimini kullanır (BTC değil):

| Birim | Satoshi | Görüntüleme |
|-------|---------|-------------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI Ayarları**: Tercihler → Görüntüleme → Birim

---

## Dövme Atama Penceresi

### Pencereye Erişim

**Menü**: `Cüzdan → Dövme Atamaları`
**Araç Çubuğu**: Madencilik simgesi (yalnızca `-miningserver` bayrağı ile görünür)
**Pencere Boyutu**: 600×450 piksel

### Pencere Modları

#### Mod 1: Atama Oluşturma

**Amaç**: Plot sahipliğini koruyarak dövme haklarını havuza veya başka bir adrese devretme.

**Kullanım Alanları**:
- Havuz madenciliği (havuz adresine ata)
- Soğuk depolama (madencilik anahtarı plot sahipliğinden ayrı)
- Paylaşılan altyapı (sıcak cüzdana devret)

**Gereksinimler**:
- Plot adresi (P2WPKH bech32, özel anahtara sahip olmalı)
- Dövme adresi (P2WPKH bech32, plot adresinden farklı)
- Cüzdan kilidi açık (şifreliyse)
- Plot adresinin onaylanmış UTXO'ları var

**Adımlar**:
1. "Atama Oluştur" modunu seç
2. Açılır listeden plot adresini seç veya manuel gir
3. Dövme adresini gir (havuz veya temsilci)
4. "Atama Gönder"e tıkla (girişler geçerli olduğunda düğme etkin)
5. İşlem hemen yayınlanır
6. `nForgingAssignmentDelay` bloktan sonra atama aktif olur:
   - Mainnet/Testnet: 30 blok (~1 saat)
   - Regtest: 4 blok (~4 saniye)

**İşlem Ücreti**: Varsayılan 10× `minRelayFee` (özelleştirilebilir)

**İşlem Yapısı**:
- Giriş: Plot adresinden UTXO (sahipliği kanıtlar)
- OP_RETURN çıktısı: `POCX` işareti + plot_address + forging_address (46 bayt)
- Para üstü çıktısı: Cüzdana döner

#### Mod 2: Atama İptali

**Amaç**: Dövme atamasını iptal et ve hakları plot sahibine döndür.

**Gereksinimler**:
- Plot adresi (özel anahtara sahip olmalı)
- Cüzdan kilidi açık (şifreliyse)
- Plot adresinin onaylanmış UTXO'ları var

**Adımlar**:
1. "Atama İptali" modunu seç
2. Plot adresini seç
3. "İptal Gönder"e tıkla
4. İşlem hemen yayınlanır
5. `nForgingRevocationDelay` bloktan sonra iptal geçerli olur:
   - Mainnet/Testnet: 720 blok (~24 saat)
   - Regtest: 8 blok (~8 saniye)

**Etki**:
- Dövme adresi gecikme süresi boyunca hala dövebilir
- Plot sahibi iptal tamamlandıktan sonra hakları geri alır
- Ardından yeni atama oluşturulabilir

**İşlem Yapısı**:
- Giriş: Plot adresinden UTXO (sahipliği kanıtlar)
- OP_RETURN çıktısı: `XCOP` işareti + plot_address (26 bayt)
- Para üstü çıktısı: Cüzdana döner

#### Mod 3: Atama Durumunu Kontrol Et

**Amaç**: Herhangi bir plot adresi için mevcut atama durumunu sorgula.

**Gereksinimler**: Yok (salt okunur, cüzdan gerekmez)

**Adımlar**:
1. "Atama Durumunu Kontrol Et" modunu seç
2. Plot adresini gir
3. "Durumu Kontrol Et"e tıkla
4. Durum kutusu detaylarla mevcut durumu görüntüler

**Durum Göstergeleri** (renk kodlu):

**Gri - UNASSIGNED (ATANMAMIŞ)**
```
ATANMAMIŞ - Atama yok
```

**Turuncu - ASSIGNING (ATANIYOR)**
```
ATANIYOR - Atama aktivasyonu bekleniyor
Dövme Adresi: pocx1qforger...
Oluşturma yüksekliği: 12000
Aktivasyon yüksekliği: 12030 (5 blok kaldı)
```

**Yeşil - ASSIGNED (ATANMIŞ)**
```
ATANMIŞ - Aktif atama
Dövme Adresi: pocx1qforger...
Oluşturma yüksekliği: 12000
Aktivasyon yüksekliği: 12030
```

**Kırmızı-Turuncu - REVOKING (İPTAL EDİLİYOR)**
```
İPTAL EDİLİYOR - İptal bekleniyor
Dövme Adresi: pocx1qforger... (hala aktif)
Atama oluşturma yüksekliği: 12000
İptal yüksekliği: 12300
İptal geçerlilik yüksekliği: 13020 (50 blok kaldı)
```

**Kırmızı - REVOKED (İPTAL EDİLMİŞ)**
```
İPTAL EDİLMİŞ - Atama iptal edildi
Daha önce atanmış: pocx1qforger...
Atama oluşturma yüksekliği: 12000
İptal yüksekliği: 12300
İptal geçerlilik yüksekliği: 13020
```

---

## İşlem Geçmişi

### Atama İşlemi Görüntüleme

**Tür**: "Atama"
**Simge**: Madencilik simgesi (madencilik yapılmış bloklarla aynı)

**Adres Sütunu**: Plot adresi (dövme hakları atanan adres)
**Miktar Sütunu**: İşlem ücreti (negatif, giden işlem)
**Durum Sütunu**: Onay sayısı (0-6+)

**Detaylar** (tıklandığında):
- İşlem kimliği
- Plot adresi
- Dövme adresi (OP_RETURN'dan ayrıştırılmış)
- Oluşturma yüksekliği
- Aktivasyon yüksekliği
- İşlem ücreti
- Zaman damgası

### İptal İşlemi Görüntüleme

**Tür**: "İptal"
**Simge**: Madencilik simgesi

**Adres Sütunu**: Plot adresi
**Miktar Sütunu**: İşlem ücreti (negatif)
**Durum Sütunu**: Onay sayısı

**Detaylar** (tıklandığında):
- İşlem kimliği
- Plot adresi
- İptal yüksekliği
- İptal geçerlilik yüksekliği
- İşlem ücreti
- Zaman damgası

### İşlem Filtreleme

**Mevcut Filtreler**:
- "Tümü" (varsayılan, atamaları/iptalleri içerir)
- Tarih aralığı
- Miktar aralığı
- Adrese göre ara
- İşlem kimliğine göre ara
- Etikete göre ara (adres etiketliyse)

**Not**: Atama/İptal işlemleri şu anda "Tümü" filtresi altında görünür. Özel tür filtresi henüz uygulanmadı.

### İşlem Sıralaması

**Sıralama Düzeni** (türe göre):
- Oluşturulan (tür 0)
- Alınan (tür 1-3)
- Atama (tür 4)
- İptal (tür 5)
- Gönderilen (tür 6+)

---

## Adres Gereksinimleri

### Yalnızca P2WPKH (SegWit v0)

**Dövme işlemleri şunları gerektirir**:
- Bech32 kodlu adresler (mainnet'te "pocx1q", testnet'te "tpocx1q", regtest'te "rpocx1q" ile başlar)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) formatı
- 20 baytlık anahtar hash'i

**DESTEKLENMİYOR**:
- P2PKH (eski, "1" ile başlar)
- P2SH (sarılmış SegWit, "3" ile başlar)
- P2TR (Taproot, "bc1p" ile başlar)

**Gerekçe**: PoCX blok imzaları, kanıt doğrulaması için belirli witness v0 formatı gerektirir.

### Adres Açılır Liste Filtreleme

**Plot Adresi ComboBox**:
- Cüzdanın alıcı adresleriyle otomatik doldurulur
- P2WPKH olmayan adresleri filtreler
- Format gösterir: etiketliyse "Etiket (adres)", değilse sadece adres
- İlk öğe: "-- Özel adres girin --" manuel giriş için

**Manuel Giriş**:
- Girildiğinde formatı doğrular
- Geçerli bech32 P2WPKH olmalı
- Format geçersizse düğme devre dışı

### Doğrulama Hata Mesajları

**Pencere Hataları**:
- "Plot adresi P2WPKH (bech32) olmalıdır"
- "Dövme adresi P2WPKH (bech32) olmalıdır"
- "Geçersiz adres formatı"
- "Plot adresinde coin yok. Sahiplik kanıtlanamıyor."
- "Salt izleme cüzdanıyla işlem oluşturulamaz"
- "Cüzdan mevcut değil"
- "Cüzdan kilitli" (RPC'den)

---

## Madencilik Entegrasyonu

### Kurulum Gereksinimleri

**Düğüm Yapılandırması**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Cüzdan Gereksinimleri**:
- Plot sahipliği için P2WPKH adresleri
- Madencilik için özel anahtarlar (veya atama kullanılıyorsa dövme adresi)
- İşlem oluşturma için onaylanmış UTXO'lar

**Harici Araçlar**:
- `pocx_plotter`: Plot dosyaları oluştur
- `pocx_miner`: Plot'ları tara ve nonce gönder

### İş Akışı

#### Solo Madencilik

1. **Plot Dosyaları Oluştur**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bayt> --nonces <sayı>
   ```

2. **Düğümü Başlat** madencilik sunucusu ile:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Madenciyi Yapılandır**:
   - Düğüm RPC uç noktasına yönlendir
   - Plot dosya dizinlerini belirt
   - Hesap kimliğini yapılandır (plot adresinden)

4. **Madenciliği Başlat**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /plot/yolu
   ```

5. **İzle**:
   - Madenci her blokta `get_mining_info` çağırır
   - En iyi son tarih için plot'ları tarar
   - Çözüm bulunduğunda `submit_nonce` çağırır
   - Düğüm bloğu otomatik olarak doğrular ve döver

#### Havuz Madenciliği

1. **Plot Dosyaları Oluştur** (solo madencilikle aynı)

2. **Dövme Ataması Oluştur**:
   - Dövme Atama Penceresini aç
   - Plot adresini seç
   - Havuzun dövme adresini gir
   - "Atama Gönder"e tıkla
   - Aktivasyon gecikmesini bekle (testnet'te 30 blok)

3. **Madenciyi Yapılandır**:
   - **Havuz** uç noktasına yönlendir (yerel düğüm değil)
   - Havuz zincire `submit_nonce` işlemini yönetir

4. **Havuz İşleyişi**:
   - Havuz cüzdanı dövme adresi özel anahtarlarına sahip
   - Havuz madencilerden gelen gönderimleri doğrular
   - Havuz blok zincirine `submit_nonce` çağırır
   - Havuz, havuz politikasına göre ödülleri dağıtır

### Coinbase Ödülleri

**Atama Yok**:
- Coinbase doğrudan plot sahibi adresine öder
- Plot adresinde bakiye kontrol edin

**Atama İle**:
- Coinbase dövme adresine öder
- Havuz ödülleri alır
- Madenci havuzdan pay alır

**Ödül Programı**:
- Başlangıç: Blok başına 10 BTCX
- Yarılanma: Her 1050000 blokta (~4 yıl)
- Program: 10 → 5 → 2.5 → 1.25 → ...

---

## Sorun Giderme

### Yaygın Sorunlar

#### "Cüzdan plot adresi için özel anahtara sahip değil"

**Neden**: Cüzdan adresin sahibi değil
**Çözüm**:
- `importprivkey` RPC ile özel anahtarı içe aktar
- Veya cüzdana ait farklı plot adresi kullan

#### "Bu plot için zaten atama mevcut"

**Neden**: Plot zaten başka bir adrese atanmış
**Çözüm**:
1. Mevcut atamayı iptal et
2. İptal gecikmesini bekle (testnet'te 720 blok)
3. Yeni atama oluştur

#### "Adres formatı desteklenmiyor"

**Neden**: Adres P2WPKH bech32 değil
**Çözüm**:
- "pocx1q" (mainnet) veya "tpocx1q" (testnet) ile başlayan adresler kullan
- Gerekirse yeni adres oluştur: `getnewaddress "" "bech32"`

#### "İşlem ücreti çok düşük"

**Neden**: Ağ mempool tıkanıklığı veya iletim için ücret çok düşük
**Çözüm**:
- Ücret oranı parametresini artır
- Mempool temizlenmesini bekle

#### "Atama henüz aktif değil"

**Neden**: Aktivasyon gecikmesi henüz geçmedi
**Çözüm**:
- Durumu kontrol et: aktivasyona kaç blok kaldı
- Gecikme süresinin tamamlanmasını bekle

#### "Plot adresinde coin yok"

**Neden**: Plot adresinin onaylanmış UTXO'su yok
**Çözüm**:
1. Plot adresine fon gönder
2. 1 onay bekle
3. Atama oluşturmayı tekrar dene

#### "Salt izleme cüzdanıyla işlem oluşturulamaz"

**Neden**: Cüzdan özel anahtar olmadan adres içe aktarmış
**Çözüm**: Sadece adres değil, tam özel anahtarı içe aktar

#### "Dövme Atama sekmesi görünmüyor"

**Neden**: Düğüm `-miningserver` bayrağı olmadan başlatılmış
**Çözüm**: `bitcoin-qt -server -miningserver` ile yeniden başlat

### Hata Ayıklama Adımları

1. **Cüzdan Durumunu Kontrol Et**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Adres Sahipliğini Doğrula**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Kontrol: "iswatchonly": false, "ismine": true
   ```

3. **Atama Durumunu Kontrol Et**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Son İşlemleri Görüntüle**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Düğüm Senkronizasyonunu Kontrol Et**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Doğrula: blocks == headers (tam senkronize)
   ```

---

## Güvenlik En İyi Uygulamaları

### Plot Adresi Güvenliği

**Anahtar Yönetimi**:
- Plot adresi özel anahtarlarını güvenli şekilde saklayın
- Atama işlemleri imza ile sahipliği kanıtlar
- Yalnızca plot sahibi atama oluşturabilir/iptal edebilir

**Yedekleme**:
- Cüzdanı düzenli olarak yedekleyin (`dumpwallet` veya `backupwallet`)
- wallet.dat'ı güvenli konumda saklayın
- HD cüzdan kullanılıyorsa kurtarma ifadelerini kaydedin

### Dövme Adresi Devri

**Güvenlik Modeli**:
- Dövme adresi blok ödüllerini alır
- Dövme adresi blokları imzalayabilir (madencilik)
- Dövme adresi atamayı değiştiremez veya iptal **edemez**
- Plot sahibi tam kontrolü korur

**Kullanım Alanları**:
- **Sıcak Cüzdan Devri**: Plot anahtarı soğuk depoda, dövme anahtarı madencilik için sıcak cüzdanda
- **Havuz Madenciliği**: Havuza devret, plot sahipliğini koru
- **Paylaşılan Altyapı**: Birden fazla madenci, tek dövme adresi

### Ağ Zaman Senkronizasyonu

**Önemi**:
- PoCX konsensüsü doğru zaman gerektirir
- Saat sapması >10s uyarı tetikler
- Saat sapması >15s madenciliği önler

**Çözüm**:
- Sistem saatini NTP ile senkronize tutun
- İzleme: zaman ofseti uyarıları için `bitcoin-cli getnetworkinfo`
- Güvenilir NTP sunucuları kullanın

### Atama Gecikmeleri

**Aktivasyon Gecikmesi** (testnet'te 30 blok):
- Zincir çatalları sırasında hızlı yeniden atamayı önler
- Ağın konsensüse ulaşmasını sağlar
- Atlanamaz

**İptal Gecikmesi** (testnet'te 720 blok):
- Madencilik havuzları için kararlılık sağlar
- Atama "griefing" saldırılarını önler
- Gecikme sırasında dövme adresi aktif kalır

### Cüzdan Şifreleme

**Şifrelemeyi Etkinleştir**:
```bash
bitcoin-cli encryptwallet "şifreniz"
```

**İşlemler İçin Kilidi Aç**:
```bash
bitcoin-cli walletpassphrase "şifreniz" 300
```

**En İyi Uygulamalar**:
- Güçlü şifre kullan (20+ karakter)
- Şifreyi düz metin olarak saklamayın
- Atama oluşturduktan sonra cüzdanı kilitle

---

## Kod Referansları

**Dövme Atama Penceresi**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**İşlem Görüntüleme**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**İşlem Ayrıştırma**: `src/qt/transactionrecord.cpp`
**Cüzdan Entegrasyonu**: `src/pocx/assignments/transactions.cpp`
**Atama RPC'leri**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Ana**: `src/qt/bitcoingui.cpp`

---

## Çapraz Referanslar

İlgili bölümler:
- [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md) - Madencilik süreci
- [Bölüm 4: Dövme Atamaları](4-forging-assignments.md) - Atama mimarisi
- [Bölüm 6: Ağ Parametreleri](6-network-parameters.md) - Atama gecikme değerleri
- [Bölüm 7: RPC Referansı](7-rpc-reference.md) - RPC komut detayları

---

[← Önceki: RPC Referansı](7-rpc-reference.md) | [İçindekiler](index.md)
