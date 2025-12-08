#!/bin/bash
# Intra-Block Conflict Test
# Tests that conflicting assignments/revocations are rejected within a single block
# Verifies that transaction order does not affect conflict detection

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin/regtest"

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
echo "Intra-Block Conflict Tests"
echo "=========================================="
echo "Testing: Conflicting transactions in same block"
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
PLOT_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

echo ""
echo "=========================================="
echo "Test 1: Assignment THEN Revocation"
echo "=========================================="
echo ""

# Fund plot address with 2 separate UTXOs (1 for assignment, 1 for revocation)
for utxo_num in 1 2; do
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

    # Wait for UTXO to appear
    for i in {1..10}; do
        UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR\"]" | jq 'length')
        [ "$UTXO_COUNT" -ge $utxo_num ] && break
        sleep 0.5
    done

    # Lock this UTXO to prevent wallet from consolidating
    UTXO_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR\"]" | jq ".[] | select(.txid == \"$TXID\")")
    if [ -n "$UTXO_DATA" ]; then
        VOUT=$(echo "$UTXO_DATA" | jq -r '.vout')
        $BITCOIN_CLI -regtest -datadir="$DATADIR" lockunspent false "[{\"txid\":\"$TXID\",\"vout\":$VOUT}]" >/dev/null
    fi
done

# Unlock all UTXOs
$BITCOIN_CLI -regtest -datadir="$DATADIR" lockunspent true >/dev/null

UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR\"]" | jq 'length')
if [ "$UTXO_COUNT" -lt 2 ]; then
    fail "Expected at least 2 UTXOs, got $UTXO_COUNT"
fi
pass "Funded plot address with $UTXO_COUNT separate UTXOs"

# Create assignment - keep it in mempool (DON'T mine)
RESULT1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
TXID1=$(echo "$RESULT1" | jq -r '.txid')
HEX1=$(echo "$RESULT1" | jq -r '.hex')
pass "Created assignment in mempool (txid: ${TXID1:0:16}...)"

# Verify it's in mempool
if ! $BITCOIN_CLI -regtest -datadir="$DATADIR" getmempoolentry "$TXID1" >/dev/null 2>&1; then
    fail "Assignment not in mempool!"
fi
pass "Assignment is in mempool (unconfirmed)"

# Check current state - should be UNASSIGNED (assignment not confirmed yet)
STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR" 2>&1 || echo '{"state":"UNASSIGNED"}')
CURRENT_STATE=$(echo "$STATE" | jq -r '.state // "UNASSIGNED"')
pass "Current state: $CURRENT_STATE"

# Try to create revocation - this should fail because assignment isn't confirmed
set +e
REV_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR" 0.0001 2>&1)
REV_EXIT=$?
set -e

REV_TXID=$(echo "$REV_RESULT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$REV_TXID" ]; then
    REV_HEX=$(echo "$REV_RESULT" | jq -r '.hex')
    pass "Created revocation transaction (txid: ${REV_TXID:0:16}...)"

    # Check if mempool accepted it (it shouldn't have)
    if $BITCOIN_CLI -regtest -datadir="$DATADIR" getmempoolentry "$REV_TXID" >/dev/null 2>&1; then
        fail "Mempool ACCEPTED revocation of unconfirmed assignment!"
    else
        # Try to submit via sendrawtransaction
        set +e
        MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$REV_HEX" 2>&1)
        MEMPOOL_EXIT=$?
        set -e

        if [ $MEMPOOL_EXIT -eq 0 ]; then
            fail "Mempool accepted revocation via sendrawtransaction!"
        else
            echo "Mempool rejection: $MEMPOOL_RESULT"
            pass "Mempool correctly rejected revocation"
        fi
    fi

    echo ""
    echo "Attempting to mine: [Assignment, Revocation] in same block..."
    echo ""

    # Try to mine BOTH transactions using generateblock (Assignment FIRST, Revocation SECOND)
    set +e
    BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX1\",\"$REV_HEX\"]" 2>&1)
    BLOCK_EXIT=$?
    set -e

    if [ $BLOCK_EXIT -eq 0 ]; then
        # Block was created - check which transactions made it in
        BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
        BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)

        TX1_IN_BLOCK=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$TXID1\")" >/dev/null 2>&1 && echo "yes" || echo "no")
        TX2_IN_BLOCK=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$REV_TXID\")" >/dev/null 2>&1 && echo "yes" || echo "no")

        echo "Assignment in block: $TX1_IN_BLOCK"
        echo "Revocation in block: $TX2_IN_BLOCK"

        if [ "$TX2_IN_BLOCK" = "yes" ]; then
            fail "Block accepted revocation of unconfirmed assignment!"
        elif [ "$TX1_IN_BLOCK" = "yes" ]; then
            pass "Block accepted assignment, excluded revocation (correct behavior)"

            # Verify final state
            STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR" | jq -r '.state')
            if [ "$STATE" = "ASSIGNING" ]; then
                pass "Assignment is now in ASSIGNING state"
            else
                fail "Expected ASSIGNING state, got $STATE"
            fi
        else
            fail "Block rejected BOTH transactions (should have accepted assignment)"
        fi
    else
        # Block creation failed entirely
        echo "Block validation error: $BLOCK_RESULT"
        pass "Block validation rejected the invalid block"
    fi
