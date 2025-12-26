[← Iepriekšējā: Ievads](1-introduction.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Konsensa un kalnrūpniecības process →](3-consensus-and-mining.md)

---

# 2. nodaļa: PoCX plotfaila formāta specifikācija

Šis dokuments apraksta PoCX plotfaila formātu — uzlabotu POC2 formāta versiju ar paaugstinātu drošību, SIMD optimizācijām un mērogojamu darba pierādījumu.

## Formāta pārskats

PoCX plotfaili satur iepriekš aprēķinātas Shabal256 jaucējvērtības, kas organizētas efektīvām kalnrūpniecības operācijām. Sekojot PoC tradīcijai kopš POC1, **visi metadati ir iekļauti faila nosaukumā** — nav faila galvenes.

### Faila paplašinājums
- **Standarta**: `.pocx` (pabeigtie plotfaili)
- **Procesā**: `.tmp` (plotēšanas laikā, pārdēvēts uz `.pocx`, kad pabeigts)

## Vēsturiskais konteksts un ievainojamību evolūcija

### POC1 formāts (mantots)
**Divas galvenās ievainojamības (laika-atmiņas kompromisi):**

1. **PoW sadalījuma trūkums**
   - Nevienmērīgs darba pierādījuma sadalījums pa scoopiem
   - Zemas scoopu numurus varēja aprēķināt reāllaikā
   - **Ietekme**: Samazinātas glabāšanas prasības uzbrucējiem

2. **XOR kompresijas uzbrukums** (50% laika-atmiņas kompromiss)
   - Izmantoja matemātiskas īpašības, lai sasniegtu 50% glabāšanas samazinājumu
   - **Ietekme**: Uzbrucēji varēja iegūt ar pusi no nepieciešamās glabāšanas

**Izkārtojuma optimizācija**: Pamata secīgs scoopu izkārtojums HDD efektivitātei

### POC2 formāts (Burstcoin)
- ✅ **Novērsts PoW sadalījuma trūkums**
- ❌ **XOR-transpozīcijas ievainojamība palika neizlabota**
- **Izkārtojums**: Saglabāta secīgā scoopu optimizācija

### PoCX formāts (pašreizējais)
- ✅ **Novērsts PoW sadalījums** (mantots no POC2)
- ✅ **Izlabota XOR-transpozīcijas ievainojamība** (unikāla PoCX)
- ✅ **Uzlabots SIMD/GPU izkārtojums** optimizēts paralēlai apstrādei un atmiņas apvienošanai
- ✅ **Mērogojams darba pierādījums** novērš laika-atmiņas kompromisus, palielinoties skaitļošanas jaudai (PoW tiek veikts tikai plotfailu izveidē vai jaunināšanā)

## XOR-transpozīcijas kodēšana

### Problēma: 50% laika-atmiņas kompromiss

POC1/POC2 formātos uzbrucēji varēja izmantot matemātisko sakarību starp scoopiem, lai saglabātu tikai pusi datu un pārējo aprēķinātu reāllaikā kalnrūpniecības laikā. Šis "XOR kompresijas uzbrukums" grauj glabāšanas garantiju.

### Risinājums: XOR-transpozīcijas nostiprināšana

PoCX iegūst savu kalnrūpniecības formātu (X1), piemērojot XOR-transpozīcijas kodēšanu bāzes warpu pāriem (X0):

**Lai izveidotu scoopu S noncei N X1 warpā:**
1. Ņemiet scoopu S no nonces N pirmajā X0 warpā (tiešā pozīcija)
2. Ņemiet scoopu N no nonces S otrajā X0 warpā (transponētā pozīcija)
3. Veiciet XOR divām 64 baitu vērtībām, lai iegūtu X1 scoopu

Transpozīcijas solis apmaina scoopu un nonču indeksus. Matricas terminos — kur rindas attēlo scoopus un kolonnas attēlo nonces — tas apvieno elementu pozīcijā (S, N) pirmajā warpā ar elementu (N, S) otrajā.

### Kāpēc tas novērš uzbrukumu

XOR-transpozīcija sasaista katru scoopu ar veselu rindu un veselu kolonnu pamata X0 datos. Viena X1 scoopa atgūšanai nepieciešama piekļuve datiem, kas aptver visus 4096 scoopu indeksus. Jebkurš mēģinājums aprēķināt trūkstošos datus prasītu ģenerēt 4096 pilnas nonces, nevis vienu — novēršot asimetrisko izmaksu struktūru, ko izmanto XOR uzbrukums.

Rezultātā pilna X1 warpa glabāšana kļūst par vienīgo skaitļošanas ziņā dzīvotspējīgo stratēģiju kalnračiem.

