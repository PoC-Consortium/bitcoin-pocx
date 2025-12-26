[← Precedente: Sincronizzazione temporale](5-timing-security.md) | [Indice](index.md) | [Successivo: Riferimento RPC →](7-rpc-reference.md)

---

# Capitolo 6: Parametri di rete e configurazione

Riferimento completo per la configurazione della rete Bitcoin-PoCX su tutti i tipi di rete.

---

## Indice

1. [Parametri del blocco genesis](#parametri-del-blocco-genesis)
2. [Configurazione chainparams](#configurazione-chainparams)
3. [Parametri di consenso](#parametri-di-consenso)
4. [Coinbase e ricompense dei blocchi](#coinbase-e-ricompense-dei-blocchi)
5. [Scaling dinamico](#scaling-dinamico)
6. [Configurazione della rete](#configurazione-della-rete)
7. [Struttura della directory dati](#struttura-della-directory-dati)

---

## Parametri del blocco genesis

### Calcolo del base target

**Formula**: `genesis_base_target = 2^42 / block_time_seconds`

**Motivazione**:
- Ogni nonce rappresenta 256 KiB (64 byte × 4096 scoop)
- 1 TiB = 2^22 nonce (assunzione della capacità di rete iniziale)
- Qualità minima attesa per n nonce ≈ 2^64 / n
- Per 1 TiB: E(qualità) = 2^64 / 2^22 = 2^42
- Quindi: base_target = 2^42 / block_time

**Valori calcolati**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Usa la modalità di calibrazione a bassa capacità

### Messaggio genesis

Tutte le reti condividono il messaggio genesis di Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementazione**: `src/kernel/chainparams.cpp`

---

## Configurazione chainparams

### Parametri mainnet

**Identità della rete**:
- **Magic bytes**: `0xa7 0x3c 0x91 0x5e`
- **Porta predefinita**: `8888`
- **HRP Bech32**: `pocx`

**Prefissi degli indirizzi** (Base58):
- PUBKEY_ADDRESS: `85` (gli indirizzi iniziano con 'P')
- SCRIPT_ADDRESS: `90` (gli indirizzi iniziano con 'R')
- SECRET_KEY: `128`

**Timing dei blocchi**:
- **Tempo di blocco target**: `120` secondi (2 minuti)
- **Timespan target**: `1209600` secondi (14 giorni)
- **MAX_FUTURE_BLOCK_TIME**: `15` secondi

**Ricompense dei blocchi**:
- **Sussidio iniziale**: `10 BTC`
- **Intervallo di halving**: `1050000` blocchi (~4 anni)
- **Conteggio halving**: Massimo 64 halving

**Regolazione della difficoltà**:
- **Finestra mobile**: `24` blocchi
- **Regolazione**: Ogni blocco
- **Algoritmo**: Media mobile esponenziale

**Ritardi delle assegnazioni**:
- **Attivazione**: `30` blocchi (~1 ora)
- **Revoca**: `720` blocchi (~24 ore)

### Parametri testnet

**Identità della rete**:
- **Magic bytes**: `0x6d 0xf2 0x48 0xb3`
- **Porta predefinita**: `18888`
- **HRP Bech32**: `tpocx`

**Prefissi degli indirizzi** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Timing dei blocchi**:
- **Tempo di blocco target**: `120` secondi
- **MAX_FUTURE_BLOCK_TIME**: `15` secondi
- **Permetti difficoltà minima**: `true`

**Ricompense dei blocchi**:
- **Sussidio iniziale**: `10 BTC`
- **Intervallo di halving**: `1050000` blocchi

**Regolazione della difficoltà**:
- **Finestra mobile**: `24` blocchi

**Ritardi delle assegnazioni**:
- **Attivazione**: `30` blocchi (~1 ora)
- **Revoca**: `720` blocchi (~24 ore)

### Parametri regtest

**Identità della rete**:
- **Magic bytes**: `0xfa 0xbf 0xb5 0xda`
- **Porta predefinita**: `18444`
- **HRP Bech32**: `rpocx`

**Prefissi degli indirizzi** (compatibili Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Timing dei blocchi**:
- **Tempo di blocco target**: `1` secondo (mining istantaneo per test)
- **Timespan target**: `86400` secondi (1 giorno)
- **MAX_FUTURE_BLOCK_TIME**: `15` secondi

**Ricompense dei blocchi**:
- **Sussidio iniziale**: `10 BTC`
- **Intervallo di halving**: `500` blocchi

**Regolazione della difficoltà**:
- **Finestra mobile**: `24` blocchi
- **Permetti difficoltà minima**: `true`
- **Nessun retargeting**: `true`
- **Calibrazione bassa capacità**: `true` (usa calibrazione a 16 nonce invece di 1 TiB)

**Ritardi delle assegnazioni**:
- **Attivazione**: `4` blocchi (~4 secondi)
- **Revoca**: `8` blocchi (~8 secondi)

### Parametri signet

**Identità della rete**:
- **Magic bytes**: Primi 4 byte di SHA256d(signet_challenge)
- **Porta predefinita**: `38333`
- **HRP Bech32**: `tpocx`

**Timing dei blocchi**:
- **Tempo di blocco target**: `120` secondi
- **MAX_FUTURE_BLOCK_TIME**: `15` secondi

**Ricompense dei blocchi**:
- **Sussidio iniziale**: `10 BTC`
- **Intervallo di halving**: `1050000` blocchi

**Regolazione della difficoltà**:
- **Finestra mobile**: `24` blocchi

---

## Parametri di consenso

### Parametri temporali

**MAX_FUTURE_BLOCK_TIME**: `15` secondi
- Specifico per PoCX (Bitcoin usa 2 ore)
- Motivazione: Il timing PoC richiede validazione quasi in tempo reale
- I blocchi più di 15s nel futuro vengono rifiutati

**Avviso offset temporale**: `10` secondi
- Gli operatori vengono avvisati quando l'orologio del nodo deriva di >10s dal tempo della rete
- Nessuna applicazione, solo informativo

**Tempi di blocco target**:
- Mainnet/Testnet/Signet: `120` secondi
- Regtest: `1` secondo

**TIMESTAMP_WINDOW**: `15` secondi (uguale a MAX_FUTURE_BLOCK_TIME)

**Implementazione**: `src/chain.h`, `src/validation.cpp`

### Parametri di regolazione della difficoltà

**Dimensione della finestra mobile**: `24` blocchi (tutte le reti)
- Media mobile esponenziale dei tempi di blocco recenti
- Regolazione ad ogni blocco
- Reattivo ai cambiamenti di capacità

**Implementazione**: `src/consensus/params.h`, logica della difficoltà nella creazione del blocco

### Parametri del sistema di assegnazioni

**nForgingAssignmentDelay** (ritardo di attivazione):
- Mainnet: `30` blocchi (~1 ora)
- Testnet: `30` blocchi (~1 ora)
- Regtest: `4` blocchi (~4 secondi)

**nForgingRevocationDelay** (ritardo di revoca):
- Mainnet: `720` blocchi (~24 ore)
- Testnet: `720` blocchi (~24 ore)
- Regtest: `8` blocchi (~8 secondi)

**Motivazione**:
- Il ritardo di attivazione previene la rapida riassegnazione durante le competizioni per i blocchi
- Il ritardo di revoca fornisce stabilità e previene abusi

**Implementazione**: `src/consensus/params.h`

---

## Coinbase e ricompense dei blocchi

### Programma del sussidio di blocco

**Sussidio iniziale**: `10 BTC` (tutte le reti)

**Programma di halving**:
- Ogni `1050000` blocchi (mainnet/testnet)
- Ogni `500` blocchi (regtest)
- Continua per massimo 64 halving

**Progressione dell'halving**:
```
Halving 0: 10,00000000 BTC  (blocchi 0 - 1049999)
Halving 1:  5,00000000 BTC  (blocchi 1050000 - 2099999)
Halving 2:  2,50000000 BTC  (blocchi 2100000 - 3149999)
Halving 3:  1,25000000 BTC  (blocchi 3150000 - 4199999)
...
```

**Offerta totale**: ~21 milioni di BTC (come Bitcoin)

### Regole dell'output coinbase

**Destinazione del pagamento**:
- **Senza assegnazione**: Il coinbase paga l'indirizzo del plot (proof.account_id)
- **Con assegnazione**: Il coinbase paga l'indirizzo di forging (firmatario effettivo)

**Formato dell'output**: Solo P2WPKH
- Il coinbase deve pagare a un indirizzo SegWit v0 bech32
- Generato dalla chiave pubblica del firmatario effettivo

**Risoluzione dell'assegnazione**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementazione**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Scaling dinamico

### Limiti dello scaling

**Scopo**: Aumentare la difficoltà di generazione dei plot man mano che la rete matura per prevenire l'inflazione della capacità

**Struttura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Livello minimo accettato
    uint8_t nPoCXTargetCompression;  // Livello raccomandato
};
```

**Relazione**: `target = min + 1` (sempre un livello sopra il minimo)

### Programma di aumento dello scaling

I livelli di scaling aumentano secondo un **programma esponenziale** basato sugli intervalli di halving:

| Periodo | Altezza blocco | Halving | Min | Target |
|---------|----------------|---------|-----|--------|
| Anni 0-4 | 0 a 1049999 | 0 | X1 | X2 |
| Anni 4-12 | 1050000 a 3149999 | 1-2 | X2 | X3 |
| Anni 12-28 | 3150000 a 7349999 | 3-6 | X3 | X4 |
| Anni 28-60 | 7350000 a 15749999 | 7-14 | X4 | X5 |
| Anni 60-124 | 15750000 a 32549999 | 15-30 | X5 | X6 |
| Anni 124+ | 32550000+ | 31+ | X6 | X7 |

**Altezze chiave** (anni → halving → blocchi):
- Anno 4: Halving 1 al blocco 1050000
- Anno 12: Halving 3 al blocco 3150000
- Anno 28: Halving 7 al blocco 7350000
- Anno 60: Halving 15 al blocco 15750000
- Anno 124: Halving 31 al blocco 32550000

### Difficoltà del livello di scaling

**Scaling del PoW**:
- Livello di scaling X0: baseline POC2 (teorico)
- Livello di scaling X1: baseline XOR-transpose
- Livello di scaling Xn: 2^(n-1) × lavoro X1 incorporato
- Ogni livello raddoppia il lavoro di generazione del plot

**Allineamento economico**:
- Le ricompense dei blocchi si dimezzano → la difficoltà di generazione dei plot aumenta
- Mantiene il margine di sicurezza: costo creazione plot > costo lookup
- Previene l'inflazione della capacità dai miglioramenti hardware

### Validazione dei plot

**Regole di validazione**:
- Le prove inviate devono avere un livello di scaling ≥ minimo
- Le prove con scaling > target sono accettate ma inefficienti
- Le prove sotto il minimo: rifiutate (PoW insufficiente)

**Recupero dei limiti**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementazione**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configurazione della rete

### Nodi seed e DNS seed

**Stato**: Segnaposto per il lancio della mainnet

**Configurazione pianificata**:
- Nodi seed: Da definire
- DNS seed: Da definire

**Stato attuale** (testnet/regtest):
- Nessuna infrastruttura seed dedicata
- Connessioni peer manuali supportate tramite `-addnode`

**Implementazione**: `src/kernel/chainparams.cpp`

### Checkpoint

**Checkpoint genesis**: Sempre blocco 0

**Checkpoint aggiuntivi**: Nessuno attualmente configurato

**Futuro**: I checkpoint verranno aggiunti man mano che la mainnet progredisce

---

## Configurazione del protocollo P2P

### Versione del protocollo

**Base**: Protocollo Bitcoin Core v30.0
- **Versione del protocollo**: Ereditata da Bitcoin Core
- **Service bits**: Servizi Bitcoin standard
- **Tipi di messaggio**: Messaggi P2P Bitcoin standard

**Estensioni PoCX**:
- Gli header dei blocchi includono campi specifici PoCX
- I messaggi dei blocchi includono i dati della prova PoCX
- Le regole di validazione applicano il consenso PoCX

**Compatibilità**: I nodi PoCX sono incompatibili con i nodi Bitcoin PoW (consenso diverso)

**Implementazione**: `src/protocol.h`, `src/net_processing.cpp`

---

## Struttura della directory dati

### Directory predefinita

**Posizione**: `.bitcoin/` (come Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Contenuti della directory

```
.bitcoin/
├── blocks/              # Dati dei blocchi
│   ├── blk*.dat        # File dei blocchi
│   ├── rev*.dat        # Dati di undo
│   └── index/          # Indice dei blocchi (LevelDB)
├── chainstate/         # Set UTXO + assegnazioni di forging (LevelDB)
├── wallets/            # File del wallet
│   └── wallet.dat      # Wallet predefinito
├── bitcoin.conf        # File di configurazione
├── debug.log           # Log di debug
├── peers.dat           # Indirizzi dei peer
├── mempool.dat         # Persistenza della mempool
└── banlist.dat         # Peer bannati
```

### Differenze chiave da Bitcoin

**Database chainstate**:
- Standard: Set UTXO
- **Aggiunta PoCX**: Stato delle assegnazioni di forging
- Aggiornamenti atomici: UTXO + assegnazioni aggiornati insieme
- Dati di undo sicuri per le riorganizzazioni per le assegnazioni

**File dei blocchi**:
- Formato blocco Bitcoin standard
- **Aggiunta PoCX**: Esteso con campi prova PoCX (account_id, seed, nonce, signature, pubkey)

### Esempio di file di configurazione

**bitcoin.conf**:
```ini
# Selezione della rete
#testnet=1
#regtest=1

# Server di mining PoCX (richiesto per miner esterni)
miningserver=1

# Impostazioni RPC
server=1
rpcuser=tuonomeutente
rpcpassword=tuapassword
rpcallowip=127.0.0.1
rpcport=8332

# Impostazioni di connessione
listen=1
port=8888
maxconnections=125

# Tempo di blocco target (informativo, applicato dal consenso)
# 120 secondi per mainnet/testnet
```

---

## Riferimenti al codice

**Chainparams**: `src/kernel/chainparams.cpp`
**Parametri di consenso**: `src/consensus/params.h`
**Limiti di compressione**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Calcolo del base target genesis**: `src/pocx/consensus/params.cpp`
**Logica di pagamento coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Storage dello stato delle assegnazioni**: `src/coins.h`, `src/coins.cpp` (estensioni CCoinsViewCache)

---

## Riferimenti incrociati

Capitoli correlati:
- [Capitolo 2: Formato dei plot](2-plot-format.md) - Livelli di scaling nella generazione dei plot
- [Capitolo 3: Consenso e mining](3-consensus-and-mining.md) - Validazione dello scaling, sistema di assegnazioni
- [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md) - Parametri di ritardo delle assegnazioni
- [Capitolo 5: Sicurezza temporale](5-timing-security.md) - Motivazione di MAX_FUTURE_BLOCK_TIME

---

[← Precedente: Sincronizzazione temporale](5-timing-security.md) | [Indice](index.md) | [Successivo: Riferimento RPC →](7-rpc-reference.md)
