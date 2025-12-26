[Indice](index.md) | [Successivo: Formato dei plot →](2-plot-format.md)

---

# Capitolo 1: Introduzione e panoramica

## Cos'è Bitcoin-PoCX?

Bitcoin-PoCX è un'integrazione di Bitcoin Core che aggiunge il supporto al consenso **Proof of Capacity neXt generation (PoCX)**. Mantiene l'architettura esistente di Bitcoin Core abilitando al contempo un'alternativa di mining energeticamente efficiente basata su Proof of Capacity come sostituzione completa del Proof of Work.

**Distinzione fondamentale**: Questa è una **nuova catena** senza retrocompatibilità con Bitcoin PoW. I blocchi PoCX sono incompatibili con i nodi PoW per progettazione.

---

## Identità del progetto

- **Organizzazione**: Proof of Capacity Consortium
- **Nome del progetto**: Bitcoin-PoCX
- **Nome completo**: Bitcoin Core con integrazione PoCX
- **Stato**: Fase Testnet

---

## Cos'è il Proof of Capacity?

Il Proof of Capacity (PoC) è un meccanismo di consenso in cui la potenza di mining è proporzionale allo **spazio su disco** anziché alla potenza computazionale. I miner pre-generano grandi file plot contenenti hash crittografici, poi utilizzano questi plot per trovare soluzioni valide per i blocchi.

**Efficienza energetica**: I file plot vengono generati una sola volta e riutilizzati indefinitamente. Il mining consuma una potenza CPU minima, principalmente I/O su disco.

**Miglioramenti PoCX**:
- Correzione dell'attacco di compressione XOR-transpose (compromesso tempo-memoria del 50% in POC2)
- Layout allineato a 16 nonce per hardware moderno
- Proof-of-work scalabile nella generazione dei plot (livelli di scaling Xn)
- Integrazione nativa in C++ direttamente in Bitcoin Core
- Algoritmo Time Bending per una migliore distribuzione dei tempi di blocco

---

## Panoramica dell'architettura

### Struttura del repository

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integrazione PoCX
│   └── src/pocx/        # Implementazione PoCX
├── pocx/                # Framework core PoCX (sottomodulo, sola lettura)
└── docs/                # Questa documentazione
```

### Filosofia di integrazione

**Superficie di integrazione minima**: Le modifiche sono isolate nella directory `/src/pocx/` con hook puliti nei layer di validazione, mining e RPC di Bitcoin Core.

**Feature flagging**: Tutte le modifiche sono sotto le guardie del preprocessore `#ifdef ENABLE_POCX`. Bitcoin Core si compila normalmente quando disabilitato.

**Compatibilità upstream**: La sincronizzazione regolare con gli aggiornamenti di Bitcoin Core è mantenuta attraverso punti di integrazione isolati.

**Implementazione nativa in C++**: Gli algoritmi crittografici scalari (Shabal256, calcolo degli scoop, compressione) sono integrati direttamente in Bitcoin Core per la validazione del consenso.

---

## Caratteristiche principali

### 1. Sostituzione completa del consenso

- **Struttura dei blocchi**: Campi specifici PoCX sostituiscono nonce PoW e difficulty bits
  - Generation signature (entropia deterministica per il mining)
  - Base target (inverso della difficoltà)
  - Prova PoCX (account ID, seed, nonce)
  - Firma del blocco (dimostra la proprietà del plot)

- **Validazione**: Pipeline di validazione a 5 stadi dal controllo dell'header alla connessione del blocco

- **Regolazione della difficoltà**: Regolazione ad ogni blocco usando la media mobile dei base target recenti

### 2. Algoritmo Time Bending

**Problema**: I tempi di blocco PoC tradizionali seguono una distribuzione esponenziale, portando a blocchi lunghi quando nessun miner trova una buona soluzione.

**Soluzione**: Trasformazione della distribuzione da esponenziale a chi-quadrato usando la radice cubica: `Y = scala × (X^(1/3))`.

**Effetto**: Soluzioni molto buone vengono forgiate più tardi (la rete ha tempo di scansionare tutti i dischi, riducendo i blocchi veloci), le soluzioni scadenti vengono migliorate. Il tempo medio di blocco viene mantenuto a 120 secondi, i blocchi lunghi vengono ridotti.

**Dettagli**: [Capitolo 3: Consenso e mining](3-consensus-and-mining.md)

### 3. Sistema di assegnazione del forging

**Capacità**: I proprietari dei plot possono delegare i diritti di forging ad altri indirizzi mantenendo la proprietà del plot.

