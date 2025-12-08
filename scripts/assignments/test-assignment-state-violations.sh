#!/bin/bash
# Complete State Machine Violation Test Suite
# Tests 2-layer defense: Mempool validation + Block consensus validation
#
# Coverage:
#   Assignment attempts in: ASSIGNING, ASSIGNED, REVOKING
#   Revocation attempts in: UNASSIGNED, ASSIGNING, REVOKING, REVOKED

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtest-template.sh"

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin/regtest"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; pkill -9 bitcoind 2>/dev/null || true; exit 1; }

echo "=========================================="
echo "Complete State Machine Violation Tests"
echo "=========================================="
echo "2-Layer Defense Architecture:"
echo "  Layer 1: Mempool validation"
echo "  Layer 2: Block consensus validation"
echo ""
echo "Test Coverage:"
echo "  Assignment attempts: ASSIGNING, ASSIGNED, REVOKING"
echo "  Revocation attempts: UNASSIGNED, ASSIGNING, REVOKING, REVOKED"
echo ""

cleanup() {
    echo ""
    echo "Stopping bitcoind..."
    pkill -9 bitcoind 2>/dev/null || true
    sleep 2
}
trap cleanup EXIT

pkill -9 bitcoind 2>/dev/null || true
sleep 2

setup_regtest_template
copy_template_to_datadir "$DATADIR"

echo "Starting bitcoind..."
$BITCOIND -regtest -datadir="$DATADIR" -fallbackfee=0.00001 -daemon
sleep 5

$BITCOIN_CLI -regtest -datadir="$DATADIR" loadwallet "template" >/dev/null
pass "Loaded template wallet"

MINING_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress)

# ============================================================================
# Test 1: Assignment Attempt in ASSIGNING State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 1: Assignment → ASSIGNING"
echo "=========================================="
echo ""

PLOT_ADDR1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR1B=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund with 2 UTXOs for both assignments
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR1" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR1\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done

HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR1" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR1\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 2 ] && break
    sleep 0.5
done
pass "Funded with 2 UTXOs"

# Create first assignment
OUTPUT1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR1" "$FORGE_ADDR1" 0.0001)
TXID1=$(echo "$OUTPUT1" | jq -r '.txid')
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
pass "First assignment created (txid: ${TXID1:0:16}...)"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR1" | jq -r '.state')
if [ "$STATE" != "ASSIGNING" ]; then
    fail "Expected ASSIGNING state, got $STATE"
fi
pass "Plot is in ASSIGNING state"

