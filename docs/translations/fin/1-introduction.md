[Sisällysluettelo](index.md) | [Seuraava: Plottimuoto →](2-plot-format.md)

---

# Luku 1: Johdanto ja yleiskatsaus

## Mikä on Bitcoin-PoCX?

Bitcoin-PoCX on Bitcoin Core -integraatio, joka lisää **Proof of Capacity neXt generation (PoCX)** -konsensustuen. Se säilyttää Bitcoin Coren olemassa olevan arkkitehtuurin ja mahdollistaa samalla energiatehokkaan Proof of Capacity -louhinnan täydellisenä korvaajana Proof of Work -konsensukselle.

**Keskeinen erottelu**: Tämä on **uusi ketju** ilman taaksepäin yhteensopivuutta Bitcoin PoW:n kanssa. PoCX-lohkot ovat yhteensopimattomia PoW-solmujen kanssa suunnitellusti.

---

## Projektin identiteetti

- **Organisaatio**: Proof of Capacity Consortium
- **Projektin nimi**: Bitcoin-PoCX
- **Virallinen nimi**: Bitcoin Core with PoCX Integration
- **Tila**: Testiverkkofase

---

## Mikä on Proof of Capacity?

Proof of Capacity (PoC) on konsensusmekanismi, jossa louhintateho on verrannollinen **levytilaan** laskentavoiman sijaan. Louhijat esigeneroivat suuria plottitiedostoja, jotka sisältävät kryptografisia tiivisteitä, ja käyttävät sitten näitä plotteja kelvollisten lohkoratkaisujen löytämiseen.

**Energiatehokkuus**: Plottitiedostot generoidaan kerran ja niitä käytetään uudelleen loputtomasti. Louhinta kuluttaa minimaalisesti prosessoritehoa – pääasiassa levyn I/O:ta.

**PoCX-parannukset**:
- Korjattu XOR-transpose-pakkausshyökkäys (50 % aika–muisti-vaihtokauppa POC2:ssa)
- 16-noncen-tasautettu layout modernille laitteistolle
- Skaalautuva proof-of-work plotin generoinnissa (Xn-skaalaustasot)
- Natiivi C++-integraatio suoraan Bitcoin Coreen
- Time Bending -algoritmi parannetulle lohkoaikajakaumalle

---

## Arkkitehtuurin yleiskatsaus

### Repositorion rakenne

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX-integraatio
│   └── src/pocx/        # PoCX-toteutus
├── pocx/                # PoCX-ydinkehys (alimoduuli, vain luku)
└── docs/                # Tämä dokumentaatio
```

### Integraatiofilosofia

**Minimaalinen integraatiopinta**: Muutokset eristetty `/src/pocx/`-hakemistoon puhtailla liitännöillä Bitcoin Coren validointi-, louhinta- ja RPC-kerroksiin.

**Feature-liputus**: Kaikki muutokset `#ifdef ENABLE_POCX` -esikääntäjän suojauksella. Bitcoin Core rakentuu normaalisti kun ominaisuus on poissa käytöstä.

**Upstream-yhteensopivuus**: Säännöllinen synkronointi Bitcoin Core -päivitysten kanssa ylläpidetään eristettyjen integraatiopisteiden kautta.

**Natiivi C++-toteutus**: Skalaarit kryptografiset algoritmit (Shabal256, scoop-laskenta, pakkaus) integroitu suoraan Bitcoin Coreen konsensusvalidointia varten.

---

## Keskeiset ominaisuudet

### 1. Täydellinen konsensuksen korvaaminen

- **Lohkorakenne**: PoCX-spesifiset kentät korvaavat PoW:n noncen ja vaikeusbittien
  - Generointiallekirjoitus (deterministinen louhintaentropia)
  - Perustavoite (vaikeuden käänteisluku)
  - PoCX-todiste (tilitunniste, seed, nonce)
  - Lohkoallekirjoitus (todistaa plotin omistajuuden)

- **Validointi**: 5-vaiheinen validointiputki otsikon tarkistuksesta lohkon liittämiseen

