[← Previous: Network Parameters](6-network-parameters.md) | [📘 Table of Contents](index.md) | [Next: Wallet Guide →](8-wallet-guide.md)

---

# Chapter 7: RPC Interface Reference

Complete reference for Bitcoin-PoCX RPC commands, including mining RPCs, assignment management, and modified blockchain RPCs.

---

## Table of Contents

1. [Configuration](#configuration)
2. [PoCX Mining RPCs](#pocx-mining-rpcs)
3. [Assignment RPCs](#assignment-rpcs)
4. [Modified Blockchain RPCs](#modified-blockchain-rpcs)
5. [Disabled RPCs](#disabled-rpcs)
6. [Integration Examples](#integration-examples)

---

## Configuration

### Mining Server Mode

**Flag**: `-miningserver`

**Purpose**: Enables RPC access for external miners to call mining-specific RPCs

**Requirements**:
- Required for `submit_nonce` to function
- Required for visibility of forging assignment dialog in Qt wallet

**Usage**:
```bash
# Command line
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Security Considerations**:
- No additional authentication beyond standard RPC credentials
- Mining RPCs are rate-limited by queue capacity
- Standard RPC authentication still required

**Implementation**: `src/pocx/rpc/mining.cpp`

---

## PoCX Mining RPCs

### get_mining_info

**Category**: mining
**Requires Mining Server**: No
**Requires Wallet**: No

**Purpose**: Returns current mining parameters needed for external miners to scan plot files and calculate deadlines.

**Parameters**: None

**Return Values**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 characters
  "base_target": 36650387593,                // numeric
  "height": 12345,                           // numeric, next block height
  "block_hash": "def456...",                 // hex, previous block
  "target_quality": 18446744073709551615,    // uint64_max (all solutions accepted)
  "minimum_compression_level": 1,            // numeric
  "target_compression_level": 2              // numeric
}
```

**Field Descriptions**:
- `generation_signature`: Deterministic mining entropy for this block height
- `base_target`: Current difficulty (higher = easier)
- `height`: Block height miners should target
- `block_hash`: Previous block hash (informational)
- `target_quality`: Quality threshold (currently uint64_max, no filtering)
- `minimum_compression_level`: Minimum compression required for validation
- `target_compression_level`: Recommended compression for optimal mining

**Error Codes**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Node still syncing

**Example**:
```bash
bitcoin-cli get_mining_info
```

**Implementation**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Category**: mining
**Requires Mining Server**: Yes
**Requires Wallet**: Yes (for private keys)

**Purpose**: Submit a PoCX mining solution. Validates proof, queues for time-bended forging, and automatically creates block at scheduled time.

**Parameters**:
1. `height` (numeric, required) - Block height
2. `generation_signature` (string hex, required) - Generation signature (64 characters)
3. `account_id` (string, required) - Plot account ID (40 hex characters = 20 bytes)
4. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
5. `nonce` (numeric, required) - Mining nonce
6. `compression` (numeric, required) - Scaling/compression level used (1-255)
7. `quality` (numeric, optional) - Quality value (recalculated if omitted)

**Return Values** (success):
```json
{
  "accepted": true,
  "quality": 120,           // difficulty-adjusted deadline in seconds
  "poc_time": 45            // time-bended forge time in seconds
}
```

**Return Values** (rejected):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**Validation Steps**:
1. **Format Validation** (fail-fast):
   - Account ID: exactly 40 hex characters
   - Seed: exactly 64 hex characters
2. **Context Validation**:
   - Height must match current tip + 1
   - Generation signature must match current
3. **Wallet Verification**:
   - Determine effective signer (check for active assignments)
   - Verify wallet has private key for effective signer
4. **Proof Validation** (expensive):
   - Validate PoCX proof with compression bounds
   - Calculate raw quality
5. **Scheduler Submission**:
   - Queue nonce for time-bended forging
   - Block will be created automatically at forge_time

**Error Codes**:
- `RPC_INVALID_PARAMETER`: Invalid format (account_id, seed) or height mismatch
- `RPC_VERIFY_REJECTED`: Generation signature mismatch or proof validation failed
- `RPC_INVALID_ADDRESS_OR_KEY`: No private key for effective signer
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Submission queue full
- `RPC_INTERNAL_ERROR`: Failed to initialize PoCX scheduler

**Proof Validation Error Codes**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Example**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**Notes**:
- Submission is asynchronous - RPC returns immediately, block forged later
- Time Bending delays good solutions to allow network-wide plot scanning
- Assignment system: if plot assigned, wallet must have forging address key
- Compression bounds dynamically adjusted based on block height

**Implementation**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## Assignment RPCs

### get_assignment

**Category**: mining
**Requires Mining Server**: No
**Requires Wallet**: No

**Purpose**: Query forging assignment status for a plot address. Read-only, no wallet required.

**Parameters**:
1. `plot_address` (string, required) - Plot address (bech32 P2WPKH format)
2. `height` (numeric, optional) - Block height to query (default: current tip)

**Return Values** (no assignment):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Return Values** (active assignment):
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

**Return Values** (revoking):
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

**Assignment States**:
- `UNASSIGNED`: No assignment exists
- `ASSIGNING`: Assignment tx confirmed, activation delay in progress
- `ASSIGNED`: Assignment active, forging rights delegated
- `REVOKING`: Revocation tx confirmed, still active until delay elapses
- `REVOKED`: Revocation complete, forging rights returned to plot owner

**Error Codes**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Invalid address or not P2WPKH (bech32)

**Example**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementation**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Category**: wallet
**Requires Mining Server**: No
**Requires Wallet**: Yes (must be loaded and unlocked)

**Purpose**: Create forging assignment transaction to delegate forging rights to another address (e.g., mining pool).

**Parameters**:
1. `plot_address` (string, required) - Plot owner address (must own private key, P2WPKH bech32)
2. `forging_address` (string, required) - Address to assign forging rights to (P2WPKH bech32)
3. `fee_rate` (numeric, optional) - Fee rate in BTC/kvB (default: 10× minRelayFee)

**Return Values**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Requirements**:
- Wallet loaded and unlocked
- Private key for plot_address in wallet
- Both addresses must be P2WPKH (bech32 format: pocx1q... mainnet, tpocx1q... testnet)
- Plot address must have confirmed UTXOs (proves ownership)
- Plot must not have active assignment (use revoke first)

**Transaction Structure**:
- Input: UTXO from plot address (proves ownership)
- Output: OP_RETURN (46 bytes): `POCX` marker + plot_address (20 bytes) + forging_address (20 bytes)
- Output: Change returned to wallet

**Activation**:
- Assignment becomes ASSIGNING at confirmation
- Becomes ACTIVE after `nForgingAssignmentDelay` blocks
- Delay prevents rapid reassignment during chain forks

**Error Codes**:
- `RPC_WALLET_NOT_FOUND`: No wallet available
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet encrypted and locked
- `RPC_WALLET_ERROR`: Transaction creation failed
- `RPC_INVALID_ADDRESS_OR_KEY`: Invalid address format

**Example**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementation**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Category**: wallet
**Requires Mining Server**: No
**Requires Wallet**: Yes (must be loaded and unlocked)

**Purpose**: Revoke existing forging assignment, returning forging rights to plot owner.

**Parameters**:
1. `plot_address` (string, required) - Plot address (must own private key, P2WPKH bech32)
2. `fee_rate` (numeric, optional) - Fee rate in BTC/kvB (default: 10× minRelayFee)

**Return Values**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Requirements**:
- Wallet loaded and unlocked
- Private key for plot_address in wallet
- Plot address must be P2WPKH (bech32 format)
- Plot address must have confirmed UTXOs

**Transaction Structure**:
- Input: UTXO from plot address (proves ownership)
- Output: OP_RETURN (26 bytes): `XCOP` marker + plot_address (20 bytes)
- Output: Change returned to wallet

**Effect**:
- State transitions to REVOKING immediately
- Forging address can still forge during delay period
- Becomes REVOKED after `nForgingRevocationDelay` blocks
- Plot owner can forge after revocation effective
- Can create new assignment after revocation complete

**Error Codes**:
- `RPC_WALLET_NOT_FOUND`: No wallet available
- `RPC_WALLET_UNLOCK_NEEDED`: Wallet encrypted and locked
- `RPC_WALLET_ERROR`: Transaction creation failed

**Example**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Notes**:
- Idempotent: can revoke even if no active assignment
- Cannot cancel revocation once submitted

**Implementation**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Modified Blockchain RPCs

### getdifficulty

**PoCX Modifications**:
- **Calculation**: `reference_base_target / current_base_target`
- **Reference**: 1 TiB network capacity (base_target = 36650387593)
- **Interpretation**: Estimated network storage capacity in TiB
  - Example: `1.0` = ~1 TiB
  - Example: `1024.0` = ~1 PiB
- **Difference from PoW**: Represents capacity, not hash power

**Example**:
```bash
bitcoin-cli getdifficulty
# Returns: 2048.5 (network ~2 PiB)
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX Added Fields**:
- `time_since_last_block` (numeric) - Seconds since previous block (replaces mediantime)
- `poc_time` (numeric) - Time-bended forge time in seconds
- `base_target` (numeric) - PoCX difficulty base target
- `generation_signature` (string hex) - Generation signature
- `pocx_proof` (object):
  - `account_id` (string hex) - Plot account ID (20 bytes)
  - `seed` (string hex) - Plot seed (32 bytes)
  - `nonce` (numeric) - Mining nonce
  - `compression` (numeric) - Scaling level used
  - `quality` (numeric) - Claimed quality value
- `pubkey` (string hex) - Block signer's public key (33 bytes)
- `signer_address` (string) - Block signer's address
- `signature` (string hex) - Block signature (65 bytes)

**PoCX Removed Fields**:
- `mediantime` - Removed (replaced by time_since_last_block)

**Example**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX Modifications**: Same as getblockheader, plus full transaction data

**Example**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose with tx details
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX Added Fields**:
- `base_target` (numeric) - Current base target
- `generation_signature` (string hex) - Current generation signature

**PoCX Modified Fields**:
- `difficulty` - Uses PoCX calculation (capacity-based)

**PoCX Removed Fields**:
- `mediantime` - Removed

**Example**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementation**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX Added Fields**:
- `generation_signature` (string hex) - For pool mining
- `base_target` (numeric) - For pool mining

**PoCX Removed Fields**:
- `target` - Removed (PoW-specific)
- `noncerange` - Removed (PoW-specific)
- `bits` - Removed (PoW-specific)

**Notes**:
- Still includes full transaction data for block construction
- Used by pool servers for coordinated mining

**Example**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementation**: `src/rpc/mining.cpp`

---

## Disabled RPCs

The following PoW-specific RPCs are **disabled** in PoCX mode:

### getnetworkhashps
- **Reason**: Hash rate not applicable to Proof of Capacity
- **Alternative**: Use `getdifficulty` for network capacity estimate

### getmininginfo
- **Reason**: Returns PoW-specific information
- **Alternative**: Use `get_mining_info` (PoCX-specific)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Reason**: CPU mining not applicable to PoCX (requires pre-generated plots)
- **Alternative**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp` (RPCs return error when ENABLE_POCX defined)

---

## Integration Examples

### External Miner Integration

**Basic Mining Loop**:
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

# Mining loop
while True:
    # 1. Get mining parameters
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Scan plot files (external implementation)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Submit best solution
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"Solution accepted! Quality: {result['quality']}s, "
              f"Forge time: {result['poc_time']}s")

    # 4. Wait for next block
    time.sleep(10)  # Poll interval
```

---

### Pool Integration Pattern

**Pool Server Workflow**:
1. Miners create forging assignments to pool address
2. Pool runs wallet with forging address keys
3. Pool calls `get_mining_info` and distributes to miners
4. Miners submit solutions via pool (not directly to chain)
5. Pool validates and calls `submit_nonce` with pool's keys
6. Pool distributes rewards according to pool policy

**Assignment Management**:
```bash
# Miner creates assignment (from miner's wallet)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Wait for activation (30 blocks mainnet)

# Pool checks assignment status
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool can now submit nonces for this plot
# (pool wallet must have pocx1qpool... private key)
```

---

### Block Explorer Queries

**Querying PoCX Block Data**:
```bash
# Get latest block
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Get block details with PoCX proof
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extract PoCX-specific fields
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

**Detecting Assignment Transactions**:
```bash
# Scan transaction for OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Check for assignment marker (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Error Handling

### Common Error Patterns

**Height Mismatch**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**Solution**: Re-fetch mining info, chain moved forward

**Generation Signature Mismatch**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**Solution**: Re-fetch mining info, new block arrived

**No Private Key**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**Solution**: Import key for plot or forging address

**Assignment Activation Pending**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solution**: Wait for activation delay to elapse

---

## Code References

**Mining RPCs**: `src/pocx/rpc/mining.cpp`
**Assignment RPCs**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**Blockchain RPCs**: `src/rpc/blockchain.cpp`
**Proof Validation**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Assignment State**: `src/pocx/assignments/assignment_state.cpp`
**Transaction Creation**: `src/pocx/assignments/transactions.cpp`

---

## Cross-References

Related chapters:
- [Chapter 3: Consensus and Mining](3-consensus-and-mining.md) - Mining process details
- [Chapter 4: Forging Assignments](4-forging-assignments.md) - Assignment system architecture
- [Chapter 6: Network Parameters](6-network-parameters.md) - Assignment delay values
- [Chapter 8: Wallet Guide](8-wallet-guide.md) - GUI for assignment management

---

[← Previous: Network Parameters](6-network-parameters.md) | [📘 Table of Contents](index.md) | [Next: Wallet Guide →](8-wallet-guide.md)