## Faila nosaukuma metadatu struktūra

Visi plotfaila metadati ir kodēti faila nosaukumā, izmantojot šo precīzo formātu:

```
{KONTA_DATI}_{SĒKLA}_{WARPI}_{MĒROGOŠANA}.pocx
```

### Faila nosaukuma komponenti

1. **KONTA_DATI** (40 heksadecimālie simboli)
   - Neapstrādāti 20 baitu konta dati kā lielais heksadecimālais
   - Neatkarīgs no tīkla (nav tīkla ID vai kontrolsummas)
   - Piemērs: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SĒKLA** (64 heksadecimālie simboli)
   - 32 baitu sēklas vērtība kā mazais heksadecimālais
   - **Jauns PoCX**: Nejauša 32 baitu sēkla faila nosaukumā aizstāj secīgo nonču numerāciju — novērš plotfailu pārklāšanos
   - Piemērs: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPI** (decimālskaitlis)
   - **JAUNA izmēra vienība PoCX**: Aizstāj uz noncēm balstīto izmēru no POC1/POC2
   - **XOR-transpozīcijai izturīgs dizains**: Katrs warps = tieši 4096 nonces (dalījuma izmērs, kas nepieciešams XOR-transpozīcijai izturīgai transformācijai)
   - **Izmērs**: 1 warps = 1073741824 baiti = 1 GiB (ērta vienība)
   - Piemērs: `1024` (1 TiB plotfails = 1024 warpi)

4. **MĒROGOŠANA** (X prefikss ar decimālskaitli)
   - Mērogošanas līmenis kā `X{līmenis}`
   - Augstākas vērtības = vairāk darba pierādījuma nepieciešams
   - Piemērs: `X4` (2^4 = 16× POC2 grūtība)

### Faila nosaukumu piemēri
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Faila izkārtojums un datu struktūra

### Hierarhiskā organizācija
```
Plotfails (NAV GALVENES)
├── Scoops 0
│   ├── Warps 0 (Visas nonces šim scoopam/warpam)
│   ├── Warps 1
│   └── ...
├── Scoops 1
│   ├── Warps 0
│   ├── Warps 1
│   └── ...
└── Scoops 4095
    ├── Warps 0
    └── ...
```

### Konstantes un izmēri

| Konstante | Izmērs | Apraksts |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE** | 32 B | Viena Shabal256 jaucējvērtības izvade |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE) | Jaucējvērtību pāris, kas nolasīts kalnrūpniecības raundā |
| **NUM\_SCOOPS** | 4096 (2¹²) | Scoopi vienā noncē; viens izvēlēts katrā raundā |
| **NONCE\_SIZE** | 262144 B (256 KiB) | Visi nonces scoopi (PoC1/PoC2 mazākā vienība) |
| **WARP\_SIZE** | 1073741824 B (1 GiB) | Mazākā vienība PoCX |

### SIMD optimizēts plotfaila izkārtojums

PoCX implementē SIMD apzinīgu nonču piekļuves shēmu, kas ļauj vektorizētu vairāku nonču vienlaicīgu apstrādi. Tas balstās uz konceptiem no [POC2×16 optimizācijas pētniecības](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/), lai maksimizētu atmiņas caurlaidspēju un SIMD efektivitāti.

---

#### Tradicionālais secīgais izkārtojums

Secīga nonču glabāšana:

```
[Nonce 0: Scoopu dati] [Nonce 1: Scoopu dati] [Nonce 2: Scoopu dati] ...
```

SIMD neefektivitāte: Katrai SIMD joslai vajag to pašu vārdu no dažādām noncēm:

```
Vārds 0 no Nonces 0 -> nobīde 0
Vārds 0 no Nonces 1 -> nobīde 512
Vārds 0 no Nonces 2 -> nobīde 1024
...
```

Izkaisīta savākšanas piekļuve samazina caurlaidspēju.

---

#### PoCX SIMD optimizēts izkārtojums

PoCX glabā **vārdu pozīcijas 16 noncēs** blakus:

```
Kešatmiņas līnija (64 baiti):

Vārds0_N0 Vārds0_N1 Vārds0_N2 ... Vārds0_N15
Vārds1_N0 Vārds1_N1 Vārds1_N2 ... Vārds1_N15
...
```

**ASCII diagramma**

```
Tradicionālais izkārtojums:

Nonce0: [V0][V1][V2][V3]...
Nonce1: [V0][V1][V2][V3]...
Nonce2: [V0][V1][V2][V3]...

PoCX izkārtojums:

Vārds0: [N0][N1][N2][N3]...[N15]
Vārds1: [N0][N1][N2][N3]...[N15]
Vārds2: [N0][N1][N2][N3]...[N15]
```

