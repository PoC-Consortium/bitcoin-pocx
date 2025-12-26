[← Předchozí: Síťové parametry](6-network-parameters.md) | [Obsah](index.md) | [Další: Průvodce peněženkou →](8-wallet-guide.md)

---

# Kapitola 7: Reference RPC rozhraní

Kompletní reference RPC příkazů Bitcoin-PoCX včetně těžebních RPC, správy přiřazení a modifikovaných blockchain RPC.

---

## Obsah

1. [Konfigurace](#konfigurace)
2. [PoCX těžební RPC](#pocx-těžební-rpc)
3. [RPC přiřazení](#rpc-přiřazení)
4. [Modifikovaná blockchain RPC](#modifikovaná-blockchain-rpc)
5. [Zakázaná RPC](#zakázaná-rpc)
6. [Příklady integrace](#příklady-integrace)

---

## Konfigurace

### Režim těžebního serveru

**Příznak**: `-miningserver`

**Účel**: Povoluje RPC přístup pro externí těžaře k volání těžebních RPC

**Požadavky**:
- Vyžadováno pro fungování `submit_nonce`
- Vyžadováno pro viditelnost dialogu forging přiřazení v Qt peněžence

**Použití**:
```bash
# Příkazový řádek
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Bezpečnostní aspekty**:
- Žádná další autentizace nad rámec standardních RPC přihlašovacích údajů
- Těžební RPC jsou omezeny kapacitou fronty
- Stále vyžadována standardní RPC autentizace

**Implementace**: `src/pocx/rpc/mining.cpp`

---

## PoCX těžební RPC

### get_mining_info

**Kategorie**: mining
**Vyžaduje těžební server**: Ne
**Vyžaduje peněženku**: Ne

**Účel**: Vrací aktuální těžební parametry potřebné pro externí těžaře ke skenování plot souborů a výpočtu deadlinů.

**Parametry**: Žádné

**Návratové hodnoty**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 znaků
  "base_target": 36650387593,                // číselný
  "height": 12345,                           // číselný, výška dalšího bloku
  "block_hash": "def456...",                 // hex, předchozí blok
  "target_quality": 18446744073709551615,    // uint64_max (všechna řešení přijata)
  "minimum_compression_level": 1,            // číselný
  "target_compression_level": 2              // číselný
}
```

**Popisy polí**:
- `generation_signature`: Deterministická těžební entropie pro tuto výšku bloku
- `base_target`: Aktuální obtížnost (vyšší = jednodušší)
- `height`: Výška bloku, kterou by těžaři měli cílit
- `block_hash`: Hash předchozího bloku (informativní)
- `target_quality`: Práh kvality (aktuálně uint64_max, žádné filtrování)
- `minimum_compression_level`: Minimální komprese vyžadovaná pro validaci
- `target_compression_level`: Doporučená komprese pro optimální těžbu

**Chybové kódy**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Uzel stále synchronizuje

**Příklad**:
```bash
bitcoin-cli get_mining_info
```

**Implementace**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Kategorie**: mining
**Vyžaduje těžební server**: Ano
**Vyžaduje peněženku**: Ano (pro privátní klíče)

**Účel**: Odeslat těžební řešení PoCX. Validuje důkaz, zařadí do fronty pro time-bended forging a automaticky vytvoří blok v naplánovaném čase.

**Parametry**:
1. `height` (číselný, povinný) - Výška bloku
2. `generation_signature` (string hex, povinný) - Generační podpis (64 znaků)
3. `account_id` (string, povinný) - ID účtu plotu (40 hex znaků = 20 bajtů)
4. `seed` (string, povinný) - Seed plotu (64 hex znaků = 32 bajtů)
5. `nonce` (číselný, povinný) - Těžební nonce
6. `compression` (číselný, povinný) - Použitá úroveň škálování/komprese (1-255)
7. `quality` (číselný, volitelný) - Hodnota kvality (přepočítána, pokud vynechána)

**Návratové hodnoty** (úspěch):
```json
{
  "accepted": true,
  "quality": 120,           // deadline upravený na obtížnost v sekundách
  "poc_time": 45            // čas forgu s time-bending v sekundách
}
```

**Návratové hodnoty** (odmítnuto):
```json
{
  "accepted": false,
  "error": "Nesoulad generačního podpisu"
}
```

**Kroky validace**:
1. **Validace formátu** (fail-fast):
   - Account ID: přesně 40 hex znaků
   - Seed: přesně 64 hex znaků
2. **Validace kontextu**:
   - Výška musí odpovídat aktuálnímu tipu + 1
   - Generační podpis musí odpovídat aktuálnímu
3. **Ověření peněženky**:
   - Určit efektivního podpisujícího (zkontrolovat aktivní přiřazení)
   - Ověřit, že peněženka má privátní klíč pro efektivního podpisujícího
4. **Validace důkazu** (drahá):
   - Validovat PoCX důkaz s hranicemi komprese
   - Vypočítat surovou kvalitu
5. **Odeslání do plánovače**:
   - Zařadit nonce do fronty pro time-bended forging
   - Blok bude vytvořen automaticky v čase forge_time

**Chybové kódy**:
- `RPC_INVALID_PARAMETER`: Neplatný formát (account_id, seed) nebo nesoulad výšky
- `RPC_VERIFY_REJECTED`: Nesoulad generačního podpisu nebo selhání validace důkazu
- `RPC_INVALID_ADDRESS_OR_KEY`: Žádný privátní klíč pro efektivního podpisujícího
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Fronta odesílání plná
- `RPC_INTERNAL_ERROR`: Selhání inicializace plánovače PoCX

**Chybové kódy validace důkazu**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Příklad**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_znaku..." \
  999888777 \
  1
```

**Poznámky**:
- Odeslání je asynchronní - RPC vrací okamžitě, blok vytvořen později
- Time Bending zpožďuje dobrá řešení, aby síť mohla prohledat všechny disky
- Systém přiřazení: pokud je plot přiřazen, peněženka musí mít klíč forging adresy
- Hranice komprese dynamicky upraveny na základě výšky bloku

**Implementace**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPC přiřazení

### get_assignment

**Kategorie**: mining
**Vyžaduje těžební server**: Ne
**Vyžaduje peněženku**: Ne

**Účel**: Dotaz na stav forging přiřazení pro adresu plotu. Pouze pro čtení, nevyžaduje peněženku.

**Parametry**:
1. `plot_address` (string, povinný) - Adresa plotu (bech32 P2WPKH formát)
2. `height` (číselný, volitelný) - Výška bloku pro dotaz (výchozí: aktuální tip)

**Návratové hodnoty** (bez přiřazení):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Návratové hodnoty** (aktivní přiřazení):
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

**Návratové hodnoty** (revokace):
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

**Stavy přiřazení**:
- `UNASSIGNED`: Přiřazení neexistuje
- `ASSIGNING`: Transakce přiřazení potvrzena, probíhá zpoždění aktivace
- `ASSIGNED`: Přiřazení aktivní, práva na forging delegována
- `REVOKING`: Transakce revokace potvrzena, stále aktivní do uplynutí zpoždění
- `REVOKED`: Revokace dokončena, práva na forging vrácena vlastníkovi plotu

**Chybové kódy**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Neplatná adresa nebo není P2WPKH (bech32)

**Příklad**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementace**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Kategorie**: wallet
**Vyžaduje těžební server**: Ne
**Vyžaduje peněženku**: Ano (musí být načtena a odemčena)

**Účel**: Vytvořit transakci forging přiřazení pro delegování práv na forging na jinou adresu (např. těžební pool).

**Parametry**:
1. `plot_address` (string, povinný) - Adresa vlastníka plotu (musí vlastnit privátní klíč, P2WPKH bech32)
2. `forging_address` (string, povinný) - Adresa pro přiřazení práv na forging (P2WPKH bech32)
3. `fee_rate` (číselný, volitelný) - Sazba poplatku v BTC/kvB (výchozí: 10× minRelayFee)

**Návratové hodnoty**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Požadavky**:
- Peněženka načtena a odemčena
- Privátní klíč pro plot_address v peněžence
- Obě adresy musí být P2WPKH (bech32 formát: pocx1q... mainnet, tpocx1q... testnet)
- Adresa plotu musí mít potvrzená UTXO (prokazuje vlastnictví)
- Plot nesmí mít aktivní přiřazení (nejdříve použijte revoke)

**Struktura transakce**:
- Vstup: UTXO z adresy plotu (prokazuje vlastnictví)
- Výstup: OP_RETURN (46 bajtů): marker `POCX` + plot_address (20 bajtů) + forging_address (20 bajtů)
- Výstup: Zbytek vrácen do peněženky

**Aktivace**:
- Přiřazení se stává ASSIGNING při potvrzení
- Stává se ACTIVE po `nForgingAssignmentDelay` blocích
- Zpoždění zabraňuje rychlému přeřazení během forků řetězce

**Chybové kódy**:
- `RPC_WALLET_NOT_FOUND`: Peněženka není dostupná
- `RPC_WALLET_UNLOCK_NEEDED`: Peněženka zašifrována a uzamčena
- `RPC_WALLET_ERROR`: Vytváření transakce selhalo
- `RPC_INVALID_ADDRESS_OR_KEY`: Neplatný formát adresy

**Příklad**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementace**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Kategorie**: wallet
**Vyžaduje těžební server**: Ne
**Vyžaduje peněženku**: Ano (musí být načtena a odemčena)

**Účel**: Revokovat existující forging přiřazení, vrátit práva na forging vlastníkovi plotu.

**Parametry**:
1. `plot_address` (string, povinný) - Adresa plotu (musí vlastnit privátní klíč, P2WPKH bech32)
2. `fee_rate` (číselný, volitelný) - Sazba poplatku v BTC/kvB (výchozí: 10× minRelayFee)

**Návratové hodnoty**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Požadavky**:
- Peněženka načtena a odemčena
- Privátní klíč pro plot_address v peněžence
- Adresa plotu musí být P2WPKH (bech32 formát)
- Adresa plotu musí mít potvrzená UTXO

**Struktura transakce**:
- Vstup: UTXO z adresy plotu (prokazuje vlastnictví)
- Výstup: OP_RETURN (26 bajtů): marker `XCOP` + plot_address (20 bajtů)
- Výstup: Zbytek vrácen do peněženky

**Efekt**:
- Stav okamžitě přechází na REVOKING
- Forging adresa může stále provádět forging během období zpoždění
- Stává se REVOKED po `nForgingRevocationDelay` blocích
- Vlastník plotu může provádět forging po nabytí účinnosti revokace
- Může vytvořit nové přiřazení po dokončení revokace

**Chybové kódy**:
- `RPC_WALLET_NOT_FOUND`: Peněženka není dostupná
- `RPC_WALLET_UNLOCK_NEEDED`: Peněženka zašifrována a uzamčena
- `RPC_WALLET_ERROR`: Vytváření transakce selhalo

**Příklad**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Poznámky**:
- Idempotentní: lze revokovat i když není aktivní přiřazení
- Nelze zrušit revokaci po odeslání

**Implementace**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modifikovaná blockchain RPC

### getdifficulty

**Modifikace PoCX**:
- **Výpočet**: `reference_base_target / current_base_target`
- **Reference**: Síťová kapacita 1 TiB (base_target = 36650387593)
- **Interpretace**: Odhadovaná síťová úložná kapacita v TiB
  - Příklad: `1.0` = ~1 TiB
  - Příklad: `1024.0` = ~1 PiB
- **Rozdíl od PoW**: Reprezentuje kapacitu, ne hash power

**Příklad**:
```bash
bitcoin-cli getdifficulty
# Vrací: 2048.5 (síť ~2 PiB)
```

**Implementace**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Přidaná pole PoCX**:
- `time_since_last_block` (číselný) - Sekundy od předchozího bloku (nahrazuje mediantime)
- `poc_time` (číselný) - Čas forgu s time-bending v sekundách
- `base_target` (číselný) - PoCX difficulty base target
- `generation_signature` (string hex) - Generační podpis
- `pocx_proof` (objekt):
  - `account_id` (string hex) - ID účtu plotu (20 bajtů)
  - `seed` (string hex) - Seed plotu (32 bajtů)
  - `nonce` (číselný) - Těžební nonce
  - `compression` (číselný) - Použitá úroveň škálování
  - `quality` (číselný) - Deklarovaná hodnota kvality
- `pubkey` (string hex) - Veřejný klíč podpisujícího blok (33 bajtů)
- `signer_address` (string) - Adresa podpisujícího blok
- `signature` (string hex) - Podpis bloku (65 bajtů)

**Odebraná pole PoCX**:
- `mediantime` - Odebráno (nahrazeno time_since_last_block)

**Příklad**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementace**: `src/rpc/blockchain.cpp`

---

### getblock

**Modifikace PoCX**: Stejné jako getblockheader, plus kompletní data transakcí

**Příklad**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose s detaily tx
```

**Implementace**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Přidaná pole PoCX**:
- `base_target` (číselný) - Aktuální base target
- `generation_signature` (string hex) - Aktuální generační podpis

**Modifikovaná pole PoCX**:
- `difficulty` - Používá výpočet PoCX (založeno na kapacitě)

**Odebraná pole PoCX**:
- `mediantime` - Odebráno

**Příklad**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementace**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Přidaná pole PoCX**:
- `generation_signature` (string hex) - Pro poolovou těžbu
- `base_target` (číselný) - Pro poolovou těžbu

**Odebraná pole PoCX**:
- `target` - Odebráno (specifické pro PoW)
- `noncerange` - Odebráno (specifické pro PoW)
- `bits` - Odebráno (specifické pro PoW)

**Poznámky**:
- Stále obsahuje kompletní data transakcí pro konstrukci bloku
- Používáno servery poolů pro koordinovanou těžbu

**Příklad**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementace**: `src/rpc/mining.cpp`

---

## Zakázaná RPC

Následující PoW-specifická RPC jsou **zakázána** v režimu PoCX:

### getnetworkhashps
- **Důvod**: Hash rate není aplikovatelný na Proof of Capacity
- **Alternativa**: Použijte `getdifficulty` pro odhad síťové kapacity

### getmininginfo
- **Důvod**: Vrací PoW-specifické informace
- **Alternativa**: Použijte `get_mining_info` (specifické pro PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Důvod**: CPU těžba není aplikovatelná na PoCX (vyžaduje předgenerované ploty)
- **Alternativa**: Použijte externí plotter + miner + `submit_nonce`

**Implementace**: `src/rpc/mining.cpp` (RPC vrací chybu, když je definováno ENABLE_POCX)

---

## Příklady integrace

### Integrace externího mineru

**Základní těžební smyčka**:
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

# Těžební smyčka
while True:
    # 1. Získat těžební parametry
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Skenovat plot soubory (externí implementace)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Odeslat nejlepší řešení
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Řešení přijato! Kvalita: {result['quality']}s, "
              f"Čas forgu: {result['poc_time']}s")

    # 4. Čekat na další blok
    time.sleep(10)  # Interval dotazování
```

---

### Vzor integrace poolu

**Workflow serveru poolu**:
1. Těžaři vytvářejí forging přiřazení na adresu poolu
2. Pool provozuje peněženku s klíči forging adresy
3. Pool volá `get_mining_info` a distribuuje těžařům
4. Těžaři odesílají řešení přes pool (ne přímo do řetězce)
5. Pool validuje a volá `submit_nonce` s klíči poolu
6. Pool distribuuje odměny podle politiky poolu

**Správa přiřazení**:
```bash
# Těžař vytváří přiřazení (z peněženky těžaře)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Čekat na aktivaci (30 bloků mainnet)

# Pool kontroluje stav přiřazení
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool nyní může odesílat nonces pro tento plot
# (peněženka poolu musí mít privátní klíč pocx1qpool...)
```

---

### Dotazy block exploreru

**Dotazování dat bloku PoCX**:
```bash
# Získat nejnovější blok
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Získat detaily bloku s PoCX důkazem
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extrahovat PoCX-specifická pole
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

**Detekce transakcí přiřazení**:
```bash
# Skenovat transakci na OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Zkontrolovat marker přiřazení (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Zpracování chyb

### Běžné vzory chyb

**Nesoulad výšky**:
```json
{
  "accepted": false,
  "error": "Nesoulad výšky: odesláno 12345, aktuální 12346"
}
```
**Řešení**: Znovu načíst těžební info, řetězec se posunul dopředu

**Nesoulad generačního podpisu**:
```json
{
  "accepted": false,
  "error": "Nesoulad generačního podpisu"
}
```
**Řešení**: Znovu načíst těžební info, přišel nový blok

**Žádný privátní klíč**:
```json
{
  "code": -5,
  "message": "Žádný privátní klíč dostupný pro efektivního podpisujícího"
}
```
**Řešení**: Importovat klíč pro plot nebo forging adresu

**Aktivace přiřazení čeká**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Řešení**: Čekat na uplynutí zpoždění aktivace

---

## Reference kódu

**Těžební RPC**: `src/pocx/rpc/mining.cpp`
**RPC přiřazení**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain RPC**: `src/rpc/blockchain.cpp`
**Validace důkazu**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Stav přiřazení**: `src/pocx/assignments/assignment_state.cpp`
**Vytváření transakcí**: `src/pocx/assignments/transactions.cpp`

---

## Křížové odkazy

Související kapitoly:
- [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md) - Podrobnosti procesu těžby
- [Kapitola 4: Forging přiřazení](4-forging-assignments.md) - Architektura systému přiřazení
- [Kapitola 6: Síťové parametry](6-network-parameters.md) - Hodnoty zpoždění přiřazení
- [Kapitola 8: Průvodce peněženkou](8-wallet-guide.md) - GUI pro správu přiřazení

---

[← Předchozí: Síťové parametry](6-network-parameters.md) | [Obsah](index.md) | [Další: Průvodce peněženkou →](8-wallet-guide.md)
