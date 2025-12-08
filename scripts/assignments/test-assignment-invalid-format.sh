#!/bin/bash
# Invalid OP_RETURN Format Tests
# Tests that malformed assignment/revocation data is correctly ignored by PoCX parsing

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin/regtest-format-test"

# Load template functions
source scripts/setup-regtest-template.sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗ FAILED:${NC} $1"
    pkill -9 bitcoind 2>/dev/null || true
    exit 1
}

echo "=========================================="
echo "Invalid OP_RETURN Format Tests"
echo "=========================================="
echo "Tests PoCX parsing of malformed data"
echo ""

# Clean up any existing test environment
pkill -9 bitcoind 2>/dev/null || true
sleep 2

# Setup or verify template exists
setup_regtest_template

# Copy template to test datadir
copy_template_to_datadir "$DATADIR"

# Start bitcoind with template data
$BITCOIND -regtest -datadir="$DATADIR" -fallbackfee=0.00001 -daemon
sleep 5

# Load the template wallet
$BITCOIN_CLI -regtest -datadir="$DATADIR" loadwallet template >/dev/null
pass "Loaded template wallet"

# Get addresses
MINING_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress)
FORGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

echo ""
echo "=========================================="
echo "Test 1: Wrong Magic Bytes"
echo "=========================================="
echo ""

# Create and fund plot address
PLOT_ADDR1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR1" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR1\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 1 ] && break
    sleep 0.5
done
pass "Funded plot address"

# Get UTXO details
UTXO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR1\"]" | jq -r '.[0]')
UTXO_TXID=$(echo "$UTXO" | jq -r '.txid')
UTXO_VOUT=$(echo "$UTXO" | jq -r '.vout')

# Get change address
CHANGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawchangeaddress)

# Manually craft transaction with corrupted magic bytes (DEAD instead of POCX)
# PoCX OP_RETURN format: MAGIC(4) + TYPE(1) + PLOTID(32) + RESERVED(8)
# Valid: 504f4358 (POCX) + 00 + plotid(32) + reserved(8)
# Invalid: 44454144 (DEAD) + 00 + plotid(32) + reserved(8)
PLOT_ID="c081d70a692c2e8bdb5e57f2b8310a8fe421ad8bdb7c052401f28f5c44eaf5f0"
RESERVED="a30d89499f8000ca"
CORRUPTED_DATA="4445414400${PLOT_ID}${RESERVED}"

# Create raw transaction with corrupted OP_RETURN, forge output, and change
BAD_RAW=$($BITCOIN_CLI -regtest -datadir="$DATADIR" createrawtransaction "[{\"txid\":\"$UTXO_TXID\",\"vout\":$UTXO_VOUT}]" "[{\"data\":\"$CORRUPTED_DATA\"},{\"$FORGE_ADDR\":0.0001},{\"$CHANGE_ADDR\":0.9998}]")
BAD_SIGNED=$($BITCOIN_CLI -regtest -datadir="$DATADIR" signrawtransactionwithwallet "$BAD_RAW" | jq -r '.hex')
pass "Created transaction with corrupted magic bytes: DEAD"

# Broadcast corrupted version (Bitcoin will accept any OP_RETURN)
BAD_TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$BAD_SIGNED")
pass "Broadcasted corrupted transaction: ${BAD_TXID:0:16}..."

# Mine it
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Mined transaction into block"

# Check if assignment was created (it shouldn't be, or should remain UNASSIGNED)
set +e
STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR1" 2>&1)
STATE_EXIT=$?
set -e

if [ $STATE_EXIT -ne 0 ] || echo "$STATE" | grep -q "No assignment found"; then
    pass "PoCX correctly ignored transaction with wrong magic bytes"
else
    CURRENT_STATE=$(echo "$STATE" | jq -r '.state // "UNKNOWN"')
    if [ "$CURRENT_STATE" = "UNASSIGNED" ]; then
        pass "PoCX correctly ignored transaction (state remains UNASSIGNED)"
    else
        fail "PoCX incorrectly created assignment with state: $CURRENT_STATE"
    fi
fi

echo ""
echo "=========================================="
echo "Test 2: Truncated OP_RETURN"
echo "=========================================="
echo ""

# Create and fund plot address
PLOT_ADDR2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR2" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 1 ] && break
    sleep 0.5
