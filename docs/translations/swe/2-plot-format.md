[<- Föregående: Introduktion](1-introduction.md) | [Innehållsförteckning](index.md) | [Nästa: Konsensus och mining ->](3-consensus-and-mining.md)

---

# Kapitel 2: Specifikation av PoCX-plotformat

Detta dokument beskriver PoCX-plotformatet, en förbättrad version av POC2-formatet med förbättrad säkerhet, SIMD-optimeringar och skalbart proof-of-work.

## Formatöversikt

PoCX-plotfiler innehåller förberäknade Shabal256-hashvärden organiserade för effektiva miningoperationer. I enlighet med PoC-traditionen sedan POC1, **är all metadata inbäddad i filnamnet** - det finns ingen filheader.

### Filändelse
- **Standard**: `.pocx` (färdiga plottar)
- **Pågående**: `.tmp` (under plottning, döps om till `.pocx` när komplett)

## Historisk kontext och sårbarhetsutveckling

### POC1-format (äldre)
**Två stora sårbarheter (tid-minnesavvägningar):**

1. **PoW-fördelningsbrist**
   - Ojämn fördelning av proof-of-work över scoops
   - Låga scoop-nummer kunde beräknas i realtid
   - **Påverkan**: Reducerade lagringskrav för angripare

2. **XOR-kompressionsattack** (50% tid-minnesavvägning)
   - Utnyttjade matematiska egenskaper för att uppnå 50% lagringsreduktion
   - **Påverkan**: Angripare kunde mina med hälften av den erforderliga lagringen

**Layoutoptimering**: Grundläggande sekventiell scoop-layout för HDD-effektivitet

### POC2-format (Burstcoin)
- Fixad PoW-fördelningsbrist
- XOR-transponeringssårbarhet förblev oåtgärdad
- **Layout**: Bibehöll sekventiell scoop-optimering

### PoCX-format (nuvarande)
- Fixad PoW-fördelning (ärvd från POC2)
- Åtgärdad XOR-transponeringssårbarhet (unikt för PoCX)
- Förbättrad SIMD/GPU-layout optimerad för parallell bearbetning och minneskoalescens
- Skalbart proof-of-work förhindrar tid-minnesavvägningar när beräkningskraften växer (PoW utförs endast vid skapande eller uppgradering av plotfiler)

## XOR-transponering-kodning

### Problemet: 50% tid-minnesavvägning

I POC1/POC2-format kunde angripare utnyttja det matematiska förhållandet mellan scoops för att lagra endast hälften av datan och beräkna resten i realtid under mining. Denna "XOR-kompressionsattack" underminerade lagringsgarantin.

### Lösningen: XOR-transponeringshärdning

PoCX härleder sitt miningformat (X1) genom att applicera XOR-transponering-kodning på par av baswarpar (X0):

**För att konstruera scoop S av nonce N i en X1-warp:**
1. Ta scoop S av nonce N från den första X0-warpen (direkt position)
2. Ta scoop N av nonce S från den andra X0-warpen (transponerad position)
3. XOR:a de två 64-byte-värdena för att erhålla X1-scoopen

Transponeringssteget byter scoop- och nonce-index. I matristermer - där rader representerar scoops och kolumner representerar nonces - kombinerar det elementet vid position (S, N) i den första warpen med elementet vid (N, S) i den andra.

### Varför detta eliminerar attacken

XOR-transponeringen sammanflätar varje scoop med en hel rad och en hel kolumn av den underliggande X0-datan. Att återställa en enskild X1-scoop kräver åtkomst till data som spänner över alla 4096 scoop-index. Varje försök att beräkna saknad data skulle kräva regenerering av 4096 fullständiga nonces snarare än en enskild nonce - vilket tar bort den asymmetriska kostnadsstrukturen som utnyttjades av XOR-attacken.

Som ett resultat blir lagring av den fullständiga X1-warpen den enda beräkningsmässigt gångbara strategin för miners.

## Filnamnsmetadatastruktur

All plotmetadata är kodad i filnamnet med detta exakta format:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Filnamnskomponenter

1. **ACCOUNT_PAYLOAD** (40 hexadecimala tecken)
   - Rå 20-byte kontopayload som versala hexadecimaler
   - Nätverksoberoende (inget nätverks-ID eller checksumma)
   - Exempel: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hexadecimala tecken)
   - 32-byte seed-värde som gemena hexadecimaler
   - **Nytt i PoCX**: Slumpmässig 32-byte seed i filnamnet ersätter konsekutiv nonce-numrering - förhindrar plotöverlappningar
   - Exempel: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimaltal)
   - **NY storleksenhet i PoCX**: Ersätter nonce-baserad storleksangivelse från POC1/POC2
   - **XOR-transponeringsresistent design**: Varje warp = exakt 4096 nonces (partitionsstorlek som krävs för XOR-transponeringsresistent transformation)
   - **Storlek**: 1 warp = 1073741824 bytes = 1 GiB (bekväm enhet)
   - Exempel: `1024` (1 TiB plot = 1024 warpar)

4. **SCALING** (X-prefixat decimaltal)
   - Skalningsnivå som `X{nivå}`
   - Högre värden = mer proof-of-work krävs
   - Exempel: `X4` (2^4 = 16× POC2-svårighet)

### Exempelfilnamn
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Fillayout och datastruktur

