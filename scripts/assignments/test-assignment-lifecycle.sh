#!/bin/bash
# Test script for forging assignment lifecycle with rollback testing
# Tests: UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED
# Then tests blockchain rollbacks (single-state and multi-state)

set -e

# Get script directory for sourcing setup-regtest-template.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtest-template.sh"

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin/regtest"

# Network parameters (regtest)
ASSIGNMENT_DELAY=4  # 4 blocks
REVOCATION_DELAY=8  # 8 blocks

# Block hash cache
declare -A BLOCK_HASHES

# Transaction IDs
ASSIGNMENT_TXID=""
REVOCATION_TXID=""

# Addresses
PLOT_ADDR=""
FORGE_ADDR=""
MINING_ADDR=""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

#
# Helper Functions
#

fail() {
    echo "  ✗ FAILED: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
}

pass() {
    echo "  ✓ $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

get_block_count() {
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount
}

get_block_hash() {
    local height=$1
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockhash "$height"
}

cache_block_hash() {
    local name=$1
    local height=$(get_block_count)
    local hash=$(get_block_hash "$height")
    BLOCK_HASHES[$name]=$hash
    echo "  📦 Cached $name: block $height (hash: ${hash:0:16}...)"
}

mine_blocks() {
    local count=$1
    local desc=$2
    if [ -n "$desc" ]; then
        echo "  ⛏️  Mining $count blocks ($desc)..."
    fi
    $BITCOIN_CLI -regtest -datadir="$DATADIR" generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

verify_assignment_status() {
    local plot=$1
    local expected_state=$2
    local expected_forge=$3

    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$plot" 2>/dev/null || echo "{}")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')

    if [ "$state" != "$expected_state" ]; then
        fail "Expected state '$expected_state', got '$state'"
    fi

    if [ -n "$expected_forge" ] && [ "$forge" != "$expected_forge" ]; then
        fail "Expected forge address '$expected_forge', got '$forge'"
    fi
}

verify_mempool_contains() {
    local txid=$1
    local mempool=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawmempool)
    if ! echo "$mempool" | jq -e ". | index(\"$txid\")" >/dev/null; then
        fail "Transaction $txid not found in mempool"
    fi
}

verify_mempool_empty() {
    local mempool=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getrawmempool)
    local count=$(echo "$mempool" | jq '. | length')
    if [ "$count" != "0" ]; then
        fail "Mempool not empty (contains $count transactions)"
    fi
}

verify_assignment_status_at_height() {
    local plot_addr=$1
    local expected_state=$2
    local expected_forge=$3
    local height=$4

    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" get_assignment "$plot_addr" "$height")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')

    if [ "$state" != "$expected_state" ]; then
        fail "At height $height: Expected state '$expected_state', got '$state'"
    fi

    if [ -n "$expected_forge" ] && [ "$forge" != "$expected_forge" ]; then
        fail "At height $height: Expected forge address '$expected_forge', got '$forge'"
    fi
}

get_block_height() {
    local block_hash=$1
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockheader "$block_hash" | jq -r '.height'
}

parse_assignment_opreturn() {
    local txid=$1

    # Use gettransaction for wallet transactions (works without txindex)
    local tx=$($BITCOIN_CLI -regtest -datadir="$DATADIR" gettransaction "$txid" 2>/dev/null || echo "")

    if [ -z "$tx" ] || [ "$tx" = "" ]; then
        echo ""
        return 1
    fi

    # Get the raw transaction hex
    local hex=$(echo "$tx" | jq -r '.hex')

    # Decode the transaction to extract first output scriptPubKey
    local decoded=$($BITCOIN_CLI -regtest -datadir="$DATADIR" decoderawtransaction "$hex" 2>/dev/null || echo "")
    local opreturn=$(echo "$decoded" | jq -r '.vout[0].scriptPubKey.hex')

    # OP_RETURN format: OP_RETURN + POCX (4 bytes) + plot (20 bytes) + forge (20 bytes)
    # Or for revocation: OP_RETURN + XCOP (4 bytes) + plot (20 bytes)
    echo "$opreturn"
}

invalidate_block() {
    local hash=$1
    local desc=$2
    echo "  ↩️  Invalidating block ${hash:0:16}... ($desc)"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" invalidateblock "$hash"
}

reconsider_block() {
    local hash=$1
    local desc=$2
    echo "  ↪️  Reconsidering block ${hash:0:16}... ($desc)"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" reconsiderblock "$hash"
}

#
# Phase 1: Setup & Initial State
#

