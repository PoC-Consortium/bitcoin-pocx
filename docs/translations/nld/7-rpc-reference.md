[Vorige: Netwerkparameters](6-network-parameters.md) | [Inhoudsopgave](index.md) | [Volgende: Wallet-handleiding](8-wallet-guide.md)

---

# Hoofdstuk 7: RPC-interface-referentie

Volledige referentie voor Bitcoin-PoCX RPC-opdrachten, inclusief mining-RPC's, toewijzingsbeheer en aangepaste blockchain-RPC's.

---

## Inhoudsopgave

1. [Configuratie](#configuratie)
2. [PoCX Mining-RPC's](#pocx-mining-rpcs)
3. [Toewijzings-RPC's](#toewijzings-rpcs)
4. [Aangepaste blockchain-RPC's](#aangepaste-blockchain-rpcs)
5. [Uitgeschakelde RPC's](#uitgeschakelde-rpcs)
6. [Integratievoorbeelden](#integratievoorbeelden)

---

## Configuratie

### Miningservermodus

**Vlag**: `-miningserver`

**Doel**: Schakelt RPC-toegang in voor externe miners om miningspecifieke RPC's aan te roepen

**Vereisten**:
- Vereist voor werking van `submit_nonce`
- Vereist voor zichtbaarheid van forging-toewijzingsdialoog in Qt-wallet

**Gebruik**:
```bash
# Opdrachtregel
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Beveiligingsoverwegingen**:
- Geen extra authenticatie naast standaard RPC-referenties
- Mining-RPC's zijn beperkt door wachtrijcapaciteit
- Standaard RPC-authenticatie nog steeds vereist

**Implementatie**: `src/pocx/rpc/mining.cpp`

---

## PoCX Mining-RPC's

### get_mining_info

**Categorie**: mining
**Vereist miningserver**: Nee
**Vereist wallet**: Nee

**Doel**: Retourneert huidige miningparameters die nodig zijn voor externe miners om plotbestanden te scannen en deadlines te berekenen.

**Parameters**: Geen

**Retourwaarden**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 tekens
  "base_target": 36650387593,                // numeriek
  "height": 12345,                           // numeriek, volgende blokhoogte
  "block_hash": "def456...",                 // hex, vorig blok
  "target_quality": 18446744073709551615,    // uint64_max (alle oplossingen geaccepteerd)
  "minimum_compression_level": 1,            // numeriek
  "target_compression_level": 2              // numeriek
}
```

**Veldbeschrijvingen**:
- `generation_signature`: Deterministische mining-entropie voor deze blokhoogte
- `base_target`: Huidige moeilijkheid (hoger = makkelijker)
- `height`: Blokhoogte waar miners op moeten mikken
- `block_hash`: Vorige blokhash (informatief)
- `target_quality`: Kwaliteitsdrempel (momenteel uint64_max, geen filtering)
- `minimum_compression_level`: Minimale compressie vereist voor validatie
- `target_compression_level`: Aanbevolen compressie voor optimaal minen

**Foutcodes**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node nog aan het synchroniseren

**Voorbeeld**:
```bash
bitcoin-cli get_mining_info
```

**Implementatie**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Categorie**: mining
**Vereist miningserver**: Ja
**Vereist wallet**: Ja (voor privesleutels)

**Doel**: Dien een PoCX-miningoplossing in. Valideert bewijs, plaatst in wachtrij voor time-bended forging, en creert automatisch blok op geplande tijd.

**Parameters**:
1. `height` (numeriek, vereist) - Blokhoogte
2. `generation_signature` (string hex, vereist) - Generatiehandtekening (64 tekens)
3. `account_id` (string, vereist) - Plot account-ID (40 hex-tekens = 20 bytes)
4. `seed` (string, vereist) - Plotseed (64 hex-tekens = 32 bytes)
5. `nonce` (numeriek, vereist) - Mining-nonce
6. `compression` (numeriek, vereist) - Gebruikte schaal/compressieniveau (1-255)
7. `quality` (numeriek, optioneel) - Kwaliteitswaarde (opnieuw berekend indien weggelaten)

**Retourwaarden** (succes):
```json
{
  "accepted": true,
  "quality": 120,           // moeilijkheidsaangepaste deadline in seconden
  "poc_time": 45            // time-bended forgetijd in seconden
}
```

**Retourwaarden** (afgewezen):
```json
{
  "accepted": false,
  "error": "Generatiehandtekening komt niet overeen"
}
```

**Validatiestappen**:
1. **Formaatvalidatie** (fail-fast):
   - Account-ID: exact 40 hex-tekens
   - Seed: exact 64 hex-tekens
2. **Contextvalidatie**:
   - Hoogte moet overeenkomen met huidige tip + 1
   - Generatiehandtekening moet overeenkomen met huidige
3. **Walletverificatie**:
   - Bepaal effectieve ondertekenaar (controleer op actieve toewijzingen)
   - Verifieer dat wallet privesleutel heeft voor effectieve ondertekenaar
4. **Bewijsvalidatie** (duur):
   - Valideer PoCX-bewijs met compressiegrenzen
   - Bereken ruwe kwaliteit
5. **Scheduler-indiening**:
   - Plaats nonce in wachtrij voor time-bended forging
   - Blok wordt automatisch gecreeerd op forge_time

**Foutcodes**:
- `RPC_INVALID_PARAMETER`: Ongeldig formaat (account_id, seed) of hoogte komt niet overeen
- `RPC_VERIFY_REJECTED`: Generatiehandtekening komt niet overeen of bewijsvalidatie gefaald
- `RPC_INVALID_ADDRESS_OR_KEY`: Geen privesleutel voor effectieve ondertekenaar
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Indieningswachtrij vol
- `RPC_INTERNAL_ERROR`: PoCX-scheduler kon niet worden geinitialiseerd

**Bewijsvalidatiefoutcodes**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Voorbeeld**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Opmerkingen**:
- Indiening is asynchroon - RPC keert onmiddellijk terug, blok wordt later geforged
- Time Bending vertraagt goede oplossingen om netwerkbrede plotscanning mogelijk te maken
- Toewijzingssysteem: als plot is toegewezen, moet wallet forgingadressleutel hebben
- Compressiegrenzen worden dynamisch aangepast op basis van blokhoogte

**Implementatie**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Toewijzings-RPC's

### get_assignment

**Categorie**: mining
**Vereist miningserver**: Nee
**Vereist wallet**: Nee

**Doel**: Vraag forging-toewijzingsstatus op voor een plotadres. Alleen-lezen, geen wallet vereist.

**Parameters**:
1. `plot_address` (string, vereist) - Plotadres (bech32 P2WPKH-formaat)
2. `height` (numeriek, optioneel) - Blokhoogte om op te vragen (standaard: huidige tip)

**Retourwaarden** (geen toewijzing):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Retourwaarden** (actieve toewijzing):
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

**Retourwaarden** (intrekkend):
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

**Toewijzingsstatussen**:
- `UNASSIGNED`: Geen toewijzing bestaat
- `ASSIGNING`: Toewijzings-tx bevestigd, activeringsvertraging in uitvoering
- `ASSIGNED`: Toewijzing actief, forgingrechten gedelegeerd
- `REVOKING`: Intrekkings-tx bevestigd, nog actief tot vertraging verstrijkt
- `REVOKED`: Intrekking voltooid, forgingrechten terug naar ploteigenaar

**Foutcodes**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Ongeldig adres of niet P2WPKH (bech32)

**Voorbeeld**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementatie**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Categorie**: wallet
**Vereist miningserver**: Nee
**Vereist wallet**: Ja (moet geladen en ontgrendeld zijn)

**Doel**: Creeer forging-toewijzingstransactie om forgingrechten te delegeren aan een ander adres (bijv. miningpool).

**Parameters**:
1. `plot_address` (string, vereist) - Ploteigenaaradres (moet privesleutel bezitten, P2WPKH bech32)
2. `forging_address` (string, vereist) - Adres om forgingrechten aan toe te wijzen (P2WPKH bech32)
3. `fee_rate` (numeriek, optioneel) - Kostenpercentage in BTC/kvB (standaard: 10x minRelayFee)

**Retourwaarden**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Vereisten**:
- Wallet geladen en ontgrendeld
- Privesleutel voor plot_address in wallet
- Beide adressen moeten P2WPKH zijn (bech32-formaat: pocx1q... mainnet, tpocx1q... testnet)
- Plotadres moet bevestigde UTXO's hebben (bewijst eigenaarschap)
- Plot mag geen actieve toewijzing hebben (gebruik eerst intrekking)

**Transactiestructuur**:
- Invoer: UTXO van plotadres (bewijst eigenaarschap)
- Uitvoer: OP_RETURN (46 bytes): `POCX`-markering + plot_address (20 bytes) + forging_address (20 bytes)
- Uitvoer: Wisselgeld terug naar wallet

**Activering**:
- Toewijzing wordt ASSIGNING bij bevestiging
- Wordt ACTIVE na `nForgingAssignmentDelay` blokken
- Vertraging voorkomt snelle hertoewijzing tijdens ketenvorken

**Foutcodes**:
- `RPC_WALLET_NOT_FOUND`: Geen wallet beschikbaar
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet versleuteld en vergrendeld
- `RPC_WALLET_ERROR`: Transactiecreatie gefaald
- `RPC_INVALID_ADDRESS_OR_KEY`: Ongeldig adresformaat

**Voorbeeld**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementatie**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Categorie**: wallet
**Vereist miningserver**: Nee
**Vereist wallet**: Ja (moet geladen en ontgrendeld zijn)

**Doel**: Trek bestaande forging-toewijzing in, waardoor forgingrechten terugkeren naar ploteigenaar.

**Parameters**:
1. `plot_address` (string, vereist) - Plotadres (moet privesleutel bezitten, P2WPKH bech32)
2. `fee_rate` (numeriek, optioneel) - Kostenpercentage in BTC/kvB (standaard: 10x minRelayFee)

**Retourwaarden**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Vereisten**:
- Wallet geladen en ontgrendeld
- Privesleutel voor plot_address in wallet
- Plotadres moet P2WPKH zijn (bech32-formaat)
- Plotadres moet bevestigde UTXO's hebben

**Transactiestructuur**:
- Invoer: UTXO van plotadres (bewijst eigenaarschap)
- Uitvoer: OP_RETURN (26 bytes): `XCOP`-markering + plot_address (20 bytes)
- Uitvoer: Wisselgeld terug naar wallet

**Effect**:
- Status gaat onmiddellijk over naar REVOKING
- Forgingadres kan nog steeds forgen tijdens vertragingsperiode
- Wordt REVOKED na `nForgingRevocationDelay` blokken
- Ploteigenaar kan forgen na effectieve intrekking
- Kan nieuwe toewijzing maken na voltooide intrekking

**Foutcodes**:
- `RPC_WALLET_NOT_FOUND`: Geen wallet beschikbaar
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet versleuteld en vergrendeld
- `RPC_WALLET_ERROR`: Transactiecreatie gefaald

**Voorbeeld**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Opmerkingen**:
- Idempotent: kan intrekken zelfs als geen actieve toewijzing
- Kan intrekking niet annuleren eenmaal ingediend

**Implementatie**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Aangepaste blockchain-RPC's

### getdifficulty

**PoCX-wijzigingen**:
- **Berekening**: `referentie_base_target / huidige_base_target`
- **Referentie**: 1 TiB netwerkcapaciteit (base_target = 36650387593)
- **Interpretatie**: Geschatte netwerkopslagcapaciteit in TiB
  - Voorbeeld: `1.0` = ~1 TiB
  - Voorbeeld: `1024.0` = ~1 PiB
- **Verschil met PoW**: Vertegenwoordigt capaciteit, geen hashkracht

**Voorbeeld**:
```bash
bitcoin-cli getdifficulty
# Retourneert: 2048.5 (netwerk ~2 PiB)
```

**Implementatie**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX toegevoegde velden**:
- `time_since_last_block` (numeriek) - Seconden sinds vorig blok (vervangt mediantime)
- `poc_time` (numeriek) - Time-bended forgetijd in seconden
- `base_target` (numeriek) - PoCX-moeilijkheid base target
- `generation_signature` (string hex) - Generatiehandtekening
- `pocx_proof` (object):
  - `account_id` (string hex) - Plot account-ID (20 bytes)
  - `seed` (string hex) - Plotseed (32 bytes)
  - `nonce` (numeriek) - Mining-nonce
  - `compression` (numeriek) - Gebruikt schaalniveau
  - `quality` (numeriek) - Geclaimde kwaliteitswaarde
- `pubkey` (string hex) - Publieke sleutel van blokondertekenaar (33 bytes)
- `signer_address` (string) - Adres van blokondertekenaar
- `signature` (string hex) - Blokhandtekening (65 bytes)

**PoCX verwijderde velden**:
- `mediantime` - Verwijderd (vervangen door time_since_last_block)

**Voorbeeld**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementatie**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX-wijzigingen**: Zelfde als getblockheader, plus volledige transactiegegevens

**Voorbeeld**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # uitgebreid met tx-details
```

**Implementatie**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX toegevoegde velden**:
- `base_target` (numeriek) - Huidige base target
- `generation_signature` (string hex) - Huidige generatiehandtekening

**PoCX gewijzigde velden**:
- `difficulty` - Gebruikt PoCX-berekening (capaciteitsgebaseerd)

**PoCX verwijderde velden**:
- `mediantime` - Verwijderd

**Voorbeeld**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementatie**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX toegevoegde velden**:
- `generation_signature` (string hex) - Voor pool-mining
- `base_target` (numeriek) - Voor pool-mining

**PoCX verwijderde velden**:
- `target` - Verwijderd (PoW-specifiek)
- `noncerange` - Verwijderd (PoW-specifiek)
- `bits` - Verwijderd (PoW-specifiek)

**Opmerkingen**:
- Bevat nog steeds volledige transactiegegevens voor blokconstructie
- Gebruikt door poolservers voor gecoordineerd minen

**Voorbeeld**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementatie**: `src/rpc/mining.cpp`

---

## Uitgeschakelde RPC's

De volgende PoW-specifieke RPC's zijn **uitgeschakeld** in PoCX-modus:

### getnetworkhashps
- **Reden**: Hashrate niet van toepassing op Proof of Capacity
- **Alternatief**: Gebruik `getdifficulty` voor netwerkcapaciteitsschatting

### getmininginfo
- **Reden**: Retourneert PoW-specifieke informatie
- **Alternatief**: Gebruik `get_mining_info` (PoCX-specifiek)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Reden**: CPU-mining niet van toepassing op PoCX (vereist vooraf gegenereerde plots)
- **Alternatief**: Gebruik externe plotter + miner + `submit_nonce`

**Implementatie**: `src/rpc/mining.cpp` (RPC's retourneren fout wanneer ENABLE_POCX gedefinieerd)

---

## Integratievoorbeelden

### Externe miner-integratie

**Basis mininglus**:
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

# Mininglus
while True:
    # 1. Haal miningparameters op
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scan plotbestanden (externe implementatie)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Dien beste oplossing in
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Oplossing geaccepteerd! Kwaliteit: {result['quality']}s, "
              f"Forgetijd: {result['poc_time']}s")

    # 4. Wacht op volgend blok
    time.sleep(10)  # Pollinterval
```

---

### Pool-integratiepatroon

**Pool-serverworkflow**:
1. Miners creeren forging-toewijzingen naar pooladres
2. Pool draait wallet met forgingadressleutels
3. Pool roept `get_mining_info` aan en distribueert naar miners
4. Miners dienen oplossingen in via pool (niet direct naar keten)
5. Pool valideert en roept `submit_nonce` aan met poolsleutels
6. Pool distribueert beloningen volgens poolbeleid

**Toewijzingsbeheer**:
```bash
# Miner creert toewijzing (vanuit miner's wallet)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Wacht op activering (30 blokken mainnet)

# Pool controleert toewijzingsstatus
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool kan nu nonces indienen voor dit plot
# (pool-wallet moet pocx1qpool... privesleutel hebben)
```

---

### Blokverkenner-queries

**PoCX-blokgegevens opvragen**:
```bash
# Haal laatste blok op
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Haal blokdetails op met PoCX-bewijs
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extraheer PoCX-specifieke velden
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

**Toewijzingstransacties detecteren**:
```bash
# Scan transactie op OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Controleer op toewijzingsmarkering (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Foutafhandeling

### Veelvoorkomende foutpatronen

**Hoogte komt niet overeen**:
```json
{
  "accepted": false,
  "error": "Hoogte komt niet overeen: ingediend 12345, huidige 12346"
}
```
**Oplossing**: Haal mining-info opnieuw op, keten is verder gegaan

**Generatiehandtekening komt niet overeen**:
```json
{
  "accepted": false,
  "error": "Generatiehandtekening komt niet overeen"
}
```
**Oplossing**: Haal mining-info opnieuw op, nieuw blok is gearriveerd

**Geen privesleutel**:
```json
{
  "code": -5,
  "message": "Geen privesleutel beschikbaar voor effectieve ondertekenaar"
}
```
**Oplossing**: Importeer sleutel voor plot- of forgingadres

**Toewijzingsactivering wachtend**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Oplossing**: Wacht tot activeringsvertraging verstrijkt

---

## Codereferenties

**Mining-RPC's**: `src/pocx/rpc/mining.cpp`
**Toewijzings-RPC's**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain-RPC's**: `src/rpc/blockchain.cpp`
**Bewijsvalidatie**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Toewijzingsstatus**: `src/pocx/assignments/assignment_state.cpp`
**Transactiecreatie**: `src/pocx/assignments/transactions.cpp`

---

## Kruisverwijzingen

Gerelateerde hoofdstukken:
- [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md) - Miningprocesdetails
- [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md) - Toewijzingssysteemarchitectuur
- [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md) - Toewijzingsvertragingswaarden
- [Hoofdstuk 8: Wallet-handleiding](8-wallet-guide.md) - GUI voor toewijzingsbeheer

---

[Vorige: Netwerkparameters](6-network-parameters.md) | [Inhoudsopgave](index.md) | [Volgende: Wallet-handleiding](8-wallet-guide.md)
