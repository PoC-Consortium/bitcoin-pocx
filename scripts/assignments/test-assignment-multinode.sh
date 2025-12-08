#!/bin/bash
# Multi-node forging assignment lifecycle test
# Node1: Creates assignments and performs operations
# Node2: Validates all state changes (separate wallet, queries only)
# Tests complete assignment lifecycle + blockchain rollbacks with cross-node validation

set -e

# Get script directory for sourcing setup-regtest-template.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtest-template.sh"

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

# Node1 (operator) configuration
NODE1_DATADIR="$HOME/.bitcoin/regtest-node1"
NODE1_PORT=18444
NODE1_RPCPORT=18443

# Node2 (validator) configuration
NODE2_DATADIR="$HOME/.bitcoin/regtest-node2"
NODE2_PORT=18445
NODE2_RPCPORT=18446

# Network parameters (regtest)
ASSIGNMENT_DELAY=4  # 4 blocks
REVOCATION_DELAY=8  # 8 blocks

# Block hash cache
declare -A BLOCK_HASHES

# Transaction IDs
ASSIGNMENT_TXID=""
REVOCATION_TXID=""

# Addresses (Node1)
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
    cleanup
    exit 1
}

pass() {
    echo "  ✓ $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Node-specific CLI wrappers
cli_node1() {
    $BITCOIN_CLI -regtest -datadir="$NODE1_DATADIR" -rpcport="$NODE1_RPCPORT" "$@"
}

cli_node2() {
    $BITCOIN_CLI -regtest -datadir="$NODE2_DATADIR" -rpcport="$NODE2_RPCPORT" "$@"
}

get_block_count() {
    cli_node1 getblockcount
}

get_block_hash() {
    local height=$1
    cli_node1 getblockhash "$height"
}

get_block_height() {
    local block_hash=$1
    cli_node1 getblockheader "$block_hash" | jq -r '.height'
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
    cli_node1 generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

wait_for_sync() {
    local desc=${1:-"blocks"}
    local node1_height=$(get_block_count)
    local timeout=30
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        local node2_height=$(cli_node2 getblockcount)
        if [ "$node2_height" -eq "$node1_height" ]; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "Nodes failed to sync within ${timeout}s (Node1: $node1_height, Node2: $(cli_node2 getblockcount))"
}

# Verify assignment status on Node2
verify_assignment_status_node2() {
    local plot=$1
    local expected_state=$2
    local expected_forge=$3

    local result=$(cli_node2 get_assignment "$plot" 2>/dev/null || echo "{}")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')

    if [ "$state" != "$expected_state" ]; then
        fail "Node2: Expected state '$expected_state', got '$state'"
    fi

    if [ -n "$expected_forge" ] && [ "$forge" != "$expected_forge" ]; then
        fail "Node2: Expected forge address '$expected_forge', got '$forge'"
    fi
}

verify_assignment_status_at_height_node2() {
    local plot=$1
    local expected_state=$2
    local expected_forge=$3
    local height=$4

    local result=$(cli_node2 get_assignment "$plot" "$height")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')

    if [ "$state" != "$expected_state" ]; then
        fail "Node2 at height $height: Expected state '$expected_state', got '$state'"
    fi

    if [ -n "$expected_forge" ] && [ "$forge" != "$expected_forge" ]; then
        fail "Node2 at height $height: Expected forge address '$expected_forge', got '$forge'"
    fi
}

verify_mempool_contains() {
    local txid=$1
    local mempool=$(cli_node1 getrawmempool)
    if ! echo "$mempool" | jq -e ". | index(\"$txid\")" >/dev/null; then
        fail "Transaction $txid not found in Node1 mempool"
    fi
}

verify_mempool_empty() {
    local mempool=$(cli_node1 getrawmempool)
    local count=$(echo "$mempool" | jq '. | length')
    if [ "$count" -ne 0 ]; then
        fail "Expected empty mempool, found $count transactions"
    fi
}

parse_assignment_opreturn() {
    local txid=$1
    local tx=$(cli_node1 gettransaction "$txid" 2>/dev/null)
    local hex=$(echo "$tx" | jq -r '.hex')
    local decoded=$(cli_node1 decoderawtransaction "$hex" 2>/dev/null)
    echo "$decoded" | jq -r '.vout[0].scriptPubKey.hex'
}

invalidate_block() {
    local hash=$1
    local desc=$2
    if [ -n "$desc" ]; then
        echo "  ↩️  Invalidating $desc block: ${hash:0:16}..."
    fi
    cli_node1 invalidateblock "$hash"
    cli_node2 invalidateblock "$hash"
    wait_for_sync "after invalidate"
}

reconsider_block() {
    local hash=$1
    local desc=$2
    if [ -n "$desc" ]; then
        echo "  ↪️  Reconsidering $desc block: ${hash:0:16}..."
    fi
    cli_node1 reconsiderblock "$hash"
    cli_node2 reconsiderblock "$hash"
    wait_for_sync "after reconsider"
}

cleanup() {
    echo ""
    echo "Stopping nodes..."
    cli_node1 stop 2>/dev/null || true
    cli_node2 stop 2>/dev/null || true
    sleep 2
    pkill -9 bitcoind 2>/dev/null || true
    sleep 1
}

#
# Setup
#

setup_nodes() {
    echo ""
    echo "=========================================="
    echo "Multi-Node Assignment Lifecycle Test"
    echo "=========================================="
    echo ""
    echo "Network Parameters:"
    echo "  Assignment Delay: $ASSIGNMENT_DELAY blocks"
    echo "  Revocation Delay: $REVOCATION_DELAY blocks"
    echo ""

    # Clean up any existing processes
    pkill -9 bitcoind 2>/dev/null || true
    sleep 2

    # Setup or load regtest template (instant after first run)
    setup_regtest_template

    # Copy template to both node datadirs
    echo "Setting up node datadirs from template..."
    copy_template_to_datadir "$NODE1_DATADIR"
    copy_template_to_datadir "$NODE2_DATADIR"
    pass "Loaded regtest template for both nodes"

    # Start Node1 (operator)
    echo ""
    echo "Starting Node1 (operator)..."
    echo "  Port: $NODE1_PORT, RPC: $NODE1_RPCPORT"
    $BITCOIND -regtest -datadir="$NODE1_DATADIR" \
        -port="$NODE1_PORT" -rpcport="$NODE1_RPCPORT" \
        -bind=127.0.0.1:$NODE1_PORT \
        -fallbackfee=0.00001 \
        -daemon
    sleep 5

    # Start Node2 (validator)
    echo ""
    echo "Starting Node2 (validator)..."
    echo "  Port: $NODE2_PORT, RPC: $NODE2_RPCPORT"
    $BITCOIND -regtest -datadir="$NODE2_DATADIR" \
        -port="$NODE2_PORT" -rpcport="$NODE2_RPCPORT" \
        -bind=127.0.0.1:$NODE2_PORT \
        -fallbackfee=0.00001 \
        -daemon
    sleep 10

    # Load template wallets with retry logic
    echo ""
    echo "Loading wallets..."

    # Load wallet on Node1
    cli_node1 loadwallet "template" >/dev/null
    pass "Node1 wallet loaded"

    # Wait for Node2 to be ready, then load wallet
    local retry_count=0
    local max_retries=5
    while [ $retry_count -lt $max_retries ]; do
        if cli_node2 getblockchaininfo >/dev/null 2>&1; then
            # Node2 RPC is ready, now load wallet
            if cli_node2 loadwallet "template" >/dev/null 2>&1; then
                pass "Node2 wallet loaded"
                break
            fi
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -eq $max_retries ]; then
            fail "Node2 failed to start after $max_retries attempts"
        fi
        sleep 1
    done

    # Connect nodes
    echo ""
    echo "Connecting nodes..."
    cli_node1 addnode "127.0.0.1:$NODE2_PORT" add
    sleep 2

    local peer_count=$(cli_node1 getconnectioncount)
    if [ "$peer_count" -lt 1 ]; then
        fail "Node1 failed to connect to Node2"
    fi
    pass "Nodes connected (Node1 peers: $peer_count)"
}

#
# Phase 1: Setup
#

phase1_setup() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Setup"
    echo "=========================================="
    echo ""

    # Get mining address from template wallet (already has 101 blocks)
    MINING_ADDR=$(cli_node1 getnewaddress)

    # Wait for nodes to sync with template chain
    wait_for_sync "initial blocks"
    pass "Nodes synced with template chain (101 blocks)"

    # Verify Node1 has funds
    local balance=$(cli_node1 getbalance)
    echo "  Node1 wallet balance: $balance BTCX"
    if [ "$(echo "$balance < 10" | bc)" -eq 1 ]; then
        fail "Node1 wallet has insufficient funds: $balance BTCX"
    fi

    # Create addresses
    PLOT_ADDR=$(cli_node1 getnewaddress "" "bech32")
    FORGE_ADDR=$(cli_node1 getnewaddress "" "bech32")
    echo "  Plot address:  $PLOT_ADDR"
    echo "  Forge address: $FORGE_ADDR"
    pass "Created addresses"

    # Fund plot address
    HEIGHT=$(get_block_count)
    cli_node1 sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding"
    cli_node1 waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    wait_for_sync "funding"
    pass "Funded plot address with 1.0 BTCX"

    cache_block_hash "UNASSIGNED"

    # Verify UNASSIGNED state on Node2
    verify_assignment_status_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Verified UNASSIGNED state"
    verify_mempool_empty
    pass "Node2: Verified mempool empty"
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
    local result=$(cli_node1 create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
    ASSIGNMENT_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID"
    pass "Created assignment transaction"

    # Verify transaction in mempool
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Verified assignment in mempool"

    # Mine block to include assignment on-chain
    mine_blocks 1 "confirm assignment"
    wait_for_sync "assignment confirmation"
    cache_block_hash "ASSIGNING"

    # Verify ASSIGNING state on Node2
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Node2: Verified ASSIGNING state"

    cache_block_hash "ASSIGNED_CONFIRMED"

    verify_mempool_empty
    pass "Verified mempool empty after confirmation"

    # Assignment is confirmed but not yet active
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Node2: Verified still ASSIGNING (waiting for activation delay)"

    # Mine activation delay blocks
    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    wait_for_sync "assignment activation"
    cache_block_hash "ASSIGNED_ACTIVE"

    # Verify ASSIGNED state on Node2
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Verified ASSIGNED state (active)"

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

    # Fund plot address again
    HEIGHT=$(get_block_count)
    cli_node1 sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    cli_node1 waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    wait_for_sync "revocation funding"
    pass "Refunded plot address with 1.0 BTCX"

    # Create revocation transaction
    local result=$(cli_node1 revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID"
    pass "Created revocation transaction"

    # Verify transaction in mempool
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Verified revocation in mempool"

    # Mine block to include revocation on-chain
    mine_blocks 1 "confirm revocation"
    wait_for_sync "revocation confirmation"
    cache_block_hash "REVOKING"

    # Verify REVOKING state on Node2
    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Node2: Verified REVOKING state"

    cache_block_hash "REVOKED_CONFIRMED"

    verify_mempool_empty
    pass "Verified mempool empty after revocation confirmation"

    # Revocation is confirmed but not yet active
    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Node2: Verified still REVOKING (waiting for activation delay)"

    # Mine activation delay blocks
    mine_blocks $REVOCATION_DELAY "revocation delay"
    wait_for_sync "revocation activation"
    cache_block_hash "REVOKED_ACTIVE"

    # Verify REVOKED state on Node2
    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Verified REVOKED state (revocation active)"

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
    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Node2: Rolled back REVOKED → REVOKING"

    # REVOKING → ASSIGNED (invalidate revocation confirmation)
    echo ""
    echo "Step 2: REVOKING → ASSIGNED"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Revocation back in mempool"
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Rolled back REVOKING → ASSIGNED"

    # ASSIGNED → ASSIGNING (invalidate assignment activation blocks)
    echo ""
    echo "Step 3: ASSIGNED → ASSIGNING"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Node2: Rolled back ASSIGNED → ASSIGNING"

    # ASSIGNING → UNASSIGNED (invalidate assignment confirmation)
    echo ""
    echo "Step 4: ASSIGNING → UNASSIGNED"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Assignment back in mempool"
    verify_assignment_status_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Rolled back ASSIGNING → UNASSIGNED"

    echo ""
    echo "Step 5: Reconsidering all blocks back to REVOKED state"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    reconsider_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    reconsider_block "${BLOCK_HASHES[REVOKED_ACTIVE]}" "revocation activation"

    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Reconsidered back to REVOKED state"

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
    verify_assignment_status_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Jumped REVOKED → ASSIGNED"

    # ASSIGNED → UNASSIGNED (jump over ASSIGNING)
    echo ""
    echo "Step 2: ASSIGNED → UNASSIGNED (multi-block jump)"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    invalidate_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    verify_assignment_status_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Jumped ASSIGNED → UNASSIGNED"

    # UNASSIGNED → REVOKED (reconsider pulls in all descendants)
    echo ""
    echo "Step 3: UNASSIGNED → REVOKED (reconsider with descendants)"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    verify_assignment_status_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Jumped UNASSIGNED → REVOKED (with descendants)"
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

    # Extract block heights from cached hashes
    local unassigned_height=$(get_block_height "${BLOCK_HASHES[UNASSIGNED]}")
    local assigning_height=$(get_block_height "${BLOCK_HASHES[ASSIGNING]}")
    local assigned_height=$(get_block_height "${BLOCK_HASHES[ASSIGNED_ACTIVE]}")
    local revoking_height=$(get_block_height "${BLOCK_HASHES[REVOKING]}")
    local revoked_height=$(get_block_height "${BLOCK_HASHES[REVOKED_ACTIVE]}")

    echo "  Testing historical state queries on Node2..."
    echo ""

    # Check UNASSIGNED
    echo "  Height $unassigned_height (UNASSIGNED):"
    verify_assignment_status_at_height_node2 "$PLOT_ADDR" "UNASSIGNED" "" "$unassigned_height"
    pass "  ✓ Node2 historical query: UNASSIGNED"

    # Check ASSIGNING
    echo "  Height $assigning_height (ASSIGNING):"
    verify_assignment_status_at_height_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR" "$assigning_height"
    pass "  ✓ Node2 historical query: ASSIGNING"

    # Check ASSIGNED
    echo "  Height $assigned_height (ASSIGNED):"
    verify_assignment_status_at_height_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR" "$assigned_height"
    pass "  ✓ Node2 historical query: ASSIGNED"

    # Check REVOKING
    echo "  Height $revoking_height (REVOKING):"
    verify_assignment_status_at_height_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR" "$revoking_height"
    pass "  ✓ Node2 historical query: REVOKING"

    # Check REVOKED
    echo "  Height $revoked_height (REVOKED):"
    verify_assignment_status_at_height_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR" "$revoked_height"
    pass "  ✓ Node2 historical query: REVOKED"

    echo ""
    pass "All historical state queries successful on Node2"
}

#
# Main Test Execution
#

main() {
    # Trap to ensure cleanup on exit
    trap cleanup EXIT

    setup_nodes
    phase1_setup
    phase2_assignment
    phase3_revocation
    phase4_single_state_rollback
    phase5_multi_state_rollback
    phase6_historic_verification

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
        echo "✓ All multi-node tests passed!"
        echo ""
        cleanup
        exit 0
    else
        echo "✗ Some tests failed"
        echo ""
        cleanup
        exit 1
    fi
}

main