phase1_setup() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Setup & Initial State"
    echo "=========================================="
    echo ""

    # Stop any running bitcoind
    echo "Stopping any running bitcoind..."
    pkill -9 bitcoind 2>/dev/null || true
    sleep 2

    # Setup or load regtest template (instant after first run)
    setup_regtest_template

    # Copy template to test datadir
    copy_template_to_datadir "$DATADIR"
    pass "Loaded regtest template (101 blocks)"

    # Start bitcoind with pre-mined chain
    echo "Starting bitcoind..."
    $BITCOIND -regtest -datadir="$DATADIR" -fallbackfee=0.00001 -daemon
    sleep 5
    pass "Started bitcoind"

    # Load template wallet
    $BITCOIN_CLI -regtest -datadir="$DATADIR" loadwallet "template" >/dev/null
    pass "Loaded template wallet"

    # Get mining address from template wallet
    MINING_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress)

    # Create addresses
    PLOT_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
    FORGE_ADDR=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
    echo "  Plot address:  $PLOT_ADDR"
    echo "  Forge address: $FORGE_ADDR"
    pass "Created addresses"

    # Fund plot address
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    pass "Funded plot address with 1.0 BTCX"

    cache_block_hash "UNASSIGNED"

    # Verify UNASSIGNED state
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Verified UNASSIGNED state"
    verify_mempool_empty
    pass "Verified mempool empty"
}

#
# Phase 2: Assignment Creation
#

phase2_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Assignment Creation"
    echo "=========================================="
    echo ""

    # Create assignment transaction
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
    ASSIGNMENT_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID"
    pass "Created assignment transaction"

    # Verify transaction in mempool
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Verified assignment in mempool"

    # Mine block to include assignment on-chain
    mine_blocks 1 "confirm assignment"
    cache_block_hash "ASSIGNING"

    # Verify ASSIGNING state (assignment now on-chain but not yet active)
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Verified ASSIGNING state"

    cache_block_hash "ASSIGNED_CONFIRMED"

    verify_mempool_empty
    pass "Verified mempool empty after confirmation"

    # Assignment is confirmed but not yet active (need to wait for delay)
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Verified still ASSIGNING (waiting for activation delay)"

    # Mine activation delay blocks
    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "ASSIGNED_ACTIVE"

    # Verify ASSIGNED state
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Verified ASSIGNED state (active)"

    # Parse and verify OP_RETURN data
    local opreturn=$(parse_assignment_opreturn "$ASSIGNMENT_TXID")
    if [[ ! "$opreturn" =~ ^6a2c504f4358 ]]; then
        fail "Invalid OP_RETURN format (should start with OP_RETURN + POCX), got: ${opreturn:0:20}..."
    fi
    pass "Verified assignment OP_RETURN format"
}

#
# Phase 3: Revocation
#

phase3_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Revocation"
    echo "=========================================="
    echo ""

    # Fund plot address again (assignment spent the original UTXO, change went to new address)
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address with 1.0 BTCX"

    # Create revocation transaction
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID"
    pass "Created revocation transaction"

    # Verify transaction in mempool
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Verified revocation in mempool"

    # Mine block to include revocation on-chain
    mine_blocks 1 "confirm revocation"
    cache_block_hash "REVOKING"

    # Verify REVOKING state (revocation now on-chain but not yet active)
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Verified REVOKING state"

    cache_block_hash "REVOKED_CONFIRMED"

    verify_mempool_empty
    pass "Verified mempool empty after confirmation"

    # Revocation is confirmed but not yet active (need to wait for delay)
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Verified still REVOKING (waiting for revocation delay)"

    # Mine revocation delay blocks
    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "REVOKED_ACTIVE"

    # Verify REVOKED state (revocation is now active)
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Verified REVOKED state (revocation active)"

    # Parse and verify OP_RETURN data
    local opreturn=$(parse_assignment_opreturn "$REVOCATION_TXID")
    if [[ ! "$opreturn" =~ ^6a1858434f50 ]]; then
        fail "Invalid OP_RETURN format (should start with OP_RETURN + XCOP)"
    fi
    pass "Verified revocation OP_RETURN format"
}

#
# Phase 4: Single-State Rollback
#