---

#### Atmiņas piekļuves ieguvumi

- Viena kešatmiņas līnija nodrošina visas SIMD joslas.
- Novērš izkaisītas savākšanas operācijas.
- Samazina kešatmiņas kļūdas.
- Pilnībā secīga atmiņas piekļuve vektorizētiem aprēķiniem.
- GPU arī gūst labumu no 16 nonču izlīdzināšanas, maksimizējot kešatmiņas efektivitāti.

---

#### SIMD mērogošana

| SIMD | Vektora platums* | Nonces | Apstrādes cikli uz kešatmiņas līniju |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX | 128 biti | 4 | 4 cikli |
| AVX2 | 256 biti | 8 | 2 cikli |
| AVX512 | 512 biti | 16 | 1 cikls |

\* Veselskaitļu operācijām

---



## Darba pierādījuma mērogošana

### Mērogošanas līmeņi
- **X0**: Bāzes nonces bez XOR-transpozīcijas kodēšanas (teorētisks, netiek izmantots kalnrūpniecībā)
- **X1**: XOR-transpozīcijas bāzlīnija — pirmais nostiprinātais formāts (1× darbs)
- **X2**: 2× X1 darbs (XOR pa 2 warpiem)
- **X3**: 4× X1 darbs (XOR pa 4 warpiem)
- **…**
- **Xn**: 2^(n-1) × X1 darbs iegults

### Ieguvumi
- **Pielāgojama PoW grūtība**: Palielina skaitļošanas prasības, lai sekotu līdzi ātrākai aparatūrai
- **Formāta ilgmūžība**: Nodrošina elastīgu kalnrūpniecības grūtības mērogošanu laika gaitā

### Plotfailu jaunināšana / Atpakaļejoša saderība

Kad tīkls palielina PoW (darba pierādījuma) skalu par 1, esošajiem plotfailiem nepieciešama jaunināšana, lai saglabātu to pašu efektīvo plotfaila izmēru. Būtībā jums tagad ir nepieciešams divreiz vairāk PoW jūsu plotfailos, lai sasniegtu to pašu ieguldījumu jūsu kontā.

Labā ziņa ir tā, ka PoW, ko jau esat veicis, veidojot savus plotfailus, netiek zaudēts — jums vienkārši jāpievieno papildu PoW esošajiem failiem. Nav jāpārplotē.

Alternatīvi, jūs varat turpināt izmantot pašreizējos plotfailus bez jaunināšanas, bet ņemiet vērā, ka tie tagad ieguldīs tikai 50% no to iepriekšējā efektīvā izmēra jūsu kontā. Jūsu kalnrūpniecības programmatūra var mērogot plotfailu reāllaikā.

## Salīdzinājums ar mantotajiem formātiem

| Funkcija | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW sadalījums | ❌ Kļūdains | ✅ Novērsts | ✅ Novērsts |
| XOR-transpozīcijas izturība | ❌ Ievainojams | ❌ Ievainojams | ✅ Novērsts |
| SIMD optimizācija | ❌ Nav | ❌ Nav | ✅ Uzlabota |
| GPU optimizācija | ❌ Nav | ❌ Nav | ✅ Optimizēta |
| Mērogojams darba pierādījums | ❌ Nav | ❌ Nav | ✅ Jā |
| Sēklas atbalsts | ❌ Nav | ❌ Nav | ✅ Jā |

PoCX formāts pārstāv pašreizējo jaudas pierādījuma plotfailu formātu tehnikas virsotni, risinot visas zināmās ievainojamības, vienlaikus nodrošinot ievērojamus veiktspējas uzlabojumus modernai aparatūrai.

## Atsauces un papildu lasāmviela

- **POC1/POC2 fons**: [Burstcoin kalnrūpniecības pārskats](https://www.burstcoin.community/burstcoin-mining/) - Visaptverošs ceļvedis tradicionālajiem jaudas pierādījuma kalnrūpniecības formātiem
- **POC2×16 pētniecība**: [CIP paziņojums: POC2×16 - Jauns optimizēts plotfaila formāts](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Oriģinālā SIMD optimizācijas pētniecība, kas iedvesmoja PoCX
- **Shabal jaucēšanas algoritms**: [Saphir projekts: Shabal, iesniegums NIST kriptogrāfisko jaucēšanas algoritmu konkursā](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Shabal256 algoritma tehniskā specifikācija, kas izmantota PoC kalnrūpniecībā

---

[← Iepriekšējā: Ievads](1-introduction.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Konsensa un kalnrūpniecības process →](3-consensus-and-mining.md)