done
pass "Funded plot address"

# Get UTXO details
UTXO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq -r '.[0]')
UTXO_TXID=$(echo "$UTXO" | jq -r '.txid')
UTXO_VOUT=$(echo "$UTXO" | jq -r '.vout')

# Get change address
CHANGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawchangeaddress)

# Manually craft transaction with truncated OP_RETURN (missing reserved bytes)
# Valid: 504f4358 (POCX) + 00 + plotid(32) + reserved(8) = 45 bytes
# Invalid: 504f4358 (POCX) + 00 + plotid(32) = 37 bytes (missing 8 byte reserved)
PLOT_ID="c081d70a692c2e8bdb5e57f2b8310a8fe421ad8bdb7c052401f28f5c44eaf5f0"
TRUNCATED_DATA="504f435800${PLOT_ID}"

# Create raw transaction with truncated OP_RETURN and change
BAD_RAW=$($BITCOIN_CLI -regtest -datadir="$DATADIR" createrawtransaction "[{\"txid\":\"$UTXO_TXID\",\"vout\":$UTXO_VOUT}]" "[{\"data\":\"$TRUNCATED_DATA\"},{\"$FORGE_ADDR\":0.0001},{\"$CHANGE_ADDR\":0.9998}]")
BAD_SIGNED=$($BITCOIN_CLI -regtest -datadir="$DATADIR" signrawtransactionwithwallet "$BAD_RAW" | jq -r '.hex')
pass "Created transaction with truncated OP_RETURN (37 bytes instead of 45)"

# Broadcast truncated version
BAD_TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$BAD_SIGNED")
pass "Broadcasted truncated transaction: ${BAD_TXID:0:16}..."

$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Mined transaction into block"

# Check if assignment was created
set +e
STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR2" 2>&1)
STATE_EXIT=$?
set -e

if [ $STATE_EXIT -ne 0 ] || echo "$STATE" | grep -q "No assignment found"; then
    pass "PoCX correctly ignored truncated OP_RETURN"
else
    CURRENT_STATE=$(echo "$STATE" | jq -r '.state // "UNKNOWN"')
    if [ "$CURRENT_STATE" = "UNASSIGNED" ]; then
        pass "PoCX correctly ignored truncated OP_RETURN (state remains UNASSIGNED)"
    else
        fail "PoCX incorrectly created assignment with state: $CURRENT_STATE"
    fi
fi

echo ""
echo "=========================================="
echo "Test 3: Assignment with Revocation Magic"
echo "=========================================="
echo ""

# Create and fund plot address
PLOT_ADDR3=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR3" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR3\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 1 ] && break
    sleep 0.5
done
pass "Funded plot address"

# Get UTXO details
UTXO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR3\"]" | jq -r '.[0]')
UTXO_TXID=$(echo "$UTXO" | jq -r '.txid')
UTXO_VOUT=$(echo "$UTXO" | jq -r '.vout')

# Get change address
CHANGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawchangeaddress)

# Manually craft transaction with revocation magic (XCOP instead of POCX)
# Valid assignment: 504f4358 (POCX) + 00 + plotid(32) + reserved(8)
# Invalid: 58434f50 (XCOP) + 00 + plotid(32) + reserved(8) - wrong magic for assignment
PLOT_ID="c081d70a692c2e8bdb5e57f2b8310a8fe421ad8bdb7c052401f28f5c44eaf5f0"
RESERVED="a30d89499f8000ca"
WRONG_MAGIC_DATA="58434f5000${PLOT_ID}${RESERVED}"

# Create raw transaction with wrong magic and change
BAD_RAW=$($BITCOIN_CLI -regtest -datadir="$DATADIR" createrawtransaction "[{\"txid\":\"$UTXO_TXID\",\"vout\":$UTXO_VOUT}]" "[{\"data\":\"$WRONG_MAGIC_DATA\"},{\"$FORGE_ADDR\":0.0001},{\"$CHANGE_ADDR\":0.9998}]")
BAD_SIGNED=$($BITCOIN_CLI -regtest -datadir="$DATADIR" signrawtransactionwithwallet "$BAD_RAW" | jq -r '.hex')
pass "Created transaction with revocation magic: XCOP"

