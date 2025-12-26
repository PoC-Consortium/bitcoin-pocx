[Sisukord](index.md) | [Järgmine: Graafikuvorming ->](2-plot-format.md)

---

# Peatükk 1: Sissejuhatus ja ülevaade

## Mis on Bitcoin-PoCX?

Bitcoin-PoCX on Bitcoin Core'i integratsioon, mis lisab **uue põlvkonna mahtutõestuse (Proof of Capacity neXt generation, PoCX)** konsensuse toe. See säilitab Bitcoin Core'i olemasoleva arhitektuuri, võimaldades samal ajal energiasäästlikku mahtutõestuse kaevandamist täieliku asendusena tööst tuletatud tõestusele (Proof of Work).

**Põhiline erinevus**: See on **uus ahel** ilma tagasiühilduvuseta Bitcoin PoW-ga. PoCX plokid on disaini järgi ühildumatud PoW sõlmedega.

---

## Projekti identiteet

- **Organisatsioon**: Proof of Capacity Consortium
- **Projekti nimi**: Bitcoin-PoCX
- **Täisnimi**: Bitcoin Core PoCX integratsiooniga
- **Staatus**: Testivõrgu faas

---

## Mis on mahtutõestus?

Mahtutõestus (Proof of Capacity, PoC) on konsensusmehhanism, kus kaevandamisvõimsus on proportsionaalne **kettaruumiga**, mitte arvutusvõimsusega. Kaevandajad genereerivad eelnevalt suuri graafikufaile, mis sisaldavad krüptograafilisi räsisid, seejärel kasutavad neid graafikuid kehtivate plokilahenduste leidmiseks.

**Energiatõhusus**: Graafikufailid genereeritakse üks kord ja neid kasutatakse määramata ajani. Kaevandamine tarbib minimaalset protsessorivõimsust - peamiselt ketta sisend/väljund operatsioone.

**PoCX täiustused**:
- Parandatud XOR-transponeeri kompressiooni rünnak (50% aja-mälu kompromiss POC2-s)
- 16-nonce-joondatud paigutus kaasaegsele riistvarale
- Skaleeritav tööst tuletatud tõestus graafikugenereerimisel (Xn skaleerimistasemed)
- Natiivne C++ integratsioon otse Bitcoin Core'i
- Ajapainde algoritm paremaks plokkide aja jaotuseks

---

## Arhitektuuri ülevaade

### Hoidla struktuur

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX integratsioon
│   └── src/pocx/        # PoCX implementatsioon
├── pocx/                # PoCX põhiraamistik (alamoodul, ainult lugemiseks)
└── docs/                # See dokumentatsioon
```

### Integratsiooni filosoofia

**Minimaalne integratsioonipind**: Muudatused on isoleeritud `/src/pocx/` kataloogis puhaste haakidega Bitcoin Core'i valideerimis-, kaevandamis- ja RPC kihtidesse.

**Funktsiooni lipud**: Kõik modifikatsioonid on `#ifdef ENABLE_POCX` eelprotsessori kaitsete all. Bitcoin Core kompileerub normaalselt, kui see on keelatud.

**Ülesvoolu ühilduvus**: Regulaarne sünkroniseerimine Bitcoin Core'i uuendustega säilitatakse läbi isoleeritud integratsioonipunktide.

**Natiivne C++ implementatsioon**: Skalaarsed krüptograafilised algoritmid (Shabal256, scoop arvutamine, kompressioon) on integreeritud otse Bitcoin Core'i konsensuse valideerimiseks.

---

## Põhifunktsioonid

### 1. Täielik konsensuse asendamine

- **Ploki struktuur**: PoCX-spetsiifilised väljad asendavad PoW nonce'i ja raskusbitte
  - Genereerimisallkiri (deterministiline kaevandamise entroopia)
  - Baassihtmärk (raskuse pöördväärtus)
  - PoCX tõestus (konto ID, seeme, nonce)
  - Ploki allkiri (tõestab graafikuomanikku)

