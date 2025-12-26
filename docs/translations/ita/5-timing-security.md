[← Precedente: Assegnazioni di forging](4-forging-assignments.md) | [Indice](index.md) | [Successivo: Parametri di rete →](6-network-parameters.md)

---

# Capitolo 5: Sincronizzazione temporale e sicurezza

## Panoramica

Il consenso PoCX richiede una sincronizzazione temporale precisa attraverso la rete. Questo capitolo documenta i meccanismi di sicurezza relativi al tempo, la tolleranza alla deriva dell'orologio e il comportamento del forging difensivo.

**Meccanismi chiave**:
- Tolleranza futura di 15 secondi per i timestamp dei blocchi
- Sistema di avviso per deriva dell'orologio di 10 secondi
- Forging difensivo (anti-manipolazione dell'orologio)
- Integrazione dell'algoritmo Time Bending

---

## Indice

1. [Requisiti di sincronizzazione temporale](#requisiti-di-sincronizzazione-temporale)
2. [Rilevamento e avvisi sulla deriva dell'orologio](#rilevamento-e-avvisi-sulla-deriva-dellorologio)
3. [Meccanismo di forging difensivo](#meccanismo-di-forging-difensivo)
4. [Analisi delle minacce alla sicurezza](#analisi-delle-minacce-alla-sicurezza)
5. [Best practice per gli operatori di nodi](#best-practice-per-gli-operatori-di-nodi)

---

## Requisiti di sincronizzazione temporale

### Costanti e parametri

**Configurazione Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 secondi

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 secondi
```

### Controlli di validazione

**Validazione del timestamp del blocco** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Controllo monotonico: timestamp >= timestamp del blocco precedente
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Controllo futuro: timestamp <= ora + 15 secondi
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Controllo deadline: tempo trascorso >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabella impatto della deriva dell'orologio

| Offset orologio | Può sincronizzarsi? | Può minare? | Stato validazione | Effetto competitivo |
|-----------------|---------------------|-------------|-------------------|---------------------|
| -30s lento | NO - Controllo futuro fallisce | N/A | **NODO MORTO** | Non può partecipare |
| -14s lento | Sì | Sì | Forging in ritardo, passa validazione | Perde le competizioni |
| 0s perfetto | Sì | Sì | Ottimale | Ottimale |
| +14s veloce | Sì | Sì | Forging anticipato, passa validazione | Vince le competizioni |
| +16s veloce | Sì | NO - Controllo futuro fallisce | Non può propagare blocchi | Può sincronizzare, non può minare |

**Intuizione chiave**: La finestra di 15 secondi è simmetrica per la partecipazione (±14,9s), ma gli orologi veloci forniscono un vantaggio competitivo ingiusto entro la tolleranza.

### Integrazione del Time Bending

L'algoritmo Time Bending (dettagliato nel [Capitolo 3](3-consensus-and-mining.md#calcolo-del-time-bending)) trasforma le deadline raw usando la radice cubica:

```
time_bended_deadline = scala × (deadline_seconds)^(1/3)
```

**Interazione con la deriva dell'orologio**:
- Le soluzioni migliori forgiano prima (la radice cubica amplifica le differenze di qualità)
- La deriva dell'orologio influisce sul tempo di forging relativo alla rete
- Il forging difensivo assicura la competizione basata sulla qualità nonostante la varianza temporale

---

## Rilevamento e avvisi sulla deriva dell'orologio

### Sistema di avviso

Bitcoin-PoCX monitora l'offset temporale tra il nodo locale e i peer della rete.

**Messaggio di avviso** (quando la deriva supera i 10 secondi):
> "La data e l'ora del tuo computer sembrano essere sfasate di più di 10 secondi rispetto alla rete, questo potrebbe portare a fallimenti del consenso PoCX. Per favore controlla l'orologio di sistema."

**Implementazione**: `src/node/timeoffsets.cpp`

### Motivazione del design

**Perché 10 secondi?**
- Fornisce un buffer di sicurezza di 5 secondi prima del limite di tolleranza di 15 secondi
- Più rigoroso del default di Bitcoin Core (10 minuti)
- Appropriato per i requisiti di timing del PoC

**Approccio preventivo**:
- Avviso anticipato prima del fallimento critico
- Permette agli operatori di risolvere i problemi proattivamente
- Riduce la frammentazione della rete da fallimenti legati al tempo

---

## Meccanismo di forging difensivo

### Cos'è

Il forging difensivo è un comportamento standard del miner in Bitcoin-PoCX che elimina i vantaggi basati sul timing nella produzione dei blocchi. Quando il tuo miner riceve un blocco concorrente alla stessa altezza, controlla automaticamente se hai una soluzione migliore. In caso affermativo, forgia immediatamente il tuo blocco, assicurando una competizione basata sulla qualità piuttosto che sulla manipolazione dell'orologio.

### Il problema

Il consenso PoCX permette blocchi con timestamp fino a 15 secondi nel futuro. Questa tolleranza è necessaria per la sincronizzazione globale della rete. Tuttavia, crea un'opportunità per la manipolazione dell'orologio:

**Senza forging difensivo:**
- Miner A: Tempo corretto, qualità 800 (migliore), attende la deadline corretta
- Miner B: Orologio veloce (+14s), qualità 1000 (peggiore), forgia 14 secondi prima
- Risultato: Miner B vince la competizione nonostante un lavoro proof-of-capacity inferiore

**Il problema:** La manipolazione dell'orologio fornisce un vantaggio anche con qualità peggiore, minando il principio del proof-of-capacity.

### La soluzione: difesa a due livelli

#### Livello 1: Avviso sulla deriva dell'orologio (preventivo)

Bitcoin-PoCX monitora l'offset temporale tra il tuo nodo e i peer della rete. Se il tuo orologio deriva di più di 10 secondi dal consenso della rete, ricevi un avviso che ti avvisa di risolvere i problemi dell'orologio prima che causino problemi.

#### Livello 2: Forging difensivo (reattivo)

Quando un altro miner pubblica un blocco alla stessa altezza che stai minando:

1. **Rilevamento**: Il tuo nodo identifica la competizione alla stessa altezza
2. **Validazione**: Estrae e valida la qualità del blocco concorrente
3. **Confronto**: Controlla se la tua qualità è migliore
4. **Risposta**: Se migliore, forgia immediatamente il tuo blocco

**Risultato:** La rete riceve entrambi i blocchi e sceglie quello con la migliore qualità attraverso la risoluzione standard dei fork.

### Come funziona

#### Scenario: competizione alla stessa altezza

```
Tempo 150s: Miner B (orologio +10s) forgia con qualità 1000
           → Il timestamp del blocco mostra 160s (10s nel futuro)

Tempo 150s: Il tuo nodo riceve il blocco di Miner B
           → Rileva: stessa altezza, qualità 1000
           → Tu hai: qualità 800 (migliore!)
           → Azione: Forgia immediatamente con timestamp corretto (150s)

Tempo 152s: La rete valida entrambi i blocchi
           → Entrambi validi (entro tolleranza di 15s)
           → Qualità 800 vince (più basso = migliore)
           → Il tuo blocco diventa il tip della catena
```

#### Scenario: riorganizzazione genuina

```
La tua altezza di mining 100, il concorrente pubblica blocco 99
→ Non è competizione alla stessa altezza
→ Il forging difensivo NON si attiva
→ Procede la gestione normale della riorganizzazione
```

### Benefici

**Zero incentivo per la manipolazione dell'orologio**
- Gli orologi veloci aiutano solo se hai già la migliore qualità
- La manipolazione dell'orologio diventa economicamente inutile

**Competizione basata sulla qualità applicata**
- Costringe i miner a competere sul lavoro proof-of-capacity effettivo
- Preserva l'integrità del consenso PoCX

**Sicurezza della rete**
- Resistente a strategie di gaming basate sul timing
- Nessuna modifica al consenso richiesta - puro comportamento del miner

**Completamente automatico**
- Nessuna configurazione necessaria
- Si attiva solo quando necessario
- Comportamento standard in tutti i nodi Bitcoin-PoCX

### Compromessi

**Minimo aumento del tasso di orfani**
- Intenzionale - i blocchi di attacco vengono orfanati
- Si verifica solo durante tentativi effettivi di manipolazione dell'orologio
- Risultato naturale della risoluzione dei fork basata sulla qualità

**Breve competizione nella rete**
- La rete vede brevemente due blocchi concorrenti
- Si risolve in secondi attraverso la validazione standard
- Stesso comportamento del mining simultaneo in Bitcoin

### Dettagli tecnici

**Impatto sulle prestazioni:** Trascurabile
- Attivato solo sulla competizione alla stessa altezza
- Usa dati in memoria (nessun I/O su disco)
- La validazione completa in millisecondi

**Utilizzo risorse:** Minimo
- ~20 righe di logica core
- Riutilizza l'infrastruttura di validazione esistente
- Singola acquisizione di lock

**Compatibilità:** Completa
- Nessuna modifica alle regole di consenso
- Funziona con tutte le funzionalità di Bitcoin Core
- Monitoraggio opzionale tramite log di debug

**Stato**: Attivo in tutte le release di Bitcoin-PoCX
**Prima introduzione**: 10-10-2025

---

## Analisi delle minacce alla sicurezza

### Attacco con orologio veloce (mitigato dal forging difensivo)

**Vettore di attacco**:
Un miner con un orologio **+14s in anticipo** può:
1. Ricevere blocchi normalmente (appaiono vecchi a lui)
2. Forgiare blocchi immediatamente quando la deadline passa
3. Trasmettere blocchi che appaiono 14s "in anticipo" alla rete
4. **I blocchi vengono accettati** (entro tolleranza di 15s)
5. **Vince le competizioni** contro i miner onesti

**Impatto senza forging difensivo**:
Il vantaggio è limitato a 14,9 secondi (non abbastanza per saltare lavoro PoC significativo), ma fornisce un vantaggio costante nelle competizioni per i blocchi.

**Mitigazione (forging difensivo)**:
- I miner onesti rilevano la competizione alla stessa altezza
- Confrontano i valori di qualità
- Forgiano immediatamente se la qualità è migliore
- **Risultato**: L'orologio veloce aiuta solo se hai già la migliore qualità
- **Incentivo**: Zero - la manipolazione dell'orologio diventa economicamente inutile

### Fallimento con orologio lento (critico)

**Modalità di fallimento**:
Un nodo **>15s indietro** è catastrofico:
- Non può validare i blocchi in arrivo (controllo futuro fallisce)
- Diventa isolato dalla rete
- Non può minare o sincronizzarsi

**Mitigazione**:
- L'avviso forte a 10s di deriva dà un buffer di 5 secondi prima del fallimento critico
- Gli operatori possono risolvere i problemi dell'orologio proattivamente
- Messaggi di errore chiari guidano la risoluzione dei problemi

---

## Best practice per gli operatori di nodi

### Configurazione della sincronizzazione temporale

**Configurazione raccomandata**:
1. **Abilitare NTP**: Usare il Network Time Protocol per la sincronizzazione automatica
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Controllare lo stato
   timedatectl status
   ```

2. **Verificare l'accuratezza dell'orologio**: Controllare regolarmente l'offset temporale
   ```bash
   # Controllare lo stato della sincronizzazione NTP
   ntpq -p

   # Oppure con chrony
   chronyc tracking
   ```

3. **Monitorare gli avvisi**: Controllare gli avvisi di deriva dell'orologio di Bitcoin-PoCX nei log

### Per i miner

**Nessuna azione richiesta**:
- La funzionalità è sempre attiva
- Opera automaticamente
- Basta mantenere l'orologio di sistema accurato

**Best practice**:
- Usare la sincronizzazione temporale NTP
- Monitorare gli avvisi di deriva dell'orologio
- Risolvere prontamente gli avvisi se appaiono

**Comportamento atteso**:
- Mining in solitario: Il forging difensivo si attiva raramente (nessuna competizione)
- Mining in rete: Protegge contro i tentativi di manipolazione dell'orologio
- Operazione trasparente: La maggior parte dei miner non lo nota mai

### Risoluzione dei problemi

**Avviso: "10 secondi fuori sincronizzazione"**
- Azione: Controllare e correggere la sincronizzazione dell'orologio di sistema
- Impatto: Buffer di 5 secondi prima del fallimento critico
- Strumenti: NTP, chrony, systemd-timesyncd

**Errore: "time-too-new" sui blocchi in arrivo**
- Causa: Il tuo orologio è >15 secondi lento
- Impatto: Non può validare blocchi, nodo isolato
- Soluzione: Sincronizzare immediatamente l'orologio di sistema

**Errore: Non può propagare blocchi forgiati**
- Causa: Il tuo orologio è >15 secondi veloce
- Impatto: Blocchi rifiutati dalla rete
- Soluzione: Sincronizzare immediatamente l'orologio di sistema

---

## Decisioni di design e motivazioni

### Perché tolleranza di 15 secondi?

**Motivazione**:
- Il timing variabile delle deadline di Bitcoin-PoCX è meno critico rispetto al consenso a timing fisso
- 15s fornisce una protezione adeguata prevenendo la frammentazione della rete

**Compromessi**:
- Tolleranza più stretta = più frammentazione della rete da deriva minore
- Tolleranza più ampia = più opportunità per attacchi di timing
- 15s bilancia sicurezza e robustezza

### Perché avviso a 10 secondi?

**Motivazione**:
- Fornisce un buffer di sicurezza di 5 secondi
- Più appropriato per il PoC rispetto al default di 10 minuti di Bitcoin
- Permette correzioni proattive prima del fallimento critico

### Perché il forging difensivo?

**Problema affrontato**:
- La tolleranza di 15 secondi abilita il vantaggio dell'orologio veloce
- Il consenso basato sulla qualità potrebbe essere minato dalla manipolazione del timing

**Benefici della soluzione**:
- Difesa a costo zero (nessuna modifica al consenso)
- Operazione automatica
- Elimina l'incentivo all'attacco
- Preserva i principi del proof-of-capacity

### Perché nessuna sincronizzazione temporale intra-rete?

**Motivazione di sicurezza**:
- Bitcoin Core moderno ha rimosso la regolazione temporale basata sui peer
- Vulnerabile agli attacchi Sybil sul tempo percepito della rete
- PoCX evita deliberatamente di fare affidamento su fonti temporali interne alla rete
- L'orologio di sistema è più affidabile del consenso dei peer
- Gli operatori dovrebbero sincronizzarsi usando NTP o sorgente temporale esterna equivalente
- I nodi monitorano la propria deriva ed emettono avvisi se l'orologio locale diverge dai timestamp dei blocchi recenti

---

## Riferimenti all'implementazione

**File core**:
- Validazione temporale: `src/validation.cpp:4547-4561`
- Costante tolleranza futura: `src/chain.h:31`
- Soglia di avviso: `src/node/timeoffsets.h:27`
- Monitoraggio offset temporale: `src/node/timeoffsets.cpp`
- Forging difensivo: `src/pocx/mining/scheduler.cpp`

**Documentazione correlata**:
- Algoritmo Time Bending: [Capitolo 3: Consenso e mining](3-consensus-and-mining.md#calcolo-del-time-bending)
- Validazione dei blocchi: [Capitolo 3: Validazione dei blocchi](3-consensus-and-mining.md#validazione-dei-blocchi)

---

**Generato**: 10-10-2025
**Stato**: Implementazione completa
**Copertura**: Requisiti di sincronizzazione temporale, gestione della deriva dell'orologio, forging difensivo

---

[← Precedente: Assegnazioni di forging](4-forging-assignments.md) | [Indice](index.md) | [Successivo: Parametri di rete →](6-network-parameters.md)
