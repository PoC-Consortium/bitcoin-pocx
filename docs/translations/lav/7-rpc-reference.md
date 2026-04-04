[← Iepriekšējā: Tīkla parametri](6-network-parameters.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Maka ceļvedis →](8-wallet-guide.md)

---

# 7. nodaļa: RPC saskarnes atsauce

Pilnīga atsauce Bitcoin-PoCX RPC komandām, ieskaitot kalnrūpniecības RPC, piešķīrumu pārvaldību un modificētas blokķēdes RPC.

---

## Satura rādītājs

1. [Konfigurācija](#konfigurācija)
2. [PoCX kalnrūpniecības RPC](#pocx-kalnrūpniecības-rpc)
3. [Piešķīrumu RPC](#piešķīrumu-rpc)
4. [Modificētās blokķēdes RPC](#modificētās-blokķēdes-rpc)
5. [Atspējotās RPC](#atspējotās-rpc)
6. [Integrācijas piemēri](#integrācijas-piemēri)

---

## Konfigurācija

### Kalnrūpniecības servera režīms

**Karodziņš**: ``

**Mērķis**: Iespējo RPC piekļuvi ārējiem kalnračiem izsaukt kalnrūpniecībai specifiskas RPC

**Prasības**:
- Nepieciešams, lai `submit_nonce` darbotos
- Nepieciešams, lai kalšanas piešķīrumu dialogs būtu redzams Qt maciņā

**Lietošana**:
```bash
# Komandrinda
./bitcoind

# bitcoin.conf
```

**Drošības apsvērumi**:
- Nav papildu autentifikācijas ārpus standarta RPC akreditācijas datiem
- Kalnrūpniecības RPC ir ātruma ierobežotas pēc rindas jaudas
- Joprojām nepieciešama standarta RPC autentifikācija

**Implementācija**: `src/pocx/rpc/mining.cpp`

---

## PoCX kalnrūpniecības RPC

### get_mining_info

**Kategorija**: mining
**Nepieciešams maciņš**: Nē

**Mērķis**: Atgriež pašreizējos kalnrūpniecības parametrus, kas nepieciešami ārējiem kalnračiem, lai skenētu plotfailus un aprēķinātu termiņus.

**Parametri**: Nav

**Atgriešanas vērtības**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 simboli
  "base_target": 36650387592,                // skaitlisks
  "height": 12345,                           // skaitlisks, nākamā bloka augstums
  "block_hash": "def456...",                 // hex, iepriekšējais bloks
  "target_quality": 18446744073709551615,    // uint64_max (visi risinājumi pieņemti)
  "minimum_compression_level": 1,            // skaitlisks
  "target_compression_level": 2              // skaitlisks
}
```

**Lauku apraksti**:
- `generation_signature`: Deterministiska kalnrūpniecības entropija šim bloka augstumam
- `base_target`: Pašreizējā grūtība (augstāka = vieglāk)
- `height`: Bloka augstums, kuru kalnračiem jāmērķē
- `block_hash`: Iepriekšējā bloka jaucējvērtība (informatīvs)
- `target_quality`: Kvalitātes slieksnis (pašlaik uint64_max, nav filtrēšanas)
- `minimum_compression_level`: Minimālā kompresija, kas nepieciešama validācijai
- `target_compression_level`: Ieteicamā kompresija optimālai kalnrūpniecībai

**Kļūdu kodi**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Mezgls joprojām sinhronizējas

**Piemērs**:
```bash
bitcoin-cli get_mining_info
```

**Implementācija**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategorija**: mining
**Nepieciešams maciņš**: Jā (privātajām atslēgām)

**Mērķis**: Iesniegt PoCX kalnrūpniecības risinājumu. Validē pierādījumu, ievieto rindā laika līkumo kalšanai un automātiski izveido bloku plānotajā laikā.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (20-byte hex or address)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Atgriešanas vērtības** (veiksme):
```json
{
  "accepted": true,
  "raw_quality": 120,       // raw quality from proof validation
  "poc_time": 45            // laika līkumo kalšanas laiks sekundēs
}
```

**Atgriešanas vērtības** (noraidīts):
```json
{
  "accepted": false,
  "error": "Ģenerēšanas paraksta nesakritība"
}
```

**Validācijas soļi**:
1. **Formāta validācija** (ātra neveiksme):
   - Konta ID: tieši 40 hex simboli
   - Sēkla: tieši 64 hex simboli
2. **Konteksta validācija**:
   - Augstumam jāsakrīt ar pašreizējo virsotni + 1
   - Ģenerēšanas parakstam jāsakrīt ar pašreizējo
3. **Maciņa verifikācija**:
   - Noteikt efektīvo parakstītāju (pārbaudīt aktīvos piešķīrumus)
   - Verificēt, ka maciņam ir privātā atslēga efektīvajam parakstītājam
4. **Pierādījuma validācija** (dārga):
   - Validēt PoCX pierādījumu ar kompresijas robežām
   - Aprēķināt neapstrādātu kvalitāti
5. **Plānotāja iesniegšana**:
   - Ievietot nonce rindā laika līkumo kalšanai
   - Bloks tiks izveidots automātiski forge_time laikā

**Kļūdu kodi**:
- `RPC_INVALID_PARAMETER`: Nederīgs formāts (account_id, seed) vai augstuma nesakritība
- `RPC_VERIFY_REJECTED`: Ģenerēšanas paraksta nesakritība vai pierādījuma validācija neizdevās
- `RPC_INVALID_ADDRESS_OR_KEY`: Nav privātās atslēgas efektīvajam parakstītājam
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Iesniegumu rinda pilna
- `RPC_INTERNAL_ERROR`: Neizdevās inicializēt PoCX plānotāju

**Pierādījuma validācijas kļūdu kodi**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Piemērs**:
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

**Piezīmes**:
- Iesniegšana ir asinhrona - RPC atgriežas nekavējoties, bloks tiek kalts vēlāk
- Laika līkumo aizkavē labus risinājumus, lai ļautu visam tīklam skenēt plotfailus
- Piešķīrumu sistēma: ja plotfails piešķirts, maciņam jābūt kalšanas adreses atslēgai
- Kompresijas robežas tiek dinamiski pielāgotas, balstoties uz bloka augstumu

**Implementācija**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Piešķīrumu RPC

### get_assignment

**Kategorija**: mining
**Nepieciešams maciņš**: Nē

**Mērķis**: Vaicāt kalšanas piešķīruma statusu plotfaila adresei. Tikai lasīšana, nav nepieciešams maciņš.

**Parametri**:
1. `plot_address` (virkne, obligāts) - Plotfaila adrese (bech32 P2WPKH formāts)
2. `height` (skaitlisks, neobligāts) - Bloka augstums vaicājumam (noklusējums: pašreizējā virsotne)

**Atgriešanas vērtības** (nav piešķīruma):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Atgriešanas vērtības** (aktīvs piešķīrums):
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

**Atgriešanas vērtības** (atsaukšana procesā):
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

**Piešķīrumu stāvokļi**:
- `UNASSIGNED`: Piešķīrums neeksistē
- `ASSIGNING`: Piešķīruma darījums apstiprināts, aktivizācijas aizkave procesā
- `ASSIGNED`: Piešķīrums aktīvs, kalšanas tiesības deleģētas
- `REVOKING`: Atsaukšanas darījums apstiprināts, joprojām aktīvs līdz aizkave iziet
- `REVOKED`: Atsaukšana pabeigta, kalšanas tiesības atgrieztas plotfaila īpašniekam

**Kļūdu kodi**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Nederīga adrese vai nav P2WPKH (bech32)

**Piemērs**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementācija**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategorija**: wallet
**Nepieciešams maciņš**: Jā (jābūt ielādētam un atbloķētam)

**Mērķis**: Izveidot kalšanas piešķīruma darījumu, lai deleģētu kalšanas tiesības citai adresei (piem., kalnrūpniecības pūlam).

**Parametri**:
1. `plot_address` (virkne, obligāts) - Plotfaila īpašnieka adrese (jāpieder privātā atslēga, P2WPKH bech32)
2. `forging_address` (virkne, obligāts) - Adrese, kurai piešķirt kalšanas tiesības (P2WPKH bech32)
3. `fee_rate` (skaitlisks, neobligāts) - Maksas likme BTC/kvB (noklusējums: 10× minRelayFee)

**Atgriešanas vērtības**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Prasības**:
- Maciņš ielādēts un atbloķēts
- Privātā atslēga plot_address maciņā
- Abām adresēm jābūt P2WPKH (bech32 formāts: pocx1q... mainnet, tpocx1q... testnet)
- Plotfaila adresei jābūt apstiprinātiem UTXO (pierāda īpašumtiesības)
- Plotfailam nedrīkst būt aktīvs piešķīrums (vispirms izmantojiet atsaukšanu)

**Darījuma struktūra**:
- Ievade: UTXO no plotfaila adreses (pierāda īpašumtiesības)
- Izvade: OP_RETURN (46 baiti): `POCX` marķieris + plot_address (20 baiti) + forging_address (20 baiti)
- Izvade: Atlikums atgriezts maciņā

**Aktivizācija**:
- Piešķīrums kļūst ASSIGNING apstiprinājuma brīdī
- Becomes ASSIGNED after `nForgingAssignmentDelay` blocks
- Aizkave novērš ātru pārpiešķiršanu ķēdes dakšu laikā

**Kļūdu kodi**:
- `RPC_WALLET_NOT_FOUND`: Nav pieejams maciņš
- `RPC_WALLET_UNLOCK_NEEDED`: Maciņš šifrēts un bloķēts
- `RPC_WALLET_ERROR`: Darījuma izveide neizdevās
- `RPC_INVALID_ADDRESS_OR_KEY`: Nederīgs adreses formāts

**Piemērs**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementācija**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategorija**: wallet
**Nepieciešams maciņš**: Jā (jābūt ielādētam un atbloķētam)

**Mērķis**: Atsaukt esošu kalšanas piešķīrumu, atgriežot kalšanas tiesības plotfaila īpašniekam.

**Parametri**:
1. `plot_address` (virkne, obligāts) - Plotfaila adrese (jāpieder privātā atslēga, P2WPKH bech32)
2. `fee_rate` (skaitlisks, neobligāts) - Maksas likme BTC/kvB (noklusējums: 10× minRelayFee)

**Atgriešanas vērtības**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Prasības**:
- Maciņš ielādēts un atbloķēts
- Privātā atslēga plot_address maciņā
- Plotfaila adresei jābūt P2WPKH (bech32 formāts)
- Plotfaila adresei jābūt apstiprinātiem UTXO

**Darījuma struktūra**:
- Ievade: UTXO no plotfaila adreses (pierāda īpašumtiesības)
- Izvade: OP_RETURN (26 baiti): `XCOP` marķieris + plot_address (20 baiti)
- Izvade: Atlikums atgriezts maciņā

**Efekts**:
- Stāvoklis nekavējoties pāriet uz REVOKING
- Kalšanas adrese joprojām var kalst aizkaves periodā
- Kļūst REVOKED pēc `nForgingRevocationDelay` blokiem
- Plotfaila īpašnieks var kalst pēc atsaukšanas stāšanās spēkā
- Var izveidot jaunu piešķīrumu pēc atsaukšanas pabeigšanas

**Kļūdu kodi**:
- `RPC_WALLET_NOT_FOUND`: Nav pieejams maciņš
- `RPC_WALLET_UNLOCK_NEEDED`: Maciņš šifrēts un bloķēts
- `RPC_WALLET_ERROR`: Darījuma izveide neizdevās

**Piemērs**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Piezīmes**:
- Idempotenta: var atsaukt pat ja nav aktīva piešķīruma
- Nevar atcelt atsaukšanu, kad iesniegta

**Implementācija**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modificētās blokķēdes RPC

### getdifficulty

**PoCX modifikācijas**:
- **Aprēķins**: `reference_base_target / current_base_target`
- **Atsauce**: 1 TiB tīkla jauda (base_target = 36650387592)
- **Interpretācija**: Aptuvena tīkla glabāšanas jauda TiB
  - Piemērs: `1.0` = ~1 TiB
  - Piemērs: `1024.0` = ~1 PiB
- **Atšķirība no PoW**: Pārstāv jaudu, nevis jaucējātrumu

**Piemērs**:
```bash
bitcoin-cli getdifficulty
# Atgriež: 2048.5 (tīkls ~2 PiB)
```

**Implementācija**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX pievienotie lauki**:
- `time_since_last_block` (skaitlisks) - Sekundes kopš iepriekšējā bloka (aizstāj mediantime)
- `poc_time` (skaitlisks) - Laika līkumo kalšanas laiks sekundēs
- `base_target` (skaitlisks) - PoCX grūtības bāzes mērķis
- `generation_signature` (virkne hex) - Ģenerēšanas paraksts
- `pocx_proof` (objekts):
  - `account_id` (virkne hex) - Plotfaila konta ID (20 baiti)
  - `seed` (virkne hex) - Plotfaila sēkla (32 baiti)
  - `nonce` (skaitlisks) - Kalnrūpniecības nonce
  - `compression` (skaitlisks) - Izmantotais mērogošanas līmenis
  - `quality` (skaitlisks) - Deklarētā kvalitātes vērtība
- `pubkey` (virkne hex) - Bloka parakstītāja publiskā atslēga (33 baiti)
- `signer_address` (virkne) - Bloka parakstītāja adrese
- `signature` (virkne hex) - Bloka paraksts (65 baiti)

**PoCX noņemtie lauki**:
- `mediantime` - Noņemts (aizstāts ar time_since_last_block)

**Piemērs**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementācija**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX modifikācijas**: Tāpat kā getblockheader, plus pilni darījumu dati

**Piemērs**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # detalizēts ar darījumu detaļām
```

**Implementācija**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX pievienotie lauki**:
- `base_target` (skaitlisks) - Pašreizējais bāzes mērķis
- `generation_signature` (virkne hex) - Pašreizējais ģenerēšanas paraksts

**PoCX modificētie lauki**:
- `difficulty` - Izmanto PoCX aprēķinu (uz jaudu balstīts)

**PoCX noņemtie lauki**:
- `mediantime` - Noņemts

**Piemērs**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementācija**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX pievienotie lauki**:
- `generation_signature` (virkne hex) - Pūla kalnrūpniecībai
- `base_target` (skaitlisks) - Pūla kalnrūpniecībai

**PoCX noņemtie lauki**:
- `target` - Removed (replaced by `base_target`)
- `noncerange` - Noņemts (PoW specifisks)
- `bits` - Noņemts (PoW specifisks)

**Piezīmes**:
- Joprojām ietver pilnus darījumu datus bloka konstrukcijai
- Izmanto pūla serveri koordinētai kalnrūpniecībai

**Piemērs**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementācija**: `src/rpc/mining.cpp`

---

## Atspējotās RPC

Šīs PoW specifiskās RPC ir **atspējotas** PoCX režīmā:

### getnetworkhashps
- **Iemesls**: Jaucējātrums nav piemērojams jaudas pierādījumam
- **Alternatīva**: Izmantojiet `getdifficulty` tīkla jaudas aptuvenim vērtējumam

### getmininginfo
- **Iemesls**: Atgriež PoW specifisko informāciju
- **Alternatīva**: Izmantojiet `get_mining_info` (PoCX specifiska)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Integrācijas piemēri

### Ārējā kalnraču integrācija

**Pamata kalnrūpniecības cilpa**:
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

# Kalnrūpniecības cilpa
while True:
    # 1. Iegūt kalnrūpniecības parametrus
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skenēt plotfailus (ārēja implementācija)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Iesniegt labāko risinājumu
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

    if result["accepted"]:
        print(f"Risinājums pieņemts! Kvalitāte: {result['quality']}s, "
              f"Kalšanas laiks: {result['poc_time']}s")

    # 4. Gaidīt nākamo bloku
    time.sleep(10)  # Aptaujas intervāls
```

---

### Pūla integrācijas modelis

**Pūla servera darbplūsma**:
1. Kalnrači izveido kalšanas piešķīrumus pūla adresei
2. Pūls darbina maciņu ar kalšanas adreses atslēgām
3. Pūls izsauc `get_mining_info` un izplata kalnračiem
4. Kalnrači iesniedz risinājumus caur pūlu (ne tieši ķēdei)
5. Pūls validē un izsauc `submit_nonce` ar pūla atslēgām
6. Pūls izplata atlīdzības saskaņā ar pūla politiku

**Piešķīrumu pārvaldība**:
```bash
# Kalnracis izveido piešķīrumu (no kalnraču maciņa)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Gaidīt aktivizāciju (30 bloki mainnet)

# Pūls pārbauda piešķīruma statusu
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pūls tagad var iesniegt nonces šim plotfailam
# (pūla maciņam jābūt pocx1qpool... privātajai atslēgai)
```

---

### Bloku pārlūka vaicājumi

**PoCX bloku datu vaicāšana**:
```bash
# Iegūt jaunāko bloku
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Iegūt bloka detaļas ar PoCX pierādījumu
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Iegūt PoCX specifiskos laukus
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

**Piešķīrumu darījumu noteikšana**:
```bash
# Skenēt darījumu OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Pārbaudīt piešķīruma marķieri (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Kļūdu apstrāde

### Biežākie kļūdu modeļi

**Augstuma nesakritība**:
```json
{
  "accepted": false,
  "error": "Augstuma nesakritība: iesniegts 12345, pašreizējais 12346"
}
```
**Risinājums**: Atkārtoti iegūt kalnrūpniecības info, ķēde ir pavirzījusies uz priekšu

**Ģenerēšanas paraksta nesakritība**:
```json
{
  "accepted": false,
  "error": "Ģenerēšanas paraksta nesakritība"
}
```
**Risinājums**: Atkārtoti iegūt kalnrūpniecības info, jauns bloks ir pienācis

**Nav privātās atslēgas**:
```json
{
  "code": -5,
  "message": "Nav pieejama privātā atslēga efektīvajam parakstītājam"
}
```
**Risinājums**: Importēt atslēgu plotfaila vai kalšanas adresei

**Piešķīruma aktivizācija gaida**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Risinājums**: Gaidīt, līdz aktivizācijas aizkave iziet

---

## Koda atsauces

**Kalnrūpniecības RPC**: `src/pocx/rpc/mining.cpp`
**Piešķīrumu RPC**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blokķēdes RPC**: `src/rpc/blockchain.cpp`
**Pierādījuma validācija**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Piešķīrumu stāvoklis**: `src/pocx/assignments/assignment_state.cpp`
**Darījumu izveide**: `src/pocx/assignments/transactions.cpp`

---

## Savstarpējās atsauces

Saistītās nodaļas:
- [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md) - Kalnrūpniecības procesa detaļas
- [4. nodaļa: Kalšanas piešķīrumi](4-forging-assignments.md) - Piešķīrumu sistēmas arhitektūra
- [6. nodaļa: Tīkla parametri](6-network-parameters.md) - Piešķīrumu aizkaves vērtības
- [8. nodaļa: Maka ceļvedis](8-wallet-guide.md) - GUI piešķīrumu pārvaldībai

---

[← Iepriekšējā: Tīkla parametri](6-network-parameters.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Maka ceļvedis →](8-wallet-guide.md)