- **Valideerimine**: 5-astmeline valideerimise töövoog päise kontrollist ploki ühendamiseni

- **Raskuse kohandamine**: Kohandamine igal plokil, kasutades hiljutiste baassihtmärkide libisevat keskmist

### 2. Ajapainde algoritm

**Probleem**: Traditsioonilised PoC plokkide ajad järgivad eksponentsiaalset jaotust, mis viib pikkade plokkideni, kui ükski kaevandaja ei leia head lahendust.

**Lahendus**: Jaotuse teisendamine eksponentsiaalsest hii-ruut jaotuseks kuupjuurega: `Y = skaala × (X^(1/3))`.

**Tulemus**: Väga head lahendused sepistavad hiljem (võrgul on aega kõiki kettaid skaneerida, vähendab kiireid plokke), kehvad lahendused paranevad. Keskmine plokkide aeg säilitatakse 120 sekundil, pikad plokid vähenevad.

**Detailid**: [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md)

### 3. Sepistamisülesannete süsteem

**Võimekus**: Graafikuomanikud saavad delegeerida sepistamisõigused teistele aadressidele, säilitades samal ajal graafikuomandi.

**Kasutusjuhud**:
- Basseinikaevandamine (graafikud määratakse basseini aadressile)
- Külm hoiustamine (kaevandamisvõti eraldi graafikuomandist)
- Mitme osapoolega kaevandamine (jagatud infrastruktuur)

**Arhitektuur**: OP_RETURN-ainult disain - pole erilisi UTXO-sid, ülesandeid jälgitakse eraldi chainstate andmebaasis.

**Detailid**: [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md)

### 4. Kaitsev sepistamine

**Probleem**: Kiired kellad võivad anda ajastuse eelise 15-sekundilise tuleviku tolerantsi piires.

**Lahendus**: Konkureeriva ploki saamisel samal kõrgusel kontrolli automaatselt kohalikku kvaliteeti. Kui parem, sepista kohe.

**Tulemus**: Elimineerib kellamanipuleerimise stiimuli - kiired kellad aitavad ainult siis, kui sul juba on parim lahendus.

**Detailid**: [Peatükk 5: Ajastuse turvalisus](5-timing-security.md)

### 5. Dünaamiline kompressiooni skaleerimine

**Majanduslik joondamine**: Skaleerimistaseme nõuded suurenevad eksponentsiaalsel graafikus (Aastad 4, 12, 28, 60, 124 = poolnemised 1, 3, 7, 15, 31).

**Tulemus**: Kui plokkide tasud vähenevad, graafikugenereerimise raskus suureneb. Säilitab ohutuspiiri graafikukoostamise ja otsimise kulude vahel.

**Takistab**: Mahtude inflatsiooni kiirema riistvara tõttu aja jooksul.

**Detailid**: [Peatükk 6: Võrguparameetrid](6-network-parameters.md)

---

## Disainifilosoofia

### Koodi turvalisus

