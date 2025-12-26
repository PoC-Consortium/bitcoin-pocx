[<- Forrige: Introduktion](1-introduction.md) | [Indholdsfortegnelse](index.md) | [Naeste: Konsensus og mining ->](3-consensus-and-mining.md)

---

# Kapitel 2: PoCX-plotformatspecifikation

Dette dokument beskriver PoCX-plotformatet, en forbedret version af POC2-formatet med forbedret sikkerhed, SIMD-optimeringer og skalerbar proof-of-work.

## Formatoversigt

PoCX-plotfiler indeholder forberegnede Shabal256-hashvaerdier organiseret til effektive miningoperationer. I overensstemmelse med PoC-traditionen siden POC1 er **al metadata indlejret i filnavnet** - der er ingen filheader.

### Filendelse
- **Standard**: `.pocx` (faerdige plots)
- **Under arbejde**: `.tmp` (under plotting, omdoebest til `.pocx` ved faerdiggoerelse)

## Historisk kontekst og sarbarhedsudvikling

### POC1-format (aeldre)
**To store sarbarheder (tid-hukommelse-afvejninger):**

1. **PoW-fordelingsfejl**
   - Ujeavnt fordelt proof-of-work pa tvaers af scoops
   - Lave scoop-numre kunne beregnes on-the-fly
   - **Konsekvens**: Reduceret lagringskrav for angribere

2. **XOR-kompressionsangreb** (50% tid-hukommelse-afvejning)
   - Udnyttede matematiske egenskaber til at opna 50% lagerreduktion
   - **Konsekvens**: Angribere kunne mine med halvt sa meget lagerplads

**Layout-optimering**: Grundlaeggende sekventielt scoop-layout til HDD-effektivitet

### POC2-format (Burstcoin)
- Rettet PoW-fordelingsfejl
- XOR-transpose-sarbarhed forblev urettet
- **Layout**: Bevarede sekventiel scoop-optimering

### PoCX-format (nuvaerende)
- Rettet PoW-fordeling (arvet fra POC2)
- Rettet XOR-transpose-sarbarhed (unikt for PoCX)
- Forbedret SIMD/GPU-layout optimeret til parallel behandling og hukommelsessamling
- Skalerbar proof-of-work forebygger tid-hukommelse-afvejninger, efterhanden som beregningskraft vokser (PoW udfoeres kun ved oprettelse eller opgradering af plotfiler)

## XOR-transpose-kodning

### Problemet: 50% tid-hukommelse-afvejning

I POC1/POC2-formater kunne angribere udnytte det matematiske forhold mellem scoops til kun at gemme halvdelen af dataene og beregne resten on-the-fly under mining. Dette "XOR-kompressionsangreb" underminerede lagergarantien.

### Losningen: XOR-transpose-haerdning

PoCX udleder sit miningformat (X1) ved at anvende XOR-transpose-kodning pa par af base-warps (X0):

**For at konstruere scoop S af nonce N i en X1-warp:**
1. Tag scoop S af nonce N fra den forste X0-warp (direkte position)
2. Tag scoop N af nonce S fra den anden X0-warp (transponeret position)
3. XOR de to 64-byte-vaerdier for at fa X1-scoopen

Transpose-trinnet bytter scoop- og nonce-indekser. I matrixtermer - hvor raekker repraesenterer scoops og kolonner repraesenterer nonces - kombinerer det elementet pa position (S, N) i den forste warp med elementet pa (N, S) i den anden.

### Hvorfor dette eliminerer angrebet

XOR-transposen sammenlaaser hver scoop med en hel raekke og en hel kolonne af de underliggende X0-data. Gendannelse af en enkelt X1-scoop kraever adgang til data, der spaender over alle 4096 scoop-indekser. Ethvert forsog pa at beregne manglende data ville kraeve regenerering af 4096 fulde nonces i stedet for en enkelt nonce - hvilket fjerner den asymmetriske omkostningsstruktur, der udnyttes af XOR-angrebet.

Som resultat bliver lagring af den fulde X1-warp den eneste beregningsmssigt levedygtige strategi for minere.