- **Vaikeuden säätö**: Jokaisessa lohkossa säätö käyttäen viimeaikaisten perustavoitteiden liukuvaa keskiarvoa

### 2. Time Bending -algoritmi

**Ongelma**: Perinteinen PoC-lohkoaika noudattaa eksponentiaalijakaumaa, mikä johtaa pitkiin lohkoihin kun kukaan louhija ei löydä hyvää ratkaisua.

**Ratkaisu**: Jakauman muunnos eksponentiaalisesta khii-neliö-jakaumaksi kuutiojuuren avulla: `Y = skaala × (X^(1/3))`.

**Vaikutus**: Erittäin hyvät ratkaisut forgataan myöhemmin (verkolla on aikaa skannata kaikki levyt, vähentää nopeita lohkoja), huonot ratkaisut parannetaan. Keskimääräinen lohkoaika säilyy 120 sekunnissa, pitkät lohkot vähenevät.

**Lisätiedot**: [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md)

### 3. Forging-delegointijärjestelmä

**Ominaisuus**: Plotin omistajat voivat delegoida forging-oikeudet muille osoitteille säilyttäen plotin omistajuuden.

**Käyttötapaukset**:
- Poolilouhinta (plotit delegoidaan poolin osoitteelle)
- Kylmäsäilytys (louhintaavain erillään plotin omistajuudesta)
- Monen osapuolen louhinta (jaettu infrastruktuuri)

**Arkkitehtuuri**: Vain OP_RETURN -pohjainen suunnittelu – ei erityisiä UTXO:ita, delegoinnit seurataan erikseen chainstate-tietokannassa.

**Lisätiedot**: [Luku 4: Forging-delegoinnit](4-forging-assignments.md)

### 4. Puolustava forging

**Ongelma**: Nopeat kellot voisivat tarjota ajoitusetua 15 sekunnin tulevaisuustoleranssin puitteissa.

**Ratkaisu**: Kun vastaanotetaan kilpaileva lohko samalla korkeudella, tarkista automaattisesti paikallinen laatu. Jos parempi, forgaa välittömästi.

**Vaikutus**: Poistaa kannustimet kellon manipuloinnille – nopeat kellot auttavat vain jos sinulla on jo paras ratkaisu.

**Lisätiedot**: [Luku 5: Aikasynkronointi ja turvallisuus](5-timing-security.md)

### 5. Dynaaminen pakkausskaalaus

**Taloudellinen yhdenmukaistaminen**: Skaalaustason vaatimukset kasvavat eksponentiaalisella aikataululla (vuodet 4, 12, 28, 60, 124 = puolittamiset 1, 3, 7, 15, 31).

**Vaikutus**: Kun lohkopalkkiot pienenevät, plotin generoinnin vaikeus kasvaa. Ylläpitää turvamarginaalia plotin luomis- ja hakukustannusten välillä.

**Estää**: Kapasiteetti-inflaation nopeammasta laitteistosta ajan myötä.

**Lisätiedot**: [Luku 6: Verkkoparametrit](6-network-parameters.md)

---

## Suunnittelufilosofia

### Kooditurvallisuus

- Puolustava ohjelmointikäytäntö läpi koodin
- Kattava virheenkäsittely validointipoluissa
- Ei sisäkkäisiä lukkoja (deadlock-esto)
- Atomiset tietokantaoperaatiot (UTXO + delegoinnit yhdessä)

### Modulaarinen arkkitehtuuri

- Puhdas erottelu Bitcoin Core -infrastruktuurin ja PoCX-konsensuksen välillä
- PoCX-ydinkehys tarjoaa kryptografiset primitiivit
- Bitcoin Core tarjoaa validointikehyksen, tietokannan, verkostoinnin

### Suorituskykyoptimioinnit

- Nopean epäonnistumisen validointijärjestys (halvat tarkistukset ensin)
- Yksi kontekstihaku lähetystä kohti (ei toistuvia cs_main-hankintoja)
- Atomiset tietokantaoperaatiot yhdenmukaisuuden takaamiseksi

