[← Precedente: Introduzione](1-introduction.md) | [Indice](index.md) | [Successivo: Consenso e mining →](3-consensus-and-mining.md)

---

# Capitolo 2: Specifica del formato plot PoCX

Questo documento descrive il formato plot PoCX, una versione migliorata del formato POC2 con sicurezza rafforzata, ottimizzazioni SIMD e proof-of-work scalabile.

## Panoramica del formato

I file plot PoCX contengono valori hash Shabal256 pre-calcolati, organizzati per operazioni di mining efficienti. Seguendo la tradizione PoC fin da POC1, **tutti i metadati sono incorporati nel nome del file** - non c'è header del file.

### Estensione del file
- **Standard**: `.pocx` (plot completati)
- **In corso**: `.tmp` (durante il plotting, rinominato in `.pocx` al completamento)

## Contesto storico ed evoluzione delle vulnerabilità

### Formato POC1 (Legacy)
**Due vulnerabilità principali (compromessi tempo-memoria):**

1. **Difetto nella distribuzione del PoW**
   - Distribuzione non uniforme del proof-of-work tra gli scoop
   - I numeri di scoop bassi potevano essere calcolati al volo
   - **Impatto**: Requisiti di storage ridotti per gli attaccanti

2. **Attacco di compressione XOR** (compromesso tempo-memoria del 50%)
   - Sfruttava proprietà matematiche per ottenere una riduzione dello storage del 50%
   - **Impatto**: Gli attaccanti potevano minare con la metà dello storage richiesto

**Ottimizzazione del layout**: Layout sequenziale base degli scoop per l'efficienza degli HDD

### Formato POC2 (Burstcoin)
- ✅ **Corretto il difetto nella distribuzione del PoW**
- ❌ **La vulnerabilità XOR-transpose è rimasta non corretta**
- **Layout**: Mantenuta l'ottimizzazione sequenziale degli scoop

### Formato PoCX (Attuale)
- ✅ **Distribuzione del PoW corretta** (ereditata da POC2)
- ✅ **Vulnerabilità XOR-transpose corretta** (esclusiva di PoCX)
- ✅ **Layout SIMD/GPU migliorato** ottimizzato per l'elaborazione parallela e la coalescenza della memoria
- ✅ **Proof-of-work scalabile** previene i compromessi tempo-memoria man mano che la potenza di calcolo cresce (il PoW viene eseguito solo durante la creazione o l'aggiornamento dei file plot)

## Codifica XOR-Transpose

### Il problema: compromesso tempo-memoria del 50%

Nei formati POC1/POC2, gli attaccanti potevano sfruttare la relazione matematica tra gli scoop per memorizzare solo la metà dei dati e calcolare il resto al volo durante il mining. Questo "attacco di compressione XOR" minava la garanzia di storage.

### La soluzione: rafforzamento XOR-Transpose

PoCX deriva il suo formato di mining (X1) applicando la codifica XOR-transpose a coppie di warp base (X0):

**Per costruire lo scoop S del nonce N in un warp X1:**
1. Prendere lo scoop S del nonce N dal primo warp X0 (posizione diretta)
2. Prendere lo scoop N del nonce S dal secondo warp X0 (posizione trasposta)
3. Effettuare lo XOR dei due valori da 64 byte per ottenere lo scoop X1

Il passo di trasposizione scambia gli indici di scoop e nonce. In termini matriciali, dove le righe rappresentano gli scoop e le colonne rappresentano i nonce, combina l'elemento alla posizione (S, N) nel primo warp con l'elemento alla posizione (N, S) nel secondo.

### Perché questo elimina l'attacco

La codifica XOR-transpose interconnette ogni scoop con un'intera riga e un'intera colonna dei dati X0 sottostanti. Recuperare un singolo scoop X1 richiede l'accesso a dati che coprono tutti i 4096 indici di scoop. Qualsiasi tentativo di calcolare i dati mancanti richiederebbe la rigenerazione di 4096 nonce completi anziché un singolo nonce, eliminando la struttura dei costi asimmetrica sfruttata dall'attacco XOR.

Di conseguenza, memorizzare l'intero warp X1 diventa l'unica strategia computazionalmente praticabile per i miner.

## Struttura dei metadati nel nome del file

Tutti i metadati del plot sono codificati nel nome del file usando questo formato esatto:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Componenti del nome file

1. **ACCOUNT_PAYLOAD** (40 caratteri esadecimali)
   - Payload account raw da 20 byte come hex maiuscolo
   - Indipendente dalla rete (nessun ID di rete o checksum)
   - Esempio: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 caratteri esadecimali)
   - Valore seed da 32 byte come hex minuscolo
   - **Novità in PoCX**: Seed random da 32 byte nel nome del file sostituisce la numerazione consecutiva dei nonce - previene le sovrapposizioni dei plot
   - Esempio: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (numero decimale)
   - **Nuova unità di dimensione in PoCX**: Sostituisce la dimensione basata sui nonce da POC1/POC2
   - **Design resistente a XOR-transpose**: Ogni warp = esattamente 4096 nonce (dimensione della partizione richiesta per la trasformazione resistente a XOR-transpose)
   - **Dimensione**: 1 warp = 1073741824 byte = 1 GiB (unità conveniente)
   - Esempio: `1024` (1 TiB plot = 1024 warp)

4. **SCALING** (decimale con prefisso X)
   - Livello di scaling come `X{livello}`
   - Valori più alti = più proof-of-work richiesto
   - Esempio: `X4` (2^4 = 16× difficoltà POC2)

### Esempi di nomi file
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Layout del file e struttura dei dati

