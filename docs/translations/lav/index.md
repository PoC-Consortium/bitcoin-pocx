# Bitcoin-PoCX tehniskā dokumentācija

**Versija**: 1.0
**Bitcoin Core bāze**: v30.0
**Statuss**: Testnet fāze
**Pēdējais atjauninājums**: 2025-12-25

---

## Par šo dokumentāciju

Šī ir pilnīga Bitcoin-PoCX tehniskā dokumentācija — Bitcoin Core integrācijas, kas pievieno jaunās paaudzes jaudas pierādījuma (PoCX — Proof of Capacity neXt generation) konsensa atbalstu. Dokumentācija ir organizēta kā pārlūkojams ceļvedis ar savstarpēji saistītām nodaļām, kas aptver visus sistēmas aspektus.

**Mērķauditorijas**:
- **Mezglu operatori**: 1., 5., 6., 8. nodaļa
- **Kalnrači**: 2., 3., 7. nodaļa
- **Izstrādātāji**: Visas nodaļas
- **Pētnieki**: 3., 4., 5. nodaļa




## Tulkojumi

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arābu](../ara/index.md) | [🇧🇬 Bulgāru](../bul/index.md) | [🇨🇿 Čehu](../ces/index.md) | [🇩🇰 Dāņu](../dan/index.md) | [🇪🇪 Igauņu](../est/index.md) | [🇵🇭 Filipīniešu](../fil/index.md) |
| [🇫🇷 Franču](../fra/index.md) | [🇬🇷 Grieķu](../ell/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇳🇱 Holandiešu](../nld/index.md) | [🇮🇩 Indonēziešu](../ind/index.md) | [🇮🇹 Itāļu](../ita/index.md) |
| [🇮🇱 Ivrits](../heb/index.md) | [🇯🇵 Japāņu](../jpn/index.md) | [🇰🇷 Korejiešu](../kor/index.md) | [🇷🇺 Krievu](../rus/index.md) | [🇨🇳 Ķīniešu](../zho/index.md) | [🇱🇻 Latviešu](../lav/index.md) |
| [🇱🇹 Lietuviešu](../lit/index.md) | [🇳🇴 Norvēģu](../nor/index.md) | [🇵🇱 Poļu](../pol/index.md) | [🇵🇹 Portugāļu](../por/index.md) | [🇷🇴 Rumāņu](../ron/index.md) | [🇷🇸 Serbu](../srp/index.md) |
| [🇫🇮 Somu](../fin/index.md) | [🇪🇸 Spāņu](../spa/index.md) | [🇰🇪 Svahili](../swa/index.md) | [🇸🇪 Zviedru](../swe/index.md) | [🇹🇷 Turku](../tur/index.md) | [🇺🇦 Ukraiņu](../ukr/index.md) |
| [🇭🇺 Ungāru](../hun/index.md) | [🇩🇪 Vācu](../deu/index.md) | [🇻🇳 Vjetnamiešu](../vie/index.md) | | | |


---

## Satura rādītājs

### I daļa: Pamati

**[1. nodaļa: Ievads un pārskats](1-introduction.md)**
Projekta pārskats, arhitektūra, projektēšanas filozofija, galvenās funkcijas un kā PoCX atšķiras no darba pierādījuma.

**[2. nodaļa: Plotfailu formāts](2-plot-format.md)**
Pilnīga PoCX plotfaila formāta specifikācija, ieskaitot SIMD optimizāciju, darba pierādījuma mērogošanu un formāta evolūciju no POC1/POC2.

**[3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md)**
Pilnīga PoCX konsensa mehānisma tehniskā specifikācija: bloka struktūra, ģenerēšanas paraksti, bāzes mērķa pielāgošana, kalnrūpniecības process, validācijas cauruļvads un laika līkumo algoritms.

---

### II daļa: Papildu funkcijas

**[4. nodaļa: Kalšanas piešķīrumu sistēma](4-forging-assignments.md)**
Tikai OP_RETURN arhitektūra kalšanas tiesību deleģēšanai: darījumu struktūra, datu bāzes dizains, stāvokļa mašīna, reorganizāciju apstrāde un RPC saskarne.

**[5. nodaļa: Laika sinhronizācija un drošība](5-timing-security.md)**
Pulksteņa nobīdes tolerance, aizsardzības kalšanas mehānisms, pretpulksteņa manipulācija un ar laiku saistīti drošības apsvērumi.

**[6. nodaļa: Tīkla parametri](6-network-parameters.md)**
Chainparams konfigurācija, ģenēzes bloks, konsensa parametri, coinbase noteikumi, dinamiskā mērogošana un ekonomiskais modelis.

---

### III daļa: Lietošana un integrācija

**[7. nodaļa: RPC saskarnes atsauce](7-rpc-reference.md)**
Pilnīga RPC komandu atsauce kalnrūpniecībai, piešķīrumiem un blokķēdes vaicājumiem. Būtiska kalnraču un pūlu integrācijai.

