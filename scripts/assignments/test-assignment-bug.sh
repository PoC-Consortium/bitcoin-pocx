#!/bin/bash
# Regression Test: Multiple Consecutive Assignments (Segfault Bug Fix)
#
# This test verifies that the segfault bug in forging assignment handling
# remains fixed. The bug caused daemon crashes when creating multiple
# consecutive assignments to the same forge address.
#
# Historical Context:
# - Bug: Creating 2+ assignments caused GetForgingAssignment() to read
#   stale memory, triggering segfault on assignment #2
# - Root Cause: GetForgingAssignment() only queried LevelDB base layer,
#   never checking the cache for recent assignments
# - Fix: Implemented proper cache layer with duplicate detection
#
# This regression test ensures the fix remains stable.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin/regtest-bugfix-test"

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
echo "Regression Test: Segfault Bug Fix"
echo "=========================================="
echo "Verifying multiple consecutive assignments"
echo "work correctly (bug #2025-01 - FIXED)"
echo ""

# Clean up any existing test environment
pkill -9 bitcoind 2>/dev/null || true
sleep 2

# Setup or verify template exists
setup_regtest_template

# Copy template to test datadir
copy_template_to_datadir "$DATADIR"

# Start bitcoind with template data
echo "Starting bitcoind..."
$BITCOIND -regtest -datadir="$DATADIR" -fallbackfee=0.00001 -daemon
sleep 5

# Load the template wallet
$BITCOIN_CLI -regtest -datadir="$DATADIR" loadwallet template >/dev/null
pass "Loaded template wallet"

# Get mining address
MINING_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress)
echo "Mining address: $MINING_ADDR"

# Create forge address (all plots will assign to this single address)
FORGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
echo "Forge address: $FORGE_ADDR"
echo ""

echo "Creating 5 plot addresses..."
PLOT_ADDRS=()
for i in {1..5}; do
    addr=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
    PLOT_ADDRS+=("$addr")
    echo "  Plot $i: $addr"
done
echo ""

# Fund all 5 addresses using sendmany (single transaction - avoids chaining issues)
echo "Funding all 5 plot addresses with sendmany..."
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendmany "" "{\"${PLOT_ADDRS[0]}\":1.0,\"${PLOT_ADDRS[1]}\":1.0,\"${PLOT_ADDRS[2]}\":1.0,\"${PLOT_ADDRS[3]}\":1.0,\"${PLOT_ADDRS[4]}\":1.0}" >/dev/null

HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

# Wait for wallet to process all UTXOs
for i in {1..20}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"${PLOT_ADDRS[0]}\",\"${PLOT_ADDRS[1]}\",\"${PLOT_ADDRS[2]}\",\"${PLOT_ADDRS[3]}\",\"${PLOT_ADDRS[4]}\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 5 ] && break
    sleep 0.5
done

UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"${PLOT_ADDRS[0]}\",\"${PLOT_ADDRS[1]}\",\"${PLOT_ADDRS[2]}\",\"${PLOT_ADDRS[3]}\",\"${PLOT_ADDRS[4]}\"]" | jq 'length')
if [ "$UTXO_COUNT" -ne 5 ]; then
    fail "Expected 5 UTXOs for funding, got $UTXO_COUNT"
fi
pass "Funded all 5 plot addresses (5 UTXOs confirmed)"

BALANCE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getbalance)
echo "Wallet balance: $BALANCE BTCX"
echo ""

# Now create 5 consecutive assignments to the same forge address
# This scenario previously triggered the segfault bug on assignment #2
echo "=========================================="
echo "Creating 5 Consecutive Assignments"
echo "=========================================="
echo "All assigning to same forge address: $FORGE_ADDR"
echo ""

