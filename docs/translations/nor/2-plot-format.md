[← Forrige: Introduksjon](1-introduction.md) | [Innholdsfortegnelse](index.md) | [Neste: Konsensus og mining →](3-consensus-and-mining.md)

---

# Kapittel 2: PoCX plotformat-spesifikasjon

Dette dokumentet beskriver PoCX-plotformatet, en forbedret versjon av POC2-formatet med økt sikkerhet, SIMD-optimaliseringer og skalerbar proof-of-work.

## Formatoversikt

PoCX-plotfiler inneholder forhåndsberegnede Shabal256-hashverdier organisert for effektive miningoperasjoner. I tråd med PoC-tradisjonen siden POC1 er **all metadata innebygd i filnavnet** - det finnes ingen filheader.

### Filendelse
- **Standard**: `.pocx` (fullførte plotter)
- **Under arbeid**: `.tmp` (under plotting, omdøpes til `.pocx` når fullført)

## Historisk kontekst og sårbarhetsutvikling

### POC1-format (historisk)
**To store sårbarheter (tid-minne-avveininger):**

1. **PoW-fordelingsfeil**
   - Ujevn fordeling av proof-of-work på tvers av scoops
   - Lave scoop-numre kunne beregnes i sanntid
   - **Konsekvens**: Reduserte lagringskrav for angripere

2. **XOR-komprimeringsangrep** (50% tid-minne-avveining)
   - Utnyttet matematiske egenskaper for å oppnå 50% lagringsreduksjon
   - **Konsekvens**: Angripere kunne mine med halvparten av nødvendig lagring

**Layout-optimalisering**: Grunnleggende sekvensiell scoop-layout for HDD-effektivitet

### POC2-format (Burstcoin)
- Fikset PoW-fordelingsfeil
- XOR-transpose-sårbarhet forble ufikset
- **Layout**: Opprettholdt sekvensiell scoop-optimalisering

### PoCX-format (nåværende)
- Fikset PoW-fordeling (arvet fra POC2)
- Fikset XOR-transpose-sårbarhet (unikt for PoCX)
- Forbedret SIMD/GPU-layout optimalisert for parallell prosessering og minnesammenslåing
- Skalerbar proof-of-work forhindrer tid-minne-avveininger etter hvert som beregningskraft øker (PoW utføres kun ved oppretting eller oppgradering av plotfiler)

## XOR-transpose-koding

### Problemet: 50% tid-minne-avveining

I POC1/POC2-formater kunne angripere utnytte det matematiske forholdet mellom scoops for å lagre bare halvparten av dataene og beregne resten i sanntid under mining. Dette «XOR-komprimeringsangrepet» undergravde lagringsgarantien.

### Løsningen: XOR-transpose-herding

PoCX utleder sitt miningformat (X1) ved å anvende XOR-transpose-koding på par av base-warps (X0):

**For å konstruere scoop S av nonce N i en X1-warp:**
1. Ta scoop S av nonce N fra den første X0-warpen (direkte posisjon)
2. Ta scoop N av nonce S fra den andre X0-warpen (transponert posisjon)
3. XOR de to 64-byte-verdiene for å få X1-scoopen

Transpose-trinnet bytter scoop- og nonce-indekser. I matrisetermer - der rader representerer scoops og kolonner representerer nonces - kombinerer det elementet på posisjon (S, N) i den første warpen med elementet på (N, S) i den andre.

### Hvorfor dette eliminerer angrepet

XOR-transpose sammenlåser hver scoop med en hel rad og en hel kolonne av de underliggende X0-dataene. Å gjenopprette en enkelt X1-scoop krever tilgang til data som spenner over alle 4096 scoop-indekser. Ethvert forsøk på å beregne manglende data ville kreve regenerering av 4096 fulle nonces i stedet for en enkelt nonce - noe som fjerner den asymmetriske kostnadsstrukturen som ble utnyttet av XOR-angrepet.

Som et resultat blir lagring av den fulle X1-warpen den eneste beregingsmessig levedyktige strategien for minere.

## Filnavn-metadatastruktur

All plotmetadata er kodet i filnavnet med dette eksakte formatet:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Filnavnkomponenter

1. **ACCOUNT_PAYLOAD** (40 hex-tegn)
   - Rå 20-byte kontopayload som store bokstaver hex
   - Nettverksuavhengig (ingen nettverks-ID eller sjekksum)
   - Eksempel: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex-tegn)
   - 32-byte seed-verdi som små bokstaver hex
   - **Nytt i PoCX**: Tilfeldig 32-byte seed i filnavn erstatter fortløpende nonce-nummerering - forhindrer plotoverlapping
   - Eksempel: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (desimaltall)
   - **NY størrelsesenhet i PoCX**: Erstatter nonce-basert størrelse fra POC1/POC2
   - **XOR-transpose-resistent design**: Hver warp = nøyaktig 4096 nonces (partisjonsstørrelse nødvendig for XOR-transpose-resistent transformasjon)
   - **Størrelse**: 1 warp = 1073741824 bytes = 1 GiB (praktisk enhet)
   - Eksempel: `1024` (1 TiB plot = 1024 warps)

4. **SCALING** (X-prefikset desimaltall)
   - Skaleringsnivå som `X{nivå}`
   - Høyere verdier = mer proof-of-work påkrevd
   - Eksempel: `X4` (2^4 = 16× POC2-vanskelighetsgrad)

