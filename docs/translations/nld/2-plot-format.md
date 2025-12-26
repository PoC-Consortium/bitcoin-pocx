[Vorige: Inleiding](1-introduction.md) | [Inhoudsopgave](index.md) | [Volgende: Consensus en mining](3-consensus-and-mining.md)

---

# Hoofdstuk 2: PoCX-plotformaatspecificatie

Dit document beschrijft het PoCX-plotformaat, een verbeterde versie van het POC2-formaat met verbeterde beveiliging, SIMD-optimalisaties en schaalbare proof-of-work.

## Formaatoverzicht

PoCX-plotbestanden bevatten vooraf berekende Shabal256-hashwaarden die zijn georganiseerd voor efficiente miningoperaties. In navolging van de PoC-traditie sinds POC1 zijn **alle metadata ingebed in de bestandsnaam** - er is geen bestandsheader.

### Bestandsextensie
- **Standaard**: `.pocx` (voltooide plots)
- **In uitvoering**: `.tmp` (tijdens plotten, hernoemd naar `.pocx` wanneer voltooid)

## Historische context en kwetsbaarheidsontwikkeling

### POC1-formaat (legacy)
**Twee grote kwetsbaarheden (tijd-geheugen-afwegingen):**

1. **PoW-distributiefout**
   - Niet-uniforme verdeling van proof-of-work over scoops
   - Lage scoopnummers konden on-the-fly worden berekend
   - **Impact**: Verminderde opslagvereisten voor aanvallers

2. **XOR-compressie-aanval** (50% tijd-geheugen-afweging)
   - Maakte misbruik van wiskundige eigenschappen om 50% opslagreductie te bereiken
   - **Impact**: Aanvallers konden minen met de helft van de vereiste opslag

**Layout-optimalisatie**: Basis sequentiele scoop-layout voor HDD-efficientie

### POC2-formaat (Burstcoin)
- Gerepareerde PoW-distributiefout
- XOR-transpose-kwetsbaarheid bleef ongepatcht
- **Layout**: Behield sequentiele scoop-optimalisatie

### PoCX-formaat (huidig)
- Gerepareerde PoW-distributie (geerfd van POC2)
- Gepatchte XOR-transpose-kwetsbaarheid (uniek voor PoCX)
- Verbeterde SIMD/GPU-layout geoptimaliseerd voor parallelle verwerking en geheugencoalescentie
- Schaalbare proof-of-work voorkomt tijd-geheugen-afwegingen naarmate rekenkracht groeit (PoW wordt alleen uitgevoerd bij het maken of upgraden van plotbestanden)

## XOR-transpose-codering

### Het probleem: 50% tijd-geheugen-afweging

In POC1/POC2-formaten konden aanvallers de wiskundige relatie tussen scoops misbruiken om slechts de helft van de gegevens op te slaan en de rest on-the-fly te berekenen tijdens het minen. Deze "XOR-compressie-aanval" ondermijnde de opslaggarantie.

### De oplossing: XOR-transpose-verharding

PoCX leidt zijn miningformaat (X1) af door XOR-transpose-codering toe te passen op paren van basis-warps (X0):

**Om scoop S van nonce N te construeren in een X1-warp:**
1. Neem scoop S van nonce N van de eerste X0-warp (directe positie)
2. Neem scoop N van nonce S van de tweede X0-warp (getransponeerde positie)
3. XOR de twee 64-byte waarden om de X1-scoop te verkrijgen

De transpose-stap verwisselt scoop- en nonce-indices. In matrixtermen - waarbij rijen scoops en kolommen nonces vertegenwoordigen - combineert het het element op positie (S, N) in de eerste warp met het element op (N, S) in de tweede.

### Waarom dit de aanval elimineert

De XOR-transpose koppelt elke scoop aan een volledige rij en een volledige kolom van de onderliggende X0-gegevens. Het herstellen van een enkele X1-scoop vereist toegang tot gegevens die alle 4096 scoop-indices omvatten. Elke poging om ontbrekende gegevens te berekenen zou het regenereren van 4096 volledige nonces vereisen in plaats van een enkele nonce - waardoor de asymmetrische kostenstructuur die door de XOR-aanval werd benut, wordt verwijderd.

