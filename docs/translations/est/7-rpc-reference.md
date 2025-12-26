[<- Eelmine: Võrguparameetrid](6-network-parameters.md) | [Sisukord](index.md) | [Järgmine: Rahakoti juhend ->](8-wallet-guide.md)

---

# Peatükk 7: RPC liidese viide

Täielik viide Bitcoin-PoCX RPC käskudele, sealhulgas kaevandamise RPC-d, ülesannete haldamine ja muudetud plokiahela RPC-d.

---

## Sisukord

1. [Konfiguratsioon](#konfiguratsioon)
2. [PoCX kaevandamise RPC-d](#pocx-kaevandamise-rpcd)
3. [Ülesannete RPC-d](#ülesannete-rpcd)
4. [Muudetud plokiahela RPC-d](#muudetud-plokiahela-rpcd)
5. [Keelatud RPC-d](#keelatud-rpcd)
6. [Integratsiooni näited](#integratsiooni-näited)

---

## Konfiguratsioon

### Kaevandamisserveri režiim

**Lipp**: `-miningserver`

**Eesmärk**: Lubab RPC juurdepääsu välistele kaevandajatele kaevandamisspetsiifiliste RPC-de kutsumiseks

**Nõuded**:
- Vajalik `submit_nonce` toimimiseks
- Vajalik sepistamisülesannete dialoogi nähtavuseks Qt rahakotis

**Kasutamine**:
```bash
# Käsurida
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Turvaküsimused**:
- Pole täiendavat autentimist peale standardsete RPC volituste
- Kaevandamise RPC-d on kiiruspiiranguga järjekorra mahtuvuse järgi
- Standardne RPC autentimine on endiselt vajalik

**Implementatsioon**: `src/pocx/rpc/mining.cpp`

---

## PoCX kaevandamise RPC-d

### get_mining_info

**Kategooria**: mining
**Nõuab kaevandamisserverit**: Ei
**Nõuab rahakotti**: Ei

**Eesmärk**: Tagastab praegused kaevandamisparameetrid, mida välised kaevandajad vajavad graafikufailide skaneerimiseks ja tähtaegade arvutamiseks.

**Parameetrid**: Puuduvad

**Tagastatavad väärtused**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 tähemärki
  "base_target": 36650387593,                // numbriline
  "height": 12345,                           // numbriline, järgmise ploki kõrgus
  "block_hash": "def456...",                 // hex, eelmine plokk
  "target_quality": 18446744073709551615,    // uint64_max (kõik lahendused aktsepteeritakse)
  "minimum_compression_level": 1,            // numbriline
  "target_compression_level": 2              // numbriline
}
```

**Väljade kirjeldused**:
- `generation_signature`: Deterministiline kaevandamise entroopia selle ploki kõrguse jaoks
- `base_target`: Praegune raskus (kõrgem = lihtsam)
- `height`: Ploki kõrgus, mida kaevandajad peaksid sihtima
- `block_hash`: Eelmise ploki räsi (informatsiooniline)
- `target_quality`: Kvaliteedi lävi (praegu uint64_max, filtreerimist pole)
- `minimum_compression_level`: Minimaalne kompressioon, mis on valideerimiseks vajalik
- `target_compression_level`: Soovitatav kompressioon optimaalseks kaevandamiseks

**Veakoodid**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Sõlm endiselt sünkroniseerub

**Näide**:
```bash
bitcoin-cli get_mining_info
```

**Implementatsioon**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategooria**: mining
**Nõuab kaevandamisserverit**: Jah
**Nõuab rahakotti**: Jah (privaatvõtmete jaoks)

**Eesmärk**: Esita PoCX kaevandamise lahendus. Valideerib tõestuse, seab järjekorda ajapaindega sepistamiseks ja loob automaatselt ploki planeeritud ajal.

**Parameetrid**:
1. `height` (numbriline, nõutud) - Ploki kõrgus
2. `generation_signature` (string hex, nõutud) - Genereerimisallkiri (64 tähemärki)
3. `account_id` (string, nõutud) - Graafiku konto ID (40 hex tähemärki = 20 baiti)
4. `seed` (string, nõutud) - Graafiku seeme (64 hex tähemärki = 32 baiti)
5. `nonce` (numbriline, nõutud) - Kaevandamise nonce
6. `compression` (numbriline, nõutud) - Kasutatud skaleerimis/kompressiooni tase (1-255)
7. `quality` (numbriline, valikuline) - Kvaliteediväärtus (arvutatakse ümber, kui puudub)

**Tagastatavad väärtused** (õnnestumine):
```json
{
  "accepted": true,
  "quality": 120,           // raskusega kohandatud tähtaeg sekundites
  "poc_time": 45            // ajapaindega sepistamisaeg sekundites
}
```

**Tagastatavad väärtused** (tagasilükkamine):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Valideerimise sammud**:
1. **Vormingu valideerimine** (kiire ebaõnnestumine):
   - Account ID: täpselt 40 hex tähemärki
   - Seed: täpselt 64 hex tähemärki
2. **Konteksti valideerimine**:
   - Kõrgus peab vastama praegusele tipule + 1
   - Genereerimisallkiri peab vastama praegusele
3. **Rahakoti verifitseerimine**:
   - Määra efektiivne allkirjastaja (kontrolli aktiivseid ülesandeid)
   - Verifitseeri, et rahakotis on privaatvõti efektiivse allkirjastaja jaoks
4. **Tõestuse valideerimine** (kulukas):
   - Valideeri PoCX tõestus kompressiooni piiridega
   - Arvuta töötlemata kvaliteet
5. **Planeerijale esitamine**:
   - Sea nonce järjekorda ajapaindega sepistamiseks
   - Plokk luuakse automaatselt forge_time'il

**Veakoodid**:
- `RPC_INVALID_PARAMETER`: Kehtetu vorming (account_id, seed) või kõrguse mittevastavus
- `RPC_VERIFY_REJECTED`: Genereerimisallkirja mittevastavus või tõestuse valideerimine ebaõnnestus
- `RPC_INVALID_ADDRESS_OR_KEY`: Pole privaatvõtit efektiivse allkirjastaja jaoks
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Esitamise järjekord täis
- `RPC_INTERNAL_ERROR`: PoCX planeerija initsialiseerimine ebaõnnestus

**Tõestuse valideerimise veakoodid**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Näide**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "graafiku_seeme_64_hex_tähemärki..." \
  999888777 \
  1
```

**Märkused**:
- Esitamine on asünkroonne - RPC tagastab kohe, plokk sepistatakse hiljem
- Ajapainde viivitab häid lahendusi, et võimaldada kogu võrgus graafikute skaneerimist
- Ülesannete süsteem: kui graafik on määratud, peab rahakotis olema sepistamise aadressi võti
- Kompressiooni piirid kohandatakse dünaamiliselt ploki kõrguse põhjal

**Implementatsioon**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Ülesannete RPC-d

### get_assignment

**Kategooria**: mining
**Nõuab kaevandamisserverit**: Ei
**Nõuab rahakotti**: Ei

**Eesmärk**: Päri sepistamisülesande staatust graafiku aadressi jaoks. Ainult lugemiseks, rahakotti pole vaja.

**Parameetrid**:
1. `plot_address` (string, nõutud) - Graafiku aadress (bech32 P2WPKH vorming)
2. `height` (numbriline, valikuline) - Ploki kõrgus päringute tegemiseks (vaikimisi: praegune tipp)

**Tagastatavad väärtused** (ülesannet pole):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Tagastatavad väärtused** (aktiivne ülesanne):
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

**Tagastatavad väärtused** (tühistamisel):
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

**Ülesannete olekud**:
- `UNASSIGNED`: Ülesannet pole
- `ASSIGNING`: Ülesande tx kinnitatud, aktiveerimise viivitus käib
- `ASSIGNED`: Ülesanne aktiivne, sepistamisõigused delegeeritud
- `REVOKING`: Tühistamise tx kinnitatud, endiselt aktiivne kuni viivitus möödub
- `REVOKED`: Tühistamine lõppenud, sepistamisõigused tagastatud graafikuomanikule

**Veakoodid**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Kehtetu aadress või mitte P2WPKH (bech32)

**Näide**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementatsioon**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategooria**: wallet
**Nõuab kaevandamisserverit**: Ei
**Nõuab rahakotti**: Jah (peab olema laetud ja lukustamata)

**Eesmärk**: Loo sepistamisülesande tehing, et delegeerida sepistamisõigused teisele aadressile (nt kaevandamisbasseinile).

**Parameetrid**:
1. `plot_address` (string, nõutud) - Graafikuomaniku aadress (peab omama privaatvõtit, P2WPKH bech32)
2. `forging_address` (string, nõutud) - Aadress, millele sepistamisõigused määrata (P2WPKH bech32)
3. `fee_rate` (numbriline, valikuline) - Tasumäär BTC/kvB (vaikimisi: 10× minRelayFee)

**Tagastatavad väärtused**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Nõuded**:
- Rahakott laetud ja lukustamata
- Privaatvõti plot_address jaoks rahakotis
- Mõlemad aadressid peavad olema P2WPKH (bech32 vorming: pocx1q... mainnet, tpocx1q... testnet)
- Graafiku aadressil peavad olema kinnitatud UTXO-d (tõestab omandi)
- Graafikul ei tohi olla aktiivset ülesannet (kasuta esmalt tühistamist)

**Tehingu struktuur**:
- Sisend: UTXO graafiku aadressilt (tõestab omandi)
- Väljund: OP_RETURN (46 baiti): `POCX` marker + plot_address (20 baiti) + forging_address (20 baiti)
- Väljund: Vahetus tagastatud rahakotti

**Aktiveerimine**:
- Ülesanne saab ASSIGNING oleku kinnitamisel
- Saab ACTIVE oleku pärast `nForgingAssignmentDelay` plokki
- Viivitus takistab kiiret ümberseadistamist ahela hargnemisel

**Veakoodid**:
- `RPC_WALLET_NOT_FOUND`: Rahakott pole saadaval
- `RPC_WALLET_UNLOCK_NEEDED`: Rahakott krüpteeritud ja lukustatud
- `RPC_WALLET_ERROR`: Tehingu loomine ebaõnnestus
- `RPC_INVALID_ADDRESS_OR_KEY`: Kehtetu aadressi vorming

**Näide**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementatsioon**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategooria**: wallet
**Nõuab kaevandamisserverit**: Ei
**Nõuab rahakotti**: Jah (peab olema laetud ja lukustamata)

**Eesmärk**: Tühista olemasolev sepistamisülesanne, tagastades sepistamisõigused graafikuomanikule.

**Parameetrid**:
1. `plot_address` (string, nõutud) - Graafiku aadress (peab omama privaatvõtit, P2WPKH bech32)
2. `fee_rate` (numbriline, valikuline) - Tasumäär BTC/kvB (vaikimisi: 10× minRelayFee)

**Tagastatavad väärtused**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Nõuded**:
- Rahakott laetud ja lukustamata
- Privaatvõti plot_address jaoks rahakotis
- Graafiku aadress peab olema P2WPKH (bech32 vorming)
- Graafiku aadressil peavad olema kinnitatud UTXO-d

**Tehingu struktuur**:
- Sisend: UTXO graafiku aadressilt (tõestab omandi)
- Väljund: OP_RETURN (26 baiti): `XCOP` marker + plot_address (20 baiti)
- Väljund: Vahetus tagastatud rahakotti

**Tulemus**:
- Olek läheb kohe üle REVOKING-ile
- Sepistamise aadress saab endiselt sepistada viivitusperioodi jooksul
- Saab REVOKED oleku pärast `nForgingRevocationDelay` plokki
- Graafikuomanik saab sepistada pärast tühistamise jõustumist
- Saab luua uue ülesande pärast tühistamise lõppu

**Veakoodid**:
- `RPC_WALLET_NOT_FOUND`: Rahakott pole saadaval
- `RPC_WALLET_UNLOCK_NEEDED`: Rahakott krüpteeritud ja lukustatud
- `RPC_WALLET_ERROR`: Tehingu loomine ebaõnnestus

**Näide**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Märkused**:
- Idempotentne: saab tühistada isegi kui aktiivset ülesannet pole
- Tühistamist ei saa pärast esitamist enam tühistada

**Implementatsioon**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Muudetud plokiahela RPC-d

### getdifficulty

**PoCX modifikatsioonid**:
- **Arvutamine**: `viite_baassihtmärk / praegune_baassihtmärk`
- **Viide**: 1 TiB võrgu maht (base_target = 36650387593)
- **Tõlgendus**: Hinnanguline võrgu hoiustusmaht TiB-s
  - Näide: `1.0` = ~1 TiB
  - Näide: `1024.0` = ~1 PiB
- **Erinevus PoW-st**: Esindab mahtu, mitte räsivõimsust

**Näide**:
```bash
bitcoin-cli getdifficulty
# Tagastab: 2048.5 (võrk ~2 PiB)
```

**Implementatsioon**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX lisatud väljad**:
- `time_since_last_block` (numbriline) - Sekundeid eelmisest plokist (asendab mediantime)
- `poc_time` (numbriline) - Ajapaindega sepistamisaeg sekundites
- `base_target` (numbriline) - PoCX raskuse baassihtmärk
- `generation_signature` (string hex) - Genereerimisallkiri
- `pocx_proof` (objekt):
  - `account_id` (string hex) - Graafiku konto ID (20 baiti)
  - `seed` (string hex) - Graafiku seeme (32 baiti)
  - `nonce` (numbriline) - Kaevandamise nonce
  - `compression` (numbriline) - Kasutatud skaleerimistase
  - `quality` (numbriline) - Väidetud kvaliteediväärtus
- `pubkey` (string hex) - Ploki allkirjastaja avalik võti (33 baiti)
- `signer_address` (string) - Ploki allkirjastaja aadress
- `signature` (string hex) - Ploki allkiri (65 baiti)

**PoCX eemaldatud väljad**:
- `mediantime` - Eemaldatud (asendatud time_since_last_block-ga)

**Näide**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementatsioon**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX modifikatsioonid**: Sama mis getblockheader, pluss täielikud tehinguandmed

**Näide**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # sõnakas tx detailidega
```

**Implementatsioon**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX lisatud väljad**:
- `base_target` (numbriline) - Praegune baassihtmärk
- `generation_signature` (string hex) - Praegune genereerimisallkiri

**PoCX muudetud väljad**:
- `difficulty` - Kasutab PoCX arvutamist (mahupõhine)

**PoCX eemaldatud väljad**:
- `mediantime` - Eemaldatud

**Näide**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementatsioon**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX lisatud väljad**:
- `generation_signature` (string hex) - Basseinikaevandamiseks
- `base_target` (numbriline) - Basseinikaevandamiseks

**PoCX eemaldatud väljad**:
- `target` - Eemaldatud (PoW-spetsiifiline)
- `noncerange` - Eemaldatud (PoW-spetsiifiline)
- `bits` - Eemaldatud (PoW-spetsiifiline)

**Märkused**:
- Sisaldab endiselt täielikke tehinguandmeid ploki ehitamiseks
- Kasutatakse basseiniserverite poolt koordineeritud kaevandamiseks

**Näide**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementatsioon**: `src/rpc/mining.cpp`

---

## Keelatud RPC-d

Järgmised PoW-spetsiifilised RPC-d on PoCX režiimis **keelatud**:

### getnetworkhashps
- **Põhjus**: Räsimäär ei ole mahtutõestusele kohaldatav
- **Alternatiiv**: Kasuta `getdifficulty` võrgu mahu hinnangu saamiseks

### getmininginfo
- **Põhjus**: Tagastab PoW-spetsiifilist informatsiooni
- **Alternatiiv**: Kasuta `get_mining_info` (PoCX-spetsiifiline)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Põhjus**: CPU kaevandamine pole PoCX-le kohaldatav (nõuab eelgenereeritud graafikuid)
- **Alternatiiv**: Kasuta välist graafikukoostajat + kaevandajat + `submit_nonce`

**Implementatsioon**: `src/rpc/mining.cpp` (RPC-d tagastavad vea, kui ENABLE_POCX on defineeritud)

---

## Integratsiooni näited

### Välise kaevandaja integratsioon

**Põhiline kaevandamistsükkel**:
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

# Kaevandamistsükkel
while True:
    # 1. Hangi kaevandamisparameetrid
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skaneeri graafikufaile (väline implementatsioon)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Esita parim lahendus
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Lahendus aktsepteeritud! Kvaliteet: {result['quality']}s, "
              f"Sepistamisaeg: {result['poc_time']}s")

    # 4. Oota järgmist plokki
    time.sleep(10)  # Pollimise intervall
```

---

### Basseini integratsiooni muster

**Basseiniserveri töövoog**:
1. Kaevandajad loovad sepistamisülesanded basseini aadressile
2. Bassein käitab rahakotti sepistamise aadressi võtmetega
3. Bassein kutsub `get_mining_info` ja jagab kaevandajatele
4. Kaevandajad esitavad lahendused läbi basseini (mitte otse ahelale)
5. Bassein valideerib ja kutsub `submit_nonce` basseini võtmetega
6. Bassein jagab tasud vastavalt basseini poliitikale

**Ülesannete haldamine**:
```bash
# Kaevandaja loob ülesande (kaevandaja rahakotist)
bitcoin-cli create_assignment "pocx1qkaevandaja_graafik..." "pocx1qbassein..."

# Oota aktiveerimist (30 plokki mainnet)

# Bassein kontrollib ülesande staatust
bitcoin-cli get_assignment "pocx1qkaevandaja_graafik..."

# Bassein saab nüüd esitada nonce'e selle graafiku eest
# (basseini rahakotis peab olema pocx1qbassein... privaatvõti)
```

---

### Plokiuurija päringud

**PoCX ploki andmete pärimine**:
```bash
# Hangi viimane plokk
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Hangi ploki detailid koos PoCX tõestusega
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Ekstrakteeri PoCX-spetsiifilised väljad
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

**Ülesande tehingute tuvastamine**:
```bash
# Skaneeri tehingut OP_RETURN jaoks
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Kontrolli ülesande markerit (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Vigade käsitlemine

### Levinud veamustrid

**Kõrguse mittevastavus**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Lahendus**: Hangi kaevandusteave uuesti, ahel liikus edasi

**Genereerimisallkirja mittevastavus**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Lahendus**: Hangi kaevandusteave uuesti, uus plokk saabus

**Privaatvõtit pole**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Lahendus**: Impordi võti graafiku või sepistamise aadressi jaoks

**Ülesande aktiveerimine ootel**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Lahendus**: Oota, kuni aktiveerimise viivitus möödub

---

## Koodi viited

**Kaevandamise RPC-d**: `src/pocx/rpc/mining.cpp`
**Ülesannete RPC-d**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Plokiahela RPC-d**: `src/rpc/blockchain.cpp`
**Tõestuse valideerimine**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Ülesande olek**: `src/pocx/assignments/assignment_state.cpp`
**Tehingu loomine**: `src/pocx/assignments/transactions.cpp`

---

## Ristviited

Seotud peatükid:
- [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md) - Kaevandamisprotsessi detailid
- [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md) - Ülesannete süsteemi arhitektuur
- [Peatükk 6: Võrguparameetrid](6-network-parameters.md) - Ülesannete viivituse väärtused
- [Peatükk 8: Rahakoti juhend](8-wallet-guide.md) - GUI ülesannete haldamiseks

---

[<- Eelmine: Võrguparameetrid](6-network-parameters.md) | [Sisukord](index.md) | [Järgmine: Rahakoti juhend ->](8-wallet-guide.md)
