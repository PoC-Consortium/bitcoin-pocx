[← Edellinen: RPC-viite](7-rpc-reference.md) | [Sisällysluettelo](index.md)

---

# Luku 8: Lompakko- ja käyttöliittymäopas

Täydellinen opas Bitcoin-PoCX Qt -lompakolle ja forging-delegointien hallinnalle.

---

## Sisällysluettelo

1. [Yleiskatsaus](#yleiskatsaus)
2. [Valuuttayksiköt](#valuuttayksiköt)
3. [Forging-delegointidialogi](#forging-delegointidialogi)
4. [Transaktiohistoria](#transaktiohistoria)
5. [Osoitevaatimukset](#osoitevaatimukset)
6. [Louhintaintegraatio](#louhintaintegraatio)
7. [Vianetsintä](#vianetsintä)
8. [Turvallisuuden parhaat käytännöt](#turvallisuuden-parhaat-käytännöt)

---

## Yleiskatsaus

### Bitcoin-PoCX-lompakon ominaisuudet

Bitcoin-PoCX Qt -lompakko (`bitcoin-qt`) tarjoaa:
- Vakio Bitcoin Core -lompakkotoiminnot (lähetä, vastaanota, transaktioiden hallinta)
- **Forging-delegointien hallinta**: Graafinen käyttöliittymä plottidelegointien luomiseen/peruuttamiseen
- **Louhintapalvelintila**: `-miningserver`-lippu mahdollistaa louhintaan liittyvät ominaisuudet
- **Transaktiohistoria**: Delegointi- ja peruutustransaktioiden näyttö

### Lompakon käynnistäminen

**Vain solmu** (ei louhintaa):
```bash
./build/bin/bitcoin-qt
```

**Louhinnan kanssa** (mahdollistaa delegointidialogin):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Komentoriviltä vaihtoehtoisesti**:
```bash
./build/bin/bitcoind -miningserver
```

### Louhintavaatimukset

**Louhintaoperaatioihin**:
- `-miningserver`-lippu vaadittu
- Lompakko P2WPKH-osoitteilla ja yksityisillä avaimilla
- Ulkoinen plotteri (`pocx_plotter`) plottien generointiin
- Ulkoinen louhija (`pocx_miner`) louhintaan

**Poolilouhintaan**:
- Luo forging-delegointi poolin osoitteelle
- Lompakkoa ei vaadita poolipalvelimella (pooli hallitsee avaimia)

---

## Valuuttayksiköt

### Yksikön näyttö

Bitcoin-PoCX käyttää **BTCX**-valuuttayksikköä (ei BTC):

| Yksikkö | Satoshia | Näyttö |
|------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI-asetukset**: Asetukset → Näyttö → Yksikkö

---

## Forging-delegointidialogi

### Dialogin avaaminen

**Valikko**: `Lompakko → Forging-delegoinnit`
**Työkalupalkki**: Louhintakuvake (näkyvissä vain `-miningserver`-lipulla)
**Ikkunan koko**: 600×450 pikseliä

### Dialogin tilat

#### Tila 1: Luo delegointi

**Tarkoitus**: Delegoi forging-oikeudet poolille tai toiselle osoitteelle säilyttäen plotin omistajuuden.

**Käyttötapaukset**:
- Poolilouhinta (delegoi poolin osoitteelle)
- Kylmäsäilytys (louhinta-avain erillään plotin omistajuudesta)
- Jaettu infrastruktuuri (delegoi hot walletille)

**Vaatimukset**:
- Plotin osoite (P2WPKH bech32, on omistettava yksityinen avain)
- Forging-osoite (P2WPKH bech32, eri kuin plotin osoite)
- Lompakko avattu (jos salattu)
- Plotin osoitteella on vahvistettuja UTXO:ita

**Vaiheet**:
1. Valitse "Luo delegointi" -tila
2. Valitse plotin osoite pudotusvalikosta tai syötä manuaalisesti
3. Syötä forging-osoite (pooli tai delegoitu)
4. Napsauta "Lähetä delegointi" (painike käytössä kun syötteet kelvollisia)
5. Transaktio lähetetään välittömästi
6. Delegointi aktiivinen `nForgingAssignmentDelay`-lohkojen jälkeen:
   - Mainnet/Testnet: 30 lohkoa (~1 tunti)
   - Regtest: 4 lohkoa (~4 sekuntia)

**Transaktiomaksu**: Oletus 10× `minRelayFee` (muokattavissa)

**Transaktiorakenne**:
- Syöte: UTXO plotin osoitteesta (todistaa omistajuuden)
- OP_RETURN-tuloste: `POCX`-merkki + plot_address + forging_address (46 tavua)
- Vaihtorahatuloste: Palautetaan lompakkoon

#### Tila 2: Peruuta delegointi

**Tarkoitus**: Peruuta forging-delegointi ja palauta oikeudet plotin omistajalle.

**Vaatimukset**:
- Plotin osoite (on omistettava yksityinen avain)
- Lompakko avattu (jos salattu)
- Plotin osoitteella on vahvistettuja UTXO:ita

**Vaiheet**:
1. Valitse "Peruuta delegointi" -tila
2. Valitse plotin osoite
3. Napsauta "Lähetä peruutus"
4. Transaktio lähetetään välittömästi
5. Peruutus voimassa `nForgingRevocationDelay`-lohkojen jälkeen:
   - Mainnet/Testnet: 720 lohkoa (~24 tuntia)
   - Regtest: 8 lohkoa (~8 sekuntia)

**Vaikutus**:
- Forging-osoite voi yhä forgata viivejakson ajan
- Plotin omistaja saa oikeudet takaisin peruutuksen valmistuttua
- Voi luoda uuden delegoinnin sen jälkeen

**Transaktiorakenne**:
- Syöte: UTXO plotin osoitteesta (todistaa omistajuuden)
- OP_RETURN-tuloste: `XCOP`-merkki + plot_address (26 tavua)
- Vaihtorahatuloste: Palautetaan lompakkoon

#### Tila 3: Tarkista delegoinnin tila

**Tarkoitus**: Kysele nykyinen delegointitila mille tahansa plotin osoitteelle.

**Vaatimukset**: Ei mitään (vain luku, ei vaadi lompakkoa)

**Vaiheet**:
1. Valitse "Tarkista delegoinnin tila" -tila
2. Syötä plotin osoite
3. Napsauta "Tarkista tila"
4. Tilaruutu näyttää nykyisen tilan yksityiskohtineen

**Tilaindikaattorit** (värikoodattu):

**Harmaa - UNASSIGNED**
```
UNASSIGNED - Ei delegointia
```

**Oranssi - ASSIGNING**
```
ASSIGNING - Delegointi odottaa aktivointia
Forging-osoite: pocx1qforger...
Luotu korkeudessa: 12000
Aktivoituu korkeudessa: 12030 (5 lohkoa jäljellä)
```

**Vihreä - ASSIGNED**
```
ASSIGNED - Aktiivinen delegointi
Forging-osoite: pocx1qforger...
Luotu korkeudessa: 12000
Aktivoitunut korkeudessa: 12030
```

**Punaoranssi - REVOKING**
```
REVOKING - Peruutus odottaa
Forging-osoite: pocx1qforger... (yhä aktiivinen)
Delegointi luotu korkeudessa: 12000
Peruutettu korkeudessa: 12300
Peruutus voimassa korkeudessa: 13020 (50 lohkoa jäljellä)
```

**Punainen - REVOKED**
```
REVOKED - Delegointi peruutettu
Aiemmin delegoitu: pocx1qforger...
Delegointi luotu korkeudessa: 12000
Peruutettu korkeudessa: 12300
Peruutus voimassa korkeudessa: 13020
```

---

## Transaktiohistoria

### Delegointitransaktion näyttö

**Tyyppi**: "Delegointi"
**Kuvake**: Louhintakuvake (sama kuin louhitut lohkot)

**Osoitesarake**: Plotin osoite (osoite jonka forging-oikeudet delegoidaan)
**Määräsarake**: Transaktiomaksu (negatiivinen, lähtevä transaktio)
**Tilasarake**: Vahvistusten määrä (0-6+)

**Yksityiskohdat** (klikatessa):
- Transaktiotunniste
- Plotin osoite
- Forging-osoite (jäsennetty OP_RETURNista)
- Luotu korkeudessa
- Aktivoitumiskorkeus
- Transaktiomaksu
- Aikaleima

### Peruutustransaktion näyttö

**Tyyppi**: "Peruutus"
**Kuvake**: Louhintakuvake

**Osoitesarake**: Plotin osoite
**Määräsarake**: Transaktiomaksu (negatiivinen)
**Tilasarake**: Vahvistusten määrä

**Yksityiskohdat** (klikatessa):
- Transaktiotunniste
- Plotin osoite
- Peruutettu korkeudessa
- Peruutuksen voimaantulokorkeus
- Transaktiomaksu
- Aikaleima

### Transaktioiden suodatus

**Saatavilla olevat suodattimet**:
- "Kaikki" (oletus, sisältää delegoinnit/peruutukset)
- Päivämääräalue
- Määräalue
- Haku osoitteella
- Haku transaktiotunnisteella
- Haku tunnisteella (jos osoite merkitty)

**Huomautus**: Delegointi/peruutus-transaktiot näkyvät tällä hetkellä "Kaikki"-suodattimen alla. Erillistä tyyppisuodatinta ei ole vielä toteutettu.

### Transaktioiden lajittelu

**Lajittelujärjestys** (tyypeittäin):
- Generoitu (tyyppi 0)
- Vastaanotettu (tyyppi 1-3)
- Delegointi (tyyppi 4)
- Peruutus (tyyppi 5)
- Lähetetty (tyyppi 6+)

---

## Osoitevaatimukset

### Vain P2WPKH (SegWit v0)

**Forging-operaatiot vaativat**:
- Bech32-koodatut osoitteet (alkavat "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) -muoto
- 20-tavuinen avaintiiviste

**EI tuettu**:
- P2PKH (vanha, alkaa "1")
- P2SH (kääritty SegWit, alkaa "3")
- P2TR (Taproot, alkaa "bc1p")

**Perustelu**: PoCX-lohkoallekirjoitukset vaativat tietyn witness v0 -muodon todisteen validointia varten.

### Osoitepudotusvalikon suodatus

**Plotin osoite-pudotusvalikko**:
- Täytetään automaattisesti lompakon vastaanotto-osoitteilla
- Suodattaa pois ei-P2WPKH-osoitteet
- Näyttää muodon: "Tunniste (osoite)" jos merkitty, muuten vain osoite
- Ensimmäinen kohde: "-- Syötä mukautettu osoite --" manuaalista syöttöä varten

**Manuaalinen syöttö**:
- Validoi muodon syötettäessä
- On oltava kelvollinen bech32 P2WPKH
- Painike poistetaan käytöstä jos muoto kelvoton

### Validointivirheilmoitukset

**Dialogin virheet**:
- "Plotin osoitteen on oltava P2WPKH (bech32)"
- "Forging-osoitteen on oltava P2WPKH (bech32)"
- "Kelvoton osoitemuoto"
- "Ei kolikoita saatavilla plotin osoitteessa. Omistajuutta ei voida todistaa."
- "Ei voi luoda transaktioita vain seurattavalla lompakolla"
- "Lompakko ei saatavilla"
- "Lompakko lukittu" (RPC:stä)

---

## Louhintaintegraatio

### Asetusten vaatimukset

**Solmun konfiguraatio**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Lompakkovaatimukset**:
- P2WPKH-osoitteet plotin omistajuudelle
- Yksityiset avaimet louhintaan (tai forging-osoitteelle delegoinneilla)
- Vahvistetut UTXO:t transaktioiden luontiin

**Ulkoiset työkalut**:
- `pocx_plotter`: Generoi plottitiedostot
- `pocx_miner`: Skannaa plotit ja lähetä noncet

### Työnkulku

#### Yksinlouhinta

1. **Generoi plottitiedostot**:
   ```bash
   pocx_plotter --account <plotin_osoitteen_hash160> --seed <32_tavua> --nonces <määrä>
   ```

2. **Käynnistä solmu** louhintapalvelimella:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfiguroi louhija**:
   - Osoita solmun RPC-päätepisteeseen
   - Määritä plottitiedostojen hakemistot
   - Konfiguroi tilitunniste (plotin osoitteesta)

4. **Aloita louhinta**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /polku/plotteihin
   ```

5. **Seuraa**:
   - Louhija kutsuu `get_mining_info` joka lohkossa
   - Skannaa plotit parasta deadlinea varten
   - Kutsuu `submit_nonce` kun ratkaisu löytyy
   - Solmu validoi ja forgaa lohkon automaattisesti

#### Poolilouhinta

1. **Generoi plottitiedostot** (sama kuin yksinlouhinta)

2. **Luo forging-delegointi**:
   - Avaa forging-delegointidialogi
   - Valitse plotin osoite
   - Syötä poolin forging-osoite
   - Napsauta "Lähetä delegointi"
   - Odota aktivointiviivettä (30 lohkoa testnetissä)

3. **Konfiguroi louhija**:
   - Osoita **poolin** päätepisteeseen (ei paikalliseen solmuun)
   - Pooli käsittelee `submit_nonce`-kutsun ketjuun

4. **Poolin toiminta**:
   - Poolin lompakolla on forging-osoitteen yksityiset avaimet
   - Pooli validoi lähetykset louhijoilta
   - Pooli kutsuu `submit_nonce` lohkoketjuun
   - Pooli jakaa palkkiot poolin käytännön mukaan

### Coinbase-palkkiot

**Ei delegointia**:
- Coinbase maksaa suoraan plotin omistajan osoitteelle
- Tarkista saldo plotin osoitteesta

**Delegoinnilla**:
- Coinbase maksaa forging-osoitteelle
- Pooli vastaanottaa palkkiot
- Louhija saa osuuden poolilta

**Palkkioaikataulu**:
- Alkuperäinen: 10 BTCX per lohko
- Puolittuminen: Joka 1050000 lohko (~4 vuotta)
- Aikataulu: 10 → 5 → 2.5 → 1.25 → ...

---

## Vianetsintä

### Yleiset ongelmat

#### "Lompakolla ei ole yksityistä avainta plotin osoitteelle"

**Syy**: Lompakko ei omista osoitetta
**Ratkaisu**:
- Tuo yksityinen avain `importprivkey`-RPC:llä
- Tai käytä eri plotin osoitetta jonka lompakko omistaa

#### "Delegointi on jo olemassa tälle plotille"

**Syy**: Plotti jo delegoitu toiselle osoitteelle
**Ratkaisu**:
1. Peruuta olemassa oleva delegointi
2. Odota peruutusviivettä (720 lohkoa testnetissä)
3. Luo uusi delegointi

#### "Osoitemuotoa ei tueta"

**Syy**: Osoite ei ole P2WPKH bech32
**Ratkaisu**:
- Käytä osoitteita jotka alkavat "pocx1q" (mainnet) tai "tpocx1q" (testnet)
- Generoi uusi osoite tarvittaessa: `getnewaddress "" "bech32"`

#### "Transaktiomaksu liian alhainen"

**Syy**: Verkon mempool ruuhkautunut tai maksu liian alhainen välitykseen
**Ratkaisu**:
- Kasvata maksuasteparametria
- Odota mempoolin tyhjentymistä

#### "Delegointi ei vielä aktiivinen"

**Syy**: Aktivointiviive ei ole vielä täyttynyt
**Ratkaisu**:
- Tarkista tila: lohkoja jäljellä aktivointiin
- Odota viivejakson valmistumista

#### "Ei kolikoita saatavilla plotin osoitteessa"

**Syy**: Plotin osoitteella ei ole vahvistettuja UTXO:ita
**Ratkaisu**:
1. Lähetä varoja plotin osoitteeseen
2. Odota 1 vahvistus
3. Yritä delegoinnin luontia uudelleen

#### "Ei voi luoda transaktioita vain seurattavalla lompakolla"

**Syy**: Lompakko tuonut osoitteen ilman yksityistä avainta
**Ratkaisu**: Tuo täysi yksityinen avain, ei pelkkää osoitetta

#### "Forging-delegointivälilehti ei näkyvissä"

**Syy**: Solmu käynnistetty ilman `-miningserver`-lippua
**Ratkaisu**: Käynnistä uudelleen `bitcoin-qt -server -miningserver`

### Vianetsintävaiheet

1. **Tarkista lompakon tila**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Varenna osoitteen omistajuus**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Tarkista: "iswatchonly": false, "ismine": true
   ```

3. **Tarkista delegoinnin tila**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Näytä viimeaikaiset transaktiot**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Tarkista solmun synkronointi**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Varmenna: blocks == headers (täysin synkronoitu)
   ```

---

## Turvallisuuden parhaat käytännöt

### Plotin osoitteen turvallisuus

**Avainten hallinta**:
- Säilytä plotin osoitteen yksityiset avaimet turvallisesti
- Delegointitransaktiot todistavat omistajuuden allekirjoituksella
- Vain plotin omistaja voi luoda/peruuttaa delegointeja

**Varmuuskopiointi**:
- Varmuuskopioi lompakko säännöllisesti (`dumpwallet` tai `backupwallet`)
- Säilytä wallet.dat turvallisessa paikassa
- Tallenna palautusfraasit jos käytät HD-lompakkoa

### Forging-osoitteen delegointi

**Turvallisuusmalli**:
- Forging-osoite vastaanottaa lohkopalkkiot
- Forging-osoite voi allekirjoittaa lohkoja (louhinta)
- Forging-osoite **ei voi** muokata tai peruuttaa delegointia
- Plotin omistaja säilyttää täyden hallinnan

**Käyttötapaukset**:
- **Hot wallet -delegointi**: Plotin avain kylmäsäilytyksessä, forging-avain hot walletissa louhintaa varten
- **Poolilouhinta**: Delegoi poolille, säilytä plotin omistajuus
- **Jaettu infrastruktuuri**: Useita louhijoita, yksi forging-osoite

### Verkon aikasynkronointi

**Merkitys**:
- PoCX-konsensus vaatii tarkan ajan
- Kellodrifti >10s laukaisee varoituksen
- Kellodrifti >15s estää louhinnan

**Ratkaisu**:
- Pidä järjestelmäkello synkronoituna NTP:n kanssa
- Seuraa: `bitcoin-cli getnetworkinfo` aikaerovaroituksia varten
- Käytä luotettavia NTP-palvelimia

### Delegointiviiveet

**Aktivointiviive** (30 lohkoa testnetissä):
- Estää nopean uudelleendelegoinnin ketjuhaarautumien aikana
- Antaa verkon saavuttaa konsensus
- Ei voida ohittaa

**Peruutusviive** (720 lohkoa testnetissä):
- Tarjoaa vakautta louhintapooleille
- Estää delegoinnin "häiriköinti"-hyökkäykset
- Forging-osoite pysyy aktiivisena viiveen ajan

### Lompakon salaus

**Ota salaus käyttöön**:
```bash
bitcoin-cli encryptwallet "sinun_salasanasi"
```

**Avaa transaktioita varten**:
```bash
bitcoin-cli walletpassphrase "sinun_salasanasi" 300
```

**Parhaat käytännöt**:
- Käytä vahvaa salasanaa (20+ merkkiä)
- Älä säilytä salasanaa selkokielellä
- Lukitse lompakko delegointien luomisen jälkeen

---

## Koodiviittaukset

**Forging-delegointidialogi**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaktioiden näyttö**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaktioiden jäsennys**: `src/qt/transactionrecord.cpp`
**Lompakkointegraatio**: `src/pocx/assignments/transactions.cpp`
**Delegointi-RPC:t**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI-pääohjelma**: `src/qt/bitcoingui.cpp`

---

## Ristiviittaukset

Liittyvät luvut:
- [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md) - Louhintaprosessi
- [Luku 4: Forging-delegoinnit](4-forging-assignments.md) - Delegointiarkkitehtuuri
- [Luku 6: Verkkoparametrit](6-network-parameters.md) - Delegointiviiveiden arvot
- [Luku 7: RPC-viite](7-rpc-reference.md) - RPC-komentojen yksityiskohdat

---

[← Edellinen: RPC-viite](7-rpc-reference.md) | [Sisällysluettelo](index.md)
