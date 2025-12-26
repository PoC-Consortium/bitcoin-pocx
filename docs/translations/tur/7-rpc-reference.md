[← Önceki: Ağ Parametreleri](6-network-parameters.md) | [İçindekiler](index.md) | [Sonraki: Cüzdan Kılavuzu →](8-wallet-guide.md)

---

# Bölüm 7: RPC Arayüzü Referansı

Madencilik RPC'leri, atama yönetimi ve değiştirilmiş blok zinciri RPC'leri dahil Bitcoin-PoCX RPC komutları için eksiksiz referans.

---

## İçindekiler

1. [Yapılandırma](#yapılandırma)
2. [PoCX Madencilik RPC'leri](#pocx-madencilik-rpcleri)
3. [Atama RPC'leri](#atama-rpcleri)
4. [Değiştirilmiş Blok Zinciri RPC'leri](#değiştirilmiş-blok-zinciri-rpcleri)
5. [Devre Dışı RPC'ler](#devre-dışı-rpcler)
6. [Entegrasyon Örnekleri](#entegrasyon-örnekleri)

---

## Yapılandırma

### Madencilik Sunucu Modu

**Bayrak**: `-miningserver`

**Amaç**: Harici madencilerin madenciliğe özgü RPC'leri çağırması için RPC erişimini etkinleştirir

**Gereksinimler**:
- `submit_nonce`'un çalışması için gerekli
- Qt cüzdanında dövme atama penceresinin görünürlüğü için gerekli

**Kullanım**:
```bash
# Komut satırı
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Güvenlik Değerlendirmeleri**:
- Standart RPC kimlik bilgilerinin ötesinde ek kimlik doğrulama yok
- Madencilik RPC'leri kuyruk kapasitesiyle hız sınırlı
- Standart RPC kimlik doğrulaması hala gerekli

**Uygulama**: `src/pocx/rpc/mining.cpp`

---

## PoCX Madencilik RPC'leri

### get_mining_info

**Kategori**: mining
**Madencilik Sunucusu Gerekli**: Hayır
**Cüzdan Gerekli**: Hayır

**Amaç**: Harici madencilerin plot dosyalarını taraması ve son tarihleri hesaplaması için gereken mevcut madencilik parametrelerini döndürür.

**Parametreler**: Yok

**Dönüş Değerleri**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 karakter
  "base_target": 36650387593,                // sayısal
  "height": 12345,                           // sayısal, sonraki blok yüksekliği
  "block_hash": "def456...",                 // hex, önceki blok
  "target_quality": 18446744073709551615,    // uint64_max (tüm çözümler kabul edilir)
  "minimum_compression_level": 1,            // sayısal
  "target_compression_level": 2              // sayısal
}
```

**Alan Açıklamaları**:
- `generation_signature`: Bu blok yüksekliği için deterministik madencilik entropisi
- `base_target`: Mevcut zorluk (yüksek = daha kolay)
- `height`: Madencilerin hedeflemesi gereken blok yüksekliği
- `block_hash`: Önceki blok hash'i (bilgilendirme)
- `target_quality`: Kalite eşiği (şu anda uint64_max, filtreleme yok)
- `minimum_compression_level`: Doğrulama için gereken minimum sıkıştırma
- `target_compression_level`: Optimal madencilik için önerilen sıkıştırma

**Hata Kodları**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Düğüm hala senkronize oluyor

**Örnek**:
```bash
bitcoin-cli get_mining_info
```

**Uygulama**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategori**: mining
**Madencilik Sunucusu Gerekli**: Evet
**Cüzdan Gerekli**: Evet (özel anahtarlar için)

**Amaç**: Bir PoCX madencilik çözümü gönderir. Kanıtı doğrular, zaman bükülmüş dövme için kuyruğa alır ve planlanan zamanda otomatik olarak blok oluşturur.

**Parametreler**:
1. `height` (sayısal, gerekli) - Blok yüksekliği
2. `generation_signature` (string hex, gerekli) - Üretim imzası (64 karakter)
3. `account_id` (string, gerekli) - Plot hesap kimliği (40 hex karakter = 20 bayt)
4. `seed` (string, gerekli) - Plot seed'i (64 hex karakter = 32 bayt)
5. `nonce` (sayısal, gerekli) - Madencilik nonce'u
6. `compression` (sayısal, gerekli) - Kullanılan ölçeklendirme/sıkıştırma seviyesi (1-255)
7. `quality` (sayısal, isteğe bağlı) - Kalite değeri (atlanırsa yeniden hesaplanır)

**Dönüş Değerleri** (başarılı):
```json
{
  "accepted": true,
  "quality": 120,           // zorluk ayarlı son tarih (saniye)
  "poc_time": 45            // zaman bükülmüş dövme süresi (saniye)
}
```

**Dönüş Değerleri** (reddedildi):
```json
{
  "accepted": false,
  "error": "Üretim imzası uyuşmazlığı"
}
```

**Doğrulama Adımları**:
1. **Format Doğrulaması** (hızlı başarısızlık):
   - Hesap Kimliği: tam 40 hex karakter
   - Seed: tam 64 hex karakter
2. **Bağlam Doğrulaması**:
   - Yükseklik mevcut uç + 1 ile eşleşmeli
   - Üretim imzası mevcut ile eşleşmeli
3. **Cüzdan Doğrulaması**:
   - Etkin imzalayanı belirle (aktif atamaları kontrol et)
   - Cüzdanın etkin imzalayan için özel anahtara sahip olduğunu doğrula
4. **Kanıt Doğrulaması** (pahalı):
   - Sıkıştırma sınırları ile PoCX kanıtını doğrula
   - Ham kaliteyi hesapla
5. **Zamanlayıcı Gönderimi**:
   - Zaman bükülmüş dövme için nonce'u kuyruğa al
   - Blok forge_time'da otomatik olarak oluşturulacak

**Hata Kodları**:
- `RPC_INVALID_PARAMETER`: Geçersiz format (account_id, seed) veya yükseklik uyuşmazlığı
- `RPC_VERIFY_REJECTED`: Üretim imzası uyuşmazlığı veya kanıt doğrulama başarısız
- `RPC_INVALID_ADDRESS_OR_KEY`: Etkin imzalayan için özel anahtar yok
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Gönderim kuyruğu dolu
- `RPC_INTERNAL_ERROR`: PoCX zamanlayıcısını başlatma başarısız

**Kanıt Doğrulama Hata Kodları**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Örnek**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_karakter..." \
  999888777 \
  1
```

**Notlar**:
- Gönderim asenkron - RPC hemen döner, blok daha sonra dövülür
- Zaman Bükme, ağ genelinde plot taramaya izin vermek için iyi çözümleri geciktirir
- Atama sistemi: plot atanmışsa, cüzdan dövme adresi anahtarına sahip olmalı
- Sıkıştırma sınırları blok yüksekliğine göre dinamik olarak ayarlanır

**Uygulama**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Atama RPC'leri

### get_assignment

**Kategori**: mining
**Madencilik Sunucusu Gerekli**: Hayır
**Cüzdan Gerekli**: Hayır

**Amaç**: Bir plot adresi için dövme atama durumunu sorgular. Salt okunur, cüzdan gerekmez.

**Parametreler**:
1. `plot_address` (string, gerekli) - Plot adresi (bech32 P2WPKH formatı)
2. `height` (sayısal, isteğe bağlı) - Sorgulanacak blok yüksekliği (varsayılan: mevcut uç)

**Dönüş Değerleri** (atama yok):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Dönüş Değerleri** (aktif atama):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Dönüş Değerleri** (iptal ediliyor):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Atama Durumları**:
- `UNASSIGNED`: Atama yok
- `ASSIGNING`: Atama işlemi onaylandı, aktivasyon gecikmesi devam ediyor
- `ASSIGNED`: Atama aktif, dövme hakları devredildi
- `REVOKING`: İptal işlemi onaylandı, gecikme geçene kadar hala aktif
- `REVOKED`: İptal tamamlandı, dövme hakları plot sahibine döndü

**Hata Kodları**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Geçersiz adres veya P2WPKH (bech32) değil

**Örnek**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Uygulama**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategori**: wallet
**Madencilik Sunucusu Gerekli**: Hayır
**Cüzdan Gerekli**: Evet (yüklenmiş ve kilidi açık olmalı)

**Amaç**: Dövme haklarını başka bir adrese (örn., madencilik havuzu) devretmek için dövme atama işlemi oluşturur.

**Parametreler**:
1. `plot_address` (string, gerekli) - Plot sahibi adresi (özel anahtara sahip olmalı, P2WPKH bech32)
2. `forging_address` (string, gerekli) - Dövme haklarının atanacağı adres (P2WPKH bech32)
3. `fee_rate` (sayısal, isteğe bağlı) - BTC/kvB olarak ücret oranı (varsayılan: 10× minRelayFee)

**Dönüş Değerleri**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Gereksinimler**:
- Cüzdan yüklenmiş ve kilidi açık
- plot_address için özel anahtar cüzdanda mevcut
- Her iki adres de P2WPKH olmalı (bech32 formatı: pocx1q... mainnet, tpocx1q... testnet)
- Plot adresinin onaylanmış UTXO'ları olmalı (sahipliği kanıtlar)
- Plot'un aktif ataması olmamalı (önce iptal kullanın)

**İşlem Yapısı**:
- Giriş: Plot adresinden UTXO (sahipliği kanıtlar)
- Çıktı: OP_RETURN (46 bayt): `POCX` işareti + plot_address (20 bayt) + forging_address (20 bayt)
- Çıktı: Para üstü cüzdana döner

**Aktivasyon**:
- Atama onayda ASSIGNING olur
- `nForgingAssignmentDelay` bloktan sonra ACTIVE olur
- Gecikme, zincir çatalları sırasında hızlı yeniden atamayı önler

**Hata Kodları**:
- `RPC_WALLET_NOT_FOUND`: Cüzdan mevcut değil
- `RPC_WALLET_UNLOCK_NEEDED`: Cüzdan şifreli ve kilitli
- `RPC_WALLET_ERROR`: İşlem oluşturma başarısız
- `RPC_INVALID_ADDRESS_OR_KEY`: Geçersiz adres formatı

**Örnek**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Uygulama**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategori**: wallet
**Madencilik Sunucusu Gerekli**: Hayır
**Cüzdan Gerekli**: Evet (yüklenmiş ve kilidi açık olmalı)

**Amaç**: Mevcut dövme atamasını iptal eder, dövme haklarını plot sahibine döndürür.

**Parametreler**:
1. `plot_address` (string, gerekli) - Plot adresi (özel anahtara sahip olmalı, P2WPKH bech32)
2. `fee_rate` (sayısal, isteğe bağlı) - BTC/kvB olarak ücret oranı (varsayılan: 10× minRelayFee)

**Dönüş Değerleri**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Gereksinimler**:
- Cüzdan yüklenmiş ve kilidi açık
- plot_address için özel anahtar cüzdanda mevcut
- Plot adresi P2WPKH olmalı (bech32 formatı)
- Plot adresinin onaylanmış UTXO'ları olmalı

**İşlem Yapısı**:
- Giriş: Plot adresinden UTXO (sahipliği kanıtlar)
- Çıktı: OP_RETURN (26 bayt): `XCOP` işareti + plot_address (20 bayt)
- Çıktı: Para üstü cüzdana döner

**Etki**:
- Durum hemen REVOKING'e geçer
- Dövme adresi gecikme süresi boyunca hala dövebilir
- `nForgingRevocationDelay` bloktan sonra REVOKED olur
- Plot sahibi iptal geçerli olduktan sonra dövebilir
- Sonrasında yeni atama oluşturulabilir

**Hata Kodları**:
- `RPC_WALLET_NOT_FOUND`: Cüzdan mevcut değil
- `RPC_WALLET_UNLOCK_NEEDED`: Cüzdan şifreli ve kilitli
- `RPC_WALLET_ERROR`: İşlem oluşturma başarısız

**Örnek**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Notlar**:
- İdempotent: aktif atama olmasa bile iptal edilebilir
- Gönderildikten sonra iptal geri alınamaz

**Uygulama**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Değiştirilmiş Blok Zinciri RPC'leri

### getdifficulty

**PoCX Değişiklikleri**:
- **Hesaplama**: `reference_base_target / current_base_target`
- **Referans**: 1 TiB ağ kapasitesi (base_target = 36650387593)
- **Yorum**: Tahmini ağ depolama kapasitesi (TiB cinsinden)
  - Örnek: `1.0` = ~1 TiB
  - Örnek: `1024.0` = ~1 PiB
- **PoW'dan Farkı**: Hash gücü değil kapasiteyi temsil eder

**Örnek**:
```bash
bitcoin-cli getdifficulty
# Döndürür: 2048.5 (ağ ~2 PiB)
```

**Uygulama**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX Eklenen Alanlar**:
- `time_since_last_block` (sayısal) - Önceki bloktan bu yana saniye (mediantime yerine)
- `poc_time` (sayısal) - Zaman bükülmüş dövme süresi (saniye)
- `base_target` (sayısal) - PoCX zorluk temel hedefi
- `generation_signature` (string hex) - Üretim imzası
- `pocx_proof` (nesne):
  - `account_id` (string hex) - Plot hesap kimliği (20 bayt)
  - `seed` (string hex) - Plot seed'i (32 bayt)
  - `nonce` (sayısal) - Madencilik nonce'u
  - `compression` (sayısal) - Kullanılan ölçeklendirme seviyesi
  - `quality` (sayısal) - Talep edilen kalite değeri
- `pubkey` (string hex) - Blok imzalayanın açık anahtarı (33 bayt)
- `signer_address` (string) - Blok imzalayanın adresi
- `signature` (string hex) - Blok imzası (65 bayt)

**PoCX Kaldırılan Alanlar**:
- `mediantime` - Kaldırıldı (time_since_last_block ile değiştirildi)

**Örnek**:
```bash
bitcoin-cli getblockheader <blokhash>
```

**Uygulama**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX Değişiklikleri**: getblockheader ile aynı, artı tam işlem verisi

**Örnek**:
```bash
bitcoin-cli getblock <blokhash>
bitcoin-cli getblock <blokhash> 2  # işlem detaylarıyla ayrıntılı
```

**Uygulama**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX Eklenen Alanlar**:
- `base_target` (sayısal) - Mevcut temel hedef
- `generation_signature` (string hex) - Mevcut üretim imzası

**PoCX Değiştirilen Alanlar**:
- `difficulty` - PoCX hesaplamasını kullanır (kapasite tabanlı)

**PoCX Kaldırılan Alanlar**:
- `mediantime` - Kaldırıldı

**Örnek**:
```bash
bitcoin-cli getblockchaininfo
```

**Uygulama**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX Eklenen Alanlar**:
- `generation_signature` (string hex) - Havuz madenciliği için
- `base_target` (sayısal) - Havuz madenciliği için

**PoCX Kaldırılan Alanlar**:
- `target` - Kaldırıldı (PoW'a özgü)
- `noncerange` - Kaldırıldı (PoW'a özgü)
- `bits` - Kaldırıldı (PoW'a özgü)

**Notlar**:
- Blok oluşturma için tam işlem verisi hala dahil
- Havuz sunucuları tarafından koordineli madencilik için kullanılır

**Örnek**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Uygulama**: `src/rpc/mining.cpp`

---

## Devre Dışı RPC'ler

Aşağıdaki PoW'a özgü RPC'ler PoCX modunda **devre dışıdır**:

### getnetworkhashps
- **Neden**: Hash oranı Kapasite Kanıtına uygulanamaz
- **Alternatif**: Ağ kapasitesi tahmini için `getdifficulty` kullanın

### getmininginfo
- **Neden**: PoW'a özgü bilgi döndürür
- **Alternatif**: `get_mining_info` (PoCX'e özgü) kullanın

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Neden**: CPU madenciliği PoCX'e uygulanamaz (önceden oluşturulmuş plot'lar gerektirir)
- **Alternatif**: Harici plotter + madenci + `submit_nonce` kullanın

**Uygulama**: `src/rpc/mining.cpp` (ENABLE_POCX tanımlı olduğunda RPC'ler hata döndürür)

---

## Entegrasyon Örnekleri

### Harici Madenci Entegrasyonu

**Temel Madencilik Döngüsü**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Madencilik döngüsü
while True:
    # 1. Madencilik parametrelerini al
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Plot dosyalarını tara (harici uygulama)
    best_nonce = scan_plots(gen_sig, height)

    # 3. En iyi çözümü gönder
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Çözüm kabul edildi! Kalite: {result['quality']}s, "
              f"Dövme süresi: {result['poc_time']}s")

    # 4. Sonraki bloğu bekle
    time.sleep(10)  # Yoklama aralığı
```

---

### Havuz Entegrasyon Deseni

**Havuz Sunucu İş Akışı**:
1. Madenciler havuz adresine dövme atamaları oluşturur
2. Havuz, dövme adresi anahtarlarına sahip cüzdan çalıştırır
3. Havuz `get_mining_info` çağırır ve madencilere dağıtır
4. Madenciler çözümleri havuz üzerinden gönderir (doğrudan zincire değil)
5. Havuz doğrular ve havuzun anahtarlarıyla `submit_nonce` çağırır
6. Havuz, havuz politikasına göre ödülleri dağıtır

**Atama Yönetimi**:
```bash
# Madenci atama oluşturur (madencinin cüzdanından)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Aktivasyonu bekle (30 blok mainnet)

# Havuz atama durumunu kontrol eder
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Havuz artık bu plot için nonce gönderebilir
# (havuz cüzdanı pocx1qpool... özel anahtarına sahip olmalı)
```

---

### Blok Gezgini Sorguları

**PoCX Blok Verisini Sorgulama**:
```bash
# En son bloğu al
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# PoCX kanıtı ile blok detaylarını al
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX'e özgü alanları çıkar
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Atama İşlemlerini Tespit Etme**:
```bash
# OP_RETURN için işlemi tara
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Atama işareti için kontrol et (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Hata Yönetimi

### Yaygın Hata Desenleri

**Yükseklik Uyuşmazlığı**:
```json
{
  "accepted": false,
  "error": "Yükseklik uyuşmazlığı: gönderilen 12345, mevcut 12346"
}
```
**Çözüm**: Madencilik bilgisini yeniden al, zincir ilerledi

**Üretim İmzası Uyuşmazlığı**:
```json
{
  "accepted": false,
  "error": "Üretim imzası uyuşmazlığı"
}
```
**Çözüm**: Madencilik bilgisini yeniden al, yeni blok geldi

**Özel Anahtar Yok**:
```json
{
  "code": -5,
  "message": "Etkin imzalayan için özel anahtar mevcut değil"
}
```
**Çözüm**: Plot veya dövme adresi için anahtar içe aktar

**Atama Aktivasyonu Bekliyor**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Çözüm**: Aktivasyon gecikmesinin geçmesini bekle

---

## Kod Referansları

**Madencilik RPC'leri**: `src/pocx/rpc/mining.cpp`
**Atama RPC'leri**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blok Zinciri RPC'leri**: `src/rpc/blockchain.cpp`
**Kanıt Doğrulaması**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Atama Durumu**: `src/pocx/assignments/assignment_state.cpp`
**İşlem Oluşturma**: `src/pocx/assignments/transactions.cpp`

---

## Çapraz Referanslar

İlgili bölümler:
- [Bölüm 3: Konsensüs ve Madencilik](3-consensus-and-mining.md) - Madencilik süreci detayları
- [Bölüm 4: Dövme Atamaları](4-forging-assignments.md) - Atama sistemi mimarisi
- [Bölüm 6: Ağ Parametreleri](6-network-parameters.md) - Atama gecikme değerleri
- [Bölüm 8: Cüzdan Kılavuzu](8-wallet-guide.md) - Atama yönetimi için GUI

---

[← Önceki: Ağ Parametreleri](6-network-parameters.md) | [İçindekiler](index.md) | [Sonraki: Cüzdan Kılavuzu →](8-wallet-guide.md)
