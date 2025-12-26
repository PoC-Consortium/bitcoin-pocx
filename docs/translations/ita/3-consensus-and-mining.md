[← Precedente: Formato dei plot](2-plot-format.md) | [Indice](index.md) | [Successivo: Assegnazioni di forging →](4-forging-assignments.md)

---

# Capitolo 3: Processo di consenso e mining di Bitcoin-PoCX

Specifica tecnica completa del meccanismo di consenso PoCX (Proof of Capacity neXt generation) e del processo di mining integrato in Bitcoin Core.

---

## Indice

1. [Panoramica](#panoramica)
2. [Architettura del consenso](#architettura-del-consenso)
3. [Processo di mining](#processo-di-mining)
4. [Validazione dei blocchi](#validazione-dei-blocchi)
5. [Sistema di assegnazioni](#sistema-di-assegnazioni)
6. [Propagazione nella rete](#propagazione-nella-rete)
7. [Dettagli tecnici](#dettagli-tecnici)

---

## Panoramica

Bitcoin-PoCX implementa un meccanismo di consenso Proof of Capacity puro come sostituzione completa del Proof of Work di Bitcoin. Questa è una nuova catena senza requisiti di retrocompatibilità.

**Proprietà chiave:**
- **Efficiente dal punto di vista energetico:** Il mining utilizza file plot pre-generati invece dell'hashing computazionale
- **Deadline con Time Bending:** Trasformazione della distribuzione (esponenziale→chi-quadrato) riduce i blocchi lunghi, migliora i tempi medi di blocco
- **Supporto alle assegnazioni:** I proprietari dei plot possono delegare i diritti di forging ad altri indirizzi
- **Integrazione nativa in C++:** Algoritmi crittografici implementati in C++ per la validazione del consenso

**Flusso del mining:**
```
Miner esterno → get_mining_info → Calcola nonce → submit_nonce →
Coda del forger → Attesa deadline → Forging del blocco → Propagazione nella rete →
Validazione del blocco → Estensione della catena
```

---

## Architettura del consenso

### Struttura dei blocchi

I blocchi PoCX estendono la struttura dei blocchi di Bitcoin con campi di consenso aggiuntivi:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed del plot (32 byte)
    std::array<uint8_t, 20> account_id;       // Indirizzo del plot (hash160 da 20 byte)
    uint32_t compression;                     // Livello di scaling (1-255)
    uint64_t nonce;                           // Nonce di mining (64-bit)
    uint64_t quality;                         // Qualità dichiarata (output hash PoC)
};

class CBlockHeader {
    // Campi standard di Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Campi di consenso PoCX (sostituiscono nBits e nNonce)
    int nHeight;                              // Altezza del blocco (validazione senza contesto)
    uint256 generationSignature;              // Generation signature (entropia per il mining)
    uint64_t nBaseTarget;                     // Parametro di difficoltà (difficoltà inversa)
    PoCXProof pocxProof;                      // Prova di mining

    // Campi della firma del blocco
    std::array<uint8_t, 33> vchPubKey;        // Chiave pubblica compressa (33 byte)
    std::array<uint8_t, 65> vchSignature;     // Firma compatta (65 byte)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transazioni
};
```

**Nota:** La firma (`vchSignature`) è esclusa dal calcolo dell'hash del blocco per prevenire la malleabilità.

**Implementazione:** `src/primitives/block.h`

### Generation Signature

La generation signature crea entropia per il mining e previene gli attacchi di pre-calcolo.

**Calcolo:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Blocco genesis:** Utilizza una generation signature iniziale codificata staticamente

**Implementazione:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Difficoltà)

Il base target è l'inverso della difficoltà - valori più alti significano mining più facile.

**Algoritmo di regolazione:**
- Tempo di blocco target: 120 secondi (mainnet), 1 secondo (regtest)
- Intervallo di regolazione: Ogni blocco
- Utilizza la media mobile dei base target recenti
- Limitato per prevenire oscillazioni estreme della difficoltà

**Implementazione:** `src/consensus/params.h`, logica di regolazione della difficoltà nella creazione del blocco

### Livelli di scaling

PoCX supporta il proof-of-work scalabile nei file plot attraverso i livelli di scaling (Xn).

**Limiti dinamici:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Livello minimo accettato
    uint8_t nPoCXTargetCompression;  // Livello raccomandato
};
```

**Programma di aumento dello scaling:**
- Intervalli esponenziali: Anni 4, 12, 28, 60, 124 (halving 1, 3, 7, 15, 31)
- Il livello minimo di scaling aumenta di 1
- Il livello target di scaling aumenta di 1
- Mantiene il margine di sicurezza tra i costi di creazione e lookup dei plot
- Livello massimo di scaling: 255

**Implementazione:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Processo di mining

### 1. Recupero delle informazioni di mining

**Comando RPC:** `get_mining_info`

**Processo:**
1. Chiamare `GetNewBlockContext(chainman)` per ottenere lo stato corrente della blockchain
2. Calcolare i limiti dinamici di compressione per l'altezza corrente
3. Restituire i parametri di mining

**Risposta:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementazione:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Note:**
- Nessun lock mantenuto durante la generazione della risposta
- L'acquisizione del contesto gestisce `cs_main` internamente
- `block_hash` incluso come riferimento ma non usato nella validazione

### 2. Mining esterno

**Responsabilità del miner esterno:**
1. Leggere i file plot dal disco
2. Calcolare lo scoop basato sulla generation signature e sull'altezza
3. Trovare il nonce con la migliore deadline
4. Inviare al nodo tramite `submit_nonce`

**Formato dei file plot:**
- Basato sul formato POC2 (Burstcoin)
- Migliorato con correzioni di sicurezza e miglioramenti di scalabilità
- Vedere l'attribuzione in `CLAUDE.md`

**Implementazione del miner:** Esterno (es., basato su Scavenger)

### 3. Invio e validazione del nonce

**Comando RPC:** `submit_nonce`

**Parametri:**
```
height, generation_signature, account_id, seed, nonce, quality (opzionale)
```

**Flusso di validazione (ordine ottimizzato):**

#### Passo 1: Validazione rapida del formato
```cpp
// Account ID: 40 caratteri hex = 20 byte
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 caratteri hex = 32 byte
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Passo 2: Acquisizione del contesto
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Restituisce: height, generation_signature, base_target, block_hash
```

**Locking:** `cs_main` gestito internamente, nessun lock mantenuto nel thread RPC

#### Passo 3: Validazione del contesto
```cpp
// Controllo dell'altezza
if (height != context.height) reject;

// Controllo della generation signature
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Passo 4: Verifica del wallet
```cpp
// Determinare il firmatario effettivo (considerando le assegnazioni)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Verificare se il nodo ha la chiave privata per il firmatario effettivo
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Supporto alle assegnazioni:** Il proprietario del plot può assegnare i diritti di forging a un altro indirizzo. Il wallet deve avere la chiave per il firmatario effettivo, non necessariamente per il proprietario del plot.

#### Passo 5: Validazione della prova
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 byte
    block_height,
    nonce,
    seed,                // 32 byte
    min_compression,
    max_compression,
    &result             // Output: quality, deadline
);
```

**Algoritmo:**
1. Decodificare la generation signature da hex
2. Calcolare la migliore qualità nell'intervallo di compressione usando algoritmi ottimizzati SIMD
3. Validare che la qualità soddisfi i requisiti di difficoltà
4. Restituire il valore di qualità raw

**Implementazione:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Passo 6: Calcolo del Time Bending
```cpp
// Deadline raw regolata per difficoltà (secondi)
uint64_t deadline_seconds = quality / base_target;

// Tempo di forging con Time Bending (secondi)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Formula del Time Bending:**
```
Y = scala * (X^(1/3))
dove:
  X = quality / base_target
  scala = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Scopo:** Trasforma la distribuzione esponenziale in chi-quadrato. Le soluzioni molto buone vengono forgiate più tardi (la rete ha tempo di scansionare i dischi), le soluzioni scadenti vengono migliorate. Riduce i blocchi lunghi, mantiene la media di 120s.

**Implementazione:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Passo 7: Invio al forger
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NON deadline - ricalcolata nel forger
    height,
    generation_signature
);
```

**Design basato su coda:**
- L'invio ha sempre successo (aggiunto alla coda)
- L'RPC ritorna immediatamente
- Il thread worker elabora in modo asincrono

**Implementazione:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Elaborazione della coda del forger

**Architettura:**
- Singolo thread worker persistente
- Coda di invio FIFO
- Stato di forging senza lock (solo thread worker)
- Nessun lock annidato (prevenzione del deadlock)

**Loop principale del thread worker:**
```cpp
while (!shutdown) {
    // 1. Controllare gli invii in coda
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Attendere la deadline o un nuovo invio
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logica ProcessSubmission:**
```cpp
1. Ottenere contesto fresco: GetNewBlockContext(*chainman)

2. Controlli di obsolescenza (scarto silenzioso):
   - Mismatch dell'altezza → scarta
   - Mismatch della generation signature → scarta
   - Hash del blocco tip cambiato (reorg) → resetta stato di forging

3. Confronto della qualità:
   - Se qualità >= current_best → scarta

4. Calcolare deadline con Time Bending:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Aggiornare stato di forging:
   - Cancellare forging esistente (se trovato migliore)
   - Memorizzare: account_id, seed, nonce, quality, deadline
   - Calcolare: forge_time = block_time + deadline_seconds
   - Memorizzare hash del tip per rilevamento reorg
```

**Implementazione:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Attesa della deadline e forging del blocco

**WaitForDeadlineOrNewSubmission:**

**Condizioni di attesa:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Quando la deadline è raggiunta - Validazione del contesto fresco:**
```cpp
1. Ottenere contesto corrente: GetNewBlockContext(*chainman)

2. Validazione dell'altezza:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validazione della generation signature:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Caso limite del base target:
   if (forging_base_target != current_base_target) {
       // Ricalcolare deadline con nuovo base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Attendere di nuovo
   }

5. Tutto valido → ForgeBlock()
```

**Processo ForgeBlock:**

```cpp
1. Determinare firmatario effettivo (supporto assegnazioni):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Creare script coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Paga al firmatario effettivo

3. Creare template del blocco:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Aggiungere prova PoCX:
   block.pocxProof.account_id = plot_address;    // Indirizzo del plot originale
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Ricalcolare merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Firmare il blocco:
   // Usare la chiave del firmatario effettivo (può essere diversa dal proprietario del plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Inviare alla catena:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Gestione del risultato:
   if (accepted) {
       log_success();
       reset_forging_state();  // Pronto per il prossimo blocco
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementazione:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Decisioni di design chiave:**
- Il coinbase paga al firmatario effettivo (rispetta le assegnazioni)
- La prova contiene l'indirizzo del plot originale (per la validazione)
- La firma dalla chiave del firmatario effettivo (prova di proprietà)
- La creazione del template include automaticamente le transazioni dalla mempool

---

## Validazione dei blocchi

### Flusso di validazione dei blocchi in arrivo

Quando un blocco viene ricevuto dalla rete o inviato localmente, subisce la validazione in più fasi:

### Fase 1: Validazione dell'header (CheckBlockHeader)

**Validazione senza contesto:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validazione PoCX (quando ENABLE_POCX è definito):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validazione base della firma (nessun supporto assegnazioni ancora)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validazione base della firma:**
1. Verificare la presenza dei campi pubkey e signature
2. Validare la dimensione della pubkey (33 byte compressi)
3. Validare la dimensione della firma (65 byte compatti)
4. Recuperare la pubkey dalla firma: `pubkey.RecoverCompact(hash, signature)`
5. Verificare che la pubkey recuperata corrisponda alla pubkey memorizzata

**Implementazione:** `src/validation.cpp:CheckBlockHeader()`
**Logica della firma:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Fase 2: Validazione del blocco (CheckBlock)

**Valida:**
- Correttezza del merkle root
- Validità delle transazioni
- Requisiti del coinbase
- Limiti di dimensione del blocco
- Regole di consenso standard di Bitcoin

**Implementazione:** `src/consensus/validation.cpp:CheckBlock()`

### Fase 3: Validazione contestuale dell'header (ContextualCheckBlockHeader)

**Validazione specifica PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Passo 1: Validare la generation signature
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Passo 2: Validare il base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Passo 3: Validare il proof of capacity
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Passo 4: Verificare il timing della deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Passi di validazione:**
1. **Generation Signature:** Deve corrispondere al valore calcolato dal blocco precedente
2. **Base Target:** Deve corrispondere al calcolo della regolazione della difficoltà
3. **Livello di scaling:** Deve soddisfare il minimo della rete (`compression >= min_compression`)
4. **Dichiarazione della qualità:** La qualità inviata deve corrispondere alla qualità calcolata dalla prova
5. **Proof of Capacity:** Validazione crittografica della prova (ottimizzata SIMD)
6. **Timing della deadline:** La deadline con Time Bending (`poc_time`) deve essere ≤ tempo trascorso

**Implementazione:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Fase 4: Connessione del blocco (ConnectBlock)

**Validazione contestuale completa:**

```cpp
#ifdef ENABLE_POCX
    // Validazione estesa della firma con supporto assegnazioni
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validazione estesa della firma:**
1. Eseguire la validazione base della firma
2. Estrarre l'account ID dalla pubkey recuperata
3. Ottenere il firmatario effettivo per l'indirizzo del plot: `GetEffectiveSigner(plot_address, height, view)`
4. Verificare che l'account della pubkey corrisponda al firmatario effettivo

**Logica delle assegnazioni:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Restituisce il firmatario assegnato
    }

    return plotAddress;  // Nessuna assegnazione - il proprietario del plot firma
}
```

**Implementazione:**
- Connessione: `src/validation.cpp:ConnectBlock()`
- Validazione estesa: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logica delle assegnazioni: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Fase 5: Attivazione della catena

**Flusso ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validare e memorizzare su disco
    2. ActivateBestChain → Aggiornare il tip della catena se questa è la catena migliore
    3. Notificare la rete del nuovo blocco
}
```

**Implementazione:** `src/validation.cpp:ProcessNewBlock()`

### Riepilogo della validazione

**Percorso di validazione completo:**
```
Ricezione blocco
    ↓
CheckBlockHeader (firma base)
    ↓
CheckBlock (transazioni, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, prova PoC, deadline)
    ↓
ConnectBlock (firma estesa con assegnazioni, transizioni di stato)
    ↓
ActivateBestChain (gestione reorg, estensione della catena)
    ↓
Propagazione nella rete
```

---

## Sistema di assegnazioni

### Panoramica

Le assegnazioni permettono ai proprietari dei plot di delegare i diritti di forging ad altri indirizzi mantenendo la proprietà del plot.

**Casi d'uso:**
- Mining in pool (i plot vengono assegnati all'indirizzo del pool)
- Cold storage (chiave di mining separata dalla proprietà del plot)
- Mining multi-party (infrastruttura condivisa)

### Architettura delle assegnazioni

**Design solo OP_RETURN:**
- Le assegnazioni sono memorizzate in output OP_RETURN (nessun UTXO)
- Nessun requisito di spesa (nessun dust, nessuna fee per mantenere)
- Tracciate nello stato esteso di CCoinsViewCache
- Attivate dopo un periodo di ritardo (default: 4 blocchi)

**Stati delle assegnazioni:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nessuna assegnazione esiste
    ASSIGNING = 1,   // Assegnazione in attesa di attivazione (periodo di ritardo)
    ASSIGNED = 2,    // Assegnazione attiva, forging permesso
    REVOKING = 3,    // Revoca in attesa (periodo di ritardo, ancora attiva)
    REVOKED = 4      // Revoca completa, assegnazione non più attiva
};
```

### Creazione delle assegnazioni

**Formato della transazione:**
```cpp
Transaction {
    inputs: [any]  // Dimostra la proprietà dell'indirizzo del plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Regole di validazione:**
1. L'input deve essere firmato dal proprietario del plot (dimostra la proprietà)
2. L'OP_RETURN contiene dati di assegnazione validi
3. Il plot deve essere UNASSIGNED o REVOKED
4. Nessuna assegnazione duplicata pendente nella mempool
5. Fee minima della transazione pagata

**Attivazione:**
- L'assegnazione diventa ASSIGNING all'altezza di conferma
- Diventa ASSIGNED dopo il periodo di ritardo (4 blocchi regtest, 30 blocchi mainnet)
- Il ritardo previene rapide riassegnazioni durante le competizioni per i blocchi

**Implementazione:** `src/script/forging_assignment.h`, validazione in ConnectBlock

### Revoca delle assegnazioni

**Formato della transazione:**
```cpp
Transaction {
    inputs: [any]  // Dimostra la proprietà dell'indirizzo del plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effetto:**
- Transizione immediata allo stato REVOKED
- Il proprietario del plot può forgiare immediatamente
- Può creare una nuova assegnazione successivamente

### Validazione delle assegnazioni durante il mining

**Determinazione del firmatario effettivo:**
```cpp
// Nella validazione di submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Nel forging del blocco
coinbase_script = P2WPKH(effective_signer);  // La ricompensa va qui

// Nella firma del blocco
signature = effective_signer_key.SignCompact(hash);  // Deve firmare con il firmatario effettivo
```

**Validazione del blocco:**
```cpp
// In VerifyPoCXBlockCompactSignature (estesa)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Proprietà chiave:**
- La prova contiene sempre l'indirizzo del plot originale
- La firma deve essere del firmatario effettivo
- Il coinbase paga al firmatario effettivo
- La validazione usa lo stato dell'assegnazione all'altezza del blocco

---

## Propagazione nella rete

### Annuncio del blocco

**Protocollo P2P standard di Bitcoin:**
1. Il blocco forgiato viene inviato tramite `ProcessNewBlock()`
2. Il blocco viene validato e aggiunto alla catena
3. Notifica della rete: `GetMainSignals().BlockConnected()`
4. Il layer P2P trasmette il blocco ai peer

**Implementazione:** net_processing standard di Bitcoin Core

### Relay dei blocchi

**Compact Blocks (BIP 152):**
- Usato per la propagazione efficiente dei blocchi
- Inizialmente vengono inviati solo gli ID delle transazioni
- I peer richiedono le transazioni mancanti

**Full Block Relay:**
- Fallback quando i compact block falliscono
- Dati completi del blocco trasmessi

### Riorganizzazioni della catena

**Gestione delle riorganizzazioni:**
```cpp
// Nel thread worker del forger
if (current_tip_hash != stored_tip_hash) {
    // Rilevata riorganizzazione della catena
    reset_forging_state();
    log("Tip della catena cambiato, reset del forging");
}
```

**A livello di blockchain:**
- Gestione standard delle riorganizzazioni di Bitcoin Core
- La catena migliore è determinata dal chainwork
- I blocchi disconnessi vengono restituiti alla mempool

---

## Dettagli tecnici

### Prevenzione dei deadlock

**Pattern deadlock ABBA (prevenuto):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Soluzione:**
1. **submit_nonce:** Zero utilizzo di cs_main
   - `GetNewBlockContext()` gestisce il locking internamente
   - Tutta la validazione prima dell'invio al forger

2. **Forger:** Architettura basata su coda
   - Singolo thread worker (nessun thread join)
   - Contesto fresco ad ogni accesso
   - Nessun lock annidato

3. **Controlli wallet:** Eseguiti prima delle operazioni costose
   - Rifiuto anticipato se nessuna chiave disponibile
   - Separato dall'accesso allo stato della blockchain

### Ottimizzazioni delle prestazioni

**Validazione fail-fast:**
```cpp
1. Controlli di formato (immediati)
2. Validazione del contesto (leggera)
3. Verifica del wallet (locale)
4. Validazione della prova (costosa, SIMD)
```

**Singolo fetch del contesto:**
- Una chiamata `GetNewBlockContext()` per invio
- Cache dei risultati per controlli multipli
- Nessuna acquisizione ripetuta di cs_main

**Efficienza della coda:**
- Struttura di invio leggera
- Nessun base_target/deadline nella coda (ricalcolati freschi)
- Impronta di memoria minima

### Gestione dell'obsolescenza

**Design del forger "stupido":**
- Nessuna sottoscrizione agli eventi della blockchain
- Validazione lazy quando necessaria
- Scarto silenzioso degli invii obsoleti

**Benefici:**
- Architettura semplice
- Nessuna sincronizzazione complessa
- Robusto contro casi limite

**Casi limite gestiti:**
- Cambiamenti di altezza → scarta
- Cambiamenti della generation signature → scarta
- Cambiamenti del base target → ricalcola deadline
- Riorganizzazioni → resetta stato di forging

### Dettagli crittografici

**Generation Signature:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash della firma del blocco:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Formato della firma compatta:**
- 65 byte: [recovery_id][r][s]
- Permette il recupero della chiave pubblica
- Usato per l'efficienza dello spazio

**Account ID:**
- HASH160 da 20 byte della chiave pubblica compressa
- Corrisponde ai formati degli indirizzi Bitcoin (P2PKH, P2WPKH)

### Miglioramenti futuri

**Limitazioni documentate:**
1. Nessuna metrica delle prestazioni (tassi di invio, distribuzioni delle deadline)
2. Nessuna categorizzazione dettagliata degli errori per i miner
3. Interrogazione limitata dello stato del forger (deadline corrente, profondità della coda)

**Potenziali miglioramenti:**
- RPC per lo stato del forger
- Metriche per l'efficienza del mining
- Logging migliorato per il debugging
- Supporto al protocollo dei pool

---

## Riferimenti al codice

**Implementazioni core:**
- Interfaccia RPC: `src/pocx/rpc/mining.cpp`
- Coda del forger: `src/pocx/mining/scheduler.cpp`
- Validazione del consenso: `src/pocx/consensus/validation.cpp`
- Validazione della prova: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Validazione del blocco: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logica delle assegnazioni: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Gestione del contesto: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Strutture dati:**
- Formato del blocco: `src/primitives/block.h`
- Parametri di consenso: `src/consensus/params.h`
- Tracciamento delle assegnazioni: `src/coins.h` (estensioni CCoinsViewCache)

---

## Appendice: Specifiche degli algoritmi

### Formula del Time Bending

**Definizione matematica:**
```
deadline_seconds = quality / base_target  (raw)

time_bended_deadline = scala * (deadline_seconds)^(1/3)

dove:
  scala = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementazione:**
- Aritmetica a virgola fissa (formato Q42)
- Calcolo della radice cubica solo con interi
- Ottimizzato per aritmetica a 256 bit

### Calcolo della qualità

**Processo:**
1. Generare lo scoop dalla generation signature e dall'altezza
2. Leggere i dati del plot per lo scoop calcolato
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Testare i livelli di scaling da min a max
5. Restituire la migliore qualità trovata

**Scaling:**
- Livello X0: baseline POC2 (teorico)
- Livello X1: baseline XOR-transpose
- Livello Xn: 2^(n-1) × lavoro X1 incorporato
- Scaling più alto = più lavoro di generazione del plot

### Regolazione del base target

**Regolazione ad ogni blocco:**
1. Calcolare la media mobile dei base target recenti
2. Calcolare il timespan effettivo vs. timespan target per la finestra mobile
3. Regolare il base target proporzionalmente
4. Limitare per prevenire oscillazioni estreme

**Formula:**
```
avg_base_target = media_mobile(base target recenti)
fattore_regolazione = timespan_effettivo / timespan_target
nuovo_base_target = avg_base_target * fattore_regolazione
nuovo_base_target = clamp(nuovo_base_target, min, max)
```

---

*Questa documentazione riflette l'implementazione completa del consenso PoCX a ottobre 2025.*

---

[← Precedente: Formato dei plot](2-plot-format.md) | [Indice](index.md) | [Successivo: Assegnazioni di forging →](4-forging-assignments.md)