# Create second assignment (will be rejected)
set +e
OUTPUT2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR1" "$FORGE_ADDR1B" 0.0001 2>&1)
set -e
TXID2=$(echo "$OUTPUT2" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID2" ]; then
    fail "Failed to create second assignment transaction"
fi
HEX2=$(echo "$OUTPUT2" | jq -r '.hex')
pass "Second assignment transaction created"

# Test 1a: Mempool Layer
echo ""
echo "==> Test 1a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX2" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED assignment in ASSIGNING state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected assignment"

# Test 1b: Block Consensus Layer
echo ""
echo "==> Test 1b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX2\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid assignment"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid assignment"
fi

# ============================================================================
# Test 2: Assignment Attempt in ASSIGNED State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 2: Assignment → ASSIGNED"
echo "=========================================="
echo ""

PLOT_ADDR2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR2B=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund for assignment
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR2" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment"

# Create and activate assignment
$BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR2" "$FORGE_ADDR2" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Assignment activated"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR2" | jq -r '.state')
if [ "$STATE" != "ASSIGNED" ]; then
    fail "Expected ASSIGNED state, got $STATE"
fi
pass "Plot is in ASSIGNED state"

# Fund for second assignment attempt
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR2" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR2\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for second assignment attempt"

# Create second assignment (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR2" "$FORGE_ADDR2B" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create assignment transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Assignment transaction created"

# Test 2a: Mempool Layer
echo ""
echo "==> Test 2a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED assignment in ASSIGNED state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected assignment"

# Test 2b: Block Consensus Layer
echo ""
echo "==> Test 2b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid assignment"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid assignment"
fi

# ============================================================================
# Test 3: Assignment Attempt in REVOKING State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 3: Assignment → REVOKING"
echo "=========================================="
echo ""

PLOT_ADDR3=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR3=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR3B=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund for assignment
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR3" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR3\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment"

# Create and activate assignment
$BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR3" "$FORGE_ADDR3" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Assignment activated"

# Fund for revocation
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR3" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR3\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for revocation"

# Create revocation
$BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR3" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
pass "Revocation started"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR3" | jq -r '.state')
if [ "$STATE" != "REVOKING" ]; then
    fail "Expected REVOKING state, got $STATE"
fi
pass "Plot is in REVOKING state"

# Fund for assignment attempt
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR3" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR3\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment attempt"

# Create assignment (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR3" "$FORGE_ADDR3B" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create assignment transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Assignment transaction created"

# Test 3a: Mempool Layer
echo ""
echo "==> Test 3a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED assignment in REVOKING state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected assignment"

# Test 3b: Block Consensus Layer
echo ""
echo "==> Test 3b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid assignment"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid assignment"
fi

# ============================================================================
# Test 4: Revocation Attempt in UNASSIGNED State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 4: Revocation → UNASSIGNED"
echo "=========================================="
echo ""

PLOT_ADDR4=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR4" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR4\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded unassigned plot"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR4" | jq -r '.state')
if [ "$STATE" != "UNASSIGNED" ]; then
    fail "Expected UNASSIGNED state, got $STATE"
fi
pass "Plot is in UNASSIGNED state"

# Create revocation (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR4" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create revocation transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Revocation transaction created"

# Test 4a: Mempool Layer
echo ""
echo "==> Test 4a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED revocation in UNASSIGNED state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected revocation"

# Test 4b: Block Consensus Layer
echo ""
echo "==> Test 4b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid revocation"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid revocation"
fi

# ============================================================================
# Test 5: Revocation Attempt in ASSIGNING State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 5: Revocation → ASSIGNING"
echo "=========================================="
echo ""

PLOT_ADDR5=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR5=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund for assignment
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR5" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR5\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment"

# Create assignment
$BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR5" "$FORGE_ADDR5" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
pass "Assignment created"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR5" | jq -r '.state')
if [ "$STATE" != "ASSIGNING" ]; then
    fail "Expected ASSIGNING state, got $STATE"
fi
pass "Plot is in ASSIGNING state"

# Fund for revocation attempt
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR5" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR5\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for revocation attempt"

# Create revocation (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR5" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create revocation transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Revocation transaction created"

# Test 5a: Mempool Layer
echo ""
echo "==> Test 5a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED revocation in ASSIGNING state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected revocation"

# Test 5b: Block Consensus Layer
echo ""
echo "==> Test 5b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid revocation"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid revocation"
fi

# ============================================================================
# Test 6: Revocation Attempt in REVOKING State (Double Revocation)
# ============================================================================

echo ""
echo "=========================================="
echo "Test 6: Revocation → REVOKING"
echo "=========================================="
echo ""

PLOT_ADDR6=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR6=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund for assignment
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR6" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR6\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment"

# Create and activate assignment
$BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR6" "$FORGE_ADDR6" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Assignment activated"

# Fund for first revocation
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR6" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR6\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for first revocation"

# First revocation
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR6" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
pass "First revocation succeeded"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR6" | jq -r '.state')
if [ "$STATE" != "REVOKING" ]; then
    fail "Expected REVOKING state, got $STATE"
fi
pass "Plot is in REVOKING state"

# Fund for second revocation attempt
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR6" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR6\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for second revocation attempt (UTXOs: $UTXO_COUNT)"

# Create second revocation (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR6" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create second revocation transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Second revocation transaction created"

# Test 6a: Mempool Layer
echo ""
echo "==> Test 6a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED second revocation in REVOKING state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected second revocation"

# Test 6b: Block Consensus Layer
echo ""
echo "==> Test 6b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid revocation"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid revocation"
fi

# ============================================================================
# Test 7: Revocation Attempt in REVOKED State
# ============================================================================

echo ""
echo "=========================================="
echo "Test 7: Revocation → REVOKED"
echo "=========================================="
echo ""

PLOT_ADDR7=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
FORGE_ADDR7=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")

# Fund for assignment
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR7" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR7\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for assignment"

# Create and activate assignment
$BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR7" "$FORGE_ADDR7" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Assignment activated"

# Fund for revocation
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR7" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR7\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for revocation"

# Complete revocation (ASSIGNED → REVOKING → REVOKED)
# Need to mine revocation + wait 4 blocks for finalization
$BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR7" 0.0001 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 10 "$MINING_ADDR" >/dev/null
pass "Revocation completed"

STATE=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$PLOT_ADDR7" | jq -r '.state')
if [ "$STATE" != "REVOKED" ]; then
    fail "Expected REVOKED state, got $STATE"
fi
pass "Plot is in REVOKED state"

# Fund for second revocation attempt
HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
$BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR7" 1.0 >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress 1 "$MINING_ADDR" >/dev/null
$BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
for i in {1..10}; do
    UTXO_COUNT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" listunspent 1 9999999 "[\"$PLOT_ADDR7\"]" | jq 'length')
    [ "$UTXO_COUNT" -gt 0 ] && break
    sleep 0.5
done
pass "Funded for second revocation attempt"

# Create second revocation (will be rejected)
set +e
OUTPUT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR7" 0.0001 2>&1)
set -e
TXID=$(echo "$OUTPUT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -z "$TXID" ]; then
    fail "Failed to create revocation transaction"
fi
HEX=$(echo "$OUTPUT" | jq -r '.hex')
pass "Revocation transaction created"

# Test 7a: Mempool Layer
echo ""
echo "==> Test 7a: Mempool Layer"
set +e
MEMPOOL_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" sendrawtransaction "$HEX" 2>&1)
MEMPOOL_EXIT=$?
set -e

if [ $MEMPOOL_EXIT -eq 0 ]; then
    fail "Mempool ACCEPTED revocation in REVOKED state"
fi
echo "Mempool rejection: $MEMPOOL_RESULT"
pass "Mempool rejected revocation"

# Test 7b: Block Consensus Layer
echo ""
echo "==> Test 7b: Block Consensus Layer"
set +e
BLOCK_RESULT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" generateblock "$MINING_ADDR" "[\"$HEX\"]" 2>&1)
BLOCK_EXIT=$?
set -e

if [ $BLOCK_EXIT -eq 0 ]; then
    BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
    BLOCK_DATA=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblock "$BLOCKHASH" 2)
    TX_COUNT=$(echo "$BLOCK_DATA" | jq '.tx | length')
    if [ "$TX_COUNT" -ne 1 ]; then
        fail "Block included invalid transaction"
    fi
    pass "Block created but excluded invalid revocation"
else
    echo "Block rejection: $BLOCK_RESULT"
    pass "Block rejected invalid revocation"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ All 7 state machine violation tests passed!${NC}"
echo ""
echo "Coverage Summary:"
echo "  ✓ Test 1: Assignment → ASSIGNING (rejected)"
echo "  ✓ Test 2: Assignment → ASSIGNED (rejected)"
echo "  ✓ Test 3: Assignment → REVOKING (rejected)"
echo "  ✓ Test 4: Revocation → UNASSIGNED (rejected)"
echo "  ✓ Test 5: Revocation → ASSIGNING (rejected)"
echo "  ✓ Test 6: Revocation → REVOKING (rejected)"
echo "  ✓ Test 7: Revocation → REVOKED (rejected)"
echo ""
echo "2-Layer Defense Verified:"
echo "  ✓ Layer 1 (Mempool): Rejected all invalid state transitions"
echo "  ✓ Layer 2 (Block): Rejected or excluded all invalid transactions"
echo ""