### Uudelleenjärjestelyturvallisuus

- Täydelliset kumoamistiedot delegointitilan muutoksille
- Forging-tilan nollaus ketjun kärjen muuttuessa
- Vanhentumisen tunnistus kaikissa validointipisteissä

---

## Miten PoCX eroaa Proof of Workista

| Näkökulma | Bitcoin (PoW) | Bitcoin-PoCX |
|-----------|---------------|--------------|
| **Louhinnan resurssi** | Laskentateho (hash-nopeus) | Levytila (kapasiteetti) |
| **Energiankulutus** | Korkea (jatkuva tiivistäminen) | Matala (vain levyn I/O) |
| **Louhintaprosessi** | Etsi nonce jolla hash < tavoite | Etsi nonce jolla deadline < kulunut aika |
| **Vaikeus** | `bits`-kenttä, säädetään 2016 lohkon välein | `base_target`-kenttä, säädetään jokaisessa lohkossa |
| **Lohkoaika** | ~10 minuuttia (eksponentiaalijakauma) | 120 sekuntia (aikataivutettu, pienempi varianssi) |
| **Palkkio** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Laitteisto** | ASIC:t (erikoistunut) | HDD:t (tavallinen laitteisto) |
| **Louhinnan identiteetti** | Anonyymi | Plotin omistaja tai delegoitu |

---

## Järjestelmävaatimukset

### Solmun käyttö

**Samat kuin Bitcoin Corella**:
- **Prosessori**: Moderni x86_64-prosessori
- **Muisti**: 4-8 GB RAM
- **Tallennustila**: Uusi ketju, tällä hetkellä tyhjä (voi kasvaa ~4× nopeammin kuin Bitcoin 2 minuutin lohkojen ja delegointitietokannan vuoksi)
- **Verkko**: Vakaa internet-yhteys
- **Kello**: NTP-synkronointi suositeltava optimaaliseen toimintaan

**Huomautus**: Plottitiedostoja EI vaadita solmun käyttöön.

### Louhintavaatimukset

**Lisävaatimukset louhintaan**:
- **Plottitiedostot**: Esigeneroitu `pocx_plotter`-ohjelmalla (viitetoteutus)
- **Louhintaohjelmisto**: `pocx_miner` (viitetoteutus) yhdistyy RPC:n kautta
- **Lompakko**: `bitcoind` tai `bitcoin-qt` yksityisillä avaimilla louhintaosoitteelle. Poolilouhinta ei vaadi paikallista lompakkoa.

---

## Käytön aloitus

### 1. Rakenna Bitcoin-PoCX