phase4_single_state_rollback() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Single-State Rollback"
    echo "=========================================="
    echo ""

    local height_before=$(get_block_count)
    echo "  Starting height: $height_before"
    echo ""

    # REVOKED → REVOKING (invalidate activation blocks)
    echo "Step 1: REVOKED → REVOKING"
    invalidate_block "${BLOCK_HASHES[REVOKED_ACTIVE]}" "revocation activation"
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Rolled back REVOKED → REVOKING"

    # REVOKING → ASSIGNED (invalidate revocation confirmation + delay blocks)
    echo ""
    echo "Step 2: REVOKING → ASSIGNED"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Revocation back in mempool"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Rolled back REVOKING → ASSIGNED"

    # ASSIGNED → ASSIGNING (invalidate assignment activation blocks)
    echo ""
    echo "Step 3: ASSIGNED → ASSIGNING"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Rolled back ASSIGNED → ASSIGNING"

    # ASSIGNING → UNASSIGNED (invalidate assignment confirmation)
    echo ""
    echo "Step 4: ASSIGNING → UNASSIGNED"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Assignment back in mempool"
    # Transaction in mempool → get_assignment returns UNASSIGNED (doesn't check mempool)
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Rolled back ASSIGNING → UNASSIGNED"

    echo ""
    echo "Step 5: Reconsidering all blocks back to REVOKED state"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    reconsider_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    reconsider_block "${BLOCK_HASHES[REVOKED_ACTIVE]}" "revocation activation"

    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Reconsidered back to REVOKED state"

    local height_after=$(get_block_count)
    echo "  Ending height: $height_after"
}

#
# Phase 5: Multi-State Rollback
#

phase5_multi_state_rollback() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Multi-State Rollback"
    echo "=========================================="
    echo ""

    # REVOKED → ASSIGNED (jump over REVOKING)
    echo "Step 1: REVOKED → ASSIGNED (multi-block jump)"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "jump to ASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Jumped REVOKED → ASSIGNED"

    # ASSIGNED → UNASSIGNED (jump over ASSIGNING)
    echo ""
    echo "Step 2: ASSIGNED → UNASSIGNED (multi-block jump)"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    invalidate_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Jumped ASSIGNED → UNASSIGNED"

    # UNASSIGNED → REVOKED (reconsider pulls in all descendants)
    echo ""
    echo "Step 3: UNASSIGNED → REVOKED (reconsider with descendants)"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    # Note: reconsiderblock automatically reconsiders all descendant blocks including revocations
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Jumped UNASSIGNED → REVOKED (with descendants)"
}

#
# Phase 6: Historic Assignment Verification
#

phase6_historic_verification() {
    echo ""
    echo "=========================================="
    echo "Phase 6: Historic Assignment Verification"
    echo "=========================================="
    echo ""

    # Verify we can query assignment state at any historical block height
    # Current tip should be at REVOKED state (block 118)

    # Extract block heights from cached hashes
    local unassigned_height=$(get_block_height "${BLOCK_HASHES[UNASSIGNED]}")
    local assigning_height=$(get_block_height "${BLOCK_HASHES[ASSIGNING]}")
    local assigned_height=$(get_block_height "${BLOCK_HASHES[ASSIGNED_ACTIVE]}")
    local revoking_height=$(get_block_height "${BLOCK_HASHES[REVOKING]}")
    local revoked_height=$(get_block_height "${BLOCK_HASHES[REVOKED_ACTIVE]}")

    echo "  Testing historical state queries at different heights..."
    echo ""

    # Check UNASSIGNED at block 102
    echo "  Height $unassigned_height (UNASSIGNED):"
    verify_assignment_status_at_height "$PLOT_ADDR" "UNASSIGNED" "" "$unassigned_height"
    pass "  ✓ Historical query: UNASSIGNED"

    # Check ASSIGNING at block 103
    echo "  Height $assigning_height (ASSIGNING):"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR" "$assigning_height"
    pass "  ✓ Historical query: ASSIGNING"

    # Check ASSIGNED at block 107
    echo "  Height $assigned_height (ASSIGNED):"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR" "$assigned_height"
    pass "  ✓ Historical query: ASSIGNED"

    # Check REVOKING at block 110
    echo "  Height $revoking_height (REVOKING):"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR" "$revoking_height"
    pass "  ✓ Historical query: REVOKING"

    # Check REVOKED at block 118
    echo "  Height $revoked_height (REVOKED):"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR" "$revoked_height"
    pass "  ✓ Historical query: REVOKED"

    echo ""
    pass "All historical state queries successful"
}

#
# Main Test Execution
#

main() {
    echo ""
    echo "=========================================="
    echo "Assignment Lifecycle Test - Regtest"
    echo "=========================================="
    echo ""
    echo "Network Parameters:"
    echo "  Assignment Delay: $ASSIGNMENT_DELAY blocks"
    echo "  Revocation Delay: $REVOCATION_DELAY blocks"

    phase1_setup
    phase2_assignment
    phase3_revocation
    phase4_single_state_rollback
    phase5_multi_state_rollback
    phase6_historic_verification

    # Cleanup
    echo ""
    echo "Stopping bitcoind..."
    pkill -9 bitcoind 2>/dev/null || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo ""
    echo "  Tests Passed: $TESTS_PASSED"
    echo "  Tests Failed: $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "✓ All tests passed!"
        echo ""
        exit 0
    else
        echo "✗ Some tests failed"
        echo ""
        exit 1
    fi
}

# Run main
main
