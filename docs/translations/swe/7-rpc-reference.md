[<- Föregående: Nätverksparametrar](6-network-parameters.md) | [Innehållsförteckning](index.md) | [Nästa: Plånboksguide ->](8-wallet-guide.md)

---

# Kapitel 7: RPC-gränssnittsreferens

Fullständig referens för Bitcoin-PoCX RPC-kommandon, inklusive mining-RPC:er, tilldelningshantering och modifierade blockchain-RPC:er.

---

## Innehållsförteckning

1. [Konfiguration](#konfiguration)
2. [PoCX mining-RPC:er](#pocx-mining-rpcer)
3. [Tilldelnings-RPC:er](#tilldelnings-rpcer)
4. [Modifierade blockchain-RPC:er](#modifierade-blockchain-rpcer)
5. [Inaktiverade RPC:er](#inaktiverade-rpcer)
6. [Integrationsexempel](#integrationsexempel)

---

## Konfiguration

### Miningserverläge

**Flagga**: `-miningserver`

**Syfte**: Aktiverar RPC-åtkomst för externa miners att anropa miningspecifika RPC:er

**Krav**:
- Krävs för att `submit_nonce` ska fungera
- Krävs för synlighet av forging assignment-dialog i Qt-plånbok

**Användning**:
```bash
# Kommandorad
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Säkerhetsöverväganden**:
- Ingen ytterligare autentisering utöver standard RPC-inloggningsuppgifter
- Mining-RPC:er är hastighetsbegränsade av kökapacitet
- Standard RPC-autentisering krävs fortfarande

**Implementation**: `src/pocx/rpc/mining.cpp`

---

## PoCX mining-RPC:er

### get_mining_info

**Kategori**: mining
**Kräver miningserver**: Nej
**Kräver plånbok**: Nej

**Syfte**: Returnerar aktuella miningparametrar som behövs för externa miners att skanna plotfiler och beräkna deadlines.

**Parametrar**: Inga

**Returvärden**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 tecken
  "base_target": 36650387593,                // numerisk
  "height": 12345,                           // numerisk, nästa blockhöjd
  "block_hash": "def456...",                 // hex, föregående block
  "target_quality": 18446744073709551615,    // uint64_max (alla lösningar accepteras)
  "minimum_compression_level": 1,            // numerisk
  "target_compression_level": 2              // numerisk
}
```

**Fältbeskrivningar**:
- `generation_signature`: Deterministisk miningenttropi för denna blockhöjd
- `base_target`: Aktuell svårighet (högre = enklare)
- `height`: Blockhöjd miners ska sikta på
- `block_hash`: Föregående blockhash (information)
- `target_quality`: Kvalitetströskel (för närvarande uint64_max, ingen filtrering)
- `minimum_compression_level`: Minsta kompression som krävs för validering
- `target_compression_level`: Rekommenderad kompression för optimal mining

**Felkoder**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Noden synkroniserar fortfarande

**Exempel**:
```bash
bitcoin-cli get_mining_info
```

**Implementation**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategori**: mining
**Kräver miningserver**: Ja
**Kräver plånbok**: Ja (för privata nycklar)

**Syfte**: Skicka en PoCX-mininglösning. Validerar bevis, köar för tidsböjd forgning och skapar automatiskt block vid schemalagd tid.

**Parametrar**:
1. `height` (numerisk, obligatorisk) - Blockhöjd
2. `generation_signature` (sträng hex, obligatorisk) - Generationssignatur (64 tecken)
3. `account_id` (sträng, obligatorisk) - Plotkonto-ID (40 hextecken = 20 bytes)
4. `seed` (sträng, obligatorisk) - Plotseed (64 hextecken = 32 bytes)
5. `nonce` (numerisk, obligatorisk) - Miningnonce
6. `compression` (numerisk, obligatorisk) - Skalnings-/kompressionsnivå använd (1-255)
7. `quality` (numerisk, valfri) - Kvalitetsvärde (omberäknas om utelämnad)

**Returvärden** (framgång):
```json
{
  "accepted": true,
  "quality": 120,           // svårighetsjusterad deadline i sekunder
  "poc_time": 45            // tidsböjd forgningstid i sekunder
}
```

**Returvärden** (avvisad):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Valideringssteg**:
1. **Formatvalidering** (fail-fast):
   - Konto-ID: exakt 40 hextecken
   - Seed: exakt 64 hextecken
2. **Kontextvalidering**:
   - Höjd måste matcha aktuell tipp + 1
   - Generationssignatur måste matcha aktuell
3. **Plånboksverifiering**:
   - Bestäm effektiv signerare (kontrollera aktiva tilldelningar)
   - Verifiera att plånbok har privat nyckel för effektiv signerare
4. **Bevisvalidering** (dyr):
   - Validera PoCX-bevis med kompressionsgränser
   - Beräkna råkvalitet
5. **Schemaläggarinlämning**:
   - Köa nonce för tidsböjd forgning
   - Block skapas automatiskt vid forge_time

**Felkoder**:
- `RPC_INVALID_PARAMETER`: Ogiltigt format (account_id, seed) eller höjdmismatch
- `RPC_VERIFY_REJECTED`: Generationssignaturmismatch eller bevisvalidering misslyckades
- `RPC_INVALID_ADDRESS_OR_KEY`: Ingen privat nyckel för effektiv signerare
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Inlämningskö full
- `RPC_INTERNAL_ERROR`: Misslyckades med att initiera PoCX-schemaläggare

**Bevisvalideringsfelkoder**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Exempel**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Noteringar**:
- Inlämning är asynkron - RPC returnerar omedelbart, block forgas senare
- Time Bending fördröjer bra lösningar för att tillåta nätverksomfattande plotskanning
- Tilldelningssystem: om plot tilldelad, måste plånbok ha forgningsadressnyckel
- Kompressionsgränser justeras dynamiskt baserat på blockhöjd

**Implementation**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Tilldelnings-RPC:er

### get_assignment

**Kategori**: mining
**Kräver miningserver**: Nej
**Kräver plånbok**: Nej

**Syfte**: Fråga forgingstilldelningsstatus för en plotadress. Skrivskyddad, ingen plånbok krävs.

**Parametrar**:
1. `plot_address` (sträng, obligatorisk) - Plotadress (bech32 P2WPKH-format)
2. `height` (numerisk, valfri) - Blockhöjd att fråga (standard: aktuell tipp)

**Returvärden** (ingen tilldelning):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Returvärden** (aktiv tilldelning):
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

**Returvärden** (återkallar):
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

**Tilldelningsstatus**:
- `UNASSIGNED`: Ingen tilldelning existerar
- `ASSIGNING`: Tilldelnings-tx bekräftad, aktiveringsfördröjning pågår
- `ASSIGNED`: Tilldelning aktiv, forgingsrättigheter delegerade
- `REVOKING`: Återkallelse-tx bekräftad, fortfarande aktiv tills fördröjning löper ut
- `REVOKED`: Återkallelse slutförd, forgningsrättigheter återlämnade till plotägare

**Felkoder**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Ogiltig adress eller inte P2WPKH (bech32)

**Exempel**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementation**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategori**: wallet
**Kräver miningserver**: Nej
**Kräver plånbok**: Ja (måste vara laddad och upplåst)

**Syfte**: Skapa forgingstilldelningsstransaktion för att delegera forgingsrättigheter till annan adress (t.ex. miningpool).

**Parametrar**:
1. `plot_address` (sträng, obligatorisk) - Plotägaradress (måste äga privat nyckel, P2WPKH bech32)
2. `forging_address` (sträng, obligatorisk) - Adress att tilldela forgningsrättigheter till (P2WPKH bech32)
3. `fee_rate` (numerisk, valfri) - Avgiftsgrad i BTC/kvB (standard: 10× minRelayFee)

**Returvärden**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Krav**:
- Plånbok laddad och upplåst
- Privat nyckel för plot_address i plånbok
- Båda adresserna måste vara P2WPKH (bech32-format: pocx1q... mainnet, tpocx1q... testnet)
- Plotadress måste ha bekräftade UTXO:er (bevisar ägarskap)
- Plot får inte ha aktiv tilldelning (använd revoke först)

**Transaktionsstruktur**:
- Input: UTXO från plotadress (bevisar ägarskap)
- Utdata: OP_RETURN (46 bytes): `POCX`-markör + plot_address (20 bytes) + forging_address (20 bytes)
- Utdata: Växel returneras till plånbok

**Aktivering**:
- Tilldelning blir ASSIGNING vid bekräftelse
- Blir ACTIVE efter `nForgingAssignmentDelay` block
- Fördröjning förhindrar snabb omtilldelning under kedjeforks

**Felkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen plånbok tillgänglig
- `RPC_WALLET_UNLOCK_NEEDED`: Plånbok krypterad och låst
- `RPC_WALLET_ERROR`: Transaktionsskapande misslyckades
- `RPC_INVALID_ADDRESS_OR_KEY`: Ogiltigt adressformat

**Exempel**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementation**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategori**: wallet
**Kräver miningserver**: Nej
**Kräver plånbok**: Ja (måste vara laddad och upplåst)

**Syfte**: Återkalla befintlig forgingstilldelning och returnera forgingsrättigheter till plotägare.

**Parametrar**:
1. `plot_address` (sträng, obligatorisk) - Plotadress (måste äga privat nyckel, P2WPKH bech32)
2. `fee_rate` (numerisk, valfri) - Avgiftsgrad i BTC/kvB (standard: 10× minRelayFee)

**Returvärden**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Krav**:
- Plånbok laddad och upplåst
- Privat nyckel för plot_address i plånbok
- Plotadress måste vara P2WPKH (bech32-format)
- Plotadress måste ha bekräftade UTXO:er

**Transaktionsstruktur**:
- Input: UTXO från plotadress (bevisar ägarskap)
- Utdata: OP_RETURN (26 bytes): `XCOP`-markör + plot_address (20 bytes)
- Utdata: Växel returneras till plånbok

**Effekt**:
- Status övergår till REVOKING omedelbart
- Forgingsadress kan fortfarande forga under fördröjningsperiod
- Blir REVOKED efter `nForgingRevocationDelay` block
- Plotägare kan forga efter att återkallelse är effektiv
- Kan skapa ny tilldelning efter slutförd återkallelse

**Felkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen plånbok tillgänglig
- `RPC_WALLET_UNLOCK_NEEDED`: Plånbok krypterad och låst
- `RPC_WALLET_ERROR`: Transaktionsskapande misslyckades

**Exempel**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Noteringar**:
- Idempotent: kan återkalla även om ingen aktiv tilldelning
- Kan inte avbryta återkallelse när skickad

**Implementation**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modifierade blockchain-RPC:er

### getdifficulty

**PoCX-modifieringar**:
- **Beräkning**: `reference_base_target / current_base_target`
- **Referens**: 1 TiB nätverkskapacitet (base_target = 36650387593)
- **Tolkning**: Uppskattad nätverkslagringskapacitet i TiB
  - Exempel: `1.0` = ~1 TiB
  - Exempel: `1024.0` = ~1 PiB
- **Skillnad från PoW**: Representerar kapacitet, inte hashkraft

**Exempel**:
```bash
bitcoin-cli getdifficulty
# Returnerar: 2048.5 (nätverk ~2 PiB)
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX-tillagda fält**:
- `time_since_last_block` (numerisk) - Sekunder sedan föregående block (ersätter mediantime)
- `poc_time` (numerisk) - Tidsböjd forgningstid i sekunder
- `base_target` (numerisk) - PoCX-svårighet basmål
- `generation_signature` (sträng hex) - Generationssignatur
- `pocx_proof` (objekt):
  - `account_id` (sträng hex) - Plotkonto-ID (20 bytes)
  - `seed` (sträng hex) - Plotseed (32 bytes)
  - `nonce` (numerisk) - Miningnonce
  - `compression` (numerisk) - Skalningsnivå använd
  - `quality` (numerisk) - Hävdat kvalitetsvärde
- `pubkey` (sträng hex) - Blocksignerarens publika nyckel (33 bytes)
- `signer_address` (sträng) - Blocksignerarens adress
- `signature` (sträng hex) - Blocksignatur (65 bytes)

**PoCX-borttagna fält**:
- `mediantime` - Borttagen (ersatt av time_since_last_block)

**Exempel**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-modifieringar**: Samma som getblockheader, plus fullständig transaktionsdata

**Exempel**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose med tx-detaljer
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX-tillagda fält**:
- `base_target` (numerisk) - Aktuellt basmål
- `generation_signature` (sträng hex) - Aktuell generationssignatur

**PoCX-modifierade fält**:
- `difficulty` - Använder PoCX-beräkning (kapacitetsbaserad)

**PoCX-borttagna fält**:
- `mediantime` - Borttagen

**Exempel**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX-tillagda fält**:
- `generation_signature` (sträng hex) - För poolmining
- `base_target` (numerisk) - För poolmining

**PoCX-borttagna fält**:
- `target` - Borttagen (PoW-specifik)
- `noncerange` - Borttagen (PoW-specifik)
- `bits` - Borttagen (PoW-specifik)

**Noteringar**:
- Inkluderar fortfarande fullständig transaktionsdata för blockkonstruktion
- Används av poolservrar för koordinerad mining

**Exempel**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementation**: `src/rpc/mining.cpp`

---

## Inaktiverade RPC:er

Följande PoW-specifika RPC:er är **inaktiverade** i PoCX-läge:

### getnetworkhashps
- **Orsak**: Hashrate inte tillämpligt för Proof of Capacity
- **Alternativ**: Använd `getdifficulty` för nätverkskapacitetsuppskattning

### getmininginfo
- **Orsak**: Returnerar PoW-specifik information
- **Alternativ**: Använd `get_mining_info` (PoCX-specifik)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Orsak**: CPU-mining inte tillämpligt för PoCX (kräver förgenererade plottar)
- **Alternativ**: Använd extern plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp` (RPC:er returnerar fel när ENABLE_POCX definierad)

---

## Integrationsexempel

### Integration av extern miner

**Grundläggande miningloop**:
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

# Miningloop
while True:
    # 1. Hämta miningparametrar
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skanna plotfiler (extern implementation)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Skicka bästa lösning
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Lösning accepterad! Kvalitet: {result['quality']}s, "
              f"Forgningstid: {result['poc_time']}s")

    # 4. Vänta på nästa block
    time.sleep(10)  # Pollningsintervall
```

---

### Poolintegrationsmönster

**Poolserver-arbetsflöde**:
1. Miners skapar forgingstilldelningar till pooladress
2. Pool kör plånbok med forgingsadressnycklar
3. Pool anropar `get_mining_info` och distribuerar till miners
4. Miners skickar lösningar via pool (inte direkt till kedja)
5. Pool validerar och anropar `submit_nonce` med poolens nycklar
6. Pool distribuerar belöningar enligt poolpolicy

**Tilldelningshantering**:
```bash
# Miner skapar tilldelning (från miners plånbok)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Vänta på aktivering (30 block mainnet)

# Pool kontrollerar tilldelningsstatus
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool kan nu skicka nonces för denna plot
# (poolplånbok måste ha pocx1qpool... privat nyckel)
```

---

### Blockutforskarförfrågningar

**Fråga PoCX-blockdata**:
```bash
# Hämta senaste block
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Hämta blockdetaljer med PoCX-bevis
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extrahera PoCX-specifika fält
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

**Detektera tilldelningsstransaktioner**:
```bash
# Skanna transaktion för OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Kontrollera efter tilldelningsmarkör (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Felhantering

### Vanliga felmönster

**Höjdmismatch**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Lösning**: Hämta om mininginfo, kedjan har flyttat framåt

**Generationssignaturmismatch**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Lösning**: Hämta om mininginfo, nytt block anlänt

**Ingen privat nyckel**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Lösning**: Importera nyckel för plot- eller forgingsadress

**Tilldelningsaktivering väntar**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Lösning**: Vänta tills aktiveringsfördröjning löper ut

---

## Kodreferenser

**Mining-RPC:er**: `src/pocx/rpc/mining.cpp`
**Tilldelnings-RPC:er**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain-RPC:er**: `src/rpc/blockchain.cpp`
**Bevisvalidering**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Tilldelningsstatus**: `src/pocx/assignments/assignment_state.cpp`
**Transaktionsskapande**: `src/pocx/assignments/transactions.cpp`

---

## Korsreferenser

Relaterade kapitel:
- [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md) - Miningprocessdetaljer
- [Kapitel 4: Forging Assignments](4-forging-assignments.md) - Tilldelningssystemarkitektur
- [Kapitel 6: Nätverksparametrar](6-network-parameters.md) - Tilldelningsfördröjningsvärden
- [Kapitel 8: Plånboksguide](8-wallet-guide.md) - GUI för tilldelningshantering

---

[<- Föregående: Nätverksparametrar](6-network-parameters.md) | [Innehållsförteckning](index.md) | [Nästa: Plånboksguide ->](8-wallet-guide.md)