```bash
# Kloonaa alimoduuleineen
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Rakenna PoCX käytössä
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Lisätiedot**: Katso `CLAUDE.md` repositorion juurihakemistossa

### 2. Käynnistä solmu

**Vain solmu**:
```bash
./build/bin/bitcoind
# tai
./build/bin/bitcoin-qt
```

**Louhintaa varten** (sallii RPC-pääsyn ulkoisille louhijoille):
```bash
./build/bin/bitcoind -miningserver
# tai
./build/bin/bitcoin-qt -server -miningserver
```

**Lisätiedot**: [Luku 6: Verkkoparametrit](6-network-parameters.md)

### 3. Generoi plottitiedostot

Käytä `pocx_plotter`-ohjelmaa (viitetoteutus) PoCX-muotoisten plottitiedostojen generointiin.

**Lisätiedot**: [Luku 2: Plottimuoto](2-plot-format.md)

### 4. Aseta louhinta

Käytä `pocx_miner`-ohjelmaa (viitetoteutus) yhdistyäksesi solmusi RPC-rajapintaan.

**Lisätiedot**: [Luku 7: RPC-viite](7-rpc-reference.md) ja [Luku 8: Lompakko-opas](8-wallet-guide.md)

---

## Attribuutio

### Plottimuoto

Perustuu POC2-muotoon (Burstcoin) parannuksineen:
- Korjattu tietoturvaongelma (XOR-transpose-pakkausshyökkäys)
- Skaalautuva proof-of-work
- SIMD-optimoitu layout
- Seed-toiminnallisuus

### Lähdeprojektit

- **pocx_miner**: Viitetoteutus perustuu [scavenger](https://github.com/PoC-Consortium/scavenger)-projektiin
- **pocx_plotter**: Viitetoteutus perustuu [engraver](https://github.com/PoC-Consortium/engraver)-projektiin

**Täydellinen attribuutio**: [Luku 2: Plottimuoto](2-plot-format.md)

---

## Teknisten määrittelyjen yhteenveto

- **Lohkoaika**: 120 sekuntia (mainnet), 1 sekunti (regtest)
- **Lohkopalkkio**: 10 BTC aluksi, puolittuen 1050000 lohkon välein (~4 vuotta)
- **Kokonaistarjonta**: ~21 miljoonaa BTC (sama kuin Bitcoin)
- **Tulevaisuustoleranssi**: 15 sekuntia (enintään 15s tulevaisuudessa olevat lohkot hyväksytään)
- **Kellovaroitus**: 10 sekuntia (varoittaa operaattoreita aikadriftistä)
- **Delegoinnin viive**: 30 lohkoa (~1 tunti)
- **Peruutuksen viive**: 720 lohkoa (~24 tuntia)
- **Osoitemuoto**: P2WPKH (bech32, pocx1q...) vain PoCX-louhintaoperaatioille ja forging-delegoinneille

---

## Koodin organisointi

**Bitcoin Core -muutokset**: Minimaaliset muutokset ydintiedostoihin, feature-liputettu `#ifdef ENABLE_POCX`:lla

**Uusi PoCX-toteutus**: Eristetty `src/pocx/`-hakemistoon

---

## Turvallisuusnäkökohdat

### Ajoitusturvallisuus

- 15 sekunnin tulevaisuustoleranssi estää verkon fragmentoitumisen
- 10 sekunnin varoituskynnys varoittaa operaattoreita kellodriftistä
- Puolustava forging poistaa kannustimet kellon manipuloinnille
- Time Bending vähentää ajoitusvaihtelun vaikutusta

**Lisätiedot**: [Luku 5: Aikasynkronointi ja turvallisuus](5-timing-security.md)

### Delegointien turvallisuus

- Vain OP_RETURN -pohjainen suunnittelu (ei UTXO-manipulointia)
- Transaktion allekirjoitus todistaa plotin omistajuuden
- Aktivointiviiveet estävät nopean tilan manipuloinnin
- Uudelleenjärjestelyturvallinen kumoamisdata kaikille tilan muutoksille

**Lisätiedot**: [Luku 4: Forging-delegoinnit](4-forging-assignments.md)

### Konsensuksen turvallisuus

- Allekirjoitus poissuljettu lohkon tiivisteestä (estää muunneltavuuden)
- Rajoitetut allekirjoituskoot (estää DoS:n)
- Pakkausrajojen validointi (estää heikot todisteet)
- Jokaisessa lohkossa vaikeuden säätö (reagoi kapasiteetin muutoksiin)

**Lisätiedot**: [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md)

---

## Verkon tila

**Mainnet**: Ei vielä käynnistetty
**Testnet**: Saatavilla testaukseen
**Regtest**: Täysin toimiva kehitykseen

**Genesis-lohkon parametrit**: [Luku 6: Verkkoparametrit](6-network-parameters.md)

---

## Seuraavat vaiheet

**PoCX:n ymmärtämiseksi**: Jatka [Lukuun 2: Plottimuoto](2-plot-format.md) oppiaksesi plottitiedoston rakenteesta ja muodon kehityksestä.

**Louhinnan aloittamiseksi**: Siirry [Lukuun 7: RPC-viite](7-rpc-reference.md) integraation yksityiskohtia varten.

**Solmun käyttöön**: Tutustu [Lukuun 6: Verkkoparametrit](6-network-parameters.md) konfiguraatiovaihtoehtoja varten.

---

[Sisällysluettelo](index.md) | [Seuraava: Plottimuoto →](2-plot-format.md)
