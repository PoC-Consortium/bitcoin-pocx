#!/bin/bash
# PoCX regtestv2: mining performance smoke test
# Fresh regtest, mocktime-driven, no template caching.
# Mines $BLOCKS blocks as a single generatetoaddress call and reports rate.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtestv2-mining"
BLOCKS=${BLOCKS:-100}

echo "PoCX Regtestv2 Mining Test"
echo "=========================="

pkill -9 bitcoind 2>/dev/null || true
sleep 1
rm -rf "$DATADIR"
mkdir -p "$DATADIR"

$BITCOIND -regtest -datadir="$DATADIR" -daemon >/dev/null
for i in 1 2 3 4 5; do
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

$BITCOIN_CLI -regtest -datadir="$DATADIR" setmocktime "$(date +%s)" >/dev/null

$BITCOIN_CLI -regtest -datadir="$DATADIR" createwallet test >/dev/null
address=$($BITCOIN_CLI -regtest -datadir="$DATADIR" -rpcwallet=test getnewaddress)
echo "Mining to: $address"

echo "Mining $BLOCKS blocks..."
start_ns=$(date +%s%N)
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress "$BLOCKS" "$address" >/dev/null
end_ns=$(date +%s%N)

elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
per_block_us=$(( (end_ns - start_ns) / 1000 / BLOCKS ))

HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
TIP=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getbestblockhash)

echo ""
echo "Results"
echo "======="
echo "Final block count: $HEIGHT"
echo "Tip: $TIP"
echo "Elapsed: ${elapsed_ms} ms ($((elapsed_ms / 1000)).${elapsed_ms: -3:3} s)"
echo "Per block: ${per_block_us} us"

$BITCOIN_CLI -regtest -datadir="$DATADIR" stop >/dev/null
sleep 1

if [ "$HEIGHT" != "$BLOCKS" ]; then
    echo "FAIL: expected height $BLOCKS, got $HEIGHT"
    exit 1
fi
echo ""
echo "PASS"
