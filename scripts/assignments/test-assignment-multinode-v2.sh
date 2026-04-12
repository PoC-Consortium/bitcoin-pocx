#!/bin/bash
# Regtestv2: multi-node assignment lifecycle.
# Node1 operator creates/mines; Node2 validator observes.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

NODE1_DATADIR="$HOME/.bitcoin-pocx/regtestv2-multinode-node1"
NODE1_PORT=18544
NODE1_RPCPORT=18543
NODE2_DATADIR="$HOME/.bitcoin-pocx/regtestv2-multinode-node2"
NODE2_PORT=18546
NODE2_RPCPORT=18545

ASSIGNMENT_DELAY=4
REVOCATION_DELAY=8

declare -A BLOCK_HASHES
ASSIGNMENT_TXID=""; REVOCATION_TXID=""
PLOT_ADDR=""; FORGE_ADDR=""; MINING_ADDR=""
TESTS_PASSED=0

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "  ${RED}✗ FAILED:${NC} $1"; cleanup; exit 1; }

cli_node1() { $BITCOIN_CLI -regtest -datadir="$NODE1_DATADIR" -rpcport="$NODE1_RPCPORT" "$@"; }
cli_node2() { $BITCOIN_CLI -regtest -datadir="$NODE2_DATADIR" -rpcport="$NODE2_RPCPORT" "$@"; }
wcli1()     { cli_node1 -rpcwallet=test "$@"; }

cleanup() {
    echo ""
    echo "Stopping nodes..."
    cli_node1 stop >/dev/null 2>&1 || true
    cli_node2 stop >/dev/null 2>&1 || true
    sleep 1
    pkill -9 bitcoind 2>/dev/null || true
}
trap cleanup EXIT

get_block_count() { cli_node1 getblockcount; }
get_block_hash()  { cli_node1 getblockhash "$1"; }
get_block_height(){ cli_node1 getblockheader "$1" | jq -r '.height'; }

cache_block_hash() {
    local name=$1
    local h hash
    h=$(get_block_count)
    hash=$(get_block_hash "$h")
    BLOCK_HASHES[$name]=$hash
    echo "  📦 Cached $name: block $h (${hash:0:16}...)"
}

