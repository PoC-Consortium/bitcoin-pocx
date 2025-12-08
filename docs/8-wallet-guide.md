[← Previous: RPC Reference](7-rpc-reference.md) | [📘 Table of Contents](index.md)

---

# Chapter 8: Wallet and GUI User Guide

Complete guide to Bitcoin-PoCX Qt wallet and forging assignment management.

---

## Table of Contents

1. [Overview](#overview)
2. [Currency Units](#currency-units)
3. [Forging Assignment Dialog](#forging-assignment-dialog)
4. [Transaction History](#transaction-history)
5. [Address Requirements](#address-requirements)
6. [Mining Integration](#mining-integration)
7. [Troubleshooting](#troubleshooting)
8. [Security Best Practices](#security-best-practices)

---

## Overview

### Bitcoin-PoCX Wallet Features

The Bitcoin-PoCX Qt wallet (`bitcoin-qt`) provides:
- Standard Bitcoin Core wallet functionality (send, receive, transaction management)
- **Forging Assignment Manager**: GUI for creating/revoking plot assignments
- **Mining Server Mode**: `-miningserver` flag enables mining-related features
- **Transaction History**: Assignment and revocation transaction display

### Starting the Wallet

**Node Only** (no mining):
```bash
./build/bin/bitcoin-qt
```

**With Mining** (enables assignment dialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Command Line Alternative**:
```bash
./build/bin/bitcoind -miningserver
```

### Mining Requirements

**For Mining Operations**:
- `-miningserver` flag required
- Wallet with P2WPKH addresses and private keys
- External plotter (`pocx_plotter`) for plot generation
- External miner (`pocx_miner`) for mining

**For Pool Mining**:
- Create forging assignment to pool address
- Wallet not required on pool server (pool manages keys)

---

## Currency Units

### Unit Display

Bitcoin-PoCX uses **BTCX** currency unit (not BTC):

| Unit | Satoshis | Display |
|------|----------|---------|
| **BTCX** | 100,000,000 | 1.00000000 BTCX |
| **mBTCX** | 100,000 | 1,000.00 mBTCX |
| **µBTCX** | 100 | 1,000,000.00 µBTCX |
| **satoshi** | 1 | 100,000,000 sat |

**GUI Settings**: Preferences → Display → Unit

---

## Forging Assignment Dialog

### Accessing the Dialog

**Menu**: `Wallet → Forging Assignments`
**Toolbar**: Mining icon (visible only with `-miningserver` flag)
**Window Size**: 600×450 pixels

### Dialog Modes

#### Mode 1: Create Assignment

**Purpose**: Delegate forging rights to pool or another address while retaining plot ownership.

**Use Cases**:
- Pool mining (assign to pool address)
- Cold storage (mining key separate from plot ownership)
- Shared infrastructure (delegate to hot wallet)

**Requirements**:
- Plot address (P2WPKH bech32, must own private key)
- Forging address (P2WPKH bech32, different from plot address)
- Wallet unlocked (if encrypted)
- Plot address has confirmed UTXOs

**Steps**:
1. Select "Create Assignment" mode
2. Choose plot address from dropdown or enter manually
3. Enter forging address (pool or delegate)
4. Click "Send Assignment" (button enabled when inputs valid)
5. Transaction broadcast immediately
6. Assignment active after `nForgingAssignmentDelay` blocks:
   - Mainnet/Testnet: 30 blocks (~1 hour)
   - Regtest: 4 blocks (~4 seconds)

**Transaction Fee**: Default 10× `minRelayFee` (customizable)

**Transaction Structure**:
- Input: UTXO from plot address (proves ownership)
- OP_RETURN output: `POCX` marker + plot_address + forging_address (46 bytes)
- Change output: Returned to wallet

#### Mode 2: Revoke Assignment

**Purpose**: Cancel forging assignment and return rights to plot owner.

**Requirements**:
- Plot address (must own private key)
- Wallet unlocked (if encrypted)
- Plot address has confirmed UTXOs

**Steps**:
1. Select "Revoke Assignment" mode
2. Choose plot address
3. Click "Send Revocation"
4. Transaction broadcast immediately
5. Revocation effective after `nForgingRevocationDelay` blocks:
   - Mainnet/Testnet: 720 blocks (~24 hours)
   - Regtest: 8 blocks (~8 seconds)

**Effect**:
- Forging address can still forge during delay period
- Plot owner regains rights after revocation complete
- Can create new assignment afterward

**Transaction Structure**:
- Input: UTXO from plot address (proves ownership)
- OP_RETURN output: `XCOP` marker + plot_address (26 bytes)
- Change output: Returned to wallet

#### Mode 3: Check Assignment Status

**Purpose**: Query current assignment state for any plot address.

**Requirements**: None (read-only, no wallet needed)

**Steps**:
1. Select "Check Assignment Status" mode
2. Enter plot address
3. Click "Check Status"
4. Status box displays current state with details

**State Indicators** (color-coded):

**Gray - UNASSIGNED**
```
UNASSIGNED - No assignment exists
```

**Orange - ASSIGNING**
```
ASSIGNING - Assignment pending activation
Forging Address: bc1qforger...
Created at height: 12000
Activates at height: 12030 (5 blocks remaining)
```

**Green - ASSIGNED**
```
ASSIGNED - Active assignment
Forging Address: bc1qforger...
Created at height: 12000
Activated at height: 12030
```

**Red-Orange - REVOKING**
```
REVOKING - Revocation pending
Forging Address: bc1qforger... (still active)
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020 (50 blocks remaining)
```

**Red - REVOKED**
```
REVOKED - Assignment revoked
Previously assigned to: bc1qforger...
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020
```

---

## Transaction History

### Assignment Transaction Display

**Type**: "Assignment"
**Icon**: Mining icon (same as mined blocks)

**Address Column**: Plot address (address whose forging rights are being assigned)
**Amount Column**: Transaction fee (negative, outgoing transaction)
**Status Column**: Confirmation count (0-6+)

**Details** (when clicked):
- Transaction ID
- Plot address
- Forging address (parsed from OP_RETURN)
- Created at height
- Activation height
- Transaction fee
- Timestamp

### Revocation Transaction Display

**Type**: "Revocation"
**Icon**: Mining icon

**Address Column**: Plot address
**Amount Column**: Transaction fee (negative)
**Status Column**: Confirmation count

**Details** (when clicked):
- Transaction ID
- Plot address
- Revoked at height
- Revocation effective height
- Transaction fee
- Timestamp

### Transaction Filtering

**Available Filters**:
- "All" (default, includes assignments/revocations)
- Date range
- Amount range
- Search by address
- Search by transaction ID
- Search by label (if address labeled)

**Note**: Assignment/Revocation transactions currently appear under "All" filter. Dedicated type filter not yet implemented.

### Transaction Sorting

**Sort Order** (by type):
- Generated (type 0)
- Received (type 1-3)
- Assignment (type 4)
- Revocation (type 5)
- Sent (type 6+)

---

## Address Requirements

### P2WPKH (SegWit v0) Only

**Forging operations require**:
- Bech32 encoded addresses (starting with "bc1q" mainnet, "tpocx1q" testnet/regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) format
- 20-byte key hash

**NOT Supported**:
- P2PKH (legacy, starting with "1")
- P2SH (wrapped SegWit, starting with "3")
- P2TR (Taproot, starting with "bc1p")

**Rationale**: PoCX block signatures require specific witness v0 format for proof validation.

### Address Dropdown Filtering

**Plot Address ComboBox**:
- Automatically populated with wallet's receiving addresses
- Filters out non-P2WPKH addresses
- Shows format: "Label (address)" if labeled, otherwise just address
- First item: "-- Enter custom address --" for manual entry

**Manual Entry**:
- Validates format when entered
- Must be valid bech32 P2WPKH
- Button disabled if invalid format

### Validation Error Messages

**Dialog Errors**:
- "Plot address must be P2WPKH (bech32)"
- "Forging address must be P2WPKH (bech32)"
- "Invalid address format"
- "No coins available at the plot address. Cannot prove ownership."
- "Cannot create transactions with watch-only wallet"
- "Wallet not available"
- "Wallet locked" (from RPC)

---

## Mining Integration

### Setup Requirements

**Node Configuration**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Wallet Requirements**:
- P2WPKH addresses for plot ownership
- Private keys for mining (or forging address if using assignments)
- Confirmed UTXOs for transaction creation

**External Tools**:
- `pocx_plotter`: Generate plot files
- `pocx_miner`: Scan plots and submit nonces

### Workflow

#### Solo Mining

1. **Generate Plot Files**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **Start Node** with mining server:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configure Miner**:
   - Point to node RPC endpoint
   - Specify plot file directories
   - Configure account ID (from plot address)

4. **Start Mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **Monitor**:
   - Miner calls `get_mining_info` every block
   - Scans plots for best deadline
   - Calls `submit_nonce` when solution found
   - Node validates and forges block automatically

#### Pool Mining

1. **Generate Plot Files** (same as solo mining)

2. **Create Forging Assignment**:
   - Open Forging Assignment Dialog
   - Select plot address
   - Enter pool's forging address
   - Click "Send Assignment"
   - Wait for activation delay (30 blocks testnet)

3. **Configure Miner**:
   - Point to **pool** endpoint (not local node)
   - Pool handles `submit_nonce` to chain

4. **Pool Operation**:
   - Pool wallet has forging address private keys
   - Pool validates submissions from miners
   - Pool calls `submit_nonce` to blockchain
   - Pool distributes rewards per pool policy

### Coinbase Rewards

**No Assignment**:
- Coinbase pays plot owner address directly
- Check balance in plot address

**With Assignment**:
- Coinbase pays forging address
- Pool receives rewards
- Miner receives share from pool

**Reward Schedule**:
- Initial: 10 BTCX per block
- Halving: Every 1,050,000 blocks (~4 years)
- Schedule: 10 → 5 → 2.5 → 1.25 → ...

---

## Troubleshooting

### Common Issues

#### "Wallet does not have private key for plot address"

**Cause**: Wallet doesn't own the address
**Solution**:
- Import private key via `importprivkey` RPC
- Or use different plot address owned by wallet

#### "Assignment already exists for this plot"

**Cause**: Plot already assigned to another address
**Solution**:
1. Revoke existing assignment
2. Wait for revocation delay (720 blocks testnet)
3. Create new assignment

#### "Address format not supported"

**Cause**: Address not P2WPKH bech32
**Solution**:
- Use addresses starting with "bc1q" (mainnet) or "tpocx1q" (testnet)
- Generate new address if needed: `getnewaddress "" "bech32"`

#### "Transaction fee too low"

**Cause**: Network mempool congestion or fee too low for relay
**Solution**:
- Increase fee rate parameter
- Wait for mempool clearance

#### "Assignment not yet active"

**Cause**: Activation delay not yet elapsed
**Solution**:
- Check status: blocks remaining until activation
- Wait for delay period to complete

#### "No coins available at the plot address"

**Cause**: Plot address has no confirmed UTXOs
**Solution**:
1. Send funds to plot address
2. Wait for 1 confirmation
3. Retry assignment creation

#### "Cannot create transactions with watch-only wallet"

**Cause**: Wallet imported address without private key
**Solution**: Import full private key, not just address

#### "Forging Assignment tab not visible"

**Cause**: Node started without `-miningserver` flag
**Solution**: Restart with `bitcoin-qt -server -miningserver`

### Debug Steps

1. **Check Wallet Status**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verify Address Ownership**:
   ```bash
   bitcoin-cli getaddressinfo bc1qplot...
   # Check: "iswatchonly": false, "ismine": true
   ```

3. **Check Assignment Status**:
   ```bash
   bitcoin-cli get_assignment bc1qplot...
   ```

4. **View Recent Transactions**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Check Node Sync**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verify: blocks == headers (fully synced)
   ```

---

## Security Best Practices

### Plot Address Security

**Key Management**:
- Store plot address private keys securely
- Assignment transactions prove ownership via signature
- Only plot owner can create/revoke assignments

**Backup**:
- Backup wallet regularly (`dumpwallet` or `backupwallet`)
- Store wallet.dat in secure location
- Record recovery phrases if using HD wallet

### Forging Address Delegation

**Security Model**:
- Forging address receives block rewards
- Forging address can sign blocks (mining)
- Forging address **cannot** modify or revoke assignment
- Plot owner retains full control

**Use Cases**:
- **Hot Wallet Delegation**: Plot key in cold storage, forging key in hot wallet for mining
- **Pool Mining**: Delegate to pool, retain plot ownership
- **Shared Infrastructure**: Multiple miners, one forging address

### Network Time Synchronization

**Importance**:
- PoCX consensus requires accurate time
- Clock drift >10s triggers warning
- Clock drift >15s prevents mining

**Solution**:
- Keep system clock synchronized with NTP
- Monitor: `bitcoin-cli getnetworkinfo` for time offset warnings
- Use reliable NTP servers

### Assignment Delays

**Activation Delay** (30 blocks testnet):
- Prevents rapid reassignment during chain forks
- Allows network to reach consensus
- Cannot be bypassed

**Revocation Delay** (720 blocks testnet):
- Provides stability for mining pools
- Prevents assignment "griefing" attacks
- Forging address remains active during delay

### Wallet Encryption

**Enable Encryption**:
```bash
bitcoin-cli encryptwallet "your_passphrase"
```

**Unlock for Transactions**:
```bash
bitcoin-cli walletpassphrase "your_passphrase" 300
```

**Best Practices**:
- Use strong passphrase (20+ characters)
- Don't store passphrase in plain text
- Lock wallet after creating assignments

---

## Code References

**Forging Assignment Dialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaction Display**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaction Parsing**: `src/qt/transactionrecord.cpp`
**Wallet Integration**: `src/pocx/assignments/transactions.cpp`
**Assignment RPCs**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Main**: `src/qt/bitcoingui.cpp`

---

## Cross-References

Related chapters:
- [Chapter 3: Consensus and Mining](3-consensus-and-mining.md) - Mining process
- [Chapter 4: Forging Assignments](4-forging-assignments.md) - Assignment architecture
- [Chapter 6: Network Parameters](6-network-parameters.md) - Assignment delay values
- [Chapter 7: RPC Reference](7-rpc-reference.md) - RPC command details

---

[← Previous: RPC Reference](7-rpc-reference.md) | [📘 Table of Contents](index.md)
