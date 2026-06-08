[← Ankstesnis: RPC informacija](7-rpc-reference.md) | [📘 Turinys](index.md)

---

# 8 skyrius: Piniginės ir GUI naudotojo vadovas

Išsamus Bitcoin-PoCX Qt piniginės ir kalimo priskyrimo valdymo vadovas.

---

## Turinys

1. [Apžvalga](#apžvalga)
2. [Valiutos vienetai](#valiutos-vienetai)
3. [Kalimo priskyrimo dialogas](#kalimo-priskyrimo-dialogas)
4. [Transakcijų istorija](#transakcijų-istorija)
5. [Adreso reikalavimai](#adreso-reikalavimai)
6. [Kasimo integracija](#kasimo-integracija)
7. [Trikčių šalinimas](#trikčių-šalinimas)
8. [Saugumo geriausia praktika](#saugumo-geriausia-praktika)

---

## Apžvalga

### Bitcoin-PoCX piniginės funkcijos

Bitcoin-PoCX Qt piniginė (`bitcoin-qt`) teikia:
- Standartines Bitcoin Core piniginės funkcijas (siųsti, gauti, transakcijų valdymas)
- **Kalimo priskyrimo valdytojas**: GUI priskyrimų kūrimui/atšaukimui
- **Kasimo serverio režimas**: `` vėliavė įjungia su kasimu susijusias funkcijas
- **Transakcijų istorija**: Priskyrimo ir atšaukimo transakcijų rodymas

### Piniginės paleidimas

**Tik mazgas** (be kasimo):
```bash
./build/bin/bitcoin-qt
```

**Su kasimu** (įjungia priskyrimo dialogą):
```bash
./build/bin/bitcoin-qt -server
```

**Komandų eilutės alternatyva**:
```bash
./build/bin/bitcoind
```

### Kasimo reikalavimai

**Kasimo operacijoms**:
- `` vėliavė reikalinga
- Piniginė su P2WPKH adresais ir privačiais raktais
- Išorinis grafikų kūrėjas (`pocx_plotter`) grafikų generavimui
- Išorinis kasėjas (`pocx_miner`) kasimui

**Baseino kasimui**:
- Sukurti kalimo priskyrimą baseino adresui
- Piniginė nereikalinga baseino serveryje (baseinas valdo raktus)

---

## Valiutos vienetai

### Vieneto rodymas

Bitcoin-PoCX naudoja **BTCX** valiutos vienetą (ne BTC):

| Vienetas | Satoshi | Rodymas |
|----------|---------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI nustatymai**: Nuostatos → Rodymas → Vienetas

---

## Kalimo priskyrimo dialogas

### Prieiga prie dialogo

**Toolbar Tab**: Mining icon in the main toolbar (visible when compiled with `ENABLE_POCX=ON`)
**Lango dydis**: 600×450 pikselių

### Dialogo režimai

#### 1 režimas: Sukurti priskyrimą

**Paskirtis**: Deleguoti kalimo teises baseinui ar kitam adresui, išlaikant grafiko nuosavybę.

**Naudojimo atvejai**:
- Baseino kasimas (priskirti baseino adresui)
- Šaltoji saugykla (kasimo raktas atskirtas nuo grafiko nuosavybės)
- Bendra infrastruktūra (deleguoti karštai piniginei)

**Reikalavimai**:
- Grafiko adresas (P2WPKH bech32, turi turėti privatų raktą)
- Kalimo adresas (P2WPKH bech32, skirtingas nuo grafiko adreso)
- Piniginė atrakinta (jei užšifruota)
- Grafiko adresas turi patvirtintų UTXO

**Žingsniai**:
1. Pasirinkite "Sukurti priskyrimą" režimą
2. Pasirinkite grafiko adresą iš išskleidžiamojo sąrašo arba įveskite rankiniu būdu
3. Įveskite kalimo adresą (baseino arba įgaliotinio)
4. Spustelėkite "Siųsti priskyrimą" (mygtukas įjungtas kai įvestys galiojančios)
5. Transakcija transliuojama iš karto
6. Priskyrimas aktyvus po `nForgingAssignmentDelay` blokų:
   - Pagrindinis tinklas/Testinis tinklas: 30 blokų (~1 valanda)
   - Regtest: 4 blokai (~8 minučių esant 120s intervalui)

**Transakcijos mokestis**: Numatytas 10× `minRelayFee` (konfigūruojamas)

**Transakcijos struktūra**:
- Įvestis: UTXO iš grafiko adreso (įrodo nuosavybę)
- OP_RETURN išvestis (46 baitų scenarijus, 44 baitų duomenų naudingoji apkrova): `POCX` žymeklis + grafiko_adresas + kalimo_adresas
- Grąžos išvestis: Grąžinama į piniginę

#### 2 režimas: Atšaukti priskyrimą

**Paskirtis**: Atšaukti kalimo priskyrimą ir grąžinti teises grafiko savininkui.

**Reikalavimai**:
- Grafiko adresas (turi turėti privatų raktą)
- Piniginė atrakinta (jei užšifruota)
- Grafiko adresas turi patvirtintų UTXO

**Žingsniai**:
1. Pasirinkite "Atšaukti priskyrimą" režimą
2. Pasirinkite grafiko adresą
3. Spustelėkite "Siųsti atšaukimą"
4. Transakcija transliuojama iš karto
5. Atšaukimas įsigalioja po `nForgingRevocationDelay` blokų:
   - Pagrindinis tinklas/Testinis tinklas: 720 blokų (~24 valandos)
   - Regtest: 8 blokai (~16 minučių esant 120s intervalui)

**Poveikis**:
- Kalimo adresas vis dar gali kalti atidėjimo periodo metu
- Grafiko savininkas atgauna teises po atšaukimo užbaigimo
- Gali sukurti naują priskyrimą vėliau

**Transakcijos struktūra**:
- Įvestis: UTXO iš grafiko adreso (įrodo nuosavybę)
- OP_RETURN išvestis (26 baitų scenarijus, 24 baitų duomenų naudingoji apkrova): `XCOP` žymeklis + grafiko_adresas
- Grąžos išvestis: Grąžinama į piniginę

#### 3 režimas: Tikrinti priskyrimo būseną

**Paskirtis**: Užklausti dabartinę priskyrimo būseną bet kuriam grafiko adresui.

**Reikalavimai**: Nėra (tik skaitymas, piniginė nereikalinga)

**Žingsniai**:
1. Pasirinkite "Tikrinti priskyrimo būseną" režimą
2. Įveskite grafiko adresą
3. Spustelėkite "Tikrinti būseną"
4. Būsenos laukelis rodo dabartinę būseną su detalėmis

**Būsenos indikatoriai** (spalviniai):

**Pilka - UNASSIGNED**
```
UNASSIGNED - Nėra priskyrimo
```

**Oranžinė - ASSIGNING**
```
ASSIGNING - Priskyrimas laukia aktyvacijos
Kalimo adresas: pocx1qforger...
Sukurtas aukštyje: 12000
Aktyvuojasi aukštyje: 12030 (5 blokai liko)
```

**Žalia - ASSIGNED**
```
ASSIGNED - Aktyvus priskyrimas
Kalimo adresas: pocx1qforger...
Sukurtas aukštyje: 12000
Aktyvuotas aukštyje: 12030
```

**Raudona-oranžinė - REVOKING**
```
REVOKING - Atšaukimas laukia
Kalimo adresas: pocx1qforger... (vis dar aktyvus)
Priskyrimas sukurtas aukštyje: 12000
Atšauktas aukštyje: 12300
Atšaukimas įsigalioja aukštyje: 13020 (50 blokų liko)
```

**Raudona - REVOKED**
```
REVOKED - Priskyrimas atšauktas
Anksčiau priskirtas: pocx1qforger...
Priskyrimas sukurtas aukštyje: 12000
Atšauktas aukštyje: 12300
Atšaukimas įsigaliojo aukštyje: 13020
```

---

## Transakcijų istorija

### Priskyrimo transakcijos rodymas

**Tipas**: "Priskyrimas"
**Piktograma**: Kasimo piktograma (ta pati kaip iškastų blokų)

**Adreso stulpelis**: Grafiko adresas (adreso, kurio kalimo teisės priskiriamos)
**Sumos stulpelis**: Transakcijos mokestis (neigiamas, išeinanti transakcija)
**Būsenos stulpelis**: Patvirtinimų skaičius (0-6+)

**Detalės** (spustelėjus):
- Transakcijos ID
- Grafiko adresas
- Kalimo adresas (išanalizuotas iš OP_RETURN)
- Sukurtas aukštyje
- Aktyvacijos aukštis
- Transakcijos mokestis
- Laiko žymė

### Atšaukimo transakcijos rodymas

**Tipas**: "Atšaukimas"
**Piktograma**: Kasimo piktograma

**Adreso stulpelis**: Grafiko adresas
**Sumos stulpelis**: Transakcijos mokestis (neigiamas)
**Būsenos stulpelis**: Patvirtinimų skaičius

**Detalės** (spustelėjus):
- Transakcijos ID
- Grafiko adresas
- Atšauktas aukštyje
- Atšaukimo įsigaliojimo aukštis
- Transakcijos mokestis
- Laiko žymė

### Transakcijų filtravimas

**Prieinami filtrai**:
- "Visi" (numatytas, apima priskyrimus/atšaukimus)
- Datų intervalas
- Sumos intervalas
- Paieška pagal adresą
- Paieška pagal transakcijos ID
- Paieška pagal etiketę (jei adresas pažymėtas)

**Pastaba**: Priskyrimo/Atšaukimo transakcijos šiuo metu rodomos "Visi" filtru. Dedikuotas tipo filtras dar neįgyvendintas.

### Transakcijų rikiavimas

**Rikiavimo tvarka** (pagal tipą):
- Sugeneruota (tipas 0)
- Gauta (tipas 1-3)
- Priskyrimas (tipas 4)
- Atšaukimas (tipas 5)
- Išsiųsta (tipas 6+)

---

## Adreso reikalavimai

### Tik P2WPKH (SegWit v0)

**Kalimo operacijoms reikia**:
- Bech32 koduotų adresų (prasidedančių "pocx1q" pagrindiniame tinkle, "tpocx1q" testiniame tinkle, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) formato
- 20 baitų rakto maišos

**NEPALAIKOMA**:
- P2PKH (palikimas, prasidedantis "1")
- P2SH (supakuotas SegWit, prasidedantis "3")
- P2TR (Taproot, prasidedantis "bc1p")

**Pagrindimas**: PoCX bloko parašams reikalingas specifinis witness v0 formatas įrodymo validacijai.

### Adreso išskleidžiamojo sąrašo filtravimas

**Grafiko adreso ComboBox**:
- Automatiškai užpildomas piniginės gavimo adresais
- Išfiltruoja ne-P2WPKH adresus
- Rodo formatą: "Etiketė (adresas)" jei pažymėtas, kitaip tik adresas
- Pirmas elementas: "-- Įvesti pasirinktinį adresą --" rankiniam įvedimui

**Rankinis įvedimas**:
- Validuoja formatą kai įvedama
- Turi būti galiojantis bech32 P2WPKH
- Mygtukas išjungtas jei neteisingas formatas

### Validacijos klaidų pranešimai

**Dialogo klaidos**:
- "Plot address must be segwit v0 (bech32)"
- Invalid forging address silently disables the Send button
- "Neteisingas adreso formatas"
- "Nėra monetų grafiko adrese. Negalima įrodyti nuosavybės."
- "Negalima sukurti transakcijų su tik stebėjimo pinigine"
- "Piniginė nepasiekiama"
- "Piniginė užrakinta" (iš RPC)

---

## Kasimo integracija

### Nustatymo reikalavimai

**Mazgo konfigūracija**:
```bash
# bitcoin.conf
server=1
```

**Piniginės reikalavimai**:
- P2WPKH adresai grafiko nuosavybei
- Privatūs raktai kasimui (arba kalimo adreso jei naudojami priskyrimai)
- Patvirtinti UTXO transakcijų kūrimui

**Išoriniai įrankiai**:
- `pocx_plotter`: Generuoti grafiko failus
- `pocx_miner`: Nuskaityti grafikus ir pateikti nonces

### Darbo eiga

#### Solo kasimas

1. **Generuoti grafiko failus**:
   ```bash
   pocx_plotter --account <grafiko_adreso_hash160> --seed <32_baitai> --nonces <kiekis>
   ```

2. **Paleisti mazgą** su kasimo serveriu:
   ```bash
   bitcoin-qt -server
   ```

3. **Konfigūruoti kasėją**:
   - Nurodyti mazgo RPC galą
   - Nurodyti grafiko failų katalogus
   - Konfigūruoti paskyros ID (iš grafiko adreso)

4. **Pradėti kasimą**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /kelias/iki/grafikų
   ```

5. **Stebėti**:
   - Kasėjas kviečia `get_mining_info` kiekviename bloke
   - Nuskaito grafikus geriausiam terminui
   - Kviečia `submit_nonce` kai rastas sprendimas
   - Mazgas validuoja ir nukala bloką automatiškai

#### Baseino kasimas

1. **Generuoti grafiko failus** (kaip solo kasime)

2. **Sukurti kalimo priskyrimą**:
   - Atidaryti kalimo priskyrimo dialogą
   - Pasirinkti grafiko adresą
   - Įvesti baseino kalimo adresą
   - Spustelėti "Siųsti priskyrimą"
   - Laukti aktyvacijos atidėjimo (30 blokų testiniame tinkle)

3. **Konfigūruoti kasėją**:
   - Nurodyti **baseino** galą (ne lokalaus mazgo)
   - Baseinas tvarko `submit_nonce` į grandinę

4. **Baseino veikimas**:
   - Baseino piniginė turi kalimo adreso privačius raktus
   - Baseinas validuoja pateikimus iš kasėjų
   - Baseinas kviečia `submit_nonce` į blockchain
   - Baseinas paskirsto atlygius pagal baseino politiką

### Coinbase atlygiai

**Be priskyrimo**:
- Coinbase moka tiesiai grafiko savininko adresui
- Tikrinti balansą grafiko adrese

**Su priskyrimu**:
- Coinbase moka kalimo adresui
- Baseinas gauna atlygius
- Kasėjas gauna dalį iš baseino

**Atlygio grafikas**:
- Pradinis: 10 BTCX už bloką
- Pusė: Kas 1050000 blokų (~4 metai)
- Grafikas: 10 → 5 → 2.5 → 1.25 → ...

---

## Trikčių šalinimas

### Dažnos problemos

#### "Piniginė neturi privataus rakto grafiko adresui"

**Priežastis**: Piniginė nevaldo adreso
**Sprendimas**:
- Importuoti privatų raktą per `importprivkey` RPC
- Arba naudoti kitą grafiko adresą, valdomą piniginės

#### "Cannot create assignment: plot is in ... state"

**Cause**: Plot is not in UNASSIGNED or REVOKED state
**Solution**:
1. Revoke existing assignment
2. Wait for revocation delay (720 blocks mainnet/testnet, 8 blocks regtest)
3. Create new assignment

#### "Adreso formatas nepalaikomas"

**Priežastis**: Adresas ne P2WPKH bech32
**Sprendimas**:
- Naudoti adresus prasidedančius "pocx1q" (pagrindinis tinklas) arba "tpocx1q" (testinis tinklas)
- Generuoti naują adresą jei reikia: `getnewaddress "" "bech32"`

#### "Transakcijos mokestis per mažas"

**Priežastis**: Tinklo mempool perpildymas arba mokestis per mažas perdavimui
**Sprendimas**:
- Padidinti mokesčio dažnio parametrą
- Laukti mempool išsivalymo

#### "Priskyrimas dar neaktyvus"

**Priežastis**: Aktyvacijos atidėjimas dar nepraėjęs
**Sprendimas**:
- Tikrinti būseną: blokai liko iki aktyvacijos
- Laukti kol praeis atidėjimo periodas

#### "Nėra monetų grafiko adrese"

**Priežastis**: Grafiko adresas neturi patvirtintų UTXO
**Sprendimas**:
1. Siųsti lėšas į grafiko adresą
2. Laukti 1 patvirtinimo
3. Bandyti priskyrimo kūrimą iš naujo

#### "Negalima sukurti transakcijų su tik stebėjimo pinigine"

**Priežastis**: Piniginė importavo adresą be privataus rakto
**Sprendimas**: Importuoti pilną privatų raktą, ne tik adresą

### Derinimo žingsniai

1. **Tikrinti piniginės būseną**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Patikrinti adreso nuosavybę**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Tikrinti: "iswatchonly": false, "ismine": true
   ```

3. **Tikrinti priskyrimo būseną**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Peržiūrėti paskutines transakcijas**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Tikrinti mazgo sinchronizaciją**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Patikrinti: blocks == headers (pilnai sinchronizuotas)
   ```

---

## Saugumo geriausia praktika

### Grafiko adreso saugumas

**Raktų valdymas**:
- Saugoti grafiko adreso privačius raktus saugiai
- Priskyrimo transakcijos įrodo nuosavybę parašu
- Tik grafiko savininkas gali kurti/atšaukti priskyrimus

**Atsarginė kopija**:
- Reguliariai kurti piniginės atsarginę kopiją (`dumpwallet` arba `backupwallet`)
- Saugoti wallet.dat saugioje vietoje
- Užsirašyti atkūrimo frazes jei naudojama HD piniginė

### Kalimo adreso delegavimas

**Saugumo modelis**:
- Kalimo adresas gauna bloko atlygius
- Kalimo adresas gali pasirašyti blokus (kasimas)
- Kalimo adresas **NEGALI** modifikuoti ar atšaukti priskyrimo
- Grafiko savininkas išlaiko pilną kontrolę

**Naudojimo atvejai**:
- **Karštos piniginės delegavimas**: Grafiko raktas šaltoje saugykloje, kalimo raktas karštoje piniginėje kasimui
- **Baseino kasimas**: Deleguoti baseinui, išlaikyti grafiko nuosavybę
- **Bendra infrastruktūra**: Keli kasėjai, vienas kalimo adresas

### Tinklo laiko sinchronizacija

**Svarba**:
- PoCX konsensusas reikalauja tikslaus laiko
- Laikrodžio nuokrypis >10s sukelia įspėjimą
- Laikrodžio nuokrypis >15s neleidžia kasti

**Sprendimas**:
- Laikyti sistemos laikrodį sinchronizuotą su NTP
- Stebėti: `bitcoin-cli getnetworkinfo` laiko poslinkio įspėjimams
- Naudoti patikimus NTP serverius

### Priskyrimo atidėjimai

**Aktyvacijos atidėjimas** (30 blokų testiniame tinkle):
- Apsaugo nuo greito perpriskyrimo grandinės šakų metu
- Leidžia tinklui pasiekti konsensusą
- Negalima apeiti

**Atšaukimo atidėjimas** (720 blokų testiniame tinkle):
- Teikia stabilumą kasimo baseinams
- Apsaugo nuo priskyrimo "grieferinimo" atakų
- Kalimo adresas lieka aktyvus atidėjimo metu

### Piniginės šifravimas

**Įjungti šifravimą**:
```bash
bitcoin-cli encryptwallet "jūsų_slaptafrazė"
```

**Atrakinti transakcijoms**:
```bash
bitcoin-cli walletpassphrase "jūsų_slaptafrazė" 300
```

**Geriausia praktika**:
- Naudoti stiprią slaptafrazę (20+ simbolių)
- Nesaugoti slaptafrazės paprastu tekstu
- Užrakinti piniginę sukūrus priskyrimus

---

## Kodo nuorodos

**Kalimo priskyrimo dialogas**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transakcijos rodymas**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transakcijos analizė**: `src/qt/transactionrecord.cpp`
**Piniginės integracija**: `src/pocx/assignments/transactions.cpp`
**Priskyrimo RPC**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI pagrindinis**: `src/qt/bitcoingui.cpp`

---

## Kryžminės nuorodos

Susiję skyriai:
- [3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md) - Kasimo procesas
- [4 skyrius: Kalimo priskyrimai](4-forging-assignments.md) - Priskyrimo architektūra
- [6 skyrius: Tinklo parametrai](6-network-parameters.md) - Priskyrimo atidėjimo reikšmės
- [7 skyrius: RPC informacija](7-rpc-reference.md) - RPC komandų detalės

---

[← Ankstesnis: RPC informacija](7-rpc-reference.md) | [📘 Turinys](index.md)
