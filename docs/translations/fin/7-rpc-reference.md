[← Edellinen: Verkkoparametrit](6-network-parameters.md) | [Sisällysluettelo](index.md) | [Seuraava: Lompakko-opas →](8-wallet-guide.md)

---

# Luku 7: RPC-rajapintaviite

Täydellinen viite Bitcoin-PoCX:n RPC-komennoille, mukaan lukien louhinnan RPC:t, delegointien hallinta ja muokatut lohkoketju-RPC:t.

---

## Sisällysluettelo

1. [Konfiguraatio](#konfiguraatio)
2. [PoCX-louhinnan RPC:t](#pocx-louhinnan-rpct)
3. [Delegointi-RPC:t](#delegointi-rpct)
4. [Muokatut lohkoketju-RPC:t](#muokatut-lohkoketju-rpct)
5. [Poistetut RPC:t](#poistetut-rpct)
6. [Integraatioesimerkit](#integraatioesimerkit)

---

## Konfiguraatio

### Louhintapalvelintila

**Lippu**: `-miningserver`

**Tarkoitus**: Mahdollistaa RPC-pääsyn ulkoisille louhijoille kutsua louhintakohtaisia RPC:itä

**Vaatimukset**:
- Vaaditaan `submit_nonce`-komennon toimintaan
- Vaaditaan forging-delegointidialogin näkyvyyteen Qt-lompakossa

**Käyttö**:
```bash
# Komentorivi
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Turvallisuusnäkökohdat**:
- Ei lisäautentikointia vakio RPC-tunnusten lisäksi
- Louhinnan RPC:t ovat nopeusrajoitettuja jonon kapasiteetilla
- Vakio RPC-autentikointi yhä vaaditaan

**Toteutus**: `src/pocx/rpc/mining.cpp`

---

## PoCX-louhinnan RPC:t

### get_mining_info

**Kategoria**: mining
**Vaatii louhintapalvelimen**: Ei
**Vaatii lompakon**: Ei

**Tarkoitus**: Palauttaa nykyiset louhintaparametrit, joita ulkoiset louhijat tarvitsevat plottitiedostojen skannaamiseen ja deadlinejen laskemiseen.

**Parametrit**: Ei mitään

**Palautusarvot**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 merkkiä
  "base_target": 36650387593,                // numeerinen
  "height": 12345,                           // numeerinen, seuraavan lohkon korkeus
  "block_hash": "def456...",                 // hex, edellinen lohko
  "target_quality": 18446744073709551615,    // uint64_max (kaikki ratkaisut hyväksytään)
  "minimum_compression_level": 1,            // numeerinen
  "target_compression_level": 2              // numeerinen
}
```

**Kenttien kuvaukset**:
- `generation_signature`: Deterministinen louhinnan entropia tälle lohkokorkeudelle
- `base_target`: Nykyinen vaikeus (korkeampi = helpompi)
- `height`: Lohkon korkeus johon louhijoiden tulisi tähdätä
- `block_hash`: Edellisen lohkon tiiviste (tiedoksi)
- `target_quality`: Laatukynnys (tällä hetkellä uint64_max, ei suodatusta)
- `minimum_compression_level`: Vähimmäispakkaus joka vaaditaan validointiin
- `target_compression_level`: Suositeltu pakkaus optimaaliseen louhintaan

**Virhekoodit**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Solmu yhä synkronoitumassa

**Esimerkki**:
```bash
bitcoin-cli get_mining_info
```

**Toteutus**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategoria**: mining
**Vaatii louhintapalvelimen**: Kyllä
**Vaatii lompakon**: Kyllä (yksityisiä avaimia varten)

**Tarkoitus**: Lähetä PoCX-louhintaratkaisu. Validoi todisteen, jonottaa aikataivutettua forgingia varten ja luo automaattisesti lohkon ajoitettuna aikana.

**Parametrit**:
1. `height` (numeerinen, vaadittu) - Lohkon korkeus
2. `generation_signature` (merkkijono hex, vaadittu) - Generoinnin allekirjoitus (64 merkkiä)
3. `account_id` (merkkijono, vaadittu) - Plotin tilitunniste (40 heksamerkkiä = 20 tavua)
4. `seed` (merkkijono, vaadittu) - Plotin seed (64 heksamerkkiä = 32 tavua)
5. `nonce` (numeerinen, vaadittu) - Louhinnan nonce
6. `compression` (numeerinen, vaadittu) - Käytetty skaalaus/pakkaustaso (1-255)
7. `quality` (numeerinen, valinnainen) - Laatuarvo (lasketaan uudelleen jos jätetään pois)

**Palautusarvot** (onnistuminen):
```json
{
  "accepted": true,
  "quality": 120,           // vaikeussäädetty deadline sekunteina
  "poc_time": 45            // aikataivutettu forging-aika sekunteina
}
```

**Palautusarvot** (hylätty):
```json
{
  "accepted": false,
  "error": "Generoinnin allekirjoitus ei täsmää"
}
```

**Validointivaiheet**:
1. **Muotovalidointi** (nopea epäonnistuminen):
   - Tilitunniste: täsmälleen 40 heksamerkkiä
   - Seed: täsmälleen 64 heksamerkkiä
2. **Kontekstivalidointi**:
   - Korkeuden on vastattava nykyistä kärkeä + 1
   - Generoinnin allekirjoituksen on vastattava nykyistä
3. **Lompakkovarmistus**:
   - Määritä tehokas allekirjoittaja (tarkista aktiiviset delegoinnit)
   - Varmista lompakolla on yksityinen avain tehokkaalle allekirjoittajalle
4. **Todisteen validointi** (kallis):
   - Validoi PoCX-todiste pakkausrajoilla
   - Laske raaka laatu
5. **Ajastimen lähetys**:
   - Jonota nonce aikataivutettua forgingia varten
   - Lohko luodaan automaattisesti forge_time-aikana

**Virhekoodit**:
- `RPC_INVALID_PARAMETER`: Kelvoton muoto (account_id, seed) tai korkeusero
- `RPC_VERIFY_REJECTED`: Generoinnin allekirjoitusero tai todisteen validointi epäonnistui
- `RPC_INVALID_ADDRESS_OR_KEY`: Ei yksityistä avainta tehokkaalle allekirjoittajalle
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Lähetysjono täynnä
- `RPC_INTERNAL_ERROR`: PoCX-ajastimen alustus epäonnistui

**Todisteen validoinnin virhekoodit**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Esimerkki**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_heksamerkkiä..." \
  999888777 \
  1
```

**Huomautukset**:
- Lähetys on asynkroninen - RPC palaa välittömästi, lohko forgataan myöhemmin
- Time Bending viivästyttää hyviä ratkaisuja mahdollistaen verkon laajuisen plotin skannauksen
- Delegointijärjestelmä: jos plotti on delegoitu, lompakolla on oltava forging-osoitteen avain
- Pakkausrajat säädetään dynaamisesti lohkon korkeuden perusteella

**Toteutus**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Delegointi-RPC:t

### get_assignment

**Kategoria**: mining
**Vaatii louhintapalvelimen**: Ei
**Vaatii lompakon**: Ei

**Tarkoitus**: Kysele forging-delegoinnin tilaa plotin osoitteelle. Vain luku, ei vaadi lompakkoa.

**Parametrit**:
1. `plot_address` (merkkijono, vaadittu) - Plotin osoite (bech32 P2WPKH-muoto)
2. `height` (numeerinen, valinnainen) - Lohkon korkeus kyselyyn (oletus: nykyinen kärki)

**Palautusarvot** (ei delegointia):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Palautusarvot** (aktiivinen delegointi):
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

**Palautusarvot** (peruuttamassa):
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

**Delegointitilat**:
- `UNASSIGNED`: Ei delegointia
- `ASSIGNING`: Delegointitransaktio vahvistettu, aktivointiviive käynnissä
- `ASSIGNED`: Delegointi aktiivinen, forging-oikeudet delegoitu
- `REVOKING`: Peruutustransaktio vahvistettu, yhä aktiivinen kunnes viive täyttyy
- `REVOKED`: Peruutus valmis, forging-oikeudet palautettu plotin omistajalle

**Virhekoodit**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Kelvoton osoite tai ei P2WPKH (bech32)

**Esimerkki**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Toteutus**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategoria**: wallet
**Vaatii louhintapalvelimen**: Ei
**Vaatii lompakon**: Kyllä (on oltava ladattu ja avattu)

**Tarkoitus**: Luo forging-delegointitransaktio delegoidaksesi forging-oikeudet toiselle osoitteelle (esim. louhintapoolille).

**Parametrit**:
1. `plot_address` (merkkijono, vaadittu) - Plotin omistajan osoite (on omistettava yksityinen avain, P2WPKH bech32)
2. `forging_address` (merkkijono, vaadittu) - Osoite jolle forging-oikeudet delegoidaan (P2WPKH bech32)
3. `fee_rate` (numeerinen, valinnainen) - Maksuaste BTC/kvB (oletus: 10× minRelayFee)

**Palautusarvot**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Vaatimukset**:
- Lompakko ladattu ja avattu
- Yksityinen avain plot_address:lle lompakossa
- Molempien osoitteiden on oltava P2WPKH (bech32-muoto: pocx1q... mainnet, tpocx1q... testnet)
- Plotin osoitteella on oltava vahvistettuja UTXO:ita (todistaa omistajuuden)
- Plotilla ei saa olla aktiivista delegointia (käytä peruutusta ensin)

**Transaktiorakenne**:
- Syöte: UTXO plotin osoitteesta (todistaa omistajuuden)
- Tuloste: OP_RETURN (46 tavua): `POCX`-merkki + plot_address (20 tavua) + forging_address (20 tavua)
- Tuloste: Vaihtoraha palautetaan lompakkoon

**Aktivointi**:
- Delegointi muuttuu ASSIGNING-tilaan vahvistuksessa
- Muuttuu ACTIVE-tilaan `nForgingAssignmentDelay`-lohkojen jälkeen
- Viive estää nopean uudelleendelegoinnin ketjuhaarautumien aikana

**Virhekoodit**:
- `RPC_WALLET_NOT_FOUND`: Ei lompakkoa saatavilla
- `RPC_WALLET_UNLOCK_NEEDED`: Lompakko salattu ja lukittu
- `RPC_WALLET_ERROR`: Transaktion luonti epäonnistui
- `RPC_INVALID_ADDRESS_OR_KEY`: Kelvoton osoitemuoto

**Esimerkki**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Toteutus**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategoria**: wallet
**Vaatii louhintapalvelimen**: Ei
**Vaatii lompakon**: Kyllä (on oltava ladattu ja avattu)

**Tarkoitus**: Peruuta olemassa oleva forging-delegointi, palauttaen forging-oikeudet plotin omistajalle.

**Parametrit**:
1. `plot_address` (merkkijono, vaadittu) - Plotin osoite (on omistettava yksityinen avain, P2WPKH bech32)
2. `fee_rate` (numeerinen, valinnainen) - Maksuaste BTC/kvB (oletus: 10× minRelayFee)

**Palautusarvot**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Vaatimukset**:
- Lompakko ladattu ja avattu
- Yksityinen avain plot_address:lle lompakossa
- Plotin osoitteen on oltava P2WPKH (bech32-muoto)
- Plotin osoitteella on oltava vahvistettuja UTXO:ita

**Transaktiorakenne**:
- Syöte: UTXO plotin osoitteesta (todistaa omistajuuden)
- Tuloste: OP_RETURN (26 tavua): `XCOP`-merkki + plot_address (20 tavua)
- Tuloste: Vaihtoraha palautetaan lompakkoon

**Vaikutus**:
- Tila siirtyy REVOKING-tilaan välittömästi
- Forging-osoite voi yhä forgata viivejakson ajan
- Muuttuu REVOKED-tilaan `nForgingRevocationDelay`-lohkojen jälkeen
- Plotin omistaja voi forgata peruutuksen voimaantulon jälkeen
- Voi luoda uuden delegoinnin peruutuksen valmistuttua

**Virhekoodit**:
- `RPC_WALLET_NOT_FOUND`: Ei lompakkoa saatavilla
- `RPC_WALLET_UNLOCK_NEEDED`: Lompakko salattu ja lukittu
- `RPC_WALLET_ERROR`: Transaktion luonti epäonnistui

**Esimerkki**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Huomautukset**:
- Idempotentti: voi peruuttaa vaikka ei olisi aktiivista delegointia
- Peruutusta ei voi perua lähetyksen jälkeen

**Toteutus**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Muokatut lohkoketju-RPC:t

### getdifficulty

**PoCX-muutokset**:
- **Laskenta**: `viite_base_target / nykyinen_base_target`
- **Viite**: 1 TiB verkon kapasiteetti (base_target = 36650387593)
- **Tulkinta**: Arvioitu verkon tallennuskapasiteetti TiB:nä
  - Esimerkki: `1.0` = ~1 TiB
  - Esimerkki: `1024.0` = ~1 PiB
- **Ero PoW:sta**: Edustaa kapasiteettia, ei hash-tehoa

**Esimerkki**:
```bash
bitcoin-cli getdifficulty
# Palauttaa: 2048.5 (verkko ~2 PiB)
```

**Toteutus**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX:n lisäämät kentät**:
- `time_since_last_block` (numeerinen) - Sekunteja edellisestä lohkosta (korvaa mediantimen)
- `poc_time` (numeerinen) - Aikataivutettu forging-aika sekunteina
- `base_target` (numeerinen) - PoCX-vaikeuden perustavoite
- `generation_signature` (merkkijono hex) - Generoinnin allekirjoitus
- `pocx_proof` (objekti):
  - `account_id` (merkkijono hex) - Plotin tilitunniste (20 tavua)
  - `seed` (merkkijono hex) - Plotin seed (32 tavua)
  - `nonce` (numeerinen) - Louhinnan nonce
  - `compression` (numeerinen) - Käytetty skaalaustaso
  - `quality` (numeerinen) - Väitetty laatuarvo
- `pubkey` (merkkijono hex) - Lohkon allekirjoittajan julkinen avain (33 tavua)
- `signer_address` (merkkijono) - Lohkon allekirjoittajan osoite
- `signature` (merkkijono hex) - Lohkon allekirjoitus (65 tavua)

**PoCX:n poistamat kentät**:
- `mediantime` - Poistettu (korvattu time_since_last_block:lla)

**Esimerkki**:
```bash
bitcoin-cli getblockheader <lohkotiiviste>
```

**Toteutus**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-muutokset**: Samat kuin getblockheader, plus täydet transaktiotiedot

**Esimerkki**:
```bash
bitcoin-cli getblock <lohkotiiviste>
bitcoin-cli getblock <lohkotiiviste> 2  # verbose transaktiodetaljeillla
```

**Toteutus**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX:n lisäämät kentät**:
- `base_target` (numeerinen) - Nykyinen perustavoite
- `generation_signature` (merkkijono hex) - Nykyinen generoinnin allekirjoitus

**PoCX:n muuttamat kentät**:
- `difficulty` - Käyttää PoCX-laskentaa (kapasiteettipohjainen)

**PoCX:n poistamat kentät**:
- `mediantime` - Poistettu

**Esimerkki**:
```bash
bitcoin-cli getblockchaininfo
```

**Toteutus**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX:n lisäämät kentät**:
- `generation_signature` (merkkijono hex) - Poolilouhintaa varten
- `base_target` (numeerinen) - Poolilouhintaa varten

**PoCX:n poistamat kentät**:
- `target` - Poistettu (PoW-spesifinen)
- `noncerange` - Poistettu (PoW-spesifinen)
- `bits` - Poistettu (PoW-spesifinen)

**Huomautukset**:
- Sisältää yhä täydet transaktiotiedot lohkon rakentamiseen
- Poolipalvelimet käyttävät koordinoituun louhintaan

**Esimerkki**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Toteutus**: `src/rpc/mining.cpp`

---

## Poistetut RPC:t

Seuraavat PoW-spesifiset RPC:t ovat **poistettu** PoCX-tilassa:

### getnetworkhashps
- **Syy**: Hash-nopeus ei sovellu Proof of Capacityyn
- **Vaihtoehto**: Käytä `getdifficulty`-komentoa verkon kapasiteetin arvioon

### getmininginfo
- **Syy**: Palauttaa PoW-spesifistä tietoa
- **Vaihtoehto**: Käytä `get_mining_info`-komentoa (PoCX-spesifinen)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Syy**: Prosessorilouhinta ei sovellu PoCX:ään (vaatii esigeneroidut plotit)
- **Vaihtoehto**: Käytä ulkoista plotteria + louhijaa + `submit_nonce`

**Toteutus**: `src/rpc/mining.cpp` (RPC:t palauttavat virheen kun ENABLE_POCX määritelty)

---

## Integraatioesimerkit

### Ulkoisen louhijan integraatio

**Peruslouhintasilmukka**:
```python
import requests
import time

RPC_URL = "http://käyttäjä:salasana@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Louhintasilmukka
while True:
    # 1. Hae louhintaparametrit
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skannaa plottitiedostot (ulkoinen toteutus)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Lähetä paras ratkaisu
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Ratkaisu hyväksytty! Laatu: {result['quality']}s, "
              f"Forging-aika: {result['poc_time']}s")

    # 4. Odota seuraavaa lohkoa
    time.sleep(10)  # Kyselyväli
```

---

### Pooli-integraatiomalli

**Poolipalvelimen työnkulku**:
1. Louhijat luovat forging-delegointeja poolin osoitteelle
2. Pooli ajaa lompakkoa forging-osoitteen avaimilla
3. Pooli kutsuu `get_mining_info` ja jakaa louhijoille
4. Louhijat lähettävät ratkaisuja poolin kautta (ei suoraan ketjuun)
5. Pooli validoi ja kutsuu `submit_nonce` poolin avaimilla
6. Pooli jakaa palkkiot poolin käytännön mukaan

**Delegointien hallinta**:
```bash
# Louhija luo delegoinnin (louhijan lompakosta)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Odota aktivointia (30 lohkoa mainnetissä)

# Pooli tarkistaa delegoinnin tilan
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pooli voi nyt lähettää nonceja tälle plotille
# (poolin lompakolla on oltava pocx1qpool... yksityinen avain)
```

---

### Lohkoselainkyselyt

**PoCX-lohkodatan kysely**:
```bash
# Hae viimeisin lohko
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Hae lohkon tiedot PoCX-todisteen kanssa
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Poimi PoCX-spesifiset kentät
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

**Delegointitransaktioiden tunnistus**:
```bash
# Skannaa transaktiosta OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Tarkista delegointimerkki (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Virheiden käsittely

### Yleiset virhemallit

**Korkeusero**:
```json
{
  "accepted": false,
  "error": "Korkeusero: lähetetty 12345, nykyinen 12346"
}
```
**Ratkaisu**: Hae louhintatiedot uudelleen, ketju eteni

**Generoinnin allekirjoitusero**:
```json
{
  "accepted": false,
  "error": "Generoinnin allekirjoitus ei täsmää"
}
```
**Ratkaisu**: Hae louhintatiedot uudelleen, uusi lohko saapui

**Ei yksityistä avainta**:
```json
{
  "code": -5,
  "message": "Ei yksityistä avainta tehokkaalle allekirjoittajalle"
}
```
**Ratkaisu**: Tuo avain plotin tai forging-osoitteelle

**Delegoinnin aktivointi odottaa**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Ratkaisu**: Odota aktivointiviiveen täyttymistä

---

## Koodiviittaukset

**Louhinnan RPC:t**: `src/pocx/rpc/mining.cpp`
**Delegointi-RPC:t**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Lohkoketju-RPC:t**: `src/rpc/blockchain.cpp`
**Todisteen validointi**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Delegointitila**: `src/pocx/assignments/assignment_state.cpp`
**Transaktion luonti**: `src/pocx/assignments/transactions.cpp`

---

## Ristiviittaukset

Liittyvät luvut:
- [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md) - Louhintaprosessin yksityiskohdat
- [Luku 4: Forging-delegoinnit](4-forging-assignments.md) - Delegointijärjestelmän arkkitehtuuri
- [Luku 6: Verkkoparametrit](6-network-parameters.md) - Delegoinnin viivearvot
- [Luku 8: Lompakko-opas](8-wallet-guide.md) - GUI delegointien hallintaan

---

[← Edellinen: Verkkoparametrit](6-network-parameters.md) | [Sisällysluettelo](index.md) | [Seuraava: Lompakko-opas →](8-wallet-guide.md)
