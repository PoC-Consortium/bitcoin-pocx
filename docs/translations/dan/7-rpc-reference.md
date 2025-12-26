[<- Forrige: Netvaerksparametre](6-network-parameters.md) | [Indholdsfortegnelse](index.md) | [Naeste: Wallet-guide ->](8-wallet-guide.md)

---

# Kapitel 7: RPC-graensefladereference

Komplet reference til Bitcoin-PoCX RPC-kommandoer, inklusive mining-RPC'er, assignment-styring og modificerede blockchain-RPC'er.

---

## Indholdsfortegnelse

1. [Konfiguration](#konfiguration)
2. [PoCX Mining-RPC'er](#pocx-mining-rpcer)
3. [Assignment-RPC'er](#assignment-rpcer)
4. [Modificerede Blockchain-RPC'er](#modificerede-blockchain-rpcer)
5. [Deaktiverede RPC'er](#deaktiverede-rpcer)
6. [Integrationseksempler](#integrationseksempler)

---

## Konfiguration

### Miningservertilstand

**Flag**: `-miningserver`

**Formal**: Aktiverer RPC-adgang for eksterne minere til at kalde miningspecifikke RPC'er

**Krav**:
- Kraeves for at `submit_nonce` fungerer
- Kraeves til synlighed af forging assignment-dialog i Qt-wallet

**Brug**:
```bash
# Kommandolinje
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Sikkerhedsovervejelser**:
- Ingen yderligere godkendelse ud over standard RPC-legitimationsoplysninger
- Mining-RPC'er er rate-begraenset af kokapacitet
- Standard RPC-godkendelse kraeves stadig

**Implementering**: `src/pocx/rpc/mining.cpp`

---

## PoCX Mining-RPC'er

### get_mining_info

**Kategori**: mining
**Kraever miningserver**: Nej
**Kraever wallet**: Nej

**Formal**: Returnerer nuvaerende miningparametre, der er nodvendige for, at eksterne minere kan scanne plotfiler og beregne deadlines.

**Parametre**: Ingen

**Returvaerdier**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 tegn
  "base_target": 36650387593,                // numerisk
  "height": 12345,                           // numerisk, naeste blokhojde
  "block_hash": "def456...",                 // hex, forrige blok
  "target_quality": 18446744073709551615,    // uint64_max (alle losninger accepteres)
  "minimum_compression_level": 1,            // numerisk
  "target_compression_level": 2              // numerisk
}
```

**Feltbeskrivelser**:
- `generation_signature`: Deterministisk miningentropy for denne blokhojde
- `base_target`: Nuvaerende svaerhed (hojere = lettere)
- `height`: Blokhojde minere bor sigte efter
- `block_hash`: Forrige blokhash (informativ)
- `target_quality`: Kvalitetsgraensevaerdi (i oejeblikket uint64_max, ingen filtrering)
- `minimum_compression_level`: Minimumkompression kraevet til validering
- `target_compression_level`: Anbefalet kompression til optimal mining

**Fejlkoder**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node synkroniserer stadig

**Eksempel**:
```bash
bitcoin-cli get_mining_info
```

**Implementering**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategori**: mining
**Kraever miningserver**: Ja
**Kraever wallet**: Ja (til private nogler)

**Formal**: Indsend en PoCX-mininglosning. Validerer bevis, saetter i ko til time-bendet forging og opretter automatisk blok pa planlagt tidspunkt.

**Parametre**:
1. `height` (numerisk, kraevet) - Blokhojde
2. `generation_signature` (streng hex, kraevet) - Generationssignatur (64 tegn)
3. `account_id` (streng, kraevet) - Plot-konto-ID (40 hex-tegn = 20 bytes)
4. `seed` (streng, kraevet) - Plotseed (64 hex-tegn = 32 bytes)
5. `nonce` (numerisk, kraevet) - Miningnonce
6. `compression` (numerisk, kraevet) - Skalerings-/kompressionsniveau brugt (1-255)
7. `quality` (numerisk, valgfrit) - Kvalitetsvaerdi (genberegnes, hvis udeladt)

**Returvaerdier** (succes):
```json
{
  "accepted": true,
  "quality": 120,           // svaerhedsjusteret deadline i sekunder
  "poc_time": 45            // time-bendet forgetid i sekunder
}
```

**Returvaerdier** (afvist):
```json
{
  "accepted": false,
  "error": "Generationssignaturmismatch"
}
```

**Valideringstrin**:
1. **Formatvalidering** (hurtig-fejl):
   - Konto-ID: praecis 40 hex-tegn
   - Seed: praecis 64 hex-tegn
2. **Kontekstvalidering**:
   - Hojde skal matche nuvaerende tip + 1
   - Generationssignatur skal matche nuvaerende
3. **Wallet-verifikation**:
   - Bestem effektiv underskriver (kontroller for aktive assignments)
   - Bekraeft wallet har privat nogle til effektiv underskriver
4. **Bevisvalidering** (dyr):
   - Valider PoCX-bevis med kompressionsgraenser
   - Beregn ra kvalitet
5. **Scheduler-indsendelse**:
   - Saet nonce i ko til time-bendet forging
   - Blok vil blive oprettet automatisk ved forge_time

**Fejlkoder**:
- `RPC_INVALID_PARAMETER`: Ugyldigt format (account_id, seed) eller hojdemismatch
- `RPC_VERIFY_REJECTED`: Generationssignaturmismatch eller bevisvalidering fejlede
- `RPC_INVALID_ADDRESS_OR_KEY`: Ingen privat nogle til effektiv underskriver
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Indsendelsesenko fuld
- `RPC_INTERNAL_ERROR`: Kunne ikke initialisere PoCX-scheduler

**Bevisvalideringsfejlkoder**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Eksempel**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Bemaaerkninger**:
- Indsendelse er asynkron - RPC returnerer med det samme, blok forges senere
- Time Bending forsinker gode losninger for at tillade netvaerksdaekkende plotscanning
- Assignment-system: hvis plot tildelt, skal wallet have forging-adressenogle
- Kompressionsgraenser justeres dynamisk baseret pa blokhojde

**Implementering**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Assignment-RPC'er

### get_assignment

**Kategori**: mining
**Kraever miningserver**: Nej
**Kraever wallet**: Nej

**Formal**: Foresporsel om forging assignment-status for en plotadresse. Skrivebeskyttet, ingen wallet kraevet.

**Parametre**:
1. `plot_address` (streng, kraevet) - Plotadresse (bech32 P2WPKH-format)
2. `height` (numerisk, valgfrit) - Blokhojde at foresporge (standard: nuvaerende tip)

**Returvaerdier** (ingen assignment):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Returvaerdier** (aktiv assignment):
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

**Returvaerdier** (tilbagekalder):
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

**Assignment-tilstande**:
- `UNASSIGNED`: Ingen assignment eksisterer
- `ASSIGNING`: Assignment-tx bekraeftet, aktiveringsforsinkelse i gang
- `ASSIGNED`: Assignment aktiv, forging-rettigheder delegeret
- `REVOKING`: Tilbagekaldelses-tx bekraeftet, stadig aktiv indtil forsinkelse udlober
- `REVOKED`: Tilbagekaldelse faerdig, forging-rettigheder returneret til plotejer

**Fejlkoder**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Ugyldig adresse eller ikke P2WPKH (bech32)

**Eksempel**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementering**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategori**: wallet
**Kraever miningserver**: Nej
**Kraever wallet**: Ja (skal vaere indlaest og oplast)

**Formal**: Opret forging assignment-transaktion for at delegere forging-rettigheder til en anden adresse (f.eks. miningpool).

**Parametre**:
1. `plot_address` (streng, kraevet) - Plotejeradresse (skal eje privat nogle, P2WPKH bech32)
2. `forging_address` (streng, kraevet) - Adresse at tildele forging-rettigheder til (P2WPKH bech32)
3. `fee_rate` (numerisk, valgfrit) - Gebyrsats i BTC/kvB (standard: 10x minRelayFee)

**Returvaerdier**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Krav**:
- Wallet indlaest og oplast
- Privat nogle til plot_address i wallet
- Begge adresser skal vaere P2WPKH (bech32-format: pocx1q... mainnet, tpocx1q... testnet)
- Plotadresse skal have bekraeftede UTXO'er (beviser ejerskab)
- Plot ma ikke have aktiv assignment (brug tilbagekald forst)

**Transaktionsstruktur**:
- Input: UTXO fra plotadresse (beviser ejerskab)
- Output: OP_RETURN (46 bytes): `POCX`-markor + plot_address (20 bytes) + forging_address (20 bytes)
- Output: Byttepenge returneret til wallet

**Aktivering**:
- Assignment bliver ASSIGNING ved bekraeftelse
- Bliver AKTIV efter `nForgingAssignmentDelay` blokke
- Forsinkelse forebygger hurtig omtildeling under kaedegafler

**Fejlkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen wallet tilgaengelig
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet krypteret og last
- `RPC_WALLET_ERROR`: Transaktionsoprettelse fejlede
- `RPC_INVALID_ADDRESS_OR_KEY`: Ugyldigt adresseformat

**Eksempel**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementering**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategori**: wallet
**Kraever miningserver**: Nej
**Kraever wallet**: Ja (skal vaere indlaest og oplast)

**Formal**: Tilbagekald eksisterende forging assignment, returnerer forging-rettigheder til plotejer.

**Parametre**:
1. `plot_address` (streng, kraevet) - Plotadresse (skal eje privat nogle, P2WPKH bech32)
2. `fee_rate` (numerisk, valgfrit) - Gebyrsats i BTC/kvB (standard: 10x minRelayFee)

**Returvaerdier**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Krav**:
- Wallet indlaest og oplast
- Privat nogle til plot_address i wallet
- Plotadresse skal vaere P2WPKH (bech32-format)
- Plotadresse skal have bekraeftede UTXO'er

**Transaktionsstruktur**:
- Input: UTXO fra plotadresse (beviser ejerskab)
- Output: OP_RETURN (26 bytes): `XCOP`-markor + plot_address (20 bytes)
- Output: Byttepenge returneret til wallet

**Effekt**:
- Tilstand overgår til REVOKING ojeblikkelig
- Forging-adresse kan stadig forge i forsinkelsesperiode
- Bliver REVOKED efter `nForgingRevocationDelay` blokke
- Plotejer kan forge efter tilbagekaldelse traeder i kraft
- Kan oprette ny assignment efter tilbagekaldelse er faerdig

**Fejlkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen wallet tilgaengelig
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet krypteret og last
- `RPC_WALLET_ERROR`: Transaktionsoprettelse fejlede

**Eksempel**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Bemaaerkninger**:
- Idempotent: kan tilbagekalde selv hvis ingen aktiv assignment
- Kan ikke annullere tilbagekaldelse, nar den er indsendt

**Implementering**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modificerede Blockchain-RPC'er

### getdifficulty

**PoCX-modifikationer**:
- **Beregning**: `reference_base_target / current_base_target`
- **Reference**: 1 TiB netvaerkskapacitet (base_target = 36650387593)
- **Fortolkning**: Estimeret netvaerkslagringskapacitet i TiB
  - Eksempel: `1.0` = ~1 TiB
  - Eksempel: `1024.0` = ~1 PiB
- **Forskel fra PoW**: Repraesenterer kapacitet, ikke hashkraft

**Eksempel**:
```bash
bitcoin-cli getdifficulty
# Returnerer: 2048.5 (netvaerk ~2 PiB)
```

**Implementering**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX-tilojede felter**:
- `time_since_last_block` (numerisk) - Sekunder siden forrige blok (erstatter mediantime)
- `poc_time` (numerisk) - Time-bendet forgetid i sekunder
- `base_target` (numerisk) - PoCX-svaerhed base target
- `generation_signature` (streng hex) - Generationssignatur
- `pocx_proof` (objekt):
  - `account_id` (streng hex) - Plot-konto-ID (20 bytes)
  - `seed` (streng hex) - Plotseed (32 bytes)
  - `nonce` (numerisk) - Miningnonce
  - `compression` (numerisk) - Skaleringsniveau brugt
  - `quality` (numerisk) - Pastaet kvalitetsvaerdi
- `pubkey` (streng hex) - Blokunderskrivers offentlige nogle (33 bytes)
- `signer_address` (streng) - Blokunderskrivers adresse
- `signature` (streng hex) - Bloksignatur (65 bytes)

**PoCX-fjernede felter**:
- `mediantime` - Fjernet (erstattet af time_since_last_block)

**Eksempel**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementering**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-modifikationer**: Samme som getblockheader, plus fulde transaktionsdata

**Eksempel**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose med tx-detaljer
```

**Implementering**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX-tilojede felter**:
- `base_target` (numerisk) - Nuvaerende base target
- `generation_signature` (streng hex) - Nuvaerende generationssignatur

**PoCX-modificerede felter**:
- `difficulty` - Bruger PoCX-beregning (kapacitetsbaseret)

**PoCX-fjernede felter**:
- `mediantime` - Fjernet

**Eksempel**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementering**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX-tilojede felter**:
- `generation_signature` (streng hex) - Til pool-mining
- `base_target` (numerisk) - Til pool-mining

**PoCX-fjernede felter**:
- `target` - Fjernet (PoW-specifik)
- `noncerange` - Fjernet (PoW-specifik)
- `bits` - Fjernet (PoW-specifik)

**Bemaaerkninger**:
- Inkluderer stadig fulde transaktionsdata til blokkonstruktion
- Brugt af pool-servere til koordineret mining

**Eksempel**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementering**: `src/rpc/mining.cpp`

---

## Deaktiverede RPC'er

Folgende PoW-specifikke RPC'er er **deaktiveret** i PoCX-tilstand:

### getnetworkhashps
- **Arsag**: Hashrate ikke relevant for Proof of Capacity
- **Alternativ**: Brug `getdifficulty` til netvaerkskapacitetsestimat

### getmininginfo
- **Arsag**: Returnerer PoW-specifik information
- **Alternativ**: Brug `get_mining_info` (PoCX-specifik)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Arsag**: CPU-mining ikke relevant for PoCX (kraever forgenererede plots)
- **Alternativ**: Brug ekstern plotter + miner + `submit_nonce`

**Implementering**: `src/rpc/mining.cpp` (RPC'er returnerer fejl, nar ENABLE_POCX er defineret)

---

## Integrationseksempler

### Ekstern minerintegration

**Grundlaeggende miningsloeje**:
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

# Miningsloeje
while True:
    # 1. Hent miningparametre
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scan plotfiler (ekstern implementering)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Indsend bedste losning
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Losning accepteret! Kvalitet: {result['quality']}s, "
              f"Forgetid: {result['poc_time']}s")

    # 4. Vent pa naeste blok
    time.sleep(10)  # Pollinginterval
```

---

### Pool-integrationsmoenster

**Pool-serverworkflow**:
1. Minere opretter forging assignments til pooladresse
2. Pool korer wallet med forging-adressenogler
3. Pool kalder `get_mining_info` og distribuerer til minere
4. Minere indsender losninger via pool (ikke direkte til kaede)
5. Pool validerer og kalder `submit_nonce` med pools nogler
6. Pool distribuerer beloninger ifolge poolpolitik

**Assignment-styring**:
```bash
# Miner opretter assignment (fra miners wallet)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Vent pa aktivering (30 blokke mainnet)

# Pool kontrollerer assignment-status
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool kan nu indsende nonces for dette plot
# (pool-wallet skal have pocx1qpool... privat nogle)
```

---

### Blokudforskerforesporgsler

**Foresporsel om PoCX-blokdata**:
```bash
# Hent seneste blok
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Hent blokdetaljer med PoCX-bevis
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Udtræk PoCX-specifikke felter
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

**Detektering af assignment-transaktioner**:
```bash
# Scan transaktion for OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Kontroller for assignment-markor (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Fejlhandtering

### Almindelige fejlmonstre

**Hojdemismatch**:
```json
{
  "accepted": false,
  "error": "Hojdemismatch: indsendt 12345, nuvaerende 12346"
}
```
**Losning**: Hent mininginfo igen, kaede rykkede frem

**Generationssignaturmismatch**:
```json
{
  "accepted": false,
  "error": "Generationssignaturmismatch"
}
```
**Losning**: Hent mininginfo igen, ny blok ankom

**Ingen privat nogle**:
```json
{
  "code": -5,
  "message": "Ingen privat nogle tilgaengelig for effektiv underskriver"
}
```
**Losning**: Importer nogle til plot- eller forging-adresse

**Assignment-aktivering afventer**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Losning**: Vent pa at aktiveringsforsinkelse udlober

---

## Kodereferencer

**Mining-RPC'er**: `src/pocx/rpc/mining.cpp`
**Assignment-RPC'er**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain-RPC'er**: `src/rpc/blockchain.cpp`
**Bevisvalidering**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Assignment-tilstand**: `src/pocx/assignments/assignment_state.cpp`
**Transaktionsoprettelse**: `src/pocx/assignments/transactions.cpp`

---

## Krydsreferencer

Relaterede kapitler:
- [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md) - Miningprocesdetaljer
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Assignment-systemarkitektur
- [Kapitel 6: Netvaerksparametre](6-network-parameters.md) - Assignment-forsinkelsesvaerdier
- [Kapitel 8: Wallet-guide](8-wallet-guide.md) - GUI til assignment-styring

---

[<- Forrige: Netvaerksparametre](6-network-parameters.md) | [Indholdsfortegnelse](index.md) | [Naeste: Wallet-guide ->](8-wallet-guide.md)