### Hierarkisk organisation
```
Plotfil (INGEN HEADER)
├── Scoop 0
│   ├── Warp 0 (Alla nonces för denna scoop/warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Konstanter och storlekar

| Konstant        | Storlek                 | Beskrivning                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Enskild Shabal256-hashutdata                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Hashpar som läses i en miningrunda              |
| **NUM\_SCOOPS** | 4096 (2^12)            | Scoops per nonce; en väljs per runda            |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Alla scoops av en nonce (PoC1/PoC2 minsta enhet)|
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Minsta enhet i PoCX                             |

### SIMD-optimerad plotfillayout

PoCX implementerar ett SIMD-medvetet nonce-åtkomstmönster som möjliggör vektoriserad bearbetning av flera nonces samtidigt. Det bygger på koncept från [POC2×16-optimeringsforkning](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) för att maximera minnesgenomströmning och SIMD-effektivitet.

---

#### Traditionell sekventiell layout

Sekventiell lagring av nonces:

```
[Nonce 0: Scoop-data] [Nonce 1: Scoop-data] [Nonce 2: Scoop-data] ...
```

SIMD-ineffektivitet: Varje SIMD-lane behöver samma ord över nonces:

```
Ord 0 från Nonce 0 -> offset 0
Ord 0 från Nonce 1 -> offset 512
Ord 0 från Nonce 2 -> offset 1024
...
```

Scatter-gather-åtkomst reducerar genomströmning.

---

#### PoCX SIMD-optimerad layout

PoCX lagrar **ordpositioner över 16 nonces** sammanhängande:

```
Cache Line (64 bytes):

Ord0_N0 Ord0_N1 Ord0_N2 ... Ord0_N15
Ord1_N0 Ord1_N1 Ord1_N2 ... Ord1_N15
...
```

**ASCII-diagram**

```
Traditionell layout:

Nonce0: [O0][O1][O2][O3]...
Nonce1: [O0][O1][O2][O3]...
Nonce2: [O0][O1][O2][O3]...

PoCX-layout:

Ord0: [N0][N1][N2][N3]...[N15]
Ord1: [N0][N1][N2][N3]...[N15]
Ord2: [N0][N1][N2][N3]...[N15]
```

---

#### Fördelar med minnesåtkomst

- En cache line tillhandahåller alla SIMD-lanes.
- Eliminerar scatter-gather-operationer.
- Minskar cachemissar.
- Fullt sekventiell minnesåtkomst för vektoriserad beräkning.
- GPU:er drar också nytta av 16-nonce-justering, maximerar cacheeffektivitet.

---

#### SIMD-skalning

| SIMD       | Vektorbredd* | Nonces | Bearbetningscykler per cache line |
|------------|--------------|--------|-----------------------------------|
| SSE2/AVX   | 128-bit      | 4      | 4 cykler                          |
| AVX2       | 256-bit      | 8      | 2 cykler                          |
| AVX512     | 512-bit      | 16     | 1 cykel                           |

\* För heltalsoperationer

---



## Proof-of-Work-skalning

### Skalningsnivåer
- **X0**: Basnonces utan XOR-transponering-kodning (teoretisk, används inte för mining)
- **X1**: XOR-transponeringsbaslinje - första härdade formatet (1× arbete)
- **X2**: 2× X1-arbete (XOR över 2 warpar)
- **X3**: 4× X1-arbete (XOR över 4 warpar)
- **...**
- **Xn**: 2^(n-1) × X1-arbete inbäddat

### Fördelar
- **Justerbar PoW-svårighet**: Ökar beräkningskrav för att hänga med snabbare hårdvara
- **Formatlångsiktighet**: Möjliggör flexibel skalning av miningsvårighet över tid

### Plotuppgradering / Bakåtkompatibilitet

När nätverket ökar PoW (Proof of Work)-skalan med 1 kräver befintliga plottar en uppgradering för att bibehålla samma effektiva plotstorlek. I princip behöver du nu dubbelt så mycket PoW i dina plotfiler för att uppnå samma bidrag till ditt konto.

Den goda nyheten är att det PoW du redan har utfört när du skapade dina plotfiler inte går förlorat - du behöver bara lägga till ytterligare PoW till de befintliga filerna. Ingen omplotting behövs.

Alternativt kan du fortsätta använda dina nuvarande plottar utan uppgradering, men observera att de nu endast kommer att bidra med 50% av sin tidigare effektiva storlek mot ditt konto. Din miningprogramvara kan skala en plotfil i realtid.

## Jämförelse med äldre format

| Funktion | POC1 | POC2 | PoCX |
|----------|------|------|------|
| PoW-fördelning | Bristfällig | Fixad | Fixad |
| XOR-transponeringsmotstånd | Sårbar | Sårbar | Fixad |
| SIMD-optimering | Ingen | Ingen | Avancerad |
| GPU-optimering | Ingen | Ingen | Optimerad |
| Skalbart Proof-of-Work | Nej | Nej | Ja |
| Seed-stöd | Nej | Nej | Ja |

PoCX-formatet representerar det aktuella state-of-the-art inom Proof of Capacity-plotformat och åtgärdar alla kända sårbarheter samtidigt som det ger betydande prestandaförbättringar för modern hårdvara.

## Referenser och vidare läsning

- **POC1/POC2-bakgrund**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Omfattande guide till traditionella Proof of Capacity-miningformat
- **POC2×16-forskning**: [CIP Announcement: POC2×16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Original SIMD-optimeringsforkning som inspirerade PoCX
- **Shabal-hashalgoritm**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Teknisk specifikation av Shabal256-algoritmen som används i PoC-mining

---

[<- Föregående: Introduktion](1-introduction.md) | [Innehållsförteckning](index.md) | [Nästa: Konsensus och mining ->](3-consensus-and-mining.md)