- Kaitsvad programmeerimispraktikad läbivalt
- Põhjalik vigade käsitlemine valideerimisteedel
- Pole pesastatud lukke (deadlock'i ennetamine)
- Aatomilised andmebaasi operatsioonid (UTXO + ülesanded koos)

### Modulaarne arhitektuur

- Puhas eraldatus Bitcoin Core'i infrastruktuuri ja PoCX konsensuse vahel
- PoCX põhiraamistik pakub krüptograafilisi primitiive
- Bitcoin Core pakub valideerimise raamistikku, andmebaasi, võrgu

### Jõudluse optimeerimised

- Kiire ebaõnnestumine valideerimise järjestuses (odavad kontrollid esimesena)
- Üks konteksti hankimine esitamise kohta (pole korduvaid cs_main haaramisi)
- Aatomilised andmebaasi operatsioonid järjepidevuse tagamiseks

### Ümberkorralduste ohutus

- Täielikud tagasivõtmise andmed ülesannete olekumuutusteks
- Sepistamise oleku lähtestamine ahela tipu muutustel
- Aegumise tuvastamine kõigis valideerimispunktides

---

## Kuidas PoCX erineb tööst tuletatud tõestusest

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Kaevandamisressurss** | Arvutusvõimsus (räsimäär) | Kettaruum (maht) |
| **Energiatarbimine** | Kõrge (pidev räsimine) | Madal (ainult ketta I/O) |
| **Kaevandamisprotsess** | Leia nonce räsiga < sihtmärk | Leia nonce tähtajaga < möödunud aeg |
| **Raskus** | `bits` väli, kohandatakse iga 2016 ploki järel | `base_target` väli, kohandatakse igal plokil |
| **Plokkide aeg** | ~10 minutit (eksponentsiaalne jaotus) | 120 sekundit (ajapaindega, vähendatud varieeruvus) |
| **Subsiidium** | 50 BTC -> 25 -> 12.5 -> ... | 10 BTC -> 5 -> 2.5 -> ... |
| **Riistvara** | ASIC-id (spetsialiseeritud) | HDD-d (tavapärane riistvara) |
| **Kaevandamise identiteet** | Anonüümne | Graafikuomanik või delegaat |

---

## Süsteeminõuded

### Sõlme opereerimine

**Sama mis Bitcoin Core'il**:
- **Protsessor**: Kaasaegne x86_64 protsessor
- **Mälu**: 4-8 GB RAM
- **Hoiustamine**: Uus ahel, praegu tühi (võib kasvada ~4× kiiremini kui Bitcoin 2-minutiliste plokkide ja ülesannete andmebaasi tõttu)
- **Võrk**: Stabiilne internetiühendus
- **Kell**: NTP sünkroniseerimine soovitatav optimaalseks tööks

**Märkus**: Graafikufailid EI ole sõlme opereerimiseks vajalikud.

### Kaevandamise nõuded

**Täiendavad nõuded kaevandamiseks**:
- **Graafikufailid**: Eelgenereeritud kasutades `pocx_plotter` (referentsimplementatsioon)
- **Kaevandamistarkvara**: `pocx_miner` (referentsimplementatsioon) ühendub RPC kaudu
- **Rahakott**: `bitcoind` või `bitcoin-qt` privaatvõtmetega kaevandamise aadressi jaoks. Basseinikaevandamine ei nõua kohalikku rahakotti.

---

## Alustamine

### 1. Kompileeri Bitcoin-PoCX

```bash
# Klooni koos alamoodulitega
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Kompileeri PoCX lubamisega
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detailid**: Vaata `CLAUDE.md` hoidla juurkataloogis

### 2. Käivita sõlm

**Ainult sõlm**:
```bash
./build/bin/bitcoind
# või
./build/bin/bitcoin-qt
```

**Kaevandamiseks** (lubab RPC juurdepääsu välistele kaevandajatele):
```bash
./build/bin/bitcoind -miningserver
# või
./build/bin/bitcoin-qt -server -miningserver
```

**Detailid**: [Peatükk 6: Võrguparameetrid](6-network-parameters.md)

### 3. Genereeri graafikufailid

Kasuta `pocx_plotter` (referentsimplementatsioon) PoCX-vormingus graafikufailide genereerimiseks.

**Detailid**: [Peatükk 2: Graafikuvorming](2-plot-format.md)

### 4. Seadista kaevandamine

Kasuta `pocx_miner` (referentsimplementatsioon), et ühenduda sinu sõlme RPC liidesega.

**Detailid**: [Peatükk 7: RPC viide](7-rpc-reference.md) ja [Peatükk 8: Rahakoti juhend](8-wallet-guide.md)

---

## Omistamine

### Graafikuvorming

Põhineb POC2 vormingul (Burstcoin) täiustustega:
- Parandatud turvaviga (XOR-transponeeri kompressiooni rünnak)
- Skaleeritav tööst tuletatud tõestus
- SIMD-optimeeritud paigutus
- Seemefunktsioon

### Lähteprojectid

- **pocx_miner**: Referentsimplementatsioon põhineb [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referentsimplementatsioon põhineb [engraver](https://github.com/PoC-Consortium/engraver)

**Täielik omistamine**: [Peatükk 2: Graafikuvorming](2-plot-format.md)

---

## Tehniliste spetsifikatsioonide kokkuvõte

- **Plokkide aeg**: 120 sekundit (mainnet), 1 sekund (regtest)
- **Ploki subsiidium**: 10 BTC algne, poolnemine iga 1050000 ploki järel (~4 aastat)
- **Kogumaht**: ~21 miljonit BTC (sama mis Bitcoinil)
- **Tuleviku tolerants**: 15 sekundit (plokid kuni 15s ees aktsepteeritakse)
- **Kella hoiatus**: 10 sekundit (hoiatab operaatoreid ajanihkest)
- **Ülesande viivitus**: 30 plokki (~1 tund)
- **Tühistamise viivitus**: 720 plokki (~24 tundi)
- **Aadressi vorming**: P2WPKH (bech32, pocx1q...) ainult PoCX kaevandamisoperatsioonide ja sepistamisülesannete jaoks

---

## Koodi korraldus

**Bitcoin Core'i modifikatsioonid**: Minimaalsed muudatused põhifailides, märgitud funktsiooni lipuga `#ifdef ENABLE_POCX`

**Uus PoCX implementatsioon**: Isoleeritud `src/pocx/` kataloogis

---

## Turvaküsimused

### Ajastuse turvalisus

- 15-sekundiline tuleviku tolerants takistab võrgu fragmenteerumist
- 10-sekundiline hoiatuslävi teavitab operaatoreid kellanihetest
- Kaitsev sepistamine elimineerib kellamanipuleerimise stiimuli
- Ajapainde vähendab ajastuse varieeruvuse mõju

**Detailid**: [Peatükk 5: Ajastuse turvalisus](5-timing-security.md)

### Ülesannete turvalisus

- OP_RETURN-ainult disain (pole UTXO manipuleerimist)
- Tehingu allkiri tõestab graafikuomandit
- Aktiveerimise viivitused takistavad kiiret olekumanipuleerimist
- Ümberkorralduskindlad tagasivõtmise andmed kõigi olekumuutuste jaoks

**Detailid**: [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md)

### Konsensuse turvalisus

- Allkiri välja arvatud ploki räsist (takistab muudetavust)
- Piiratud allkirja suurused (takistab DoS-i)
- Kompressiooni piiride valideerimine (takistab nõrku tõestusi)
- Raskuse kohandamine igal plokil (reageerib mahu muutustele)

**Detailid**: [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md)

---

## Võrgu staatus

**Mainnet**: Veel käivitamata
**Testivõrk**: Saadaval testimiseks
**Regtest**: Täielikult funktsionaalne arenduseks

**Geneesisploki parameetrid**: [Peatükk 6: Võrguparameetrid](6-network-parameters.md)

---

## Järgmised sammud

**PoCX mõistmiseks**: Jätka [Peatükk 2: Graafikuvorming](2-plot-format.md), et õppida graafikufaili struktuuri ja vormingu arengut.

**Kaevandamise seadistamiseks**: Hüppa [Peatükk 7: RPC viide](7-rpc-reference.md) integratsiooni detailide jaoks.

**Sõlme käitamiseks**: Vaata [Peatükk 6: Võrguparameetrid](6-network-parameters.md) konfiguratsiooni valikute jaoks.

---

[Sisukord](index.md) | [Järgmine: Graafikuvorming ->](2-plot-format.md)