**Casi d'uso**:
- Mining in pool (i plot vengono assegnati all'indirizzo del pool)
- Cold storage (chiave di mining separata dalla proprietà del plot)
- Mining multi-party (infrastruttura condivisa)

**Architettura**: Progettazione solo OP_RETURN, nessun UTXO speciale, le assegnazioni sono tracciate separatamente nel database chainstate.

**Dettagli**: [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md)

### 4. Forging difensivo

**Problema**: Gli orologi veloci potrebbero fornire vantaggi temporali entro la tolleranza futura di 15 secondi.

**Soluzione**: Quando si riceve un blocco concorrente alla stessa altezza, viene automaticamente controllata la qualità locale. Se migliore, si forgia immediatamente.

**Effetto**: Elimina l'incentivo alla manipolazione dell'orologio, gli orologi veloci aiutano solo se si ha già la soluzione migliore.

**Dettagli**: [Capitolo 5: Sicurezza temporale](5-timing-security.md)

### 5. Scaling dinamico della compressione

**Allineamento economico**: I requisiti del livello di scaling aumentano secondo un programma esponenziale (Anni 4, 12, 28, 60, 124 = halving 1, 3, 7, 15, 31).

**Effetto**: Man mano che le ricompense dei blocchi diminuiscono, la difficoltà di generazione dei plot aumenta. Mantiene il margine di sicurezza tra i costi di creazione e lookup dei plot.

**Previene**: L'inflazione della capacità dovuta a hardware più veloce nel tempo.

**Dettagli**: [Capitolo 6: Parametri di rete](6-network-parameters.md)

---

## Filosofia di progettazione

### Sicurezza del codice

- Pratiche di programmazione difensiva in tutto il codice
- Gestione completa degli errori nei percorsi di validazione
- Nessun lock annidato (prevenzione del deadlock)
- Operazioni atomiche sul database (UTXO + assegnazioni insieme)

### Architettura modulare

- Separazione netta tra l'infrastruttura di Bitcoin Core e il consenso PoCX
- Il framework core PoCX fornisce le primitive crittografiche
- Bitcoin Core fornisce il framework di validazione, database, networking

### Ottimizzazioni delle prestazioni

- Ordinamento della validazione fail-fast (controlli economici prima)
- Singolo fetch del contesto per submission (nessuna acquisizione ripetuta di cs_main)
- Operazioni atomiche sul database per la consistenza

### Sicurezza nelle riorganizzazioni

- Dati di undo completi per le modifiche dello stato delle assegnazioni
- Reset dello stato di forging sui cambiamenti del tip della catena
- Rilevamento dell'obsolescenza in tutti i punti di validazione

---

## Differenze tra PoCX e Proof of Work

| Aspetto | Bitcoin (PoW) | Bitcoin-PoCX |
|---------|---------------|--------------|
| **Risorsa di mining** | Potenza computazionale (hash rate) | Spazio su disco (capacità) |
| **Consumo energetico** | Alto (hashing continuo) | Basso (solo I/O su disco) |
| **Processo di mining** | Trovare nonce con hash < target | Trovare nonce con deadline < tempo trascorso |
| **Difficoltà** | Campo `bits`, regolato ogni 2016 blocchi | Campo `base_target`, regolato ogni blocco |
| **Tempo di blocco** | ~10 minuti (distribuzione esponenziale) | 120 secondi (time-bended, varianza ridotta) |
| **Sussidio** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Hardware** | ASIC (specializzato) | HDD (hardware commodity) |
| **Identità del mining** | Anonimo | Proprietario del plot o delegato |

---

## Requisiti di sistema

### Operazione del nodo

**Come Bitcoin Core**:
- **CPU**: Processore x86_64 moderno
- **Memoria**: 4-8 GB RAM
- **Storage**: Nuova catena, attualmente vuota (può crescere ~4× più velocemente di Bitcoin a causa dei blocchi da 2 minuti e del database delle assegnazioni)
- **Rete**: Connessione internet stabile
- **Orologio**: Sincronizzazione NTP raccomandata per un funzionamento ottimale

**Nota**: I file plot NON sono richiesti per l'operazione del nodo.

### Requisiti per il mining

**Requisiti aggiuntivi per il mining**:
- **File plot**: Pre-generati usando `pocx_plotter` (implementazione di riferimento)
- **Software miner**: `pocx_miner` (implementazione di riferimento) si connette via RPC
- **Wallet**: `bitcoind` o `bitcoin-qt` con chiavi private per l'indirizzo di mining. Il mining in pool non richiede un wallet locale.

---

## Per iniziare

### 1. Compilare Bitcoin-PoCX

```bash
# Clonare con i sottomoduli
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Compilare con PoCX abilitato
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Dettagli**: Vedere `CLAUDE.md` nella directory principale del repository

### 2. Eseguire il nodo

**Solo nodo**:
```bash
./build/bin/bitcoind
# oppure
./build/bin/bitcoin-qt
```

**Per il mining** (abilita l'accesso RPC per miner esterni):
```bash
./build/bin/bitcoind -miningserver
# oppure
./build/bin/bitcoin-qt -server -miningserver
```

**Dettagli**: [Capitolo 6: Parametri di rete](6-network-parameters.md)

### 3. Generare i file plot

Usare `pocx_plotter` (implementazione di riferimento) per generare file plot in formato PoCX.

**Dettagli**: [Capitolo 2: Formato dei plot](2-plot-format.md)

### 4. Configurare il mining

Usare `pocx_miner` (implementazione di riferimento) per connettersi all'interfaccia RPC del nodo.

**Dettagli**: [Capitolo 7: Riferimento RPC](7-rpc-reference.md) e [Capitolo 8: Guida al wallet](8-wallet-guide.md)

---

## Attribuzione

### Formato dei plot

Basato sul formato POC2 (Burstcoin) con miglioramenti:
- Corretta la falla di sicurezza (attacco di compressione XOR-transpose)
- Proof-of-work scalabile
- Layout ottimizzato per SIMD
- Funzionalità seed

### Progetti sorgente

- **pocx_miner**: Implementazione di riferimento basata su [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementazione di riferimento basata su [engraver](https://github.com/PoC-Consortium/engraver)

**Attribuzione completa**: [Capitolo 2: Formato dei plot](2-plot-format.md)

---

## Riepilogo delle specifiche tecniche

- **Tempo di blocco**: 120 secondi (mainnet), 1 secondo (regtest)
- **Sussidio di blocco**: 10 BTC iniziali, halving ogni 1050000 blocchi (~4 anni)
- **Offerta totale**: ~21 milioni di BTC (come Bitcoin)
- **Tolleranza futura**: 15 secondi (blocchi fino a 15s in anticipo accettati)
- **Avviso orologio**: 10 secondi (avvisa gli operatori della deriva temporale)
- **Ritardo assegnazione**: 30 blocchi (~1 ora)
- **Ritardo revoca**: 720 blocchi (~24 ore)
- **Formato indirizzi**: Solo P2WPKH (bech32, pocx1q...) per operazioni di mining PoCX e assegnazioni di forging

---

## Organizzazione del codice

**Modifiche a Bitcoin Core**: Modifiche minime ai file core, contrassegnate con `#ifdef ENABLE_POCX`

**Nuova implementazione PoCX**: Isolata nella directory `src/pocx/`

---

## Considerazioni sulla sicurezza

### Sicurezza temporale

- La tolleranza futura di 15 secondi previene la frammentazione della rete
- La soglia di avviso di 10 secondi allerta gli operatori sulla deriva dell'orologio
- Il forging difensivo elimina l'incentivo alla manipolazione dell'orologio
- Il Time Bending riduce l'impatto della varianza temporale

**Dettagli**: [Capitolo 5: Sicurezza temporale](5-timing-security.md)

### Sicurezza delle assegnazioni

- Progettazione solo OP_RETURN (nessuna manipolazione di UTXO)
- La firma della transazione dimostra la proprietà del plot
- I ritardi di attivazione prevengono la manipolazione rapida dello stato
- Dati di undo sicuri per le riorganizzazioni per tutte le modifiche di stato

**Dettagli**: [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md)

### Sicurezza del consenso

- La firma è esclusa dall'hash del blocco (previene la malleabilità)
- Dimensioni delle firme limitate (previene DoS)
- Validazione dei limiti di compressione (previene prove deboli)
- Regolazione della difficoltà ad ogni blocco (reattiva ai cambiamenti di capacità)

**Dettagli**: [Capitolo 3: Consenso e mining](3-consensus-and-mining.md)

---

## Stato della rete

**Mainnet**: Non ancora lanciata
**Testnet**: Disponibile per i test
**Regtest**: Completamente funzionale per lo sviluppo

**Parametri del blocco genesis**: [Capitolo 6: Parametri di rete](6-network-parameters.md)

---

## Prossimi passi

**Per comprendere PoCX**: Continuare con il [Capitolo 2: Formato dei plot](2-plot-format.md) per apprendere la struttura dei file plot e l'evoluzione del formato.

**Per la configurazione del mining**: Passare al [Capitolo 7: Riferimento RPC](7-rpc-reference.md) per i dettagli sull'integrazione.

**Per eseguire un nodo**: Consultare il [Capitolo 6: Parametri di rete](6-network-parameters.md) per le opzioni di configurazione.

---

[Indice](index.md) | [Successivo: Formato dei plot →](2-plot-format.md)