### Eksempler på filnavn
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Fillayout og datastruktur

### Hierarkisk organisering
```
Plotfil (INGEN HEADER)
├── Scoop 0
│   ├── Warp 0 (Alle nonces for denne scoop/warp)
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

### Konstanter og størrelser

| Konstant        | Størrelse               | Beskrivelse                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Enkelt Shabal256-hashutdata                     |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Hashpar lest i en miningrunde                   |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops per nonce; én velges per runde           |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Alle scoops av en nonce (PoC1/PoC2 minste enhet)|
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Minste enhet i PoCX                             |

### SIMD-optimalisert plotfil-layout

PoCX implementerer et SIMD-bevisst nonce-tilgangsmønster som muliggjør vektorisert prosessering av flere nonces samtidig. Det bygger på konsepter fra [POC2×16-optimaliserings-forskning](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) for å maksimere minnegjennomstrømning og SIMD-effektivitet.

---

#### Tradisjonell sekvensiell layout

Sekvensiell lagring av nonces:

```
[Nonce 0: Scoop-data] [Nonce 1: Scoop-data] [Nonce 2: Scoop-data] ...
```

SIMD-ineffektivitet: Hver SIMD-bane trenger samme ord på tvers av nonces:

```
Ord 0 fra Nonce 0 -> offset 0
Ord 0 fra Nonce 1 -> offset 512
Ord 0 fra Nonce 2 -> offset 1024
...
```

Scatter-gather-tilgang reduserer gjennomstrømning.

---

#### PoCX SIMD-optimalisert layout

PoCX lagrer **ordposisjoner på tvers av 16 nonces** sammenhengende:

```
Cache-linje (64 bytes):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII-diagram**

```
Tradisjonell layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX-layout:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Fordelene med minnetilgang

- Én cache-linje forsyner alle SIMD-baner.
- Eliminerer scatter-gather-operasjoner.
- Reduserer cache-misser.
- Fullstendig sekvensiell minnetilgang for vektorisert beregning.
- GPU-er drar også nytte av 16-nonce-justering, maksimerer cache-effektivitet.

---

#### SIMD-skalering

| SIMD       | Vektorbredde* | Nonces | Prosesseringssykluser per cache-linje |
|------------|---------------|--------|---------------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 sykluser                            |
| AVX2       | 256-bit       | 8      | 2 sykluser                            |
| AVX512     | 512-bit       | 16     | 1 syklus                              |

\* For heltallsoperasjoner

---



## Proof-of-Work-skalering

### Skaleringsnivåer
- **X0**: Base-nonces uten XOR-transpose-koding (teoretisk, ikke brukt for mining)
- **X1**: XOR-transpose-grunnlinje - første herdede format (1× arbeid)
- **X2**: 2× X1-arbeid (XOR på tvers av 2 warps)
- **X3**: 4× X1-arbeid (XOR på tvers av 4 warps)
- **...**
- **Xn**: 2^(n-1) × X1-arbeid innebygd

### Fordeler
- **Justerbar PoW-vanskelighetsgrad**: Øker beregningskravene for å holde tritt med raskere maskinvare
- **Formatlevetid**: Muliggjør fleksibel skalering av miningvanskelighetsgrad over tid

### Plotoppgradering / bakoverkompatibilitet

Når nettverket øker PoW (Proof of Work)-skalaen med 1, krever eksisterende plotter en oppgradering for å opprettholde samme effektive plotstørrelse. I hovedsak trenger du nå dobbelt så mye PoW i plotfilene dine for å oppnå samme bidrag til kontoen din.

Den gode nyheten er at PoW du allerede har utført når du opprettet plotfilene ikke går tapt - du trenger bare å legge til ekstra PoW til de eksisterende filene. Ingen behov for å plotte på nytt.

Alternativt kan du fortsette å bruke dine nåværende plotter uten oppgradering, men merk at de nå bare vil bidra med 50% av sin tidligere effektive størrelse mot kontoen din. Mining-programvaren din kan skalere en plotfil i sanntid.

## Sammenligning med eldre formater

| Funksjon | POC1 | POC2 | PoCX |
|----------|------|------|------|
| PoW-fordeling | Feilaktig | Fikset | Fikset |
| XOR-transpose-motstand | Sårbar | Sårbar | Fikset |
| SIMD-optimalisering | Ingen | Ingen | Avansert |
| GPU-optimalisering | Ingen | Ingen | Optimalisert |
| Skalerbar proof-of-work | Ingen | Ingen | Ja |
| Seed-støtte | Ingen | Ingen | Ja |

PoCX-formatet representerer den nåværende state-of-the-art innen Proof of Capacity-plotformater, og adresserer alle kjente sårbarheter samtidig som det gir betydelige ytelsesforbedringer for moderne maskinvare.

## Referanser og videre lesning

- **POC1/POC2-bakgrunn**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Omfattende veiledning til tradisjonelle Proof of Capacity-miningformater
- **POC2×16-forskning**: [CIP Announcement: POC2×16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Opprinnelig SIMD-optimaliseringsforskning som inspirerte PoCX
- **Shabal-hashalgoritme**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Teknisk spesifikasjon av Shabal256-algoritmen brukt i PoC-mining

---

[← Forrige: Introduksjon](1-introduction.md) | [Innholdsfortegnelse](index.md) | [Neste: Konsensus og mining →](3-consensus-and-mining.md)
