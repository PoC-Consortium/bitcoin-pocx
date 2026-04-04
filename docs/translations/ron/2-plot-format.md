[← Anterior: Introducere](1-introduction.md) | [📘 Cuprins](index.md) | [Următorul: Consens și minerit →](3-consensus-and-mining.md)

---

# Capitolul 2: Specificația formatului plot PoCX

Acest document descrie formatul plot PoCX, o versiune îmbunătățită a formatului POC2 cu securitate îmbunătățită, optimizări SIMD și proof-of-work scalabil.

## Prezentare generală a formatului

Fișierele plot PoCX conțin valori hash Shabal256 precalculate, organizate pentru operațiuni de minerit eficiente. Urmând tradiția PoC de la POC1, **toate metadatele sunt încorporate în numele fișierului** - nu există header de fișier.

### Extensia fișierului
- **Standard**: `.pocx` (plot-uri finalizate)
- **În progres**: `.tmp` (în timpul creării plot-ului, redenumit în `.pocx` la finalizare)

## Context istoric și evoluția vulnerabilităților

### Formatul POC1 (învechit)
**Două vulnerabilități majore (compromisuri timp-memorie):**

1. **Defectul distribuției PoW**
   - Distribuție neuniformă a proof-of-work între scoop-uri
   - Numerele mici de scoop puteau fi calculate din mers
   - **Impact**: Cerințe de stocare reduse pentru atacatori

2. **Atacul de compresie XOR** (compromis timp-memorie de 50%)
   - Exploata proprietăți matematice pentru a obține o reducere de 50% a stocării
   - **Impact**: Atacatorii puteau mina cu jumătate din stocarea necesară

**Optimizare layout**: Layout secvențial de bază al scoop-urilor pentru eficiența HDD

### Formatul POC2 (Burstcoin)
- ✅ **Corectat defectul distribuției PoW**
- ❌ **Vulnerabilitatea XOR-transpose a rămas nerezolvată**
- **Layout**: Menținut optimizarea secvențială a scoop-urilor

### Formatul PoCX (actual)
- ✅ **Distribuție PoW corectată** (moștenită din POC2)
- ✅ **Vulnerabilitatea XOR-transpose rezolvată** (unic pentru PoCX)
- ✅ **Layout SIMD/GPU îmbunătățit** optimizat pentru procesare paralelă și coalescentă memorie
- ✅ **Proof-of-work scalabil** previne compromisurile timp-memorie pe măsură ce puterea de calcul crește (PoW este efectuat doar la crearea sau actualizarea fișierelor plot)

## Codificarea XOR-Transpose

### Problema: compromis timp-memorie de 50%

În formatele POC1/POC2, atacatorii puteau exploata relația matematică între scoop-uri pentru a stoca doar jumătate din date și a calcula restul din mers în timpul mineritului. Acest „atac de compresie XOR" submina garanția de stocare.

### Soluția: întărirea XOR-Transpose

PoCX derivă formatul său de minerit (X1) prin aplicarea codificării XOR-transpose perechilor de warp-uri de bază (X0):

**Pentru a construi scoop-ul S al nonce-ului N într-un warp X1:**
1. Se ia scoop-ul S al nonce-ului N din primul warp X0 (poziție directă)
2. Se ia scoop-ul N al nonce-ului S din al doilea warp X0 (poziție transpusă)
3. Se aplică XOR celor două valori de 64 de octeți pentru a obține scoop-ul X1

Pasul de transpunere schimbă indicii scoop și nonce. În termeni matriciali - unde rândurile reprezintă scoop-uri și coloanele reprezintă nonce-uri - combină elementul de la poziția (S, N) din primul warp cu elementul de la (N, S) din al doilea.

### De ce elimină atacul

XOR-transpose interconectează fiecare scoop cu un rând întreg și o coloană întreagă din datele X0 subiacente. Recuperarea unui singur scoop X1 necesită acces la date care acoperă toți cei 4096 indici de scoop. Orice încercare de a calcula datele lipsă ar necesita regenerarea a 4096 nonce-uri complete în loc de un singur nonce - eliminând structura de cost asimetrică exploatată de atacul XOR.

Ca rezultat, stocarea întregului warp X1 devine singura strategie viabilă computațional pentru mineri.

## Structura metadatelor în numele fișierului