**[8. nodaļa: Maka un GUI ceļvedis](8-wallet-guide.md)**
Bitcoin-PoCX Qt maka lietotāja ceļvedis: kalšanas piešķīrumu dialogs, darījumu vēsture, kalnrūpniecības iestatīšana un problēmu novēršana.

---

## Ātrā navigācija

### Mezglu operatoriem
→ Sāciet ar [1. nodaļu: Ievads](1-introduction.md)
→ Pēc tam pārskatiet [6. nodaļu: Tīkla parametri](6-network-parameters.md)
→ Konfigurējiet kalnrūpniecību ar [8. nodaļu: Maka ceļvedis](8-wallet-guide.md)

### Kalnračiem
→ Izprotiet [2. nodaļu: Plotfaila formāts](2-plot-format.md)
→ Apgūstiet procesu [3. nodaļā: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md)
→ Integrējiet, izmantojot [7. nodaļu: RPC atsauce](7-rpc-reference.md)

### Pūlu operatoriem
→ Pārskatiet [4. nodaļu: Kalšanas piešķīrumi](4-forging-assignments.md)
→ Izpētiet [7. nodaļu: RPC atsauce](7-rpc-reference.md)
→ Ieviešana, izmantojot piešķīrumu RPC un submit_nonce

### Izstrādātājiem
→ Lasiet visas nodaļas secīgi
→ Veiciet savstarpējās atsauces uz implementācijas failiem, kas norādīti dokumentācijā
→ Pārbaudiet `src/pocx/` direktorijas struktūru
→ Veidojiet laidienus ar [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentācijas konvencijas

**Failu atsauces**: Implementācijas detaļas atsaucas uz avota failiem kā `ceļš/uz/failu.cpp:rinda`

**Koda integrācija**: Visas izmaiņas ir iezīmētas ar funkciju karodziņiem `#ifdef ENABLE_POCX`

**Savstarpējās atsauces**: Nodaļas saistās ar saistītām sadaļām, izmantojot relatīvās markdown saites

**Tehniskais līmenis**: Dokumentācija pieņem pārzināšanu par Bitcoin Core un C++ izstrādi

---

## Būvēšana

### Izstrādes būvējums

```bash
# Klonēt ar apakšmoduļiem
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfigurēt ar iespējotu PoCX
cmake -B build -DENABLE_POCX=ON

# Būvēt
cmake --build build -j$(nproc)
```

**Būvējumu varianti**:
```bash
# Ar Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Atkļūdošanas būvējums
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Atkarības**: Standarta Bitcoin Core būvēšanas atkarības. Skatiet [Bitcoin Core būvēšanas dokumentāciju](https://github.com/bitcoin/bitcoin/tree/master/doc#building) platformai specifiskām prasībām.

### Laidienu būvējumi

Reproducējamiem laidienu binārajiem failiem izmantojiet GUIX būvēšanas sistēmu: Skatiet [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Papildu resursi

**Repozitorijs**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX pamata ietvars**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Saistītie projekti**:
- Ploteris: Balstīts uz [engraver](https://github.com/PoC-Consortium/engraver)
- Kalnracis: Balstīts uz [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Kā lasīt šo dokumentāciju

**Secīga lasīšana**: Nodaļas ir veidotas lasīšanai secīgi, balstoties uz iepriekšējiem konceptiem.

**Atsauces lasīšana**: Izmantojiet satura rādītāju, lai pārietu tieši uz konkrētām tēmām. Katra nodaļa ir pašpietiekama ar savstarpējām atsaucēm uz saistīto materiālu.

**Pārlūkprogrammas navigācija**: Atveriet `index.md` markdown skatītājā vai pārlūkprogrammā. Visas iekšējās saites ir relatīvas un darbojas bezsaistē.

**PDF eksports**: Šo dokumentāciju var apvienot vienā PDF failā bezsaistes lasīšanai.

---

## Projekta statuss

**✅ Funkcijas pabeigtas**: Visi konsensa noteikumi, kalnrūpniecība, piešķīrumi un maka funkcijas ir implementētas.

**✅ Dokumentācija pabeigta**: Visas 8 nodaļas ir pabeigtas un pārbaudītas pret kodu bāzi.

**🔬 Testnet aktīvs**: Pašlaik testnet fāzē kopienas testēšanai.

---

## Ieguldījumi

Ieguldījumi dokumentācijā ir laipni gaidīti. Lūdzu, ievērojiet:
- Tehnisko precizitāti pār daudzrunīgumu
- Īsus, konkrētus skaidrojumus
- Nav koda vai pseidokoda dokumentācijā (atsaucieties uz avota failiem)
- Tikai kā-implementēts (nav spekulatīvu funkciju)

---

## Licence

Bitcoin-PoCX pārmanto Bitcoin Core MIT licenci. Skatiet `COPYING` repozitorija saknē.

PoCX pamata ietvara atsauces ir dokumentētas [2. nodaļā: Plotfaila formāts](2-plot-format.md).

---

**Sākt lasīšanu**: [1. nodaļa: Ievads un pārskats →](1-introduction.md)
