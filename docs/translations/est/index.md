# Bitcoin-PoCX tehniline dokumentatsioon

**Versioon**: 1.0
**Bitcoin Core baas**: v30.0
**Staatus**: Testivorgu faas
**Viimati uuendatud**: 2025-12-25

---

## Dokumentatsiooni kohta

See on Bitcoin-PoCX terviklik tehniline dokumentatsioon. Bitcoin-PoCX on Bitcoin Core'i integratsioon, mis lisab uue põlvkonna mahtutõestuse (Proof of Capacity neXt generation, PoCX) konsensuse toe. Dokumentatsioon on korraldatud omavahel seotud peatükkidena, mis hõlmavad kõiki süsteemi aspekte.

**Sihtrühmad**:
- **Sõlmeoperaatorid**: Peatükid 1, 5, 6, 8
- **Kaevandajad**: Peatükid 2, 3, 7
- **Arendajad**: Kõik peatükid
- **Teadlased**: Peatükid 3, 4, 5




## Tõlked

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Araabia](../ara/index.md) | [🇧🇬 Bulgaaria](../bul/index.md) | [🇪🇪 Eesti](../est/index.md) | [🇵🇭 Filipiini](../fil/index.md) | [🇮🇱 Heebrea](../heb/index.md) | [🇨🇳 Hiina](../zho/index.md) |
| [🇮🇳 Hindi](../hin/index.md) | [🇪🇸 Hispaania](../spa/index.md) | [🇳🇱 Hollandi](../nld/index.md) | [🇮🇩 Indoneesia](../ind/index.md) | [🇮🇹 Itaalia](../ita/index.md) | [🇯🇵 Jaapani](../jpn/index.md) |
| [🇰🇷 Korea](../kor/index.md) | [🇬🇷 Kreeka](../ell/index.md) | [🇱🇹 Leedu](../lit/index.md) | [🇱🇻 Läti](../lav/index.md) | [🇳🇴 Norra](../nor/index.md) | [🇵🇱 Poola](../pol/index.md) |
| [🇵🇹 Portugali](../por/index.md) | [🇫🇷 Prantsuse](../fra/index.md) | [🇸🇪 Rootsi](../swe/index.md) | [🇷🇴 Rumeenia](../ron/index.md) | [🇩🇪 Saksa](../deu/index.md) | [🇷🇸 Serbia](../srp/index.md) |
| [🇫🇮 Soome](../fin/index.md) | [🇰🇪 Suahiili](../swa/index.md) | [🇩🇰 Taani](../dan/index.md) | [🇨🇿 Tšehhi](../ces/index.md) | [🇹🇷 Türgi](../tur/index.md) | [🇺🇦 Ukraina](../ukr/index.md) |
| [🇭🇺 Ungari](../hun/index.md) | [🇷🇺 Vene](../rus/index.md) | [🇻🇳 Vietnami](../vie/index.md) | | | |


---

## Sisukord

### I osa: Alused

**[Peatükk 1: Sissejuhatus ja ülevaade](1-introduction.md)**
Projekti ülevaade, arhitektuur, disainifilosoofia, põhifunktsioonid ning kuidas PoCX erineb tööst tuletatud tõestusest (Proof of Work).

**[Peatükk 2: Graafikufaili vorming](2-plot-format.md)**
PoCX graafikuvormingu täielik spetsifikatsioon, sealhulgas SIMD optimeerimine, tööst tuletatud tõestuse skaleerimine ning vormingu areng POC1/POC2 versioonidest.

**[Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md)**
PoCX konsensusmehhanismi täielik tehniline spetsifikatsioon: ploki struktuur, genereerimisallkirjad, baassihtmärgi kohandamine, kaevandamisprotsess, valideerimise töövoog ning ajapainde algoritm.

---

### II osa: Täiustatud funktsioonid

**[Peatükk 4: Sepistamisülesannete süsteem](4-forging-assignments.md)**
OP_RETURN-põhine arhitektuur sepistamisõiguste delegeerimiseks: tehingu struktuur, andmebaasi disain, olekumasin, ümberkorralduste haldamine ning RPC liides.

**[Peatükk 5: Ajasünkroniseerimine ja turvalisus](5-timing-security.md)**
Kellanihe tolerants, kaitsev sepistamismehhanism, kellamanipuleerimise vastased meetmed ning ajastusega seotud turvaküsimused.

**[Peatükk 6: Võrguparameetrid](6-network-parameters.md)**
Chainparams konfiguratsioon, geneesisplokk, konsensusparameetrid, coinbase reeglid, dünaamiline skaleerimine ning majanduslik mudel.

---

### III osa: Kasutamine ja integratsioon

**[Peatükk 7: RPC liidese viide](7-rpc-reference.md)**
Täielik RPC käskude viide kaevandamiseks, ülesanneteks ja plokiahela päringuteks. Oluline kaevandajate ja kaevandamisbasseinide integratsiooniks.

