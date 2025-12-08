#!/bin/bash
# Test script for PoCX regtest mining
# Mines 100 blocks and reports performance

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtest"
BLOCKS=100

echo "PoCX Regtest Mining Test"
echo "========================"
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

# Create wallet
echo "Creating test wallet..."
$BITCOIN_CLI -regtest createwallet test >/dev/null

# Get mining address
echo "Generating mining address..."
address=$($BITCOIN_CLI -regtest getnewaddress)
echo "Mining to: $address"
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
echo "Time taken: ${elapsed} seconds"
echo "Average: $(echo "scale=2; $elapsed / $BLOCKS" | bc) seconds/block"
echo ""

# Stop bitcoind
echo "Stopping bitcoind..."
pkill -9 bitcoind 2>/dev/null || true

echo "Test complete!"
