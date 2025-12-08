#!/bin/bash
# Test script for two consecutive forging assignment cycles
# Tests: Cycle 1: UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED
#        Cycle 2: ASSIGNING → ASSIGNED → REVOKING → REVOKED
# Then verifies historical state queries across all blocks

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
ASSIGNMENT_TXID_1=""
REVOCATION_TXID_1=""
ASSIGNMENT_TXID_2=""
REVOCATION_TXID_2=""

# Addresses
PLOT_ADDR=""
FORGE_ADDR_1=""
FORGE_ADDR_2=""
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
    FORGE_ADDR_1=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
    FORGE_ADDR_2=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getnewaddress "" "bech32")
    echo "  Plot address:    $PLOT_ADDR"
    echo "  Forge address 1: $FORGE_ADDR_1"
    echo "  Forge address 2: $FORGE_ADDR_2"
    pass "Created addresses"

    # Fund plot address for cycle 1
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding cycle 1"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    pass "Funded plot address with 1.0 BTCX (cycle 1)"

    cache_block_hash "C1_UNASSIGNED"

    # Verify UNASSIGNED state
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Verified UNASSIGNED state"
}

#
# Phase 2: Cycle 1 - Assignment Creation
#

phase2_cycle1_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Cycle 1 - Assignment"
    echo "=========================================="
    echo ""

    # Create assignment transaction
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR" "$FORGE_ADDR_1" 0.0001)
    ASSIGNMENT_TXID_1=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID_1"
    pass "Created assignment transaction (cycle 1)"

    # Mine block to include assignment on-chain
    mine_blocks 1 "confirm assignment"
    cache_block_hash "C1_ASSIGNING"

    # Verify ASSIGNING state
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_1"
    pass "Verified ASSIGNING state (cycle 1)"

    # Mine activation delay blocks
    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "C1_ASSIGNED"

    # Verify ASSIGNED state
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_1"
    pass "Verified ASSIGNED state (cycle 1)"
}

#
# Phase 3: Cycle 1 - Revocation
#

phase3_cycle1_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Cycle 1 - Revocation"
    echo "=========================================="
    echo ""

    # Fund plot address again for revocation
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address with 1.0 BTCX (cycle 1 revocation)"

    # Create revocation transaction
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID_1=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID_1"
    pass "Created revocation transaction (cycle 1)"

    # Mine block to include revocation on-chain
    mine_blocks 1 "confirm revocation"
    cache_block_hash "C1_REVOKING"

    # Verify REVOKING state
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_1"
    pass "Verified REVOKING state (cycle 1)"

    # Mine revocation delay blocks
    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "C1_REVOKED"

    # Verify REVOKED state
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_1"
    pass "Verified REVOKED state (cycle 1)"
}

#
# Phase 4: Cycle 2 - Assignment Creation
#

phase4_cycle2_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Cycle 2 - Assignment"
    echo "=========================================="
    echo ""

    # Fund plot address for cycle 2
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding cycle 2"
    mine_blocks 1 "ensure maturity"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Funded plot address with 1.0 BTCX (cycle 2)"

    # Create second assignment transaction (different forge address)
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" create_assignment "$PLOT_ADDR" "$FORGE_ADDR_2" 0.0001)
    ASSIGNMENT_TXID_2=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID_2"
    pass "Created assignment transaction (cycle 2)"

    # Mine block to include assignment on-chain
    mine_blocks 1 "confirm assignment"
    cache_block_hash "C2_ASSIGNING"

    # Verify ASSIGNING state with new forge address
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_2"
    pass "Verified ASSIGNING state (cycle 2)"

    # Mine activation delay blocks
    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "C2_ASSIGNED"

    # Verify ASSIGNED state with new forge address
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_2"
    pass "Verified ASSIGNED state (cycle 2)"
}

#
# Phase 5: Cycle 2 - Revocation
#

phase5_cycle2_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Cycle 2 - Revocation"
    echo "=========================================="
    echo ""

    # Fund plot address again for second revocation
    HEIGHT=$($BITCOIN_CLI -regtest -datadir="$DATADIR" getblockcount)
    $BITCOIN_CLI -regtest -datadir="$DATADIR" sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $BITCOIN_CLI -regtest -datadir="$DATADIR" waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address with 1.0 BTCX (cycle 2 revocation)"

    # Create second revocation transaction
    local result=$($BITCOIN_CLI -regtest -datadir="$DATADIR" revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID_2=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID_2"
    pass "Created revocation transaction (cycle 2)"

    # Mine block to include revocation on-chain
    mine_blocks 1 "confirm revocation"
    cache_block_hash "C2_REVOKING"

    # Verify REVOKING state
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_2"
    pass "Verified REVOKING state (cycle 2)"

    # Mine revocation delay blocks
    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "C2_REVOKED"

    # Verify REVOKED state
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_2"
    pass "Verified REVOKED state (cycle 2)"
}