# Broadcast corrupted version
BAD_TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$BAD_SIGNED")
pass "Broadcasted transaction with wrong magic: ${BAD_TXID:0:16}..."

$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Mined transaction into block"

# Check if assignment was created
set +e
STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR3" 2>&1)
STATE_EXIT=$?
set -e

if [ $STATE_EXIT -ne 0 ] || echo "$STATE" | grep -q "No assignment found"; then
    pass "PoCX correctly ignored assignment with revocation magic"
else
    CURRENT_STATE=$(echo "$STATE" | jq -r '.state // "UNKNOWN"')
    if [ "$CURRENT_STATE" = "UNASSIGNED" ]; then
        pass "PoCX correctly ignored assignment with revocation magic (state remains UNASSIGNED)"
    else
        fail "PoCX incorrectly created assignment with state: $CURRENT_STATE"
    fi
fi

echo ""
echo "=========================================="
echo "Test 4: Oversized OP_RETURN"
echo "=========================================="
echo ""

# Create and fund plot address
PLOT_ADDR4=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR4" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR4\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 1 ] && break
    sleep 0.5
done
pass "Funded plot address"

# Get UTXO details
UTXO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR4\"]" | jq -r '.[0]')
UTXO_TXID=$(echo "$UTXO" | jq -r '.txid')
UTXO_VOUT=$(echo "$UTXO" | jq -r '.vout')

# Get change address
CHANGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawchangeaddress)

# Manually craft transaction with oversized OP_RETURN (extra garbage bytes)
# Valid: 504f4358 (POCX) + 00 + plotid(32) + reserved(8) = 45 bytes
# Invalid: 504f4358 (POCX) + 00 + plotid(32) + reserved(8) + garbage(16) = 61 bytes
PLOT_ID="c081d70a692c2e8bdb5e57f2b8310a8fe421ad8bdb7c052401f28f5c44eaf5f0"
RESERVED="a30d89499f8000ca"
GARBAGE="deadbeefdeadbeefdeadbeefdeadbeef"
OVERSIZED_DATA="504f435800${PLOT_ID}${RESERVED}${GARBAGE}"

# Create raw transaction with oversized OP_RETURN and change
BAD_RAW=$($BITCOIN_CLI -regtest -datadir="$DATADIR" createrawtransaction "[{\"txid\":\"$UTXO_TXID\",\"vout\":$UTXO_VOUT}]" "[{\"data\":\"$OVERSIZED_DATA\"},{\"$FORGE_ADDR\":0.0001},{\"$CHANGE_ADDR\":0.9998}]")
BAD_SIGNED=$($BITCOIN_CLI -regtest -datadir="$DATADIR" signrawtransactionwithwallet "$BAD_RAW" | jq -r '.hex')
pass "Created transaction with oversized OP_RETURN (61 bytes instead of 45)"

# Try to broadcast (Bitcoin will accept it - any OP_RETURN is valid)
set +e
BAD_TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$BAD_SIGNED" 2>&1)
BROADCAST_EXIT=$?
set -e

if [ $BROADCAST_EXIT -ne 0 ]; then
    echo "Bitcoin rejected: $BAD_TXID"
    pass "Bitcoin rejected oversized OP_RETURN"
else
    pass "Broadcasted oversized transaction: ${BAD_TXID:0:16}..."

    $BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
    pass "Mined transaction into block"

    # Check if assignment was created
    set +e
    STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR4" 2>&1)
    STATE_EXIT=$?
    set -e

    if [ $STATE_EXIT -ne 0 ] || echo "$STATE" | grep -q "No assignment found"; then
        pass "PoCX correctly ignored oversized OP_RETURN"
    else
        CURRENT_STATE=$(echo "$STATE" | jq -r '.state // "UNKNOWN"')
        if [ "$CURRENT_STATE" = "UNASSIGNED" ]; then
            pass "PoCX correctly ignored oversized OP_RETURN (state remains UNASSIGNED)"
        else
            fail "PoCX incorrectly created assignment with state: $CURRENT_STATE"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "All format validation tests passed!"
echo "PoCX correctly ignores malformed assignment data."
echo ""

# Cleanup
$BITCOIN_CLI -regtest -datadir="$DATADIR" stop >/dev/null 2>&1 || true
sleep 2
pkill -9 bitcoind 2>/dev/null || true
pass "Stopped bitcoind"