mine_blocks() {
    local count=$1 desc=$2
    [ -n "$desc" ] && echo "  ⛏️  Mining $count blocks ($desc)..."
    cli_node1 generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

wait_for_sync() {
    local h1 h2 elapsed=0
    h1=$(get_block_count)
    while [ $elapsed -lt 30 ]; do
        h2=$(cli_node2 getblockcount)
        [ "$h2" -eq "$h1" ] && return 0
        sleep 1
        elapsed=$((elapsed + 1))
    done
    fail "Nodes failed to sync (Node1=$h1, Node2=$(cli_node2 getblockcount))"
}

verify_state_node2() {
    local plot=$1 exp_state=$2 exp_forge=$3
    local result=$(cli_node2 get_assignment "$plot" 2>/dev/null || echo "{}")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')
    [ "$state" = "$exp_state" ] || fail "Node2: expected state $exp_state, got $state"
    if [ -n "$exp_forge" ] && [ "$forge" != "$exp_forge" ]; then
        fail "Node2: expected forge $exp_forge, got $forge"
    fi
}

verify_state_at_height_node2() {
    local plot=$1 exp_state=$2 exp_forge=$3 height=$4
    local result=$(cli_node2 get_assignment "$plot" "$height")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')
    [ "$state" = "$exp_state" ] || fail "Node2 @ $height: expected $exp_state, got $state"
    if [ -n "$exp_forge" ] && [ "$forge" != "$exp_forge" ]; then
        fail "Node2 @ $height: expected forge $exp_forge, got $forge"
    fi
}

verify_mempool_contains() {
    local txid=$1
    local mp=$(cli_node1 getrawmempool)
    echo "$mp" | jq -e ". | index(\"$txid\")" >/dev/null || fail "Tx $txid not in Node1 mempool"
}

verify_mempool_empty() {
    local mp=$(cli_node1 getrawmempool)
    [ "$(echo "$mp" | jq length)" -eq 0 ] || fail "Node1 mempool not empty"
}

parse_assignment_opreturn() {
    local txid=$1
    local tx hex decoded
    tx=$(wcli1 gettransaction "$txid" 2>/dev/null)
    hex=$(echo "$tx" | jq -r '.hex')
    decoded=$(cli_node1 decoderawtransaction "$hex" 2>/dev/null)
    echo "$decoded" | jq -r '.vout[0].scriptPubKey.hex'
}

invalidate_block() {
    local hash=$1 desc=$2
    echo "  ↩️  Invalidating $desc: ${hash:0:16}..."
    cli_node1 invalidateblock "$hash"
    cli_node2 invalidateblock "$hash"
    wait_for_sync
}

reconsider_block() {
    local hash=$1 desc=$2
    echo "  ↪️  Reconsidering $desc: ${hash:0:16}..."
    cli_node1 reconsiderblock "$hash"
    cli_node2 reconsiderblock "$hash"
    wait_for_sync
}

setup_nodes() {
    echo "=========================================="
    echo "Multi-Node Assignment Lifecycle (v2)"
    echo "=========================================="
    pkill -9 bitcoind 2>/dev/null || true
    sleep 1
    rm -rf "$NODE1_DATADIR" "$NODE2_DATADIR"
    mkdir -p "$NODE1_DATADIR" "$NODE2_DATADIR"

    echo "Starting Node1 (operator) on port $NODE1_PORT / rpc $NODE1_RPCPORT..."
    $BITCOIND -regtest -datadir="$NODE1_DATADIR" \
        -port="$NODE1_PORT" -rpcport="$NODE1_RPCPORT" \
        -bind=127.0.0.1:$NODE1_PORT \
        -fallbackfee=0.00001 -daemon >/dev/null

    echo "Starting Node2 (validator) on port $NODE2_PORT / rpc $NODE2_RPCPORT..."
    $BITCOIND -regtest -datadir="$NODE2_DATADIR" \
        -port="$NODE2_PORT" -rpcport="$NODE2_RPCPORT" \
        -bind=127.0.0.1:$NODE2_PORT \
        -fallbackfee=0.00001 -daemon >/dev/null

    for i in 1 2 3 4 5; do
        cli_node1 getblockchaininfo >/dev/null 2>&1 && \
        cli_node2 getblockchaininfo >/dev/null 2>&1 && break
        sleep 1
    done

    # Align mocktime. Node1 gets current wall clock so block.nTime tracks
    # reality and the operator wallet's birthday matches. Node2 gets a far
    # future value (+1 year) — this parks Node2's NodeClock::now() well
    # beyond any block.nTime Node1 will produce, so propagated blocks
    # always satisfy Node2's MAX_FUTURE_BLOCK_TIME (15s) check without
    # needing per-block mocktime resynchronization.
    local now=$(date +%s)
    cli_node1 setmocktime "$now" >/dev/null
    cli_node2 setmocktime "$((now + 365*24*3600))" >/dev/null

    cli_node1 createwallet test >/dev/null
    pass "Node1 wallet loaded"
    # Node2 stays wallet-less; it validates via query-only APIs.

    cli_node1 addnode "127.0.0.1:$NODE2_PORT" add
    sleep 1
    local peer_count=$(cli_node1 getconnectioncount)
    [ "$peer_count" -ge 1 ] || fail "Node1 failed to connect to Node2"
    pass "Nodes connected (Node1 peers: $peer_count)"
}

phase1_setup() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Setup"
    echo "=========================================="
    MINING_ADDR=$(wcli1 getnewaddress)
    mine_blocks 101 "initial chain"
    wait_for_sync
    pass "Mined 101 blocks on Node1, Node2 synced"

    local balance=$(wcli1 getbalance)
    echo "  Node1 wallet balance: $balance BTCX"

    PLOT_ADDR=$(wcli1 getnewaddress "" "bech32")
    FORGE_ADDR=$(wcli1 getnewaddress "" "bech32")
    echo "  Plot address:  $PLOT_ADDR"
    echo "  Forge address: $FORGE_ADDR"

    HEIGHT=$(get_block_count)
    wcli1 sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding"
    cli_node1 waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    wait_for_sync
    pass "Funded plot address"

    cache_block_hash "UNASSIGNED"
    verify_state_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Verified UNASSIGNED state"
    verify_mempool_empty
    pass "Verified mempool empty"
}

phase2_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Assignment Creation"
    echo "=========================================="
    local result=$(wcli1 create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
    ASSIGNMENT_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID"
    pass "Created assignment transaction"

    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Verified assignment in mempool"

    mine_blocks 1 "confirm assignment"
    wait_for_sync
    cache_block_hash "ASSIGNING"
    verify_state_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Node2: Verified ASSIGNING state"

    cache_block_hash "ASSIGNED_CONFIRMED"
    verify_mempool_empty
    pass "Verified mempool empty after confirmation"

    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    wait_for_sync
    cache_block_hash "ASSIGNED_ACTIVE"
    verify_state_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Verified ASSIGNED state"

    local opreturn=$(parse_assignment_opreturn "$ASSIGNMENT_TXID")
    [[ "$opreturn" =~ ^6a2c504f4358 ]] || fail "Invalid OP_RETURN: ${opreturn:0:20}..."
    pass "Verified assignment OP_RETURN format"
}