## Filnavn-metadatastruktur

Al plotmetadata er kodet i filnavnet ved hjaelp af dette praecise format:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Filnavnskomponenter

1. **ACCOUNT_PAYLOAD** (40 hex-tegn)
   - Ra 20-byte konto-payload som store hex-bogstaver
   - Netvaerksuafhaengig (ingen netvaerks-ID eller checksum)
   - Eksempel: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex-tegn)
   - 32-byte seed-vaerdi som sma hex-bogstaver
   - **Nyt i PoCX**: Tilfaeldig 32-byte seed i filnavn erstatter fortlobende nonce-nummerering - forebygger plotoverlap
   - Eksempel: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimaltal)
   - **NY storrelsesenhed i PoCX**: Erstatter nonce-baseret storrelse fra POC1/POC2
   - **XOR-transpose-resistent design**: Hver warp = praecis 4096 nonces (partitionsstorrelse kraevet til XOR-transpose-resistent transformation)
   - **Storrelse**: 1 warp = 1073741824 bytes = 1 GiB (bekvem enhed)
   - Eksempel: `1024` (1 TiB plot = 1024 warps)

4. **SCALING** (X-praefiks decimal)
   - Skaleringsniveau som `X{niveau}`
   - Hojere vaerdier = mere proof-of-work kraevet
   - Eksempel: `X4` (2^4 = 16x POC2-svaerhedsgrad)

### Eksempler pa filnavne
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Fillayout og datastruktur

### Hierarkisk organisering
```
Plotfil (INGEN HEADER)
-- Scoop 0
|   -- Warp 0 (Alle nonces for denne scoop/warp)
|   -- Warp 1
|   -- ...
-- Scoop 1
|   -- Warp 0
|   -- Warp 1
|   -- ...
-- Scoop 4095
    -- Warp 0
    -- ...
```

### Konstanter og storrelser

| Konstant        | Storrelse                  | Beskrivelse                                     |
| --------------- | -------------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                       | Enkelt Shabal256-hashoutput                     |
| **SCOOP\_SIZE** | 64 B (2 x HASH\_SIZE)      | Hashpar laest i en miningrunde                  |
| **NUM\_SCOOPS** | 4096 (2^12)                | Scoops pr. nonce; en valgt pr. runde            |
| **NONCE\_SIZE** | 262144 B (256 KiB)         | Alle scoops af en nonce (PoC1/PoC2 mindste enhed) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)       | Mindste enhed i PoCX                            |

### SIMD-optimeret plotfillayout

PoCX implementerer et SIMD-bevidst nonce-adgangsmoenster, der muliggor vektoriseret behandling af flere nonces samtidigt. Det bygger pa koncepter fra [POC2x16-optimeringssforskning](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) for at maksimere hukommelsesgennemstroemning og SIMD-effektivitet.

---

#### Traditionelt sekventielt layout

Sekventiel lagring af nonces:

```
[Nonce 0: Scoop-data] [Nonce 1: Scoop-data] [Nonce 2: Scoop-data] ...
```

SIMD-ineffektivitet: Hver SIMD-bane kraever det samme ord pa tvaers af nonces:

```
Ord 0 fra Nonce 0 -> offset 0
Ord 0 fra Nonce 1 -> offset 512
Ord 0 fra Nonce 2 -> offset 1024
...
```

Scatter-gather-adgang reducerer gennemstroemning.

---

#### PoCX SIMD-optimeret layout

PoCX gemmer **ordpositioner pa tvaers af 16 nonces** sammenhaengende:

```
Cache-linje (64 bytes):

Ord0_N0 Ord0_N1 Ord0_N2 ... Ord0_N15
Ord1_N0 Ord1_N1 Ord1_N2 ... Ord1_N15
...
```

**ASCII-diagram**

```
Traditionelt layout:

Nonce0: [O0][O1][O2][O3]...
Nonce1: [O0][O1][O2][O3]...
Nonce2: [O0][O1][O2][O3]...

PoCX-layout:

Ord0: [N0][N1][N2][N3]...[N15]
Ord1: [N0][N1][N2][N3]...[N15]
Ord2: [N0][N1][N2][N3]...[N15]
```

