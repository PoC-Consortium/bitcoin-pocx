#!/bin/bash
# PoCX regtestv2: descriptor-wallet + imported-WIF mining test.
# Fresh regtest, mocktime-driven. Imports a static WIF private key and
# mines $BLOCKS blocks to its derived bech32 address.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtestv2-mining-legacy"
BLOCKS=${BLOCKS:-100}
WIF_KEY="cNgs3AUH8xu2faRgLBR5kT7mAB6tUJZDDRH5YeKtZw4LqhbapNWd"

echo "PoCX Regtestv2 Mining (Imported Key)"
echo "===================================="

pkill -9 bitcoind 2>/dev/null || true
sleep 1
rm -rf "$DATADIR"
mkdir -p "$DATADIR"

$BITCOIND -regtest -datadir="$DATADIR" -daemon >/dev/null
for i in 1 2 3 4 5; do
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

CLI="$BITCOIN_CLI -regtest -datadir=$DATADIR"

$CLI setmocktime "$(date +%s)" >/dev/null

# Blank descriptor wallet, positional args:
#   name, disable_private_keys, blank, passphrase, avoid_reuse, descriptors
$CLI createwallet test false true "" false true >/dev/null
echo "Created blank descriptor wallet"

# Import descriptor with private key
DESC_INFO=$($CLI getdescriptorinfo "wpkh($WIF_KEY)")
CHECKSUM=$(echo "$DESC_INFO" | jq -r '.checksum')
DESCRIPTOR_WITH_PRIVKEY="wpkh($WIF_KEY)#$CHECKSUM"
import_result=$($CLI -rpcwallet=test importdescriptors "[{\"desc\": \"$DESCRIPTOR_WITH_PRIVKEY\", \"timestamp\": \"now\"}]")
import_success=$(echo "$import_result" | jq -r '.[0].success')
if [ "$import_success" != "true" ]; then
    echo "ERROR: Import failed!"
    echo "$import_result" | jq '.'
    $CLI stop >/dev/null 2>&1 || true
    exit 1
fi
echo "Imported WIF private key"

# Derive address from pubkey descriptor
PUBKEY_DESCRIPTOR=$($CLI getdescriptorinfo "wpkh($WIF_KEY)" | jq -r '.descriptor')
address=$($CLI deriveaddresses "$PUBKEY_DESCRIPTOR" | jq -r '.[0]')
echo "Derived address: $address"

# Sanity: wallet sees this address as mine & solvable
info=$($CLI -rpcwallet=test getaddressinfo "$address")
is_mine=$(echo "$info" | jq -r '.ismine')
is_solvable=$(echo "$info" | jq -r '.solvable')
if [ "$is_mine" != "true" ] || [ "$is_solvable" != "true" ]; then
    echo "ERROR: wallet cannot sign for $address (ismine=$is_mine solvable=$is_solvable)"
    $CLI stop >/dev/null 2>&1 || true
    exit 1
fi
echo "ismine=true solvable=true"

echo ""
echo "Mining $BLOCKS blocks..."
start_ns=$(date +%s%N)
$CLI generatetoaddress "$BLOCKS" "$address" >/dev/null
end_ns=$(date +%s%N)
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
per_block_us=$(( (end_ns - start_ns) / 1000 / BLOCKS ))

HEIGHT=$($CLI getblockcount)
BALANCE=$($CLI -rpcwallet=test getbalances | jq -r '.mine.immature')
echo ""
echo "Results"
echo "======="
echo "Block count: $HEIGHT"
echo "Wallet immature: $BALANCE BTCX"
echo "Elapsed: ${elapsed_ms} ms   (${per_block_us} us/block)"

$CLI stop >/dev/null
sleep 1

if [ "$HEIGHT" != "$BLOCKS" ]; then
    echo "FAIL: expected height $BLOCKS, got $HEIGHT"
    exit 1
fi
echo ""
echo "PASS"
