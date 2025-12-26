# Bitcoin-PoCX techninė dokumentacija

**Versija**: 1.0
**Bitcoin Core pagrindas**: v30.0
**Būsena**: Testinio tinklo fazė
**Paskutinis atnaujinimas**: 2025-12-25

---

## Apie šią dokumentaciją

Tai išsami Bitcoin-PoCX techninė dokumentacija - Bitcoin Core integracijos su Proof of Capacity neXt generation (PoCX) konsensuso palaikymu. Dokumentacija organizuota kaip naršomas vadovas su tarpusavyje susietais skyriais, apimančiais visus sistemos aspektus.

**Tikslinės auditorijos**:
- **Mazgų operatoriai**: 1, 5, 6, 8 skyriai
- **Kasėjai**: 2, 3, 7 skyriai
- **Kūrėjai**: Visi skyriai
- **Tyrėjai**: 3, 4, 5 skyriai




## Vertimai

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabų](../ara/index.md) | [🇧🇬 Bulgarų](../bul/index.md) | [🇨🇿 Čekų](../ces/index.md) | [🇩🇰 Danų](../dan/index.md) | [🇪🇪 Estų](../est/index.md) | [🇵🇭 Filipiniečių](../fil/index.md) |
| [🇫🇮 Suomių](../fin/index.md) | [🇫🇷 Prancūzų](../fra/index.md) | [🇬🇷 Graikų](../ell/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇪🇸 Ispanų](../spa/index.md) | [🇮🇹 Italų](../ita/index.md) |
| [🇯🇵 Japonų](../jpn/index.md) | [🇨🇳 Kinų](../zho/index.md) | [🇰🇷 Korėjiečių](../kor/index.md) | [🇱🇻 Latvių](../lav/index.md) | [🇵🇱 Lenkų](../pol/index.md) | [🇳🇱 Olandų](../nld/index.md) |
| [🇳🇴 Norvegų](../nor/index.md) | [🇵🇹 Portugalų](../por/index.md) | [🇷🇴 Rumunų](../ron/index.md) | [🇷🇺 Rusų](../rus/index.md) | [🇷🇸 Serbų](../srp/index.md) | [🇰🇪 Svahilių](../swa/index.md) |
| [🇸🇪 Švedų](../swe/index.md) | [🇹🇷 Turkų](../tur/index.md) | [🇺🇦 Ukrainiečių](../ukr/index.md) | [🇭🇺 Vengrų](../hun/index.md) | [🇻🇳 Vietnamiečių](../vie/index.md) | [🇩🇪 Vokiečių](../deu/index.md) |
| [🇮🇱 Hebrajų](../heb/index.md) | [🇮🇩 Indoneziečių](../ind/index.md) | | | | |


---

## Turinys

### I dalis: Pagrindai

**[1 skyrius: Įvadas ir apžvalga](1-introduction.md)**
Projekto apžvalga, architektūra, projektavimo filosofija, pagrindinės funkcijos ir kuo PoCX skiriasi nuo Proof of Work.

**[2 skyrius: Grafiko failo formatas](2-plot-format.md)**
Išsami PoCX grafiko formato specifikacija, įskaitant SIMD optimizavimą, darbo įrodymo mastelio keitimą ir formato evoliuciją nuo POC1/POC2.

**[3 skyrius: Konsensusas ir kasimas](3-consensus-and-mining.md)**
Išsami PoCX konsensuso mechanizmo techninė specifikacija: bloko struktūra, generavimo parašai, bazinio tikslo koregavimas, kasimo procesas, validacijos konvejeris ir laiko lenkimo algoritmas.

---

### II dalis: Išplėstinės funkcijos

**[4 skyrius: Kalimo priskyrimo sistema](4-forging-assignments.md)**
Tik OP_RETURN architektūra kalimo teisių delegavimui: transakcijos struktūra, duomenų bazės dizainas, būsenų mašina, reorganizacijų tvarkymas ir RPC sąsaja.

**[5 skyrius: Laiko sinchronizacija ir saugumas](5-timing-security.md)**
Laikrodžio nuokrypio tolerancija, gynybinio kalimo mechanizmas, apsauga nuo laikrodžio manipuliavimo ir su laiku susijusios saugumo svarstybos.

**[6 skyrius: Tinklo parametrai](6-network-parameters.md)**
Chainparams konfigūracija, pradinis blokas, konsensuso parametrai, coinbase taisyklės, dinaminis mastelio keitimas ir ekonominis modelis.

---

### III dalis: Naudojimas ir integracija

**[7 skyrius: RPC sąsajos informacija](7-rpc-reference.md)**
Išsami RPC komandų informacija kasimui, priskyrimams ir blockchain užklausoms. Būtina kasėjų ir baseinų integracijai.

**[8 skyrius: Piniginės ir GUI vadovas](8-wallet-guide.md)**
Bitcoin-PoCX Qt piniginės naudotojo vadovas: kalimo priskyrimo dialogas, transakcijų istorija, kasimo nustatymai ir trikčių šalinimas.