---

#### Fordele ved hukommelsesadgang

- En cache-linje forsyner alle SIMD-baner.
- Eliminerer scatter-gather-operationer.
- Reducerer cache-misses.
- Fuldt sekventiel hukommelsesadgang til vektoriseret beregning.
- GPU'er drager ogsa fordel af 16-nonce-justering, hvilket maksimerer cache-effektivitet.

---

#### SIMD-skalering

| SIMD       | Vektorbredde* | Nonces | Behandlingscyklusser pr. cache-linje |
|------------|---------------|--------|-------------------------------------|
| SSE2/AVX   | 128-bit       | 4      | 4 cyklusser                         |
| AVX2       | 256-bit       | 8      | 2 cyklusser                         |
| AVX512     | 512-bit       | 16     | 1 cyklus                            |

\* For heltaloperationer

---



## Proof-of-Work-skalering

### Skaleringsniveauer
- **X0**: Base-nonces uden XOR-transpose-kodning (teoretisk, bruges ikke til mining)
- **X1**: XOR-transpose-baseline - forste haerdede format (1x arbejde)
- **X2**: 2x X1-arbejde (XOR pa tvaers af 2 warps)
- **X3**: 4x X1-arbejde (XOR pa tvaers af 4 warps)
- **...**
- **Xn**: 2^(n-1) x X1-arbejde indlejret

### Fordele
- **Justerbar PoW-svaerhedsgrad**: Oger beregningskrav for at holde trit med hurtigere hardware
- **Formatlevetid**: Muliggor fleksibel skalering af miningsvaerhedsgrad over tid

### Plotopgradering / bagudkompatibilitet

Nar netvaerket oger PoW (Proof of Work)-skalaen med 1, kraever eksisterende plots en opgradering for at opretholde den samme effektive plotstorrelse. I bund og grund har du nu brug for dobbelt sa meget PoW i dine plotfiler for at opna det samme bidrag til din konto.

Den gode nyhed er, at den PoW, du allerede har udfrt, da du oprettede dine plotfiler, ikke er tabt - du skal blot tiloje yderligere PoW til de eksisterende filer. Ingen grund til at genplotte.

Alternativt kan du fortsaette med at bruge dine nuvaerende plots uden opgradering, men bemaerk, at de nu kun vil bidrage med 50% af deres tidligere effektive storrelse til din konto. Din miningsoftware kan skalere en plotfil on-the-fly.

## Sammenligning med aeldre formater

| Funktion | POC1 | POC2 | PoCX |
|----------|------|------|------|
| PoW-fordeling | Fejlbeheftet | Rettet | Rettet |
| XOR-transpose-modstand | Sarbar | Sarbar | Rettet |
| SIMD-optimering | Ingen | Ingen | Avanceret |
| GPU-optimering | Ingen | Ingen | Optimeret |
| Skalerbar Proof-of-Work | Ingen | Ingen | Ja |
| Seed-understottelse | Ingen | Ingen | Ja |

PoCX-formatet repraesenterer det nuvaerende state-of-the-art inden for Proof of Capacity-plotformater, der adresserer alle kendte sarbarheder, samtidig med at det giver betydelige ydelsesforbedringer til moderne hardware.

## Referencer og yderligere laesning

- **POC1/POC2-baggrund**: [Burstcoin Mining-oversigt](https://www.burstcoin.community/burstcoin-mining/) - Omfattende guide til traditionelle Proof of Capacity-miningformater
- **POC2x16-forskning**: [CIP-meddelelse: POC2x16 - Et nyt optimeret plotformat](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Original SIMD-optimeringsforskning, der inspirerede PoCX
- **Shabal-hashalgoritme**: [Saphir-projektet: Shabal, et bidrag til NIST's kryptografiske hashalgoritmekonkurrence](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Teknisk specifikation af Shabal256-algoritmen brugt i PoC-mining

---

[<- Forrige: Introduktion](1-introduction.md) | [Indholdsfortegnelse](index.md) | [Naeste: Konsensus og mining ->](3-consensus-and-mining.md)
