#!/bin/bash
# Regtestv2: forging assignment lifecycle + single-state and multi-state rollbacks.
# UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED, then invalidate/reconsider.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-lifecycle"

ASSIGNMENT_DELAY=4
REVOCATION_DELAY=8

declare -A BLOCK_HASHES
ASSIGNMENT_TXID=""; REVOCATION_TXID=""
PLOT_ADDR=""; FORGE_ADDR=""; MINING_ADDR=""
TESTS_PASSED=0

pass() { echo "  ✓ $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  ✗ FAILED: $1"; regtestv2_stop; exit 1; }

get_block_count()  { $CLI getblockcount; }
get_block_hash()   { $CLI getblockhash "$1"; }
get_block_height() { $CLI getblockheader "$1" | jq -r '.height'; }

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
    $CLI generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

verify_assignment_status() {
    local plot=$1 exp_state=$2 exp_forge=$3
    local result=$($CLI get_assignment "$plot" 2>/dev/null || echo "{}")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')
    [ "$state" = "$exp_state" ] || fail "Expected state '$exp_state', got '$state'"
    if [ -n "$exp_forge" ] && [ "$forge" != "$exp_forge" ]; then
        fail "Expected forge '$exp_forge', got '$forge'"
    fi
}

verify_assignment_status_at_height() {
    local plot=$1 exp_state=$2 exp_forge=$3 height=$4
    local result=$($CLI get_assignment "$plot" "$height")
    local state=$(echo "$result" | jq -r '.state // "NONE"')
    local forge=$(echo "$result" | jq -r '.forging_address // ""')
    [ "$state" = "$exp_state" ] || fail "At height $height: Expected '$exp_state', got '$state'"
    if [ -n "$exp_forge" ] && [ "$forge" != "$exp_forge" ]; then
        fail "At height $height: Expected forge '$exp_forge', got '$forge'"
    fi
}

verify_mempool_contains() {
    local txid=$1
    local mempool=$($CLI getrawmempool)
    echo "$mempool" | jq -e ". | index(\"$txid\")" >/dev/null || fail "Tx $txid not in mempool"
}

verify_mempool_empty() {
    local mempool=$($CLI getrawmempool)
    local count=$(echo "$mempool" | jq '. | length')
    [ "$count" = "0" ] || fail "Mempool not empty (count=$count)"
}

parse_assignment_opreturn() {
    local txid=$1
    local tx=$($WCLI gettransaction "$txid" 2>/dev/null || echo "")
    [ -z "$tx" ] && { echo ""; return 1; }
    local hex=$(echo "$tx" | jq -r '.hex')
    local decoded=$($CLI decoderawtransaction "$hex" 2>/dev/null || echo "")
    echo "$decoded" | jq -r '.vout[0].scriptPubKey.hex'
}

invalidate_block() {
    local hash=$1 desc=$2
    echo "  ↩️  Invalidating block ${hash:0:16}... ($desc)"
    $CLI invalidateblock "$hash"
}

reconsider_block() {
    local hash=$1 desc=$2
    echo "  ↪️  Reconsidering block ${hash:0:16}... ($desc)"
    $CLI reconsiderblock "$hash"
}

phase1_setup() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Setup & Initial State"
    echo "=========================================="
    regtestv2_start "$DATADIR" -fallbackfee=0.00001
    CLI="$REGTESTV2_CLI"
    WCLI="$REGTESTV2_CLI_WALLET"
    MINING_ADDR=$(regtestv2_mine_to_maturity)
    pass "Bootstrap complete"

    PLOT_ADDR=$($WCLI getnewaddress "" "bech32")
    FORGE_ADDR=$($WCLI getnewaddress "" "bech32")
    echo "  Plot address:  $PLOT_ADDR"
    echo "  Forge address: $FORGE_ADDR"

    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding"
    $CLI waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    pass "Funded plot address"

    cache_block_hash "UNASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Verified UNASSIGNED state"
    verify_mempool_empty
    pass "Verified mempool empty"
}

phase2_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Assignment Creation"
    echo "=========================================="
    local result=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
    ASSIGNMENT_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID"
    pass "Created assignment transaction"

    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Verified assignment in mempool"

    mine_blocks 1 "confirm assignment"
    cache_block_hash "ASSIGNING"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Verified ASSIGNING state"

    cache_block_hash "ASSIGNED_CONFIRMED"
    verify_mempool_empty
    pass "Verified mempool empty after confirmation"

    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Verified still ASSIGNING (waiting for activation delay)"

    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "ASSIGNED_ACTIVE"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Verified ASSIGNED state"

    local opreturn=$(parse_assignment_opreturn "$ASSIGNMENT_TXID")
    if [[ ! "$opreturn" =~ ^6a2c504f4358 ]]; then
        fail "Invalid OP_RETURN format (should start with OP_RETURN + POCX), got: ${opreturn:0:20}..."
    fi
    pass "Verified assignment OP_RETURN format"
}