Toate metadatele plot-ului sunt codificate în numele fișierului folosind acest format exact:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Componentele numelui de fișier

1. **ACCOUNT_PAYLOAD** (40 caractere hexazecimale)
   - Payload-ul brut de 20 octeți al contului ca hex majuscule
   - Independent de rețea (fără ID de rețea sau sumă de control)
   - Exemplu: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD0`

2. **SEED** (64 caractere hexazecimale)
   - Valoare seed de 32 de octeți ca hex minuscule
   - **Nou în PoCX**: Seed aleatoriu de 32 de octeți în numele fișierului înlocuiește numerotarea consecutivă a nonce-urilor - previne suprapunerile de plot-uri
   - Exemplu: `C0FFEEBEEFCAFEBABEDEADBEEF1337C0DE42424242FEEDFACECAFED00DABAD1D`

3. **WARPS** (număr zecimal)
   - **Unitate de dimensiune NOUĂ în PoCX**: Înlocuiește dimensionarea bazată pe nonce din POC1/POC2
   - **Design rezistent la XOR-transpose**: Fiecare warp = exact 4096 nonce-uri (dimensiunea partiției necesară pentru transformarea rezistentă la XOR-transpose)
   - **Dimensiune**: 1 warp = 1073741824 octeți = 1 GiB (unitate convenabilă)
   - Exemplu: `1024` (plot de 1 TiB = 1024 warp-uri)

4. **SCALING** (zecimal cu prefix X)
   - Nivel de scalare ca `X{nivel}`
   - Valori mai mari = mai mult proof-of-work necesar
   - Exemplu: `X4` (2^4 = 16× dificultatea POC2)

### Exemple de nume de fișiere
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_C0FFEEBEEFCAFEBABEDEADBEEF1337C0DE42424242FEEDFACECAFED00DABAD1D_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_B00B1E5FEEDC0DEBABEFACE5DEA1DEADC0DE1337C0FFEEBABEFACE5BAD1DEA50_2048_X1.pocx
```


## Aspectul fișierului și structura datelor

### Organizare ierarhică
```
Fișier plot (FĂRĂ HEADER)
├── Scoop 0
│   ├── Warp 0 (Toate nonce-urile pentru acest scoop/warp)
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

### Constante și dimensiuni

| Constantă       | Dimensiune               | Descriere                                       |
| --------------- | ------------------------ | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                    | Ieșirea unui singur hash Shabal256              |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)   | Pereche de hash-uri citită într-o rundă de minerit |
| **NUM\_SCOOPS** | 4096 (2¹²)              | Scoop-uri per nonce; unul selectat per rundă    |
| **NONCE\_SIZE** | 262144 B (256 KiB)      | Toate scoop-urile unui nonce (cea mai mică unitate PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)    | Cea mai mică unitate în PoCX                    |

### Layout optimizat SIMD pentru fișierele plot

PoCX implementează un model de acces la nonce-uri conștient de SIMD care permite procesarea vectorizată a mai multor nonce-uri simultan. Se bazează pe concepte din [cercetarea de optimizare POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) pentru a maximiza throughput-ul memoriei și eficiența SIMD.

---

#### Layout secvențial tradițional

Stocarea secvențială a nonce-urilor:

```
[Nonce 0: Date scoop] [Nonce 1: Date scoop] [Nonce 2: Date scoop] ...
```

Ineficiență SIMD: Fiecare pistă SIMD are nevoie de același cuvânt de la nonce-uri diferite:

```
Cuvânt 0 de la Nonce 0 -> offset 0
Cuvânt 0 de la Nonce 1 -> offset 512
Cuvânt 0 de la Nonce 2 -> offset 1024
...
```

Accesul dispersat-colectat reduce throughput-ul.

---

#### Layout optimizat SIMD PoCX

PoCX stochează **pozițiile cuvintelor de la 16 nonce-uri** contiguu:

```
Linie cache (64 octeți):

Cuvânt0_N0 Cuvânt0_N1 Cuvânt0_N2 ... Cuvânt0_N15
Cuvânt1_N0 Cuvânt1_N1 Cuvânt1_N2 ... Cuvânt1_N15
...
```

**Diagramă ASCII**

```
Layout tradițional:

Nonce0: [C0][C1][C2][C3]...
Nonce1: [C0][C1][C2][C3]...
Nonce2: [C0][C1][C2][C3]...

Layout PoCX:

