#!/bin/bash
# Regtestv2: two consecutive assignment cycles + historical state queries.
# Cycle 1: UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED
# Cycle 2: ASSIGNING → ASSIGNED → REVOKING → REVOKED

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-double-cycle"

# Network parameters (regtest chainparams)
ASSIGNMENT_DELAY=4
REVOCATION_DELAY=8

declare -A BLOCK_HASHES
ASSIGNMENT_TXID_1=""; REVOCATION_TXID_1=""
ASSIGNMENT_TXID_2=""; REVOCATION_TXID_2=""
PLOT_ADDR=""; FORGE_ADDR_1=""; FORGE_ADDR_2=""; MINING_ADDR=""
TESTS_PASSED=0

pass() { echo "  ✓ $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  ✗ FAILED: $1"; regtestv2_stop; exit 1; }

get_block_count()   { $CLI getblockcount; }
get_block_hash()    { $CLI getblockhash "$1"; }
get_block_height()  { $CLI getblockheader "$1" | jq -r '.height'; }

cache_block_hash() {
    local name=$1
    local h
    h=$(get_block_count)
    local hash
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
    [ "$state" = "$exp_state" ] || fail "At height $height: Expected state '$exp_state', got '$state'"
    if [ -n "$exp_forge" ] && [ "$forge" != "$exp_forge" ]; then
        fail "At height $height: Expected forge '$exp_forge', got '$forge'"
    fi
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
    FORGE_ADDR_1=$($WCLI getnewaddress "" "bech32")
    FORGE_ADDR_2=$($WCLI getnewaddress "" "bech32")
    echo "  Plot address:    $PLOT_ADDR"
    echo "  Forge address 1: $FORGE_ADDR_1"
    echo "  Forge address 2: $FORGE_ADDR_2"

    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding cycle 1"
    $CLI waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
    pass "Funded plot address (cycle 1)"

    cache_block_hash "C1_UNASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "UNASSIGNED" ""
    pass "Verified UNASSIGNED state"
}

phase2_cycle1_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Cycle 1 - Assignment"
    echo "=========================================="
    local result=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR_1" 0.0001)
    ASSIGNMENT_TXID_1=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID_1"
    pass "Created assignment tx (cycle 1)"

    mine_blocks 1 "confirm assignment"
    cache_block_hash "C1_ASSIGNING"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_1"
    pass "Verified ASSIGNING state (cycle 1)"

    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "C1_ASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_1"
    pass "Verified ASSIGNED state (cycle 1)"
}

phase3_cycle1_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Cycle 1 - Revocation"
    echo "=========================================="
    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $CLI waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address (cycle 1 revocation)"

    local result=$($WCLI revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID_1=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID_1"
    pass "Created revocation tx (cycle 1)"

    mine_blocks 1 "confirm revocation"
    cache_block_hash "C1_REVOKING"
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_1"
    pass "Verified REVOKING state (cycle 1)"

    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "C1_REVOKED"
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_1"
    pass "Verified REVOKED state (cycle 1)"
}

phase4_cycle2_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Cycle 2 - Assignment"
    echo "=========================================="
    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm funding cycle 2"
    mine_blocks 1 "ensure maturity"
    $CLI waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Funded plot address (cycle 2)"

    local result=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR_2" 0.0001)
    ASSIGNMENT_TXID_2=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID_2"
    pass "Created assignment tx (cycle 2)"

    mine_blocks 1 "confirm assignment"
    cache_block_hash "C2_ASSIGNING"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_2"
    pass "Verified ASSIGNING state (cycle 2)"

    mine_blocks $ASSIGNMENT_DELAY "activation delay"
    cache_block_hash "C2_ASSIGNED"
    verify_assignment_status "$PLOT_ADDR" "ASSIGNED" "$FORGE_ADDR_2"
    pass "Verified ASSIGNED state (cycle 2)"
}

phase5_cycle2_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Cycle 2 - Revocation"
    echo "=========================================="
    HEIGHT=$(get_block_count)
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks 1 "ensure maturity"
    $CLI waitforblockheight $((HEIGHT + 2)) 10000 >/dev/null
    pass "Refunded plot address (cycle 2 revocation)"

    local result=$($WCLI revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID_2=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID_2"
    pass "Created revocation tx (cycle 2)"

    mine_blocks 1 "confirm revocation"
    cache_block_hash "C2_REVOKING"
    verify_assignment_status "$PLOT_ADDR" "REVOKING" "$FORGE_ADDR_2"
    pass "Verified REVOKING state (cycle 2)"

    mine_blocks $REVOCATION_DELAY "revocation delay"
    cache_block_hash "C2_REVOKED"
    verify_assignment_status "$PLOT_ADDR" "REVOKED" "$FORGE_ADDR_2"
    pass "Verified REVOKED state (cycle 2)"
}

phase6_historic_verification() {
    echo ""
    echo "=========================================="
    echo "Phase 6: Historic State Verification"
    echo "=========================================="
    local c1u=$(get_block_height "${BLOCK_HASHES[C1_UNASSIGNED]}")
    local c1as=$(get_block_height "${BLOCK_HASHES[C1_ASSIGNING]}")
    local c1ad=$(get_block_height "${BLOCK_HASHES[C1_ASSIGNED]}")
    local c1rg=$(get_block_height "${BLOCK_HASHES[C1_REVOKING]}")
    local c1rd=$(get_block_height "${BLOCK_HASHES[C1_REVOKED]}")
    local c2as=$(get_block_height "${BLOCK_HASHES[C2_ASSIGNING]}")
    local c2ad=$(get_block_height "${BLOCK_HASHES[C2_ASSIGNED]}")
    local c2rg=$(get_block_height "${BLOCK_HASHES[C2_REVOKING]}")
    local c2rd=$(get_block_height "${BLOCK_HASHES[C2_REVOKED]}")

    verify_assignment_status_at_height "$PLOT_ADDR" "UNASSIGNED" "" "$c1u";    pass "C1 UNASSIGNED @ $c1u"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_1" "$c1as"; pass "C1 ASSIGNING @ $c1as"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED"  "$FORGE_ADDR_1" "$c1ad"; pass "C1 ASSIGNED @ $c1ad"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING"  "$FORGE_ADDR_1" "$c1rg"; pass "C1 REVOKING @ $c1rg"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED"   "$FORGE_ADDR_1" "$c1rd"; pass "C1 REVOKED @ $c1rd"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNING" "$FORGE_ADDR_2" "$c2as"; pass "C2 ASSIGNING @ $c2as"
    verify_assignment_status_at_height "$PLOT_ADDR" "ASSIGNED"  "$FORGE_ADDR_2" "$c2ad"; pass "C2 ASSIGNED @ $c2ad"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKING"  "$FORGE_ADDR_2" "$c2rg"; pass "C2 REVOKING @ $c2rg"
    verify_assignment_status_at_height "$PLOT_ADDR" "REVOKED"   "$FORGE_ADDR_2" "$c2rd"; pass "C2 REVOKED @ $c2rd"
}

echo "Double Assignment Cycle Test (v2)"
echo "Assignment delay: $ASSIGNMENT_DELAY blocks"
echo "Revocation delay: $REVOCATION_DELAY blocks"

phase1_setup
phase2_cycle1_assignment
phase3_cycle1_revocation
phase4_cycle2_assignment
phase5_cycle2_revocation
phase6_historic_verification

regtestv2_stop
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "✓ ALL DOUBLE-CYCLE TESTS PASSED"