### Organizzazione gerarchica
```
File Plot (NESSUN HEADER)
├── Scoop 0
│   ├── Warp 0 (Tutti i nonce per questo scoop/warp)
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

### Costanti e dimensioni

| Costante        | Dimensione              | Descrizione                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Singolo output hash Shabal256                   |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Coppia di hash letta in un round di mining      |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoop per nonce; uno selezionato per round      |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Tutti gli scoop di un nonce (unità minima PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Unità minima in PoCX                            |

### Layout del file plot ottimizzato per SIMD

PoCX implementa un pattern di accesso ai nonce consapevole di SIMD che consente l'elaborazione vettorizzata di più nonce simultaneamente. Si basa sui concetti della [ricerca sull'ottimizzazione POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) per massimizzare il throughput di memoria e l'efficienza SIMD.

---

#### Layout sequenziale tradizionale

Memorizzazione sequenziale dei nonce:

```
[Nonce 0: Dati Scoop] [Nonce 1: Dati Scoop] [Nonce 2: Dati Scoop] ...
```

Inefficienza SIMD: Ogni lane SIMD necessita della stessa word tra i nonce:

```
Word 0 da Nonce 0 -> offset 0
Word 0 da Nonce 1 -> offset 512
Word 0 da Nonce 2 -> offset 1024
...
```

L'accesso scatter-gather riduce il throughput.

---

#### Layout PoCX ottimizzato per SIMD

PoCX memorizza le **posizioni delle word attraverso 16 nonce** in modo contiguo:

```
Cache Line (64 byte):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**Diagramma ASCII**

```
Layout tradizionale:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Layout PoCX:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Benefici dell'accesso alla memoria

- Una cache line fornisce dati a tutte le lane SIMD.
- Elimina le operazioni scatter-gather.
- Riduce i cache miss.
- Accesso alla memoria completamente sequenziale per il calcolo vettorizzato.
- Anche le GPU beneficiano dell'allineamento a 16 nonce, massimizzando l'efficienza della cache.

---

#### Scaling SIMD

| SIMD       | Larghezza vettore* | Nonce | Cicli di elaborazione per cache line |
|------------|-------------------|-------|--------------------------------------|
| SSE2/AVX   | 128-bit           | 4     | 4 cicli                              |
| AVX2       | 256-bit           | 8     | 2 cicli                              |
| AVX512     | 512-bit           | 16    | 1 ciclo                              |

\* Per operazioni su interi

---



## Scaling del Proof-of-Work

### Livelli di scaling
- **X0**: Nonce base senza codifica XOR-transpose (teorico, non usato per il mining)
- **X1**: Baseline XOR-transpose - primo formato rafforzato (1× lavoro)
- **X2**: 2× lavoro X1 (XOR tra 2 warp)
- **X3**: 4× lavoro X1 (XOR tra 4 warp)
- **...**
- **Xn**: 2^(n-1) × lavoro X1 incorporato

### Benefici
- **Difficoltà PoW regolabile**: Aumenta i requisiti computazionali per stare al passo con hardware più veloce
- **Longevità del formato**: Consente lo scaling flessibile della difficoltà di mining nel tempo

### Aggiornamento dei plot / Retrocompatibilità

Quando la rete aumenta la scala PoW (Proof of Work) di 1, i plot esistenti richiedono un aggiornamento per mantenere la stessa dimensione effettiva del plot. Essenzialmente, ora è necessario il doppio del PoW nei file plot per ottenere lo stesso contributo al proprio account.

La buona notizia è che il PoW già completato durante la creazione dei file plot non viene perso - è sufficiente aggiungere PoW aggiuntivo ai file esistenti. Non c'è bisogno di ricreare i plot.

In alternativa, è possibile continuare a usare i plot attuali senza aggiornarli, ma si noti che ora contribuiranno solo per il 50% della loro precedente dimensione effettiva verso il proprio account. Il software di mining può scalare un file plot al volo.

## Confronto con i formati legacy

| Caratteristica | POC1 | POC2 | PoCX |
|----------------|------|------|------|
| Distribuzione PoW | ❌ Difettosa | ✅ Corretta | ✅ Corretta |
| Resistenza XOR-Transpose | ❌ Vulnerabile | ❌ Vulnerabile | ✅ Corretta |
| Ottimizzazione SIMD | ❌ Nessuna | ❌ Nessuna | ✅ Avanzata |
| Ottimizzazione GPU | ❌ Nessuna | ❌ Nessuna | ✅ Ottimizzata |
| Proof-of-Work scalabile | ❌ Nessuno | ❌ Nessuno | ✅ Sì |
| Supporto seed | ❌ Nessuno | ❌ Nessuno | ✅ Sì |

Il formato PoCX rappresenta lo stato dell'arte attuale nei formati plot Proof of Capacity, affrontando tutte le vulnerabilità note e fornendo al contempo significativi miglioramenti delle prestazioni per l'hardware moderno.

## Riferimenti e approfondimenti

- **Background POC1/POC2**: [Panoramica del mining Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Guida completa ai formati tradizionali di mining Proof of Capacity
- **Ricerca POC2×16**: [Annuncio CIP: POC2×16 - Un nuovo formato plot ottimizzato](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Ricerca originale sull'ottimizzazione SIMD che ha ispirato PoCX
- **Algoritmo hash Shabal**: [Il progetto Saphir: Shabal, una submission alla competizione per algoritmi hash crittografici del NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Specifica tecnica dell'algoritmo Shabal256 usato nel mining PoC

---

[← Precedente: Introduzione](1-introduction.md) | [Indice](index.md) | [Successivo: Consenso e mining →](3-consensus-and-mining.md)