---

## Greita navigacija

### Mazgų operatoriams
→ Pradėkite nuo [1 skyriaus: Įvadas](1-introduction.md)
→ Tada peržiūrėkite [6 skyrių: Tinklo parametrai](6-network-parameters.md)
→ Sukonfigūruokite kasimą su [8 skyriumi: Piniginės vadovas](8-wallet-guide.md)

### Kasėjams
→ Supraskite [2 skyrių: Grafiko formatas](2-plot-format.md)
→ Išmokite procesą [3 skyriuje: Konsensusas ir kasimas](3-consensus-and-mining.md)
→ Integruokite naudodami [7 skyrių: RPC informacija](7-rpc-reference.md)

### Baseinų operatoriams
→ Peržiūrėkite [4 skyrių: Kalimo priskyrimai](4-forging-assignments.md)
→ Išstudijuokite [7 skyrių: RPC informacija](7-rpc-reference.md)
→ Įgyvendinkite naudodami priskyrimo RPC ir submit_nonce

### Kūrėjams
→ Skaitykite visus skyrius eilės tvarka
→ Lygiagretinėte nuorodas į įgyvendinimo failus pateiktus visoje dokumentacijoje
→ Išnagrinėkite `src/pocx/` katalogo struktūrą
→ Kurkite leidimus su [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentacijos konvencijos

**Failų nuorodos**: Įgyvendinimo detalės nurodo pirminius failus kaip `kelias/iki/failo.cpp:eilutė`

**Kodo integracija**: Visi pakeitimai pažymėti funkcijos vėliavėle `#ifdef ENABLE_POCX`

**Kryžminės nuorodos**: Skyriai susieti su susijusiomis sekcijomis naudojant santykinias markdown nuorodas

**Techninis lygis**: Dokumentacija numato susipažinimą su Bitcoin Core ir C++ kūrimu

---

## Kompiliavimas

### Kūrimo versija

```bash
# Klonuoti su submoduliais
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfigūruoti su įjungtu PoCX
cmake -B build -DENABLE_POCX=ON

# Kompiliuoti
cmake --build build -j$(nproc)
```

**Kompiliavimo variantai**:
```bash
# Su Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Derinimo versija
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Priklausomybės**: Standartinės Bitcoin Core kompiliavimo priklausomybės. Žr. [Bitcoin Core kompiliavimo dokumentaciją](https://github.com/bitcoin/bitcoin/tree/master/doc#building) platformai būdingiems reikalavimams.

### Leidimų versijos

Atkuriamoms leidimų dvejetainėms rinkmenoms naudokite GUIX kompiliavimo sistemą: Žr. [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Papildomi ištekliai

**Saugykla**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core karkasas**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Susiję projektai**:
- Grafikų kūrėjas: Paremtas [engraver](https://github.com/PoC-Consortium/engraver)
- Kasėjas: Paremtas [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Kaip skaityti šią dokumentaciją

**Nuoseklus skaitymas**: Skyriai sukurti skaityti eilės tvarka, remiantis ankstesnėmis sąvokomis.

**Referencinis skaitymas**: Naudokite turinį tiesiogiai pereiti prie konkrečių temų. Kiekvienas skyrius yra savarankiškas su kryžminėmis nuorodomis į susijusią medžiagą.

**Naršyklės navigacija**: Atidarykite `index.md` markdown peržiūros programoje arba naršyklėje. Visos vidinės nuorodos yra santykinės ir veikia neprisijungus.

**PDF eksportas**: Ši dokumentacija gali būti sujungta į vieną PDF failą skaitymui neprisijungus.

---

## Projekto būsena

**✅ Funkcijos užbaigtos**: Visos konsensuso taisyklės, kasimas, priskyrimai ir piniginės funkcijos įgyvendintos.

**✅ Dokumentacija užbaigta**: Visi 8 skyriai užbaigti ir patikrinti pagal kodų bazę.

**🔬 Testinis tinklas aktyvus**: Šiuo metu testinio tinklo fazėje bendruomenės testavimui.

---

## Prisidėjimas

Prisidėjimai prie dokumentacijos laukiami. Prašome laikytis:
- Techninis tikslumas virš daugiažodžiavimo
- Trumpi, tiesioginiai paaiškinimai
- Jokio kodo ar pseudokodo dokumentacijoje (nurodykite pirminius failus)
- Tik įgyvendintos funkcijos (jokių spekuliatyvių funkcijų)

---

## Licencija

Bitcoin-PoCX paveldi Bitcoin Core MIT licenciją. Žr. `COPYING` saugyklos šaknyje.

PoCX pagrindinio karkaso autorystė dokumentuota [2 skyriuje: Grafiko formatas](2-plot-format.md).

---

**Pradėti skaityti**: [1 skyrius: Įvadas ir apžvalga →](1-introduction.md)