phase3_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Revocation"
    echo "=========================================="
    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $CLI waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address"

    local result=$($WCLI revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID"
    pass "Created revocation transaction"

    verify_mempool_contains "$REVOCATION_TXID"
    pass "Verified revocation in mempool"

    mine_blocks 1 "confirm revocation"
    cache_block_hash "REVOKING"
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Verified REVOKING state"

    cache_block_hash "REVOKED_CONFIRMED"
    verify_mempool_empty
    pass "Verified mempool empty after confirmation"
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Verified still REVOKING (waiting for revocation delay)"

    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "REVOKED_ACTIVE"
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Verified REVOKED state"

    local opreturn=$(parse_assignment_opreturn "$REVOCATION_TXID")
    if [[ ! "$opreturn" =~ ^6a1858434f50 ]]; then
        fail "Invalid OP_RETURN format (should start with OP_RETURN + XCOP)"
    fi
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
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR"
    pass "Rolled back REVOKED → REVOKING"

    echo ""
    echo "Step 2: REVOKING → ASSIGNED"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "revocation confirmation"
    verify_mempool_contains "$REVOCATION_TXID"
    pass "Revocation back in mempool"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Rolled back REVOKING → ASSIGNED"

    echo ""
    echo "Step 3: ASSIGNED → ASSIGNING"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}" "assignment activation"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR"
    pass "Rolled back ASSIGNED → ASSIGNING"

    echo ""
    echo "Step 4: ASSIGNING → UNASSIGNED"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    verify_mempool_contains "$ASSIGNMENT_TXID"
    pass "Assignment back in mempool"
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Rolled back ASSIGNING → UNASSIGNED"

    echo ""
    echo "Step 5: Reconsidering all blocks back to REVOKED state"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}"          "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}"    "assignment activation"
    reconsider_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}"  "revocation confirmation"
    reconsider_block "${BLOCK_HASHES[REVOKED_ACTIVE]}"     "revocation activation"
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Reconsidered back to REVOKED state"

    echo "  Ending height: $(get_block_count)"
}

phase5_multi_state_rollback() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Multi-State Rollback"
    echo "=========================================="

    echo "Step 1: REVOKED → ASSIGNED (multi-block jump)"
    invalidate_block "${BLOCK_HASHES[REVOKED_CONFIRMED]}" "jump to ASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR"
    pass "Jumped REVOKED → ASSIGNED"

    echo ""
    echo "Step 2: ASSIGNED → UNASSIGNED (multi-block jump)"
    invalidate_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    invalidate_block "${BLOCK_HASHES[ASSIGNING]}" "assignment mempool"
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Jumped ASSIGNED → UNASSIGNED"

    echo ""
    echo "Step 3: UNASSIGNED → REVOKED (reconsider with descendants)"
    reconsider_block "${BLOCK_HASHES[ASSIGNING]}"          "assignment mempool"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_CONFIRMED]}" "assignment confirmation"
    reconsider_block "${BLOCK_HASHES[ASSIGNED_ACTIVE]}"    "assignment activation"
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR"
    pass "Jumped UNASSIGNED → REVOKED (with descendants)"
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

    verify_assignment_status_at_height "$PLOT_ADDR" "UNASSIGNED" ""            "$u";  pass "UNASSIGNED @ $u"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING"  "$FORGE_ADDR" "$as"; pass "ASSIGNING @ $as"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED"   "$FORGE_ADDR" "$ad"; pass "ASSIGNED @ $ad"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING"   "$FORGE_ADDR" "$rg"; pass "REVOKING @ $rg"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED"    "$FORGE_ADDR" "$rd"; pass "REVOKED @ $rd"
}

echo "Assignment Lifecycle Test (v2)"
echo "Assignment delay: $ASSIGNMENT_DELAY, Revocation delay: $REVOCATION_DELAY"

phase1_setup
phase2_assignment
phase3_revocation
phase4_single_state_rollback
phase5_multi_state_rollback
phase6_historic_verification

regtestv2_stop
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "✓ ALL LIFECYCLE TESTS PASSED"