phase3_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Revocation"
    echo "=========================================="
    HEIGHT=$(get_block_count)
    wcli1 sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    cli_node1 waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    wait_for_sync
    pass "Refunded plot address"

    local result=$(wcli1 revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID"
    pass "Created revocation transaction"

    verify_mempool_contains "$REVOCATION_TXID"
    pass "Verified revocation in mempool"

    mine_blocks 1 "confirm revocation"
    wait_for_sync
    cache_block_hash "REVOKING"
    verify_state_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Node2: Verified REVOKING state"

    cache_block_hash "REVOKED_CONFIRMED"
    verify_mempool_empty
    pass "Verified mempool empty after revocation confirmation"

    mine_blocks $REVOCATION_DELAY "revocation delay"
    wait_for_sync
    cache_block_hash "REVOKED_ACTIVE"
    verify_state_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Verified REVOKED state"

    local opreturn=$(parse_assignment_opreturn "$REVOCATION_TXID")
    [[ "$opreturn" =~ ^6a1858434f50 ]] || fail "Invalid OP_RETURN format"
    pass "Verified revocation OP_RETURN format"
}

phase4_single_state_rollback() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Single-State Rollback"
    echo "=========================================="
    local h_before=$(get_block_count)
    echo "  Starting height: $h_before"

    echo ""
    echo "Step 1: REVOKED → REVOKING"
    invalidate_block "${BLOCK_HASHES[REVOKED_ACTIVE]}" "revocation activation"
    verify_state_node2 "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Node2: Rolled back REVOKED → REVOKING"

    echo ""
    echo "Step 2: REVOKING → ASSIGNED"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Revocation back in mempool"
    verify_state_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Rolled back REVOKING → ASSIGNED"

    echo ""
    echo "Step 3: ASSIGNED → ASSIGNING"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    verify_state_node2 "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Node2: Rolled back ASSIGNED → ASSIGNING"

    echo ""
    echo "Step 4: ASSIGNING → UNASSIGNED"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Assignment back in mempool"
    verify_state_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Rolled back ASSIGNING → UNASSIGNED"

    echo ""
    echo "Step 5: Reconsidering all blocks back to REVOKED state"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}"          "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}"    "assignment activation"
    reconsider_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}"  "revocation confirmation"
    reconsider_block "${BLOCK_HASHES[REVOKED_ACTIVE]}"     "revocation activation"
    verify_state_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Reconsidered back to REVOKED state"
}

phase5_multi_state_rollback() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Multi-State Rollback"
    echo "=========================================="
    echo "Step 1: REVOKED → ASSIGNED"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "jump to ASSIGNED"
    verify_state_node2 "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Node2: Jumped REVOKED → ASSIGNED"

    echo ""
    echo "Step 2: ASSIGNED → UNASSIGNED"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    invalidate_block "${BLOCK_HASHES[ASSIGNING]}"          "assignment mempool"
    verify_state_node2 "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Node2: Jumped ASSIGNED → UNASSIGNED"

    echo ""
    echo "Step 3: UNASSIGNED → REVOKED"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}"          "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}"    "assignment activation"
    verify_state_node2 "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Node2: Jumped UNASSIGNED → REVOKED (with descendants)"
}

phase6_historic_verification() {
    echo ""
    echo "=========================================="
    echo "Phase 6: Historic Assignment Verification"
    echo "=========================================="
    local u=$(get_block_height "${BLOCK_HASHES[UNASSIGNED]}")
    local as=$(get_block_height "${BLOCK_HASHES[ASSIGNING]}")
    local ad=$(get_block_height "${BLOCK_HASHES[ASSIGNED_ACTIVE]}")
    local rg=$(get_block_height "${BLOCK_HASHES[REVOKING]}")
    local rd=$(get_block_height "${BLOCK_HASHES[REVOKED_ACTIVE]}")

    verify_state_at_height_node2 "$PLOT_ADDR" "UNASSIGNED" ""             "$u";  pass "Node2: UNASSIGNED @ $u"
    verify_state_at_height_node2 "$PLOT_ADDR" "ASSIGNING"  "$FORGE_ADDR"  "$as"; pass "Node2: ASSIGNING @ $as"
    verify_state_at_height_node2 "$PLOT_ADDR" "ASSIGNED"   "$FORGE_ADDR"  "$ad"; pass "Node2: ASSIGNED @ $ad"
    verify_state_at_height_node2 "$PLOT_ADDR" "REVOKING"   "$FORGE_ADDR"  "$rg"; pass "Node2: REVOKING @ $rg"
    verify_state_at_height_node2 "$PLOT_ADDR" "REVOKED"    "$FORGE_ADDR"  "$rd"; pass "Node2: REVOKED @ $rd"
}

setup_nodes
phase1_setup
phase2_assignment
phase3_revocation
phase4_single_state_rollback
phase5_multi_state_rollback
phase6_historic_verification

echo ""
echo "Tests passed: $TESTS_PASSED"
echo -e "${GREEN}✓ ALL MULTI-NODE TESTS PASSED${NC}"
