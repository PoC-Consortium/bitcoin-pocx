[← Forrige: Nettverksparametere](6-network-parameters.md) | [Innholdsfortegnelse](index.md) | [Neste: Lommebokveiledning →](8-wallet-guide.md)

---

# Kapittel 7: RPC-grensesnittreferanse

Fullstendig referanse for Bitcoin-PoCX RPC-kommandoer, inkludert mining-RPC-er, tildelingsadministrasjon og modifiserte blockchain-RPC-er.

---

## Innholdsfortegnelse

1. [Konfigurasjon](#konfigurasjon)
2. [PoCX mining-RPC-er](#pocx-mining-rpc-er)
3. [Tildelings-RPC-er](#tildelings-rpc-er)
4. [Modifiserte blockchain-RPC-er](#modifiserte-blockchain-rpc-er)
5. [Deaktiverte RPC-er](#deaktiverte-rpc-er)
6. [Integrasjonseksempler](#integrasjonseksempler)

---

## Konfigurasjon

### Mining-servermodus

**Flagg**: `-miningserver`

**Formål**: Aktiverer RPC-tilgang for eksterne minere til å kalle mining-spesifikke RPC-er

**Krav**:
- Påkrevd for at `submit_nonce` skal fungere
- Påkrevd for synlighet av forging assignment-dialogen i Qt-lommebok

**Bruk**:
```bash
# Kommandolinje
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Sikkerhetshensyn**:
- Ingen ekstra autentisering utover standard RPC-legitimasjon
- Mining-RPC-er er hastighetsbegrenset av køkapasitet
- Standard RPC-autentisering fortsatt påkrevd

**Implementasjon**: `src/pocx/rpc/mining.cpp`

---

## PoCX mining-RPC-er

### get_mining_info

**Kategori**: mining
**Krever mining-server**: Nei
**Krever lommebok**: Nei

**Formål**: Returnerer gjeldende miningparametere som trengs for at eksterne minere skal skanne plotfiler og beregne deadlines.

**Parametere**: Ingen

**Returverdier**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 tegn
  "base_target": 36650387593,                // numerisk
  "height": 12345,                           // numerisk, neste blokkhøyde
  "block_hash": "def456...",                 // hex, forrige blokk
  "target_quality": 18446744073709551615,    // uint64_max (alle løsninger akseptert)
  "minimum_compression_level": 1,            // numerisk
  "target_compression_level": 2              // numerisk
}
```

**Feltbeskrivelser**:
- `generation_signature`: Deterministisk mining-entropi for denne blokkhøyden
- `base_target`: Gjeldende vanskelighet (høyere = enklere)
- `height`: Blokkhøyde minere bør sikte mot
- `block_hash`: Forrige blokkhash (informasjon)
- `target_quality`: Kvalitetsterskel (for øyeblikket uint64_max, ingen filtrering)
- `minimum_compression_level`: Minimumskomprimering påkrevd for validering
- `target_compression_level`: Anbefalt komprimering for optimal mining

**Feilkoder**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node synkroniserer fortsatt

**Eksempel**:
```bash
bitcoin-cli get_mining_info
```

**Implementasjon**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategori**: mining
**Krever mining-server**: Ja
**Krever lommebok**: Ja (for private nøkler)

**Formål**: Send inn en PoCX mining-løsning. Validerer bevis, køer for time-bended forging og oppretter automatisk blokk ved planlagt tidspunkt.

**Parametere**:
1. `height` (numerisk, påkrevd) - Blokkhøyde
2. `generation_signature` (streng hex, påkrevd) - Generasjonssignatur (64 tegn)
3. `account_id` (streng, påkrevd) - Plot-konto-ID (40 hex-tegn = 20 bytes)
4. `seed` (streng, påkrevd) - Plot-seed (64 hex-tegn = 32 bytes)
5. `nonce` (numerisk, påkrevd) - Mining-nonce
6. `compression` (numerisk, påkrevd) - Skalerings-/komprimeringsnivå brukt (1-255)
7. `quality` (numerisk, valgfritt) - Kvalitetsverdi (beregnes på nytt hvis utelatt)

**Returverdier** (suksess):
```json
{
  "accepted": true,
  "quality": 120,           // vanskelighetsjustert deadline i sekunder
  "poc_time": 45            // time-bended forgetid i sekunder
}
```

**Returverdier** (avvist):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Valideringstrinn**:
1. **Formatvalidering** (rask-feil):
   - Konto-ID: nøyaktig 40 hex-tegn
   - Seed: nøyaktig 64 hex-tegn
2. **Kontekstvalidering**:
   - Høyde må samsvare med gjeldende tipp + 1
   - Generasjonssignatur må samsvare med gjeldende
3. **Lommebokverifisering**:
   - Bestem effektiv signerer (sjekk for aktive tildelinger)
   - Verifiser at lommebok har privat nøkkel for effektiv signerer
4. **Bevisvalidering** (dyrt):
   - Valider PoCX-bevis med komprimeringsbegrensninger
   - Beregn rå kvalitet
5. **Planleggerinnsending**:
   - Kø nonce for time-bended forging
   - Blokk vil opprettes automatisk ved forge_time

**Feilkoder**:
- `RPC_INVALID_PARAMETER`: Ugyldig format (account_id, seed) eller høydemismatch
- `RPC_VERIFY_REJECTED`: Generasjonssignaturmismatch eller bevisvalidering feilet
- `RPC_INVALID_ADDRESS_OR_KEY`: Ingen privat nøkkel for effektiv signerer
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Innsendingskø full
- `RPC_INTERNAL_ERROR`: Kunne ikke initialisere PoCX-planlegger

**Bevisvalidering-feilkoder**:
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

**Merknader**:
- Innsending er asynkron - RPC returnerer umiddelbart, blokk forges senere
- Time Bending forsinker gode løsninger for å tillate nettverksomfattende plotskanning
- Tildelingssystem: hvis plot er tildelt, må lommebok ha forging-adressenøkkel
- Komprimeringsbegrensninger justeres dynamisk basert på blokkhøyde

**Implementasjon**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Tildelings-RPC-er

### get_assignment

**Kategori**: mining
**Krever mining-server**: Nei
**Krever lommebok**: Nei

**Formål**: Spør forging-tildelingsstatus for en plotadresse. Skrivebeskyttet, ingen lommebok påkrevd.

**Parametere**:
1. `plot_address` (streng, påkrevd) - Plotadresse (bech32 P2WPKH-format)
2. `height` (numerisk, valgfritt) - Blokkhøyde å spørre (standard: gjeldende tipp)

**Returverdier** (ingen tildeling):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Returverdier** (aktiv tildeling):
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

**Returverdier** (opphever):
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

**Tildelingstilstander**:
- `UNASSIGNED`: Ingen tildeling eksisterer
- `ASSIGNING`: Tildelingstx bekreftet, aktiveringsforsinkelse pågår
- `ASSIGNED`: Tildeling aktiv, forging-rettigheter delegert
- `REVOKING`: Opphevingstx bekreftet, fortsatt aktiv til forsinkelse utløper
- `REVOKED`: Oppheving fullført, forging-rettigheter returnert til ploteier

**Feilkoder**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Ugyldig adresse eller ikke P2WPKH (bech32)

**Eksempel**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementasjon**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategori**: wallet
**Krever mining-server**: Nei
**Krever lommebok**: Ja (må være lastet og ulåst)

**Formål**: Opprett forging-tildelingstransaksjon for å delegere forging-rettigheter til en annen adresse (f.eks. mining-pool).

**Parametere**:
1. `plot_address` (streng, påkrevd) - Ploteieradresse (må eie privat nøkkel, P2WPKH bech32)
2. `forging_address` (streng, påkrevd) - Adresse å tildele forging-rettigheter til (P2WPKH bech32)
3. `fee_rate` (numerisk, valgfritt) - Gebyrrate i BTC/kvB (standard: 10× minRelayFee)

**Returverdier**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Krav**:
- Lommebok lastet og ulåst
- Privat nøkkel for plot_address i lommebok
- Begge adresser må være P2WPKH (bech32-format: pocx1q... mainnet, tpocx1q... testnett)
- Plotadresse må ha bekreftede UTXO-er (beviser eierskap)
- Plot må ikke ha aktiv tildeling (bruk revoke først)

**Transaksjonsstruktur**:
- Input: UTXO fra plotadresse (beviser eierskap)
- Output: OP_RETURN (46 bytes): `POCX`-markør + plot_address (20 bytes) + forging_address (20 bytes)
- Output: Vekslepenger returnert til lommebok

**Aktivering**:
- Tildeling blir ASSIGNING ved bekreftelse
- Blir ACTIVE etter `nForgingAssignmentDelay` blokker
- Forsinkelse forhindrer rask omtildeling under kjedegafler

**Feilkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen lommebok tilgjengelig
- `RPC_WALLET_UNLOCK_NEEDED`: Lommebok kryptert og låst
- `RPC_WALLET_ERROR`: Transaksjonsoppretting feilet
- `RPC_INVALID_ADDRESS_OR_KEY`: Ugyldig adresseformat

**Eksempel**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementasjon**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategori**: wallet
**Krever mining-server**: Nei
**Krever lommebok**: Ja (må være lastet og ulåst)

**Formål**: Opphev eksisterende forging-tildeling og returner forging-rettigheter til ploteier.

**Parametere**:
1. `plot_address` (streng, påkrevd) - Plotadresse (må eie privat nøkkel, P2WPKH bech32)
2. `fee_rate` (numerisk, valgfritt) - Gebyrrate i BTC/kvB (standard: 10× minRelayFee)

**Returverdier**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Krav**:
- Lommebok lastet og ulåst
- Privat nøkkel for plot_address i lommebok
- Plotadresse må være P2WPKH (bech32-format)
- Plotadresse må ha bekreftede UTXO-er

**Transaksjonsstruktur**:
- Input: UTXO fra plotadresse (beviser eierskap)
- Output: OP_RETURN (26 bytes): `XCOP`-markør + plot_address (20 bytes)
- Output: Vekslepenger returnert til lommebok

**Effekt**:
- Tilstand går til REVOKING umiddelbart
- Forging-adresse kan fortsatt forge under forsinkelsesperiode
- Blir REVOKED etter `nForgingRevocationDelay` blokker
- Ploteier kan forge etter at oppheving er effektiv
- Kan opprette ny tildeling etter at oppheving er fullført

**Feilkoder**:
- `RPC_WALLET_NOT_FOUND`: Ingen lommebok tilgjengelig
- `RPC_WALLET_UNLOCK_NEEDED`: Lommebok kryptert og låst
- `RPC_WALLET_ERROR`: Transaksjonsoppretting feilet

**Eksempel**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Merknader**:
- Idempotent: kan oppheve selv om ingen aktiv tildeling
- Kan ikke kansellere oppheving når den er sendt

**Implementasjon**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modifiserte blockchain-RPC-er

### getdifficulty

**PoCX-modifikasjoner**:
- **Beregning**: `reference_base_target / current_base_target`
- **Referanse**: 1 TiB nettverkskapasitet (base_target = 36650387593)
- **Tolkning**: Estimert nettverkslagringskapasitet i TiB
  - Eksempel: `1.0` = ~1 TiB
  - Eksempel: `1024.0` = ~1 PiB
- **Forskjell fra PoW**: Representerer kapasitet, ikke hashkraft

**Eksempel**:
```bash
bitcoin-cli getdifficulty
# Returnerer: 2048.5 (nettverk ~2 PiB)
```

**Implementasjon**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX-tilføyde felt**:
- `time_since_last_block` (numerisk) - Sekunder siden forrige blokk (erstatter mediantime)
- `poc_time` (numerisk) - Time-bended forgetid i sekunder
- `base_target` (numerisk) - PoCX-vanskelighets base target
- `generation_signature` (streng hex) - Generasjonssignatur
- `pocx_proof` (objekt):
  - `account_id` (streng hex) - Plot-konto-ID (20 bytes)
  - `seed` (streng hex) - Plot-seed (32 bytes)
  - `nonce` (numerisk) - Mining-nonce
  - `compression` (numerisk) - Skaleringsnivå brukt
  - `quality` (numerisk) - Påstått kvalitetsverdi
- `pubkey` (streng hex) - Blokksignereres offentlige nøkkel (33 bytes)
- `signer_address` (streng) - Blokksignereres adresse
- `signature` (streng hex) - Blokksignatur (65 bytes)

**PoCX-fjernede felt**:
- `mediantime` - Fjernet (erstattet av time_since_last_block)

**Eksempel**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementasjon**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-modifikasjoner**: Samme som getblockheader, pluss fulle transaksjonsdata

**Eksempel**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose med tx-detaljer
```

**Implementasjon**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX-tilføyde felt**:
- `base_target` (numerisk) - Gjeldende base target
- `generation_signature` (streng hex) - Gjeldende generasjonssignatur

**PoCX-modifiserte felt**:
- `difficulty` - Bruker PoCX-beregning (kapasitetsbasert)

**PoCX-fjernede felt**:
- `mediantime` - Fjernet

**Eksempel**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementasjon**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX-tilføyde felt**:
- `generation_signature` (streng hex) - For pool-mining
- `base_target` (numerisk) - For pool-mining

**PoCX-fjernede felt**:
- `target` - Fjernet (PoW-spesifikk)
- `noncerange` - Fjernet (PoW-spesifikk)
- `bits` - Fjernet (PoW-spesifikk)

**Merknader**:
- Inkluderer fortsatt fulle transaksjonsdata for blokkonstruksjon
- Brukes av pool-servere for koordinert mining

**Eksempel**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementasjon**: `src/rpc/mining.cpp`

---

## Deaktiverte RPC-er

Følgende PoW-spesifikke RPC-er er **deaktivert** i PoCX-modus:

### getnetworkhashps
- **Årsak**: Hashrate ikke anvendelig for Proof of Capacity
- **Alternativ**: Bruk `getdifficulty` for nettverkskapasitetsestimat

### getmininginfo
- **Årsak**: Returnerer PoW-spesifikk informasjon
- **Alternativ**: Bruk `get_mining_info` (PoCX-spesifikk)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Årsak**: CPU-mining ikke anvendelig for PoCX (krever forhåndsgenererte plotter)
- **Alternativ**: Bruk ekstern plotter + miner + `submit_nonce`

**Implementasjon**: `src/rpc/mining.cpp` (RPC-er returnerer feil når ENABLE_POCX er definert)

---

## Integrasjonseksempler

### Ekstern miner-integrasjon

**Grunnleggende miningløkke**:
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

# Miningløkke
while True:
    # 1. Hent miningparametere
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skann plotfiler (ekstern implementasjon)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Send inn beste løsning
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Løsning akseptert! Kvalitet: {result['quality']}s, "
              f"Forgetid: {result['poc_time']}s")

    # 4. Vent på neste blokk
    time.sleep(10)  # Pollingintervall
```

---

### Pool-integrasjonsmønster

**Pool-server arbeidsflyt**:
1. Minere oppretter forging-tildelinger til pool-adresse
2. Pool kjører lommebok med forging-adresse-nøkler
3. Pool kaller `get_mining_info` og distribuerer til minere
4. Minere sender inn løsninger via pool (ikke direkte til kjede)
5. Pool validerer og kaller `submit_nonce` med pools nøkler
6. Pool distribuerer belønninger i henhold til pool-policy

**Tildelingsadministrasjon**:
```bash
# Miner oppretter tildeling (fra miners lommebok)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Vent på aktivering (30 blokker mainnet)

# Pool sjekker tildelingsstatus
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool kan nå sende inn nonces for dette plottet
# (pool-lommebok må ha pocx1qpool... privat nøkkel)
```

---

### Blokkutforsker-spørringer

**Spørre PoCX-blokkdata**:
```bash
# Hent siste blokk
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Hent blokkdetaljer med PoCX-bevis
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Trekk ut PoCX-spesifikke felt
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

**Oppdage tildelingstransaksjoner**:
```bash
# Skann transaksjon for OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Sjekk for tildelingsmarkør (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Feilhåndtering

### Vanlige feilmønstre

**Høydemismatch**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Løsning**: Hent mininginfo på nytt, kjeden har gått fremover

**Generasjonssignaturmismatch**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Løsning**: Hent mininginfo på nytt, ny blokk har ankommet

**Ingen privat nøkkel**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Løsning**: Importer nøkkel for plot- eller forging-adresse

**Tildelingsaktivering ventende**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Løsning**: Vent til aktiveringsforsinkelse har utløpt

---

## Kodereferanser

**Mining-RPC-er**: `src/pocx/rpc/mining.cpp`
**Tildelings-RPC-er**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain-RPC-er**: `src/rpc/blockchain.cpp`
**Bevisvalidering**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Tildelingstilstand**: `src/pocx/assignments/assignment_state.cpp`
**Transaksjonsoppretting**: `src/pocx/assignments/transactions.cpp`

---

## Kryssreferanser

Relaterte kapitler:
- [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md) - Miningprosessdetaljer
- [Kapittel 4: Forging assignments](4-forging-assignments.md) - Tildelingssystemarkitektur
- [Kapittel 6: Nettverksparametere](6-network-parameters.md) - Tildelingsforsinkelseverdier
- [Kapittel 8: Lommebokveiledning](8-wallet-guide.md) - GUI for tildelingsadministrasjon

---

[← Forrige: Nettverksparametere](6-network-parameters.md) | [Innholdsfortegnelse](index.md) | [Neste: Lommebokveiledning →](8-wallet-guide.md)
