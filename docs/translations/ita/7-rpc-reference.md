[← Precedente: Parametri di rete](6-network-parameters.md) | [Indice](index.md) | [Successivo: Guida al wallet →](8-wallet-guide.md)

---

# Capitolo 7: Riferimento dell'interfaccia RPC

Riferimento completo per i comandi RPC di Bitcoin-PoCX, inclusi RPC per il mining, gestione delle assegnazioni e RPC della blockchain modificati.

---

## Indice

1. [Configurazione](#configurazione)
2. [RPC per il mining PoCX](#rpc-per-il-mining-pocx)
3. [RPC per le assegnazioni](#rpc-per-le-assegnazioni)
4. [RPC della blockchain modificati](#rpc-della-blockchain-modificati)
5. [RPC disabilitati](#rpc-disabilitati)
6. [Esempi di integrazione](#esempi-di-integrazione)

---

## Configurazione

### Modalità server di mining

**Flag**: ``

**Scopo**: Abilita l'accesso RPC per i miner esterni per chiamare RPC specifici per il mining

**Requisiti**:
- Richiesto perché `submit_nonce` funzioni
- Richiesto per la visibilità della finestra di dialogo delle assegnazioni di forging nel wallet Qt

**Utilizzo**:
```bash
# Riga di comando
./bitcoind

# bitcoin.conf
```

**Considerazioni sulla sicurezza**:
- Nessuna autenticazione aggiuntiva oltre alle credenziali RPC standard
- Gli RPC di mining sono limitati dalla capacità della coda
- L'autenticazione RPC standard è comunque richiesta

**Implementazione**: `src/pocx/rpc/mining.cpp`

---

## RPC per il mining PoCX

### get_mining_info

**Categoria**: mining
**Richiede wallet**: No

**Scopo**: Restituisce i parametri di mining correnti necessari ai miner esterni per scansionare i file plot e calcolare le deadline.

**Parametri**: Nessuno

**Valori restituiti**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 caratteri
  "base_target": 36650387592,                // numerico
  "height": 12345,                           // numerico, altezza del prossimo blocco
  "block_hash": "def456...",                 // hex, blocco precedente
  "target_quality": 18446744073709551615,    // uint64_max (tutte le soluzioni accettate)
  "minimum_compression_level": 1,            // numerico
  "target_compression_level": 2              // numerico
}
```

**Descrizione dei campi**:
- `generation_signature`: Entropia deterministica per il mining a questa altezza di blocco
- `base_target`: Difficoltà corrente (più alto = più facile)
- `height`: Altezza del blocco che i miner dovrebbero targetizzare
- `block_hash`: Hash del blocco precedente (informativo)
- `target_quality`: Soglia di qualità (attualmente uint64_max, nessun filtraggio)
- `minimum_compression_level`: Compressione minima richiesta per la validazione
- `target_compression_level`: Compressione raccomandata per il mining ottimale

**Codici di errore**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nodo ancora in sincronizzazione

**Esempio**:
```bash
bitcoin-cli get_mining_info
```

**Implementazione**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Categoria**: mining
**Richiede server di mining**: Sì
**Richiede wallet**: Sì (per le chiavi private)

**Scopo**: Invia una soluzione di mining PoCX. Valida la prova, mette in coda per il forging con time bending e crea automaticamente il blocco al momento programmato.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (esattamente 40 caratteri hex = 20 byte; un indirizzo non è accettato)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Valori restituiti** (successo):
```json
{
  "raw_quality": 120,       // qualità raw dalla validazione della prova
  "poc_time": 45            // tempo di forging con time bending in secondi
}
```

Non esiste alcun campo `accepted`. In caso di rifiuto l'RPC **non** restituisce un oggetto JSON — lancia un `JSONRPCError` (vedi Codici di errore sotto).

**Passi di validazione**:
1. **Validazione del formato** (fail-fast):
   - Account ID: esattamente 40 caratteri hex
   - Seed: esattamente 64 caratteri hex
2. **Validazione del contesto**:
   - Block hash must match current tip
   - L'altezza deve corrispondere al tip corrente + 1
   - La generation signature deve corrispondere a quella corrente
   - Base target must match current
3. **Verifica del wallet**:
   - Determinare il firmatario effettivo (controllare le assegnazioni attive)
   - Verificare che il wallet abbia la chiave privata per il firmatario effettivo
4. **Validazione della prova** (costosa):
   - Validare la prova PoCX con i limiti di compressione
   - Calcolare la qualità raw
5. **Invio allo scheduler**:
   - Mettere in coda il nonce per il forging con time bending
   - Il blocco verrà creato automaticamente al forge_time

**Codici di errore** (lanciati come `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Formato non valido (account_id, seed) o mismatch dell'altezza (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Mismatch della generation signature o validazione della prova fallita
- `RPC_INVALID_ADDRESS_OR_KEY`: Nessuna chiave privata per il firmatario effettivo
- `RPC_WALLET_UNLOCK_NEEDED`: Il wallet che contiene la chiave del firmatario effettivo è bloccato (sbloccare con `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Coda di invio piena
- `RPC_INTERNAL_ERROR`: Impossibile inizializzare lo scheduler PoCX

**Codici di errore della validazione della prova**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Esempio**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Note**:
- L'invio è asincrono - l'RPC ritorna immediatamente, il blocco viene forgiato dopo
- Il Time Bending ritarda le buone soluzioni per permettere la scansione dei plot a livello di rete
- Sistema di assegnazioni: se il plot è assegnato, il wallet deve avere la chiave dell'indirizzo di forging
- I limiti di compressione sono regolati dinamicamente in base all'altezza del blocco

**Implementazione**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC per le assegnazioni

### get_assignment

**Categoria**: mining
**Richiede wallet**: No

**Scopo**: Interroga lo stato dell'assegnazione di forging per un indirizzo di plot. Sola lettura, nessun wallet richiesto.

**Parametri**:
1. `plot_address` (stringa, richiesta) - Indirizzo del plot (formato bech32 P2WPKH)
2. `height` (numerico, opzionale) - Altezza del blocco da interrogare (default: tip corrente)

**Valori restituiti** (nessuna assegnazione):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Valori restituiti** (assegnazione attiva):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Valori restituiti** (in revoca):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Stati delle assegnazioni**:
- `UNASSIGNED`: Nessuna assegnazione esiste
- `ASSIGNING`: Tx di assegnazione confermata, ritardo di attivazione in corso
- `ASSIGNED`: Assegnazione attiva, diritti di forging delegati
- `REVOKING`: Tx di revoca confermata, ancora attiva fino a scadenza del ritardo
- `REVOKED`: Revoca completa, diritti di forging restituiti al proprietario del plot

**Codici di errore**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Indirizzo non valido o non P2WPKH (bech32)

**Esempio**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementazione**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Categoria**: wallet
**Richiede wallet**: Sì (deve essere caricato e sbloccato)

**Scopo**: Crea una transazione di assegnazione di forging per delegare i diritti di forging a un altro indirizzo (es., pool di mining).

**Parametri**:
1. `plot_address` (stringa, richiesta) - Indirizzo del proprietario del plot (deve possedere chiave privata, P2WPKH bech32)
2. `forging_address` (stringa, richiesta) - Indirizzo a cui assegnare i diritti di forging (P2WPKH bech32)
3. `fee_rate` (numerico, opzionale) - Fee rate in BTCX/kvB (default: `0` → stima della commissione minima standard del wallet; il default 10× minRelayFee si applica solo alla finestra di dialogo della GUI Qt, non a questa RPC)

**Valori restituiti**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Requisiti**:
- Wallet caricato e sbloccato
- Chiave privata per plot_address nel wallet
- Entrambi gli indirizzi devono essere P2WPKH (formato bech32: pocx1q... mainnet, tpocx1q... testnet)
- L'indirizzo del plot deve avere UTXO confermati (dimostra la proprietà)
- Il plot non deve avere un'assegnazione attiva (usare prima revoke)

**Struttura della transazione**:
- Input: UTXO dall'indirizzo del plot (dimostra la proprietà)
- Output: script OP_RETURN (46 byte) = opcode `OP_RETURN` + lunghezza push di 1 byte + payload dati di 44 byte (marcatore `POCX` 4 + plot_address 20 + forging_address 20)
- Output: Resto restituito al wallet

**Attivazione**:
- L'assegnazione diventa ASSIGNING alla conferma
- Becomes ASSIGNED after `nForgingAssignmentDelay` blocks
- Il ritardo previene la rapida riassegnazione durante i fork della catena

**Codici di errore**:
- `RPC_WALLET_NOT_FOUND`: Nessun wallet disponibile
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet criptato e bloccato
- `RPC_WALLET_ERROR`: Creazione della transazione fallita
- `RPC_INVALID_ADDRESS_OR_KEY`: Formato indirizzo non valido

**Esempio**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementazione**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Categoria**: wallet
**Richiede wallet**: Sì (deve essere caricato e sbloccato)

**Scopo**: Revoca un'assegnazione di forging esistente, restituendo i diritti di forging al proprietario del plot.

**Parametri**:
1. `plot_address` (stringa, richiesta) - Indirizzo del plot (deve possedere chiave privata, P2WPKH bech32)
2. `fee_rate` (numerico, opzionale) - Fee rate in BTCX/kvB (default: `0` → stima della commissione minima standard del wallet; il default 10× minRelayFee si applica solo alla finestra di dialogo della GUI Qt, non a questa RPC)

**Valori restituiti**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Requisiti**:
- Wallet caricato e sbloccato
- Chiave privata per plot_address nel wallet
- L'indirizzo del plot deve essere P2WPKH (formato bech32)
- L'indirizzo del plot deve avere UTXO confermati

**Struttura della transazione**:
- Input: UTXO dall'indirizzo del plot (dimostra la proprietà)
- Output: script OP_RETURN (26 byte) = opcode `OP_RETURN` + lunghezza push di 1 byte + payload dati di 24 byte (marcatore `XCOP` 4 + plot_address 20)
- Output: Resto restituito al wallet

**Effetto**:
- Lo stato transita immediatamente a REVOKING
- L'indirizzo di forging può ancora forgiare durante il periodo di ritardo
- Diventa REVOKED dopo `nForgingRevocationDelay` blocchi
- Il proprietario del plot può forgiare dopo che la revoca è effettiva
- Può creare una nuova assegnazione dopo che la revoca è completa

**Codici di errore**:
- `RPC_WALLET_NOT_FOUND`: Nessun wallet disponibile
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet criptato e bloccato
- `RPC_WALLET_ERROR`: Creazione della transazione fallita

**Esempio**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Note**:
- Idempotente: può revocare anche se non c'è assegnazione attiva
- Non può annullare la revoca una volta inviata

**Implementazione**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPC della blockchain modificati

### getdifficulty

**Modifiche PoCX**:
- **Calcolo**: `reference_base_target / current_base_target`
- **Riferimento**: Capacità di rete di 1 TiB (base_target = 36650387592)
- **Interpretazione**: Capacità di storage stimata della rete in TiB
  - Esempio: `1.0` = ~1 TiB
  - Esempio: `1024.0` = ~1 PiB
- **Differenza da PoW**: Rappresenta la capacità, non la potenza di hash

**Esempio**:
```bash
bitcoin-cli getdifficulty
# Restituisce: 2048.5 (rete ~2 PiB)
```

**Implementazione**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Campi aggiunti PoCX**:
- `time_since_last_block` (numerico) - Secondi dal blocco precedente (sostituisce mediantime)
- `poc_time` (numerico) - Tempo di forging con time bending in secondi
- `base_target` (numerico) - Base target della difficoltà PoCX
- `generation_signature` (stringa hex) - Generation signature
- `pocx_proof` (oggetto):
  - `account_id` (stringa hex) - Account ID del plot (20 byte)
  - `seed` (stringa hex) - Seed del plot (32 byte)
  - `nonce` (numerico) - Nonce di mining
  - `compression` (numerico) - Livello di scaling usato
  - `quality` (numerico) - Valore di qualità dichiarato
- `pubkey` (stringa hex) - Chiave pubblica del firmatario del blocco (33 byte)
- `signer_address` (stringa) - Indirizzo del firmatario del blocco
- `signature` (stringa hex) - Firma del blocco (65 byte)

**Campi rimossi PoCX**:
- `mediantime` - Rimosso (sostituito da time_since_last_block)

**Esempio**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementazione**: `src/rpc/blockchain.cpp`

---

### getblock

**Modifiche PoCX**: Come getblockheader, più i dati completi delle transazioni

**Esempio**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose con dettagli tx
```

**Implementazione**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Campi aggiunti PoCX**:
- `base_target` (numerico) - Base target corrente
- `generation_signature` (stringa hex) - Generation signature corrente

**Campi modificati PoCX**:
- `difficulty` - Usa il calcolo PoCX (basato sulla capacità)

**Campi rimossi PoCX**:
- `mediantime` - Rimosso

**Esempio**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementazione**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Campi aggiunti PoCX**:
- `generation_signature` (stringa hex) - Per il mining in pool
- `base_target` (numerico) - Per il mining in pool

**Campi rimossi PoCX**:
- `target` - Rimosso (specifico PoW)
- `noncerange` - Rimosso (specifico PoW)
- `bits` - Rimosso (specifico PoW)

**Note**:
- Include ancora i dati completi delle transazioni per la costruzione del blocco
- Usato dai server dei pool per il mining coordinato

**Esempio**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementazione**: `src/rpc/mining.cpp`

---

## RPC disabilitati

I seguenti RPC specifici per PoW sono **disabilitati** in modalità PoCX:

### getnetworkhashps
- **Motivo**: L'hash rate non è applicabile al Proof of Capacity
- **Alternativa**: Usare `getdifficulty` per la stima della capacità di rete

### getmininginfo
- **Motivo**: Restituisce informazioni specifiche per PoW
- **Alternativa**: Usare `get_mining_info` (specifico PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Esempi di integrazione

### Integrazione miner esterno

**Loop di mining base**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Loop di mining
while True:
    # 1. Ottenere parametri di mining
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scansionare file plot (implementazione esterna)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Inviare la migliore soluzione (lancia JSONRPCError in caso di rifiuto)
    try:
        result = rpc_call("submit_nonce", [
            info["block_hash"],
            height,
            gen_sig,
            base_target,
            best_nonce["account_id"],
            best_nonce["seed"],
            best_nonce["nonce"],
            best_nonce["compression"],
            best_nonce["raw_quality"]
        ])
        print(f"Soluzione accettata! Qualità: {result['raw_quality']}, "
              f"Tempo di forging: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Rifiutato: {e}")

    # 4. Attendere il prossimo blocco
    time.sleep(10)  # Intervallo di polling
```

---

### Pattern di integrazione pool

**Workflow del server pool**:
1. I miner creano assegnazioni di forging all'indirizzo del pool
2. Il pool esegue il wallet con le chiavi dell'indirizzo di forging
3. Il pool chiama `get_mining_info` e distribuisce ai miner
4. I miner inviano soluzioni tramite il pool (non direttamente alla catena)
5. Il pool valida e chiama `submit_nonce` con le chiavi del pool
6. Il pool distribuisce le ricompense secondo la policy del pool

**Gestione delle assegnazioni**:
```bash
# Il miner crea l'assegnazione (dal wallet del miner)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Attendere l'attivazione (30 blocchi mainnet)

# Il pool controlla lo stato dell'assegnazione
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Il pool può ora inviare nonce per questo plot
# (il wallet del pool deve avere la chiave privata di pocx1qpool...)
```

---

### Query per block explorer

**Interrogare dati blocco PoCX**:
```bash
# Ottenere l'ultimo blocco
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Ottenere dettagli del blocco con prova PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Estrarre campi specifici PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Rilevare transazioni di assegnazione**:
```bash
# Scansionare transazione per OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Controllare il marcatore di assegnazione (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Gestione degli errori

### Pattern di errore comuni

**Mismatch dell'altezza** (lanciato `RPC_INVALID_PARAMETER`, codice -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Soluzione**: Ri-ottenere le info di mining, la catena è avanzata

**Mismatch della generation signature** (lanciato `RPC_VERIFY_REJECTED`, codice -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Soluzione**: Ri-ottenere le info di mining, è arrivato un nuovo blocco

**Nessuna chiave privata**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Soluzione**: Importare la chiave per l'indirizzo del plot o di forging

**Attivazione dell'assegnazione in corso**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Soluzione**: Attendere che il ritardo di attivazione scada

---

## Riferimenti al codice

**RPC mining**: `src/pocx/rpc/mining.cpp`
**RPC assegnazioni**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC blockchain**: `src/rpc/blockchain.cpp`
**Validazione della prova**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Stato delle assegnazioni**: `src/pocx/assignments/assignment_state.cpp`
**Creazione transazioni**: `src/pocx/assignments/transactions.cpp`

---

## Riferimenti incrociati

Capitoli correlati:
- [Capitolo 3: Consenso e mining](3-consensus-and-mining.md) - Dettagli del processo di mining
- [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md) - Architettura del sistema di assegnazioni
- [Capitolo 6: Parametri di rete](6-network-parameters.md) - Valori dei ritardi delle assegnazioni
- [Capitolo 8: Guida al wallet](8-wallet-guide.md) - GUI per la gestione delle assegnazioni

---

[← Precedente: Parametri di rete](6-network-parameters.md) | [Indice](index.md) | [Successivo: Guida al wallet →](8-wallet-guide.md)