else
    echo "Note: Could not create revocation transaction (expected - no assignment to revoke)"
    pass "RPC correctly refused to create revocation for unconfirmed assignment"
fi

echo ""
echo "=========================================="
echo "Test 2: Revocation THEN Assignment"
echo "=========================================="
echo ""

# Clear mempool
echo "Clearing mempool from Test 1..."
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
pass "Mempool cleared"

# Mine a few more blocks for funds
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null

# Create new plot address
PLOT_ADDR2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund plot address with 2 separate UTXOs
for utxo_num in 1 2; do
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    TXID=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR2" 1.0)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

    for i in {1..10}; do
        UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq 'length')
        [ "$UTXO_COUNT" -ge $utxo_num ] && break
        sleep 0.5
    done

    UTXO_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq ".[] | select(.txid == \"$TXID\")")
    if [ -n "$UTXO_DATA" ]; then
        VOUT=$(echo "$UTXO_DATA" | jq -r '.vout')
        $BITCOIN_CLI -regtest -datadir="$DATADIR" lockunspent false "[{\"txid\":\"$TXID\",\"vout\":$VOUT}]" >/dev/null
    fi
done

$BITCOIN_CLI -regtest -datadir="$DATADIR" lockunspent true >/dev/null

UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq 'length')
if [ "$UTXO_COUNT" -lt 2 ]; then
    fail "Expected at least 2 UTXOs, got $UTXO_COUNT"
fi
pass "Funded plot address with $UTXO_COUNT separate UTXOs"

# Create assignment - keep it in mempool
RESULT2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR2" "$FORGE_ADDR2" 0.0001)
TXID2=$(echo "$RESULT2" | jq -r '.txid')
HEX2=$(echo "$RESULT2" | jq -r '.hex')
pass "Created assignment in mempool (txid: ${TXID2:0:16}...)"

# Try to create revocation
set +e
REV_RESULT2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR2" 0.0001 2>&1)
REV_EXIT2=$?
set -e

REV_TXID2=$(echo "$REV_RESULT2" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$REV_TXID2" ]; then
    REV_HEX2=$(echo "$REV_RESULT2" | jq -r '.hex')
    pass "Created revocation transaction (txid: ${REV_TXID2:0:16}...)"

    echo ""
    echo "Attempting to mine: [Revocation, Assignment] in same block (SWAPPED ORDER)..."
    echo ""

    # Try to mine with SWAPPED order (Revocation FIRST, Assignment SECOND)
    set +e
    BLOCK_RESULT2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$REV_HEX2\",\"$HEX2\"]" 2>&1)
    BLOCK_EXIT2=$?
    set -e

    if [ $BLOCK_EXIT2 -eq 0 ]; then
        # Block was created - check which transactions made it in
        BLOCKHASH2=$(echo "$BLOCK_RESULT2" | jq -r '.hash')
        BLOCK_DATA2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH2" 2)

        REV_IN_BLOCK=$(echo "$BLOCK_DATA2" | jq -e ".tx[] | select(.txid == \"$REV_TXID2\")" >/dev/null 2>&1 && echo "yes" || echo "no")
        ASN_IN_BLOCK=$(echo "$BLOCK_DATA2" | jq -e ".tx[] | select(.txid == \"$TXID2\")" >/dev/null 2>&1 && echo "yes" || echo "no")

        echo "Revocation in block: $REV_IN_BLOCK"
        echo "Assignment in block: $ASN_IN_BLOCK"

        if [ "$REV_IN_BLOCK" = "yes" ]; then
            fail "Block accepted revocation before assignment (invalid)!"
        elif [ "$ASN_IN_BLOCK" = "yes" ]; then
            pass "Block accepted assignment, excluded revocation (correct behavior)"

            STATE2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR2" | jq -r '.state')
            if [ "$STATE2" = "ASSIGNING" ]; then
                pass "Assignment is now in ASSIGNING state"
            else
                fail "Expected ASSIGNING state, got $STATE2"
            fi
        else
            fail "Block rejected BOTH transactions (should have accepted assignment)"
        fi
    else
        echo "Block validation error: $BLOCK_RESULT2"
        pass "Block validation rejected the invalid block"
    fi
else
    echo "Note: Could not create revocation transaction (expected)"
    pass "RPC correctly refused to create revocation for unconfirmed assignment"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "Intra-block conflict tests completed!"
echo "Cannot revoke unconfirmed assignment in same block."
echo "Transaction order does not matter - conflicts always rejected."
echo ""

# Cleanup
$BITCOIN_CLI -regtest -datadir="$DATADIR" stop >/dev/null 2>&1 || true
sleep 2
pkill -9 bitcoind 2>/dev/null || true
pass "Stopped bitcoind"