ASSIGNMENT_TXIDS=()
for i in "${!PLOT_ADDRS[@]}"; do
    num=$((i + 1))
    addr="${PLOT_ADDRS[$i]}"

    echo "Assignment $num: $addr -> $FORGE_ADDR"

    # Create assignment
    if RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$addr" "$FORGE_ADDR" 0.0001 2>&1); then
        TXID=$(echo "$RESULT" | jq -r '.txid')
        ASSIGNMENT_TXIDS+=("$TXID")
        pass "Assignment $num succeeded (txid: ${TXID:0:16}...)"

        # Verify it's in mempool
        if ! $BITCOIN_CLI -regtest -datadir="$DATADIR" getmempoolentry "$TXID" >/dev/null 2>&1; then
            fail "Assignment $num not in mempool"
        fi
    else
        # Check if bitcoind crashed
        if ! pgrep bitcoind >/dev/null; then
            echo ""
            echo -e "${RED}💥 DAEMON CRASHED${NC}"
            echo -e "${RED}BUG REGRESSION DETECTED!${NC}"
            echo ""
            echo "The segfault bug has returned. Assignment #$num caused a crash."
            echo "This indicates a regression in the cache layer implementation."
            exit 1
        fi

        fail "Assignment $num failed but daemon still running"
    fi

    echo ""
done

echo "=========================================="
echo "✓ All 5 assignments succeeded"
echo "=========================================="
echo ""

# Mine all assignments into a block
echo "Mining all assignments into block..."
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
pass "All assignments mined into block $((HEIGHT + 1))"

# Verify assignments are on-chain
echo ""
echo "Verifying assignments are confirmed..."
for i in "${!ASSIGNMENT_TXIDS[@]}"; do
    num=$((i + 1))
    TXID="${ASSIGNMENT_TXIDS[$i]}"

    # Should NOT be in mempool anymore
    if $BITCOIN_CLI -regtest -datadir="$DATADIR" getmempoolentry "$TXID" >/dev/null 2>&1; then
        fail "Assignment $num still in mempool after mining"
    fi

    # Should be in blockchain
    if ! TX_INFO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" gettransaction "$TXID" 2>&1); then
        fail "Assignment $num not found in blockchain"
    fi

    CONFIRMATIONS=$(echo "$TX_INFO" | jq -r '.confirmations')
    if [ "$CONFIRMATIONS" -lt 1 ]; then
        fail "Assignment $num has 0 confirmations"
    fi

    pass "Assignment $num confirmed (${CONFIRMATIONS} confirmations)"
done

# Verify final state with get_assignment
echo ""
echo "Verifying final state with get_assignment..."
for i in "${!PLOT_ADDRS[@]}"; do
    num=$((i + 1))
    addr="${PLOT_ADDRS[$i]}"

    INFO=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$addr")
    STATE=$(echo "$INFO" | jq -r '.state')
    FORGE_CHECK=$(echo "$INFO" | jq -r '.forging_address // empty')

    # Accept both ASSIGNING and ASSIGNED states (assignment needs 30 blocks to activate)
    if [ "$STATE" != "ASSIGNING" ] && [ "$STATE" != "ASSIGNED" ]; then
        fail "Plot $num state is '$STATE', expected 'ASSIGNING' or 'ASSIGNED'"
    fi

    if [ "$FORGE_CHECK" != "$FORGE_ADDR" ]; then
        fail "Plot $num forge address mismatch"
    fi

    pass "Plot $num: state=$STATE, forge=$FORGE_CHECK"
done

# Show final state summary
echo ""
echo "=========================================="
echo "Final State Summary"
echo "=========================================="
FINAL_HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
FINAL_BALANCE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getbalance)
echo "Block height: $FINAL_HEIGHT"
echo "Wallet balance: $FINAL_BALANCE BTCX"
echo "Assignments created: 5"
echo "Assignments confirmed: 5"
echo "Forge address: $FORGE_ADDR"
echo ""

# Stop bitcoind
echo "Stopping bitcoind..."
$BITCOIN_CLI -regtest -datadir="$DATADIR" stop >/dev/null 2>&1 || true
sleep 3
pkill -9 bitcoind 2>/dev/null || true

echo ""
echo -e "${GREEN}=========================================="
echo "✓ REGRESSION TEST PASSED"
echo "==========================================${NC}"
echo ""
echo "The segfault bug remains fixed. Multiple"
echo "consecutive assignments work correctly."
echo ""