#
# Phase 6: Historic Assignment Verification (All 10 States)
#

phase6_historic_verification() {
    echo ""
    echo "=========================================="
    echo "Phase 6: Historic State Verification"
    echo "=========================================="
    echo ""
    echo "Testing historical queries across both cycles (10 states total)..."
    echo ""

    # Extract block heights from cached hashes
    local c1_unassigned_height=$(get_block_height "${BLOCK_HASHES[C1_UNASSIGNED]}")
    local c1_assigning_height=$(get_block_height "${BLOCK_HASHES[C1_ASSIGNING]}")
    local c1_assigned_height=$(get_block_height "${BLOCK_HASHES[C1_ASSIGNED]}")
    local c1_revoking_height=$(get_block_height "${BLOCK_HASHES[C1_REVOKING]}")
    local c1_revoked_height=$(get_block_height "${BLOCK_HASHES[C1_REVOKED]}")
    local c2_assigning_height=$(get_block_height "${BLOCK_HASHES[C2_ASSIGNING]}")
    local c2_assigned_height=$(get_block_height "${BLOCK_HASHES[C2_ASSIGNED]}")
    local c2_revoking_height=$(get_block_height "${BLOCK_HASHES[C2_REVOKING]}")
    local c2_revoked_height=$(get_block_height "${BLOCK_HASHES[C2_REVOKED]}")

    echo "Cycle 1 States:"
    echo "  Height $c1_unassigned_height: UNASSIGNED"
    verify_assignment_status_at_height "$PLOT_ADDR" "UNASSIGNED" "" "$c1_unassigned_height"
    pass "Historical query: Cycle 1 UNASSIGNED"

    echo "  Height $c1_assigning_height: ASSIGNING → $FORGE_ADDR_1"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_1" "$c1_assigning_height"
    pass "Historical query: Cycle 1 ASSIGNING"

    echo "  Height $c1_assigned_height: ASSIGNED → $FORGE_ADDR_1"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_1" "$c1_assigned_height"
    pass "Historical query: Cycle 1 ASSIGNED"

    echo "  Height $c1_revoking_height: REVOKING"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_1" "$c1_revoking_height"
    pass "Historical query: Cycle 1 REVOKING"

    echo "  Height $c1_revoked_height: REVOKED"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_1" "$c1_revoked_height"
    pass "Historical query: Cycle 1 REVOKED"

    echo ""
    echo "Cycle 2 States:"
    echo "  Height $c2_assigning_height: ASSIGNING → $FORGE_ADDR_2"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_2" "$c2_assigning_height"
    pass "Historical query: Cycle 2 ASSIGNING"

    echo "  Height $c2_assigned_height: ASSIGNED → $FORGE_ADDR_2"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_2" "$c2_assigned_height"
    pass "Historical query: Cycle 2 ASSIGNED"

    echo "  Height $c2_revoking_height: REVOKING"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_2" "$c2_revoking_height"
    pass "Historical query: Cycle 2 REVOKING"

    echo "  Height $c2_revoked_height: REVOKED"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_2" "$c2_revoked_height"
    pass "Historical query: Cycle 2 REVOKED"

    echo ""
    pass "All 9 historical state queries successful (both cycles)"
}

#
# Main Test Execution
#

main() {
    echo ""
    echo "=========================================="
    echo "Double Assignment Cycle Test - Regtest"
    echo "=========================================="
    echo ""
    echo "Network Parameters:"
    echo "  Assignment Delay: $ASSIGNMENT_DELAY blocks"
    echo "  Revocation Delay: $REVOCATION_DELAY blocks"
    echo ""
    echo "This test runs two complete assignment cycles:"
    echo "  Cycle 1: assign → revoke"
    echo "  Cycle 2: assign → revoke"
    echo "Then verifies historical state queries across all blocks"

    phase1_setup
    phase2_cycle1_assignment
    phase3_cycle1_revocation
    phase4_cycle2_assignment
    phase5_cycle2_revocation
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