**[Peatükk 8: Rahakoti ja graafilise liidese juhend](8-wallet-guide.md)**
Kasutusjuhend Bitcoin-PoCX Qt rahakotile: sepistamisülesannete dialoog, tehingute ajalugu, kaevandamise seadistamine ja veaotsing.

---

## Kiirnavigeerimine

### Sõlmeoperaatoritele
-> Alusta [Peatükk 1: Sissejuhatus](1-introduction.md)
-> Seejärel vaata [Peatükk 6: Võrguparameetrid](6-network-parameters.md)
-> Seadista kaevandamine [Peatükk 8: Rahakoti juhend](8-wallet-guide.md)

### Kaevandajatele
-> Mõista [Peatükk 2: Graafikuvorming](2-plot-format.md)
-> Õpi protsessi [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md)
-> Integreeri kasutades [Peatükk 7: RPC viide](7-rpc-reference.md)

### Basseinioperaatoritele
-> Vaata [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md)
-> Uuri [Peatükk 7: RPC viide](7-rpc-reference.md)
-> Rakenda ülesannete RPC-de ja submit_nonce abil

### Arendajatele
-> Loe kõik peatükid järjest läbi
-> Ristkontrolli läbi dokumentatsioonis viidatud lähtefaile
-> Uuri `src/pocx/` kataloogi struktuuri
-> Kompileeri väljalasked [GUIX-iga](../bitcoin/contrib/guix/README.md)

---

## Dokumentatsiooni konventsioonid

**Failiviited**: Implementatsiooni detailid viitavad lähtefailidele kujul `tee/failini.cpp:rida`

**Koodi integratsioon**: Kõik muudatused on funktsiooni lipuga `#ifdef ENABLE_POCX`

**Ristviited**: Peatükid viitavad seotud sektsioonidele suhteliste Markdown linkidega

**Tehniline tase**: Dokumentatsioon eeldab tuttavust Bitcoin Core'i ja C++ arendusega

---

## Kompileerimine

### Arenduskompileerimine

```bash
# Klooni koos alamoodulitega
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Seadista PoCX lubamisega
cmake -B build -DENABLE_POCX=ON

# Kompileeri
cmake --build build -j$(nproc)
```

**Kompileerimise variandid**:
```bash
# Qt graafilise liidesega
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Silumise kompileerimine
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Sõltuvused**: Standardsed Bitcoin Core kompileerimise sõltuvused. Vaata [Bitcoin Core kompileerimise dokumentatsiooni](https://github.com/bitcoin/bitcoin/tree/master/doc#building) platvormispetsiifiliste nõuete kohta.

### Väljalaske kompileerimine

Korratavate väljalaske binaarfailide jaoks kasuta GUIX kompileerimissüsteemi: Vaata [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Lisaressursid

**Hoidla**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX raamistik**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Seotud projektid**:
- Graafikukoostaja: Põhineb [engraver](https://github.com/PoC-Consortium/engraver)
- Kaevandaja: Põhineb [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Kuidas seda dokumentatsiooni lugeda

**Järjestikune lugemine**: Peatükid on mõeldud lugemiseks järjekorras, tuginedes eelnevatele mõistetele.

**Teatmelugemine**: Kasuta sisukorda konkreetsetele teemadele otse hüppamiseks. Iga peatükk on iseseisev ristviitadega seotud materjalidele.

**Brausernavigeerimine**: Ava `index.md` Markdown vaaturis või brauseris. Kõik sisemised lingid on suhtelised ja töötavad võrguühenduseta.

**PDF eksport**: Seda dokumentatsiooni saab ühendada üheks PDF-iks võrguühenduseta lugemiseks.

---

## Projekti staatus

**Funktsioonid valmis**: Kõik konsensusreeglid, kaevandamine, ülesanded ja rahakoti funktsioonid on implementeeritud.

**Dokumentatsioon valmis**: Kõik 8 peatükki on valmis ja kontrollitud koodibaasi vastu.

**Testivõrk aktiivne**: Praegu testivõrgu faasis kogukonna testimiseks.

---

## Panustamine

Dokumentatsiooni täiendused on teretulnud. Palun järgi:
- Tehniline täpsus enne paljusõnalisust
- Lühikesed ja täpsed selgitused
- Dokumentatsioonis koodi ega pseudokoodi (viita lähtefailidele)
- Ainult implementeeritu (mitte spekulatiivsed funktsioonid)

---

## Litsents

Bitcoin-PoCX pärib Bitcoin Core'i MIT litsentsi. Vaata `COPYING` hoidla juurkataloogis.

PoCX raamistiku omistus on dokumenteeritud [Peatükk 2: Graafikuvorming](2-plot-format.md).

---

**Alusta lugemist**: [Peatükk 1: Sissejuhatus ja ülevaade ->](1-introduction.md)
