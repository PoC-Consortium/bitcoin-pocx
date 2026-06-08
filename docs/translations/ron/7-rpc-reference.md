[← Anterior: Parametri de rețea](6-network-parameters.md) | [📘 Cuprins](index.md) | [Următorul: Ghid portofel →](8-wallet-guide.md)

---

# Capitolul 7: Referință interfață RPC

Referință completă pentru comenzile RPC Bitcoin-PoCX, incluzând RPC-urile de minerit, gestionarea atribuirilor și RPC-urile blockchain modificate.

---

## Cuprins

1. [Configurare](#configurare)
2. [RPC-uri de minerit PoCX](#rpc-uri-de-minerit-pocx)
3. [RPC-uri de atribuiri](#rpc-uri-de-atribuiri)
4. [RPC-uri blockchain modificate](#rpc-uri-blockchain-modificate)
5. [RPC-uri dezactivate](#rpc-uri-dezactivate)
6. [Exemple de integrare](#exemple-de-integrare)

---

## Configurare

### Modul server de minerit

**Flag**: ``

**Scop**: Activează accesul RPC pentru minerii externi pentru a apela RPC-uri specifice mineritului

**Cerințe**:
- Necesar pentru funcționarea `submit_nonce`
- Necesar pentru vizibilitatea dialogului de atribuire a forjării în portofelul Qt

**Utilizare**:
```bash
# Linie de comandă
./bitcoind

# bitcoin.conf
```

**Considerații de securitate**:
- Fără autentificare suplimentară dincolo de credențialele RPC standard
- RPC-urile de minerit sunt limitate de capacitatea cozii
- Autentificarea RPC standard este în continuare necesară

**Implementare**: `src/pocx/rpc/mining.cpp`

---

## RPC-uri de minerit PoCX

### get_mining_info

**Categorie**: mining
**Necesită server de minerit**: Nu
**Necesită portofel**: Nu

**Scop**: Returnează parametrii de minerit actuali necesari pentru ca minerii externi să scaneze fișierele plot și să calculeze deadline-urile.

**Parametri**: Niciunul

**Valori returnate**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 caractere
  "base_target": 36650387592,                // numeric
  "height": 12345,                           // numeric, înălțimea următorului bloc
  "block_hash": "def456...",                 // hex, blocul anterior
  "target_quality": 18446744073709551615,    // uint64_max (toate soluțiile acceptate)
  "minimum_compression_level": 1,            // numeric
  "target_compression_level": 2              // numeric
}
```

**Descrieri câmpuri**:
- `generation_signature`: Entropia deterministă de minerit pentru această înălțime de bloc
- `base_target`: Dificultatea curentă (mai mare = mai ușor)
- `height`: Înălțimea blocului pe care minerii ar trebui să o țintească
- `block_hash`: Hash-ul blocului anterior (informațional)
- `target_quality`: Pragul de calitate (momentan uint64_max, fără filtrare)
- `minimum_compression_level`: Compresia minimă necesară pentru validare
- `target_compression_level`: Compresia recomandată pentru minerit optim

**Coduri de eroare**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nodul încă sincronizează

**Exemplu**:
```bash
bitcoin-cli get_mining_info
```

**Implementare**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Categorie**: mining
**Necesită portofel**: Da (pentru chei private)

**Scop**: Trimite o soluție de minerit PoCX. Validează dovada, pune în coadă pentru forjare time-bended și creează automat blocul la momentul programat.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (exact 40 caractere hex = 20 octeți; o adresă nu este acceptată)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Valori returnate** (succes):
```json
{
  "raw_quality": 120,       // calitate brută din validarea dovezii
  "poc_time": 45            // timp de forjare time-bended în secunde
}
```

Nu există câmpul `accepted`. La respingere, RPC-ul **nu** returnează un obiect JSON — aruncă un `JSONRPCError` (vezi Coduri de eroare mai jos).

**Pași de validare**:
1. **Validare format** (eșec rapid):
   - Account ID: exact 40 caractere hex
   - Seed: exact 64 caractere hex
2. **Validare context**:
   - Înălțimea trebuie să corespundă cu vârful curent + 1
   - Semnătura de generare trebuie să corespundă cu cea curentă
3. **Verificare portofel**:
   - Determină semnatarul efectiv (verifică atribuirile active)
   - Verifică că portofelul are cheia privată pentru semnatarul efectiv
4. **Validare dovadă** (costisitoare):
   - Validează dovada PoCX cu limitele de compresie
   - Calculează calitatea brută
5. **Trimitere planificator**:
   - Pune nonce-ul în coadă pentru forjare time-bended
   - Blocul va fi creat automat la forge_time

**Coduri de eroare** (aruncate ca `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Format invalid (account_id, seed) sau nepotrivire înălțime (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Nepotrivire semnătură de generare sau validare dovadă eșuată
- `RPC_INVALID_ADDRESS_OR_KEY`: Fără cheie privată pentru semnatarul efectiv
- `RPC_WALLET_UNLOCK_NEEDED`: Portofelul care deține cheia semnatarului efectiv este blocat (deblochează cu `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Coada de trimitere plină
- `RPC_INTERNAL_ERROR`: Inițializarea planificatorului PoCX a eșuat

**Coduri de eroare validare dovadă**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Exemplu**:
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
- Trimiterea este asincronă - RPC returnează imediat, blocul este forjat ulterior
- Time Bending întârzie soluțiile bune pentru a permite scanarea plot-urilor în întreaga rețea
- Sistemul de atribuiri: dacă plot-ul este atribuit, portofelul trebuie să aibă cheia adresei de forjare
- Limitele de compresie sunt ajustate dinamic pe baza înălțimii blocului

**Implementare**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC-uri de atribuiri

### get_assignment

**Categorie**: mining
**Necesită server de minerit**: Nu
**Necesită portofel**: Nu

**Scop**: Interogă starea atribuirii de forjare pentru o adresă de plot. Doar citire, fără portofel necesar.

**Parametri**:
1. `plot_address` (string, obligatoriu) - Adresa plot-ului (format P2WPKH bech32)
2. `height` (numeric, opțional) - Înălțimea blocului pentru interogare (implicit: vârful curent)

**Valori returnate** (fără atribuire):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Valori returnate** (atribuire activă):
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

**Valori returnate** (în revocare):
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

**Stări atribuiri**:
- `UNASSIGNED`: Nu există atribuire
- `ASSIGNING`: Tranzacție atribuire confirmată, întârziere activare în curs
- `ASSIGNED`: Atribuire activă, drepturi de forjare delegate
- `REVOKING`: Tranzacție revocare confirmată, încă activă până la scurgerea întârzierii
- `REVOKED`: Revocare completă, drepturi de forjare returnate proprietarului plot-ului

**Coduri de eroare**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Adresă invalidă sau nu este P2WPKH (bech32)

**Exemplu**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementare**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Categorie**: wallet
**Necesită server de minerit**: Nu
**Necesită portofel**: Da (trebuie să fie încărcat și deblocat)

**Scop**: Creează tranzacție de atribuire a forjării pentru a delega drepturile de forjare către o altă adresă (ex. pool de minerit).

**Parametri**:
1. `plot_address` (string, obligatoriu) - Adresa proprietarului plot-ului (trebuie să dețină cheia privată, P2WPKH bech32)
2. `forging_address` (string, obligatoriu) - Adresa căreia i se atribuie drepturile de forjare (P2WPKH bech32)
3. `fee_rate` (numeric, opțional) - Rata taxei în BTCX/kvB (implicit: `0` → estimarea standard a taxei minime a portofelului; valoarea implicită de 10× minRelayFee se aplică doar dialogului Qt GUI, nu acestui RPC)

**Valori returnate**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Cerințe**:
- Portofelul încărcat și deblocat
- Cheia privată pentru plot_address în portofel
- Ambele adrese trebuie să fie P2WPKH (format bech32: pocx1q... mainnet, tpocx1q... testnet)
- Adresa plot trebuie să aibă UTXO-uri confirmate (demonstrează proprietatea)
- Plot-ul nu trebuie să aibă atribuire activă (folosiți revoke mai întâi)

**Structura tranzacției**:
- Intrare: UTXO de la adresa plot (demonstrează proprietatea)
- Ieșire: script OP_RETURN (46 octeți) = opcode `OP_RETURN` + lungime push de 1 octet + sarcină utilă de date de 44 octeți (marker `POCX` 4 + plot_address 20 + forging_address 20)
- Ieșire: Restul returnat în portofel

**Activare**:
- Atribuirea devine ASSIGNING la confirmare
- Devine ACTIVE după `nForgingAssignmentDelay` blocuri
- Întârzierea previne reatribuirea rapidă în timpul fork-urilor de lanț

**Coduri de eroare**:
- `RPC_WALLET_NOT_FOUND`: Niciun portofel disponibil
- `RPC_WALLET_UNLOCK_NEEDED`: Portofel criptat și blocat
- `RPC_WALLET_ERROR`: Crearea tranzacției a eșuat
- `RPC_INVALID_ADDRESS_OR_KEY`: Format de adresă invalid

**Exemplu**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementare**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Categorie**: wallet
**Necesită server de minerit**: Nu
**Necesită portofel**: Da (trebuie să fie încărcat și deblocat)

**Scop**: Revocă atribuirea de forjare existentă, returnând drepturile de forjare proprietarului plot-ului.

**Parametri**:
1. `plot_address` (string, obligatoriu) - Adresa plot-ului (trebuie să dețină cheia privată, P2WPKH bech32)
2. `fee_rate` (numeric, opțional) - Rata taxei în BTCX/kvB (implicit: `0` → estimarea standard a taxei minime a portofelului; valoarea implicită de 10× minRelayFee se aplică doar dialogului Qt GUI, nu acestui RPC)

**Valori returnate**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Cerințe**:
- Portofelul încărcat și deblocat
- Cheia privată pentru plot_address în portofel
- Adresa plot trebuie să fie P2WPKH (format bech32)
- Adresa plot trebuie să aibă UTXO-uri confirmate

**Structura tranzacției**:
- Intrare: UTXO de la adresa plot (demonstrează proprietatea)
- Ieșire: script OP_RETURN (26 octeți) = opcode `OP_RETURN` + lungime push de 1 octet + sarcină utilă de date de 24 octeți (marker `XCOP` 4 + plot_address 20)
- Ieșire: Restul returnat în portofel

**Efect**:
- Starea trece la REVOKING imediat
- Adresa de forjare poate încă forja în perioada de întârziere
- Devine REVOKED după `nForgingRevocationDelay` blocuri
- Proprietarul plot-ului poate forja după ce revocarea devine efectivă
- Poate crea atribuire nouă după finalizarea revocării

**Coduri de eroare**:
- `RPC_WALLET_NOT_FOUND`: Niciun portofel disponibil
- `RPC_WALLET_UNLOCK_NEEDED`: Portofel criptat și blocat
- `RPC_WALLET_ERROR`: Crearea tranzacției a eșuat

**Exemplu**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Note**:
- Idempotent: poate revoca chiar dacă nu există atribuire activă
- Nu se poate anula revocarea odată trimisă

**Implementare**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPC-uri blockchain modificate

### getdifficulty

**Modificări PoCX**:
- **Calcul**: `reference_base_target / current_base_target`
- **Referință**: Capacitate de rețea de 1 TiB (base_target = 36650387592)
- **Interpretare**: Capacitate estimată de stocare a rețelei în TiB
  - Exemplu: `1.0` = ~1 TiB
  - Exemplu: `1024.0` = ~1 PiB
- **Diferență față de PoW**: Reprezintă capacitate, nu putere de hash

**Exemplu**:
```bash
bitcoin-cli getdifficulty
# Returnează: 2048.5 (rețea ~2 PiB)
```

**Implementare**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Câmpuri adăugate PoCX**:
- `time_since_last_block` (numeric) - Secunde de la blocul anterior (înlocuiește mediantime)
- `poc_time` (numeric) - Timp de forjare time-bended în secunde
- `base_target` (numeric) - Ținta de bază a dificultății PoCX
- `generation_signature` (string hex) - Semnătura de generare
- `pocx_proof` (obiect):
  - `account_id` (string hex) - ID-ul contului plot (20 octeți)
  - `seed` (string hex) - Seed-ul plot-ului (32 octeți)
  - `nonce` (numeric) - Nonce-ul de minerit
  - `compression` (numeric) - Nivelul de scalare folosit
  - `quality` (numeric) - Valoarea calității declarate
- `pubkey` (string hex) - Cheia publică a semnatarului blocului (33 octeți)
- `signer_address` (string) - Adresa semnatarului blocului
- `signature` (string hex) - Semnătura blocului (65 octeți)

**Câmpuri eliminate PoCX**:
- `mediantime` - Eliminat (înlocuit de time_since_last_block)

**Exemplu**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementare**: `src/rpc/blockchain.cpp`

---

### getblock

**Modificări PoCX**: La fel ca getblockheader, plus datele complete ale tranzacțiilor

**Exemplu**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbos cu detalii tx
```

**Implementare**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Câmpuri adăugate PoCX**:
- `base_target` (numeric) - Ținta de bază curentă
- `generation_signature` (string hex) - Semnătura de generare curentă

**Câmpuri modificate PoCX**:
- `difficulty` - Folosește calculul PoCX (bazat pe capacitate)

**Câmpuri eliminate PoCX**:
- `mediantime` - Eliminat

**Exemplu**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementare**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Câmpuri adăugate PoCX**:
- `generation_signature` (string hex) - Pentru minerit în pool
- `base_target` (numeric) - Pentru minerit în pool

**Câmpuri eliminate PoCX**:
- `target` - Eliminat (specific PoW)
- `noncerange` - Eliminat (specific PoW)
- `bits` - Eliminat (specific PoW)

**Note**:
- Include încă datele complete ale tranzacțiilor pentru construcția blocului
- Folosit de serverele de pool pentru minerit coordonat

**Exemplu**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementare**: `src/rpc/mining.cpp`

---

## RPC-uri dezactivate

Următoarele RPC-uri specifice PoW sunt **dezactivate** în modul PoCX:

### getnetworkhashps
- **Motiv**: Rata de hash nu se aplică la Proof of Capacity
- **Alternativă**: Folosiți `getdifficulty` pentru estimarea capacității rețelei

### getmininginfo
- **Motiv**: Returnează informații specifice PoW
- **Alternativă**: Folosiți `get_mining_info` (specific PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Exemple de integrare

### Integrare miner extern

**Bucla de minerit de bază**:
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

# Bucla de minerit
while True:
    # 1. Obține parametrii de minerit
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scanează fișierele plot (implementare externă)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Trimite cea mai bună soluție (aruncă JSONRPCError la respingere)
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
        print(f"Soluție acceptată! Calitate: {result['raw_quality']}, "
              f"Timp forjare: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Respins: {e}")

    # 4. Așteaptă următorul bloc
    time.sleep(10)  # Interval de interogare
```

---

### Model de integrare pool

**Fluxul serverului de pool**:
1. Minerii creează atribuiri de forjare către adresa pool-ului
2. Pool-ul rulează portofel cu cheile adresei de forjare
3. Pool-ul apelează `get_mining_info` și distribuie către mineri
4. Minerii trimit soluții prin pool (nu direct la lanț)
5. Pool-ul validează și apelează `submit_nonce` cu cheile pool-ului
6. Pool-ul distribuie recompensele conform politicii pool-ului

**Gestionarea atribuirilor**:
```bash
# Minerul creează atribuire (din portofelul minerului)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Așteaptă activarea (30 blocuri mainnet)

# Pool-ul verifică starea atribuirii
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool-ul poate acum trimite nonce-uri pentru acest plot
# (portofelul pool-ului trebuie să aibă cheia privată pocx1qpool...)
```

---

### Interogări block explorer

**Interogarea datelor blocului PoCX**:
```bash
# Obține ultimul bloc
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Obține detaliile blocului cu dovada PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extrage câmpurile specifice PoCX
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

**Detectarea tranzacțiilor de atribuire**:
```bash
# Scanează tranzacția pentru OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Verifică pentru marker atribuire (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Gestionarea erorilor

### Modele de erori comune

**Nepotrivire înălțime** (aruncat `RPC_INVALID_PARAMETER`, cod -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Soluție**: Re-obțineți mining info, lanțul a avansat

**Nepotrivire semnătură de generare** (aruncat `RPC_VERIFY_REJECTED`, cod -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Soluție**: Re-obțineți mining info, un nou bloc a sosit

**Fără cheie privată**:
```json
{
  "code": -5,
  "message": "Nicio cheie privată disponibilă pentru semnatarul efectiv"
}
```
**Soluție**: Importați cheia pentru adresa plot sau forjare

**Activare atribuire în așteptare**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Soluție**: Așteptați să treacă întârzierea de activare

---

## Referințe cod

**RPC-uri minerit**: `src/pocx/rpc/mining.cpp`
**RPC-uri atribuiri**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPC-uri blockchain**: `src/rpc/blockchain.cpp`
**Validare dovadă**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Stare atribuiri**: `src/pocx/assignments/assignment_state.cpp`
**Creare tranzacții**: `src/pocx/assignments/transactions.cpp`

---

## Referințe încrucișate

Capitole conexe:
- [Capitolul 3: Consens și minerit](3-consensus-and-mining.md) - Detalii proces de minerit
- [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md) - Arhitectura sistemului de atribuiri
- [Capitolul 6: Parametri de rețea](6-network-parameters.md) - Valori întârziere atribuiri
- [Capitolul 8: Ghid portofel](8-wallet-guide.md) - GUI pentru gestionarea atribuirilor

---

[← Anterior: Parametri de rețea](6-network-parameters.md) | [📘 Cuprins](index.md) | [Următorul: Ghid portofel →](8-wallet-guide.md)
