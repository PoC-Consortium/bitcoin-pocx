#!/bin/bash
# Test script for PoCX regtest mining with IMPORTED KEY
# Creates blank descriptor wallet and imports a specific wpkh key
# Mines 100 blocks to a single imported bech32 address
# Tests descriptor wallet with imported legacy keys

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtest"
BLOCKS=100

echo "PoCX Regtest Mining Test (Imported Key)"
echo "========================================"
echo ""

# Stop any running bitcoind
echo "Stopping any running bitcoind..."
pkill -9 bitcoind 2>/dev/null || true
sleep 2

# Clean regtest data
echo "Cleaning regtest data directory..."
rm -rf "$DATADIR"

# Start bitcoind
echo "Starting bitcoind..."
$BITCOIND -regtest -daemon
sleep 5

# Create blank descriptor wallet
echo "Creating blank descriptor wallet..."
$BITCOIN_CLI -regtest createwallet test false true "" false true >/dev/null
echo "✓ Blank descriptor wallet created"

# Import WIF private key into descriptor wallet
echo "Importing WIF private key..."
WIF_KEY="cNgs3AUH8xu2faRgLBR5kT7mAB6tUJZDDRH5YeKtZw4LqhbapNWd"

# Import descriptor with private key and correct checksum
echo "Importing descriptor with private key..."
DESCRIPTOR_WITH_PRIVKEY="wpkh($WIF_KEY)#kc7xf65p"
import_result=$($BITCOIN_CLI -regtest -rpcwallet=test importdescriptors "[{\"desc\": \"$DESCRIPTOR_WITH_PRIVKEY\", \"timestamp\": \"now\"}]")
import_success=$(echo "$import_result" | jq -r '.[0].success')
if [ "$import_success" != "true" ]; then
    echo "ERROR: Import failed!"
    echo "$import_result" | jq '.'
    exit 1
fi
echo "✓ Private key imported successfully"

# Derive the address from public key descriptor
echo "Deriving bech32 address..."
PUBKEY_DESCRIPTOR=$($BITCOIN_CLI -regtest getdescriptorinfo "wpkh($WIF_KEY)" | jq -r '.descriptor')
address=$($BITCOIN_CLI -regtest deriveaddresses "$PUBKEY_DESCRIPTOR" | jq -r '.[0]')
echo "Derived address: $address"

# Verify wallet has the private key (can sign)
echo ""
echo "Verifying private key import..."
wallet_addr_info=$($BITCOIN_CLI -regtest -rpcwallet=test getaddressinfo "$address")
is_mine=$(echo "$wallet_addr_info" | jq -r '.ismine')
is_solvable=$(echo "$wallet_addr_info" | jq -r '.solvable')
has_privkey=$(echo "$wallet_addr_info" | jq -r '.hasprivatekeys // false')
pubkey=$(echo "$wallet_addr_info" | jq -r '.pubkey')

echo "  Address: $address"
echo "  IsMine: $is_mine"
echo "  Solvable: $is_solvable"
echo "  HasPrivateKeys: $has_privkey"
echo "  PubKey: $pubkey"

if [ "$is_mine" != "true" ] || [ "$is_solvable" != "true" ]; then
    echo "ERROR: Wallet cannot sign for this address!"
    echo "  IsMine: $is_mine (should be true)"
    echo "  Solvable: $is_solvable (should be true)"
    exit 1
fi
echo "✓ Private key verified - wallet can sign (ismine=true, solvable=true)"
echo ""

echo "Mining to: $address"
echo "  (should start with 'tpocx1' for regtest bech32)"
echo ""

# Mine blocks
echo "Mining $BLOCKS blocks (starting at $(date +%H:%M:%S))..."
start_time=$(date +%s)

for i in $(seq 1 $BLOCKS); do
    $BITCOIN_CLI -regtest generatetoaddress 1 "$address" >/dev/null
    if [ $((i % 10)) -eq 0 ]; then
        echo "Block $i mined at $(date +%H:%M:%S)"
    fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

# Results
echo ""
echo "Results"
echo "======="
echo "Final block count: $($BITCOIN_CLI -regtest getblockcount)"
echo "Wallet balance: $($BITCOIN_CLI -regtest getbalance) BTCX"
echo "Time taken: ${elapsed} seconds"
echo "Average: $(echo "scale=2; $elapsed / $BLOCKS" | bc) seconds/block"
echo ""

# Verify descriptor wallet with imported key
wallet_info=$($BITCOIN_CLI -regtest -rpcwallet=test getwalletinfo)
is_descriptor=$(echo "$wallet_info" | grep -o '"descriptors": [^,]*' | grep -o '[^: ]*$')
echo "Wallet type verification:"
echo "  Descriptors enabled: $is_descriptor (descriptor wallet with imported key)"
echo "  Address type: bech32 (native SegWit)"
echo ""

# Stop bitcoind
echo "Stopping bitcoind..."
pkill -9 bitcoind 2>/dev/null || true

echo "Test complete!"