Cuvânt0: [N0][N1][N2][N3]...[N15]
Cuvânt1: [N0][N1][N2][N3]...[N15]
Cuvânt2: [N0][N1][N2][N3]...[N15]
```

---

#### Beneficiile accesului la memorie

- O linie cache alimentează toate pistele SIMD.
- Elimină operațiunile de dispersare-colectare.
- Reduce ratările de cache.
- Acces complet secvențial la memorie pentru calcul vectorizat.
- GPU-urile beneficiază de asemenea de alinierea la 16 nonce-uri, maximizând eficiența cache-ului.

---

#### Scalarea SIMD

| SIMD       | Lățime vector* | Nonce-uri | Cicluri de procesare per linie cache |
|------------|----------------|-----------|--------------------------------------|
| SSE2/AVX   | 128 biți       | 4         | 4 cicluri                            |
| AVX2       | 256 biți       | 8         | 2 cicluri                            |
| AVX512     | 512 biți       | 16        | 1 ciclu                              |

\* Pentru operații cu numere întregi

---



## Scalarea Proof-of-Work

### Niveluri de scalare
- **X0**: Nonce-uri de bază fără codificare XOR-transpose (teoretic, nu se folosește pentru minerit)
- **X1**: Linia de bază XOR-transpose - primul format întărit (1× muncă)
- **X2**: 2× munca X1 (XOR între 2 warp-uri)
- **X3**: 4× munca X1 (XOR între 4 warp-uri)
- **…**
- **Xn**: 2^(n-1) × munca X1 încorporată

### Beneficii
- **Dificultate PoW ajustabilă**: Crește cerințele computaționale pentru a ține pasul cu hardware-ul mai rapid
- **Longevitatea formatului**: Permite scalarea flexibilă a dificultății mineritului în timp

### Actualizarea plot-urilor / Compatibilitate retroactivă

Când rețeaua crește scala PoW (Proof of Work) cu 1, plot-urile existente necesită o actualizare pentru a menține aceeași dimensiune efectivă a plot-ului. În esență, acum aveți nevoie de dublu PoW în fișierele plot pentru a obține aceeași contribuție la cont.

Vestea bună este că PoW-ul pe care l-ați efectuat deja când ați creat fișierele plot nu se pierde - trebuie doar să adăugați PoW suplimentar la fișierele existente. Nu este nevoie de re-plotare.

Alternativ, puteți continua să folosiți plot-urile actuale fără actualizare, dar rețineți că acestea vor contribui acum doar 50% din dimensiunea lor efectivă anterioară pentru contul dvs. Software-ul de minerit poate scala un fișier plot din mers.

## Comparație cu formatele vechi

| Caracteristică | POC1 | POC2 | PoCX |
|----------------|------|------|------|
| Distribuția PoW | ❌ Defectă | ✅ Corectată | ✅ Corectată |
| Rezistență XOR-Transpose | ❌ Vulnerabilă | ❌ Vulnerabilă | ✅ Corectată |
| Optimizare SIMD | ❌ Fără | ❌ Fără | ✅ Avansată |
| Optimizare GPU | ❌ Fără | ❌ Fără | ✅ Optimizată |
| Proof-of-Work scalabil | ❌ Fără | ❌ Fără | ✅ Da |
| Suport Seed | ❌ Fără | ❌ Fără | ✅ Da |

Formatul PoCX reprezintă starea actuală a tehnicii în formatele de plot Proof of Capacity, adresând toate vulnerabilitățile cunoscute oferind în același timp îmbunătățiri semnificative de performanță pentru hardware-ul modern.

## Referințe și lectură suplimentară

- **Context POC1/POC2**: [Prezentarea generală a mineritului Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Ghid cuprinzător pentru formatele tradiționale de minerit Proof of Capacity
- **Cercetare POC2×16**: [Anunț CIP: POC2×16 - Un nou format de plot optimizat](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Cercetarea originală de optimizare SIMD care a inspirat PoCX
- **Algoritmul hash Shabal**: [Proiectul Saphir: Shabal, o propunere pentru Competiția de Algoritmi Hash Criptografici NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Specificația tehnică a algoritmului Shabal256 folosit în mineritul PoC

---

[← Anterior: Introducere](1-introduction.md) | [📘 Cuprins](index.md) | [Următorul: Consens și minerit →](3-consensus-and-mining.md)