Als gevolg hiervan wordt het opslaan van de volledige X1-warp de enige rekenkundig haalbare strategie voor miners.

## Bestandsnaam-metadatastructuur

Alle plotmetadata is gecodeerd in de bestandsnaam met dit exacte formaat:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Bestandsnaamcomponenten

1. **ACCOUNT_PAYLOAD** (40 hex-tekens)
   - Ruwe 20-byte account-payload als hoofdletter-hex
   - Netwerk-onafhankelijk (geen netwerk-ID of checksum)
   - Voorbeeld: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex-tekens)
   - 32-byte seed-waarde als kleine letter-hex
   - **Nieuw in PoCX**: Willekeurige 32-byte seed in bestandsnaam vervangt opeenvolgende nonce-nummering - voorkomt plotoverlapping
   - Voorbeeld: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (decimaal getal)
   - **NIEUWE grootte-eenheid in PoCX**: Vervangt nonce-gebaseerde grootte van POC1/POC2
   - **XOR-transpose-resistent ontwerp**: Elke warp = exact 4096 nonces (partitietegrootte vereist voor XOR-transpose-resistente transformatie)
   - **Grootte**: 1 warp = 1073741824 bytes = 1 GiB (handige eenheid)
   - Voorbeeld: `1024` (1 TiB plot = 1024 warps)

4. **SCALING** (X-voorvoegsel decimaal)
   - Schaalniveau als `X{niveau}`
   - Hogere waarden = meer proof-of-work vereist
   - Voorbeeld: `X4` (2^4 = 16x POC2-moeilijkheid)

### Voorbeeldbestandsnamen
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Bestandslayout en gegevensstructuur

### Hierarchische organisatie
```
Plotbestand (GEEN HEADER)
├── Scoop 0
│   ├── Warp 0 (Alle nonces voor deze scoop/warp)
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

### Constanten en groottes

| Constante       | Grootte                 | Beschrijving                                    |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Enkele Shabal256-hash-uitvoer                   |
| **SCOOP\_SIZE** | 64 B (2 x HASH\_SIZE)  | Hashpaar gelezen in een miningronde             |
| **NUM\_SCOOPS** | 4096 (2^12)            | Scoops per nonce; een geselecteerd per ronde    |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Alle scoops van een nonce (kleinste eenheid PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Kleinste eenheid in PoCX                        |

### SIMD-geoptimaliseerde plotbestandslayout

PoCX implementeert een SIMD-bewust nonce-toegangspatroon dat gevectoriseerde verwerking van meerdere nonces tegelijk mogelijk maakt. Het bouwt voort op concepten uit [POC2x16-optimalisatieonderzoek](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) om geheugendoorvoer en SIMD-efficientie te maximaliseren.

---

#### Traditionele sequentiele layout

Sequentiele opslag van nonces:

```
[Nonce 0: Scoop-gegevens] [Nonce 1: Scoop-gegevens] [Nonce 2: Scoop-gegevens] ...
```

SIMD-inefficientie: Elke SIMD-lane heeft hetzelfde woord nodig over nonces:

```
Woord 0 van Nonce 0 -> offset 0
Woord 0 van Nonce 1 -> offset 512
Woord 0 van Nonce 2 -> offset 1024
...
```

Scatter-gather-toegang vermindert doorvoer.

---

#### PoCX SIMD-geoptimaliseerde layout

PoCX slaat **woordposities over 16 nonces** aaneengesloten op:

```
Cacheregel (64 bytes):

Woord0_N0 Woord0_N1 Woord0_N2 ... Woord0_N15
Woord1_N0 Woord1_N1 Woord1_N2 ... Woord1_N15
...
```

**ASCII-diagram**

```
Traditionele layout:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX-layout:

