[← Precedente: Riferimento RPC](7-rpc-reference.md) | [Indice](index.md)

---

# Capitolo 8: Guida al wallet e all'interfaccia grafica

Guida completa al wallet Qt di Bitcoin-PoCX e alla gestione delle assegnazioni di forging.

---

## Indice

1. [Panoramica](#panoramica)
2. [Unità di valuta](#unità-di-valuta)
3. [Finestra di dialogo delle assegnazioni di forging](#finestra-di-dialogo-delle-assegnazioni-di-forging)
4. [Cronologia delle transazioni](#cronologia-delle-transazioni)
5. [Requisiti degli indirizzi](#requisiti-degli-indirizzi)
6. [Integrazione del mining](#integrazione-del-mining)
7. [Risoluzione dei problemi](#risoluzione-dei-problemi)
8. [Best practice di sicurezza](#best-practice-di-sicurezza)

---

## Panoramica

### Funzionalità del wallet Bitcoin-PoCX

Il wallet Qt di Bitcoin-PoCX (`bitcoin-qt`) fornisce:
- Funzionalità standard del wallet Bitcoin Core (invio, ricezione, gestione transazioni)
- **Gestore delle assegnazioni di forging**: GUI per creare/revocare assegnazioni dei plot
- **Modalità server di mining**: Il flag `-miningserver` abilita le funzionalità relative al mining
- **Cronologia transazioni**: Visualizzazione delle transazioni di assegnazione e revoca

### Avvio del wallet

**Solo nodo** (senza mining):
```bash
./build/bin/bitcoin-qt
```

**Con mining** (abilita la finestra di dialogo delle assegnazioni):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternativa da riga di comando**:
```bash
./build/bin/bitcoind -miningserver
```

### Requisiti per il mining

**Per le operazioni di mining**:
- Flag `-miningserver` richiesto
- Wallet con indirizzi P2WPKH e chiavi private
- Plotter esterno (`pocx_plotter`) per la generazione dei plot
- Miner esterno (`pocx_miner`) per il mining

**Per il mining in pool**:
- Creare l'assegnazione di forging all'indirizzo del pool
- Wallet non richiesto sul server del pool (il pool gestisce le chiavi)

---

## Unità di valuta

### Visualizzazione delle unità

Bitcoin-PoCX usa l'unità di valuta **BTCX** (non BTC):

| Unità | Satoshi | Visualizzazione |
|-------|---------|-----------------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **µBTCX** | 100 | 1000000,00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Impostazioni GUI**: Preferenze → Visualizzazione → Unità

---

## Finestra di dialogo delle assegnazioni di forging

### Accedere alla finestra di dialogo

**Menu**: `Wallet → Assegnazioni di forging`
**Barra degli strumenti**: Icona del mining (visibile solo con il flag `-miningserver`)
**Dimensione finestra**: 600×450 pixel

### Modalità della finestra di dialogo

#### Modalità 1: Crea assegnazione

**Scopo**: Delegare i diritti di forging a un pool o a un altro indirizzo mantenendo la proprietà del plot.

**Casi d'uso**:
- Mining in pool (assegnare all'indirizzo del pool)
- Cold storage (chiave di mining separata dalla proprietà del plot)
- Infrastruttura condivisa (delegare a un hot wallet)

**Requisiti**:
- Indirizzo del plot (P2WPKH bech32, deve possedere la chiave privata)
- Indirizzo di forging (P2WPKH bech32, diverso dall'indirizzo del plot)
- Wallet sbloccato (se criptato)
- L'indirizzo del plot ha UTXO confermati

**Passaggi**:
1. Selezionare la modalità "Crea assegnazione"
2. Scegliere l'indirizzo del plot dal menu a discesa o inserirlo manualmente
3. Inserire l'indirizzo di forging (pool o delegato)
4. Cliccare "Invia assegnazione" (pulsante abilitato quando gli input sono validi)
5. La transazione viene trasmessa immediatamente
6. L'assegnazione diventa attiva dopo `nForgingAssignmentDelay` blocchi:
   - Mainnet/Testnet: 30 blocchi (~1 ora)
   - Regtest: 4 blocchi (~4 secondi)

**Fee della transazione**: Default 10× `minRelayFee` (personalizzabile)

**Struttura della transazione**:
- Input: UTXO dall'indirizzo del plot (dimostra la proprietà)
- Output OP_RETURN: marcatore `POCX` + plot_address + forging_address (46 byte)
- Output resto: Restituito al wallet

#### Modalità 2: Revoca assegnazione

**Scopo**: Annullare l'assegnazione di forging e restituire i diritti al proprietario del plot.

**Requisiti**:
- Indirizzo del plot (deve possedere la chiave privata)
- Wallet sbloccato (se criptato)
- L'indirizzo del plot ha UTXO confermati

**Passaggi**:
1. Selezionare la modalità "Revoca assegnazione"
2. Scegliere l'indirizzo del plot
3. Cliccare "Invia revoca"
4. La transazione viene trasmessa immediatamente
5. La revoca diventa effettiva dopo `nForgingRevocationDelay` blocchi:
   - Mainnet/Testnet: 720 blocchi (~24 ore)
   - Regtest: 8 blocchi (~8 secondi)

**Effetto**:
- L'indirizzo di forging può ancora forgiare durante il periodo di ritardo
- Il proprietario del plot riacquista i diritti dopo il completamento della revoca
- Può creare una nuova assegnazione successivamente

**Struttura della transazione**:
- Input: UTXO dall'indirizzo del plot (dimostra la proprietà)
- Output OP_RETURN: marcatore `XCOP` + plot_address (26 byte)
- Output resto: Restituito al wallet

#### Modalità 3: Controlla stato assegnazione

**Scopo**: Interrogare lo stato corrente dell'assegnazione per qualsiasi indirizzo di plot.

**Requisiti**: Nessuno (sola lettura, nessun wallet necessario)

**Passaggi**:
1. Selezionare la modalità "Controlla stato assegnazione"
2. Inserire l'indirizzo del plot
3. Cliccare "Controlla stato"
4. Il riquadro dello stato visualizza lo stato corrente con i dettagli

**Indicatori di stato** (codificati per colore):

**Grigio - UNASSIGNED**
```
UNASSIGNED - Nessuna assegnazione esiste
```

**Arancione - ASSIGNING**
```
ASSIGNING - Assegnazione in attesa di attivazione
Indirizzo di forging: pocx1qforger...
Creata all'altezza: 12000
Si attiva all'altezza: 12030 (5 blocchi rimanenti)
```

**Verde - ASSIGNED**
```
ASSIGNED - Assegnazione attiva
Indirizzo di forging: pocx1qforger...
Creata all'altezza: 12000
Attivata all'altezza: 12030
```

**Rosso-arancione - REVOKING**
```
REVOKING - Revoca in corso
Indirizzo di forging: pocx1qforger... (ancora attivo)
Assegnazione creata all'altezza: 12000
Revocata all'altezza: 12300
Revoca effettiva all'altezza: 13020 (50 blocchi rimanenti)
```

**Rosso - REVOKED**
```
REVOKED - Assegnazione revocata
Precedentemente assegnata a: pocx1qforger...
Assegnazione creata all'altezza: 12000
Revocata all'altezza: 12300
Revoca effettiva all'altezza: 13020
```

---

## Cronologia delle transazioni

### Visualizzazione delle transazioni di assegnazione

**Tipo**: "Assegnazione"
**Icona**: Icona del mining (come per i blocchi minati)

**Colonna indirizzo**: Indirizzo del plot (indirizzo i cui diritti di forging vengono assegnati)
**Colonna importo**: Fee della transazione (negativo, transazione in uscita)
**Colonna stato**: Conteggio conferme (0-6+)

**Dettagli** (quando si clicca):
- ID transazione
- Indirizzo del plot
- Indirizzo di forging (estratto dall'OP_RETURN)
- Creata all'altezza
- Altezza di attivazione
- Fee della transazione
- Timestamp

### Visualizzazione delle transazioni di revoca

**Tipo**: "Revoca"
**Icona**: Icona del mining

**Colonna indirizzo**: Indirizzo del plot
**Colonna importo**: Fee della transazione (negativo)
**Colonna stato**: Conteggio conferme

**Dettagli** (quando si clicca):
- ID transazione
- Indirizzo del plot
- Revocata all'altezza
- Altezza effettiva della revoca
- Fee della transazione
- Timestamp

### Filtro delle transazioni

**Filtri disponibili**:
- "Tutti" (default, include assegnazioni/revoche)
- Intervallo di date
- Intervallo di importi
- Ricerca per indirizzo
- Ricerca per ID transazione
- Ricerca per etichetta (se l'indirizzo è etichettato)

**Nota**: Le transazioni di assegnazione/revoca appaiono attualmente sotto il filtro "Tutti". Il filtro per tipo dedicato non è ancora implementato.

### Ordinamento delle transazioni

**Ordine di ordinamento** (per tipo):
- Generato (tipo 0)
- Ricevuto (tipo 1-3)
- Assegnazione (tipo 4)
- Revoca (tipo 5)
- Inviato (tipo 6+)

---

## Requisiti degli indirizzi

### Solo P2WPKH (SegWit v0)

**Le operazioni di forging richiedono**:
- Indirizzi codificati bech32 (che iniziano con "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Formato P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash della chiave da 20 byte

**NON supportati**:
- P2PKH (legacy, che inizia con "1")
- P2SH (SegWit wrapped, che inizia con "3")
- P2TR (Taproot, che inizia con "bc1p")

**Motivazione**: Le firme dei blocchi PoCX richiedono il formato witness v0 specifico per la validazione della prova.

### Filtro del menu a discesa degli indirizzi

**ComboBox indirizzo plot**:
- Popolato automaticamente con gli indirizzi di ricezione del wallet
- Filtra gli indirizzi non P2WPKH
- Mostra il formato: "Etichetta (indirizzo)" se etichettato, altrimenti solo l'indirizzo
- Primo elemento: "-- Inserisci indirizzo personalizzato --" per l'inserimento manuale

**Inserimento manuale**:
- Valida il formato quando inserito
- Deve essere bech32 P2WPKH valido
- Il pulsante è disabilitato se il formato non è valido

### Messaggi di errore di validazione

**Errori della finestra di dialogo**:
- "L'indirizzo del plot deve essere P2WPKH (bech32)"
- "L'indirizzo di forging deve essere P2WPKH (bech32)"
- "Formato indirizzo non valido"
- "Nessuna coin disponibile all'indirizzo del plot. Impossibile dimostrare la proprietà."
- "Impossibile creare transazioni con wallet in sola lettura"
- "Wallet non disponibile"
- "Wallet bloccato" (da RPC)

---

## Integrazione del mining

### Requisiti di configurazione

**Configurazione del nodo**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Requisiti del wallet**:
- Indirizzi P2WPKH per la proprietà del plot
- Chiavi private per il mining (o indirizzo di forging se si usano assegnazioni)
- UTXO confermati per la creazione delle transazioni

**Strumenti esterni**:
- `pocx_plotter`: Genera file plot
- `pocx_miner`: Scansiona i plot e invia i nonce

### Workflow

#### Mining in solitario

1. **Generare i file plot**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_byte> --nonces <count>
   ```

2. **Avviare il nodo** con server di mining:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configurare il miner**:
   - Puntare all'endpoint RPC del nodo
   - Specificare le directory dei file plot
   - Configurare l'account ID (dall'indirizzo del plot)

4. **Avviare il mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /percorso/ai/plot
   ```

5. **Monitorare**:
   - Il miner chiama `get_mining_info` ad ogni blocco
   - Scansiona i plot per la migliore deadline
   - Chiama `submit_nonce` quando trova una soluzione
   - Il nodo valida e forgia il blocco automaticamente

#### Mining in pool

1. **Generare i file plot** (come per il mining in solitario)

2. **Creare l'assegnazione di forging**:
   - Aprire la finestra di dialogo delle assegnazioni di forging
   - Selezionare l'indirizzo del plot
   - Inserire l'indirizzo di forging del pool
   - Cliccare "Invia assegnazione"
   - Attendere il ritardo di attivazione (30 blocchi testnet)

3. **Configurare il miner**:
   - Puntare all'endpoint del **pool** (non al nodo locale)
   - Il pool gestisce `submit_nonce` verso la catena

4. **Operazione del pool**:
   - Il wallet del pool ha le chiavi private dell'indirizzo di forging
   - Il pool valida gli invii dai miner
   - Il pool chiama `submit_nonce` verso la blockchain
   - Il pool distribuisce le ricompense secondo la policy del pool

### Ricompense coinbase

**Senza assegnazione**:
- Il coinbase paga direttamente l'indirizzo del proprietario del plot
- Controllare il saldo nell'indirizzo del plot

**Con assegnazione**:
- Il coinbase paga l'indirizzo di forging
- Il pool riceve le ricompense
- Il miner riceve la sua quota dal pool

**Programma delle ricompense**:
- Iniziale: 10 BTCX per blocco
- Halving: Ogni 1050000 blocchi (~4 anni)
- Programma: 10 → 5 → 2,5 → 1,25 → ...

---

## Risoluzione dei problemi

### Problemi comuni

#### "Il wallet non ha la chiave privata per l'indirizzo del plot"

**Causa**: Il wallet non possiede l'indirizzo
**Soluzione**:
- Importare la chiave privata tramite RPC `importprivkey`
- Oppure usare un indirizzo del plot diverso posseduto dal wallet

#### "Esiste già un'assegnazione per questo plot"

**Causa**: Il plot è già assegnato a un altro indirizzo
**Soluzione**:
1. Revocare l'assegnazione esistente
2. Attendere il ritardo di revoca (720 blocchi testnet)
3. Creare la nuova assegnazione

#### "Formato indirizzo non supportato"

**Causa**: L'indirizzo non è P2WPKH bech32
**Soluzione**:
- Usare indirizzi che iniziano con "pocx1q" (mainnet) o "tpocx1q" (testnet)
- Generare un nuovo indirizzo se necessario: `getnewaddress "" "bech32"`

#### "Fee della transazione troppo bassa"

**Causa**: Congestione della mempool della rete o fee troppo bassa per il relay
**Soluzione**:
- Aumentare il parametro fee rate
- Attendere che la mempool si svuoti

#### "Assegnazione non ancora attiva"

**Causa**: Il ritardo di attivazione non è ancora trascorso
**Soluzione**:
- Controllare lo stato: blocchi rimanenti fino all'attivazione
- Attendere il completamento del periodo di ritardo

#### "Nessuna coin disponibile all'indirizzo del plot"

**Causa**: L'indirizzo del plot non ha UTXO confermati
**Soluzione**:
1. Inviare fondi all'indirizzo del plot
2. Attendere 1 conferma
3. Riprovare la creazione dell'assegnazione

#### "Impossibile creare transazioni con wallet in sola lettura"

**Causa**: Il wallet ha importato l'indirizzo senza chiave privata
**Soluzione**: Importare la chiave privata completa, non solo l'indirizzo

#### "La scheda Assegnazione di forging non è visibile"

**Causa**: Il nodo è stato avviato senza il flag `-miningserver`
**Soluzione**: Riavviare con `bitcoin-qt -server -miningserver`

### Passi di debug

1. **Controllare lo stato del wallet**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verificare la proprietà dell'indirizzo**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Controllare: "iswatchonly": false, "ismine": true
   ```

3. **Controllare lo stato dell'assegnazione**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Visualizzare le transazioni recenti**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Controllare la sincronizzazione del nodo**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verificare: blocks == headers (completamente sincronizzato)
   ```

---

## Best practice di sicurezza

### Sicurezza dell'indirizzo del plot

**Gestione delle chiavi**:
- Memorizzare le chiavi private dell'indirizzo del plot in modo sicuro
- Le transazioni di assegnazione dimostrano la proprietà tramite firma
- Solo il proprietario del plot può creare/revocare assegnazioni

**Backup**:
- Eseguire backup regolari del wallet (`dumpwallet` o `backupwallet`)
- Memorizzare wallet.dat in una posizione sicura
- Registrare le frasi di recupero se si usa un wallet HD

### Delega dell'indirizzo di forging

**Modello di sicurezza**:
- L'indirizzo di forging riceve le ricompense dei blocchi
- L'indirizzo di forging può firmare i blocchi (mining)
- L'indirizzo di forging **non può** modificare o revocare l'assegnazione
- Il proprietario del plot mantiene il controllo completo

**Casi d'uso**:
- **Delega hot wallet**: Chiave del plot in cold storage, chiave di forging in hot wallet per il mining
- **Mining in pool**: Delegare al pool, mantenere la proprietà del plot
- **Infrastruttura condivisa**: Più miner, un indirizzo di forging

### Sincronizzazione dell'ora di rete

**Importanza**:
- Il consenso PoCX richiede un tempo accurato
- Una deriva dell'orologio >10s attiva un avviso
- Una deriva dell'orologio >15s impedisce il mining

**Soluzione**:
- Mantenere l'orologio di sistema sincronizzato con NTP
- Monitorare: `bitcoin-cli getnetworkinfo` per avvisi sull'offset temporale
- Usare server NTP affidabili

### Ritardi delle assegnazioni

**Ritardo di attivazione** (30 blocchi testnet):
- Previene la rapida riassegnazione durante i fork della catena
- Permette alla rete di raggiungere il consenso
- Non può essere bypassato

**Ritardo di revoca** (720 blocchi testnet):
- Fornisce stabilità per i pool di mining
- Previene attacchi di "griefing" sulle assegnazioni
- L'indirizzo di forging rimane attivo durante il ritardo

### Crittografia del wallet

**Abilitare la crittografia**:
```bash
bitcoin-cli encryptwallet "tua_passphrase"
```

**Sbloccare per le transazioni**:
```bash
bitcoin-cli walletpassphrase "tua_passphrase" 300
```

**Best practice**:
- Usare una passphrase forte (20+ caratteri)
- Non memorizzare la passphrase in testo semplice
- Bloccare il wallet dopo aver creato le assegnazioni

---

## Riferimenti al codice

**Finestra di dialogo assegnazioni di forging**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Visualizzazione transazioni**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsing transazioni**: `src/qt/transactionrecord.cpp`
**Integrazione wallet**: `src/pocx/assignments/transactions.cpp`
**RPC assegnazioni**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI principale**: `src/qt/bitcoingui.cpp`

---

## Riferimenti incrociati

Capitoli correlati:
- [Capitolo 3: Consenso e mining](3-consensus-and-mining.md) - Processo di mining
- [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md) - Architettura delle assegnazioni
- [Capitolo 6: Parametri di rete](6-network-parameters.md) - Valori dei ritardi delle assegnazioni
- [Capitolo 7: Riferimento RPC](7-rpc-reference.md) - Dettagli dei comandi RPC

---

[← Precedente: Riferimento RPC](7-rpc-reference.md) | [Indice](index.md)