Woord0: [N0][N1][N2][N3]...[N15]
Woord1: [N0][N1][N2][N3]...[N15]
Woord2: [N0][N1][N2][N3]...[N15]
```

---

#### Voordelen van geheugentoegang

- Een cacheregel levert alle SIMD-lanes.
- Elimineert scatter-gather-operaties.
- Vermindert cache-misses.
- Volledig sequentiele geheugentoegang voor gevectoriseerde berekening.
- GPU's profiteren ook van 16-nonce-uitlijning, wat cache-efficientie maximaliseert.

---

#### SIMD-schaling

| SIMD       | Vectorbreedte* | Nonces | Verwerkingscycli per cacheregel |
|------------|----------------|--------|--------------------------------|
| SSE2/AVX   | 128-bit        | 4      | 4 cycli                        |
| AVX2       | 256-bit        | 8      | 2 cycli                        |
| AVX512     | 512-bit        | 16     | 1 cyclus                       |

\* Voor integer-operaties

---



## Proof-of-Work-schaling

### Schaalniveaus
- **X0**: Basisnonces zonder XOR-transpose-codering (theoretisch, niet gebruikt voor mining)
- **X1**: XOR-transpose-basislijn - eerste verharde formaat (1x werk)
- **X2**: 2x X1-werk (XOR over 2 warps)
- **X3**: 4x X1-werk (XOR over 4 warps)
- **...**
- **Xn**: 2^(n-1) x X1-werk ingebed

### Voordelen
- **Aanpasbare PoW-moeilijkheid**: Verhoogt rekenvereisten om gelijke tred te houden met snellere hardware
- **Formaat-levensduur**: Maakt flexibele schaling van miningmoeilijkheid mogelijk na verloop van tijd

### Plotupgrade / achterwaartse compatibiliteit

Wanneer het netwerk de PoW (Proof of Work)-schaal met 1 verhoogt, vereisen bestaande plots een upgrade om dezelfde effectieve plotgrootte te behouden. In wezen hebt u nu tweemaal de PoW in uw plotbestanden nodig om dezelfde bijdrage aan uw account te bereiken.

Het goede nieuws is dat de PoW die u al hebt voltooid bij het maken van uw plotbestanden niet verloren gaat - u hoeft alleen extra PoW toe te voegen aan de bestaande bestanden. Niet opnieuw plotten nodig.

Als alternatief kunt u uw huidige plots blijven gebruiken zonder te upgraden, maar houd er rekening mee dat ze nu slechts 50% van hun vorige effectieve grootte bijdragen aan uw account. Uw miningsoftware kan een plotbestand on-the-fly schalen.

## Vergelijking met legacy-formaten

| Functie | POC1 | POC2 | PoCX |
|---------|------|------|------|
| PoW-distributie | Gebrekkig | Gerepareerd | Gerepareerd |
| XOR-transpose-weerstand | Kwetsbaar | Kwetsbaar | Gerepareerd |
| SIMD-optimalisatie | Geen | Geen | Geavanceerd |
| GPU-optimalisatie | Geen | Geen | Geoptimaliseerd |
| Schaalbare Proof-of-Work | Geen | Geen | Ja |
| Seed-ondersteuning | Geen | Geen | Ja |

Het PoCX-formaat vertegenwoordigt de huidige state-of-the-art in Proof of Capacity-plotformaten, waarbij alle bekende kwetsbaarheden worden aangepakt terwijl significante prestatieverbeteringen voor moderne hardware worden geboden.

## Referenties en verdere lectuur

- **POC1/POC2-achtergrond**: [Burstcoin Mining Overview](https://www.burstcoin.community/burstcoin-mining/) - Uitgebreide handleiding voor traditionele Proof of Capacity-miningformaten
- **POC2x16-onderzoek**: [CIP Announcement: POC2x16 - A new optimized plot format](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Origineel SIMD-optimalisatieonderzoek dat PoCX inspireerde
- **Shabal-hashalgoritme**: [The Saphir Project: Shabal, a Submission to NIST's Cryptographic Hash Algorithm Competition](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Technische specificatie van het Shabal256-algoritme dat wordt gebruikt in PoC-mining

---

[Vorige: Inleiding](1-introduction.md) | [Inhoudsopgave](index.md) | [Volgende: Consensus en mining](3-consensus-and-mining.md)
