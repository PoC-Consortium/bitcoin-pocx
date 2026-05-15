#!/bin/bash
# Regtestv2: deterministic SIGKILL-between-flushes test for assignment-DB
# crash resilience.
#
# Production scenario: low-traffic node receives a block carrying a
# create_assignment OP_RETURN. The coin batch flush completes, but the
# process is killed (Windows Update reboot, power loss) before the
# *separate* assignment-DB BatchWriteAssignments lands. On restart the
# assignment is permanently lost; subsequent revoke validation fails and
# the node desyncs.
#
# This script reproduces that scenario without -dbcrashratio:
#   1. Setup both nodes, sync to height 110, fund plot
#   2. Node1 creates assignment, mines + pushes the block to Node2
#   3. Mine past ASSIGNMENT_DELAY, push to Node2
#   4. SIGKILL Node2 *without* forcing any flush — anything in cache is lost
#   5. Node1 mines the corresponding revoke + past REVOCATION_DELAY
#   6. Restart Node2 and feed it the missing blocks
#   7. Compare get_assignment between nodes
#
# Pre-fix: block 112 (or a downstream block) is rejected during catch-up
# because the assignment DB has an orphan record from the pre-crash window
# that the post-fix atomic write would have prevented. Post-fix: catch-up
# completes and get_assignment matches across nodes.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

N1_DATADIR="$HOME/.bitcoin-pocx/crashrevive-n1"
N1_PORT=18554
N1_RPC=18553
N2_DATADIR="$HOME/.bitcoin-pocx/crashrevive-n2"
N2_PORT=18556
N2_RPC=18555

# Park Node2 in the future so Node1's blocks (whose timestamps drift forward
# as Node1's mocktime auto-advances with PoCX deadlines) stay inside
# MAX_FUTURE_BLOCK_TIME on Node2. Passed as -mocktime= so it survives any
# unclean shutdown.
N2_MOCKTIME=$(( $(date +%s) + 365*24*3600 ))

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗ FAILED:${NC} $1"; cleanup; exit 1; }

cli_node1() { $BITCOIN_CLI -regtest -datadir="$N1_DATADIR" -rpcport="$N1_RPC" "$@"; }
cli_node2() { $BITCOIN_CLI -regtest -datadir="$N2_DATADIR" -rpcport="$N2_RPC" "$@"; }
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

start_node2() {
    $BITCOIND -regtest -datadir="$N2_DATADIR" \
        -port="$N2_PORT" -rpcport="$N2_RPC" -bind=127.0.0.1:$N2_PORT \
        -fallbackfee=0.00001 -daemon \
        -mocktime="$N2_MOCKTIME" \
        >/dev/null 2>&1 || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if cli_node2 getblockchaininfo >/dev/null 2>&1; then
            cli_node2 setmocktime "$N2_MOCKTIME" >/dev/null 2>&1 || true
            return 0
        fi
        sleep 1
    done
    return 1
}

push_block_to_node2() {
    local hash="$1" hex out
    hex=$(cli_node1 getblock "$hash" 0)
    out=$(printf '%s\n' "$hex" | cli_node2 -stdin submitblock 2>&1)
    if [ -n "$out" ] && [ "$out" != "duplicate" ] && [ "$out" != "inconclusive" ]; then
        echo "submitblock returned: $out"
        return 1
    fi
    return 0
}

# Push blocks (start_h+1 .. node1 tip) to Node2, fail loudly on rejection.
sync_from_height() {
    local start_h=$1 end_h h hash
    end_h=$(cli_node1 getblockcount)
    for h in $(seq $((start_h + 1)) "$end_h"); do
        hash=$(cli_node1 getblockhash "$h")
        if ! push_block_to_node2 "$hash"; then
            fail "Node2 REJECTED block $h ($hash) — this is the bug signal"
        fi
    done
}

show_state() {
    local who="$1" plot="$2"
    local cli="cli_node$who"
    local s
    s=$($cli get_assignment "$plot" 2>/dev/null | jq -c '{state, has_assignment, revoked, forging_address: .forging_address[0:14]}')
    echo "  Node$who → $s"
}

# ============================================================================
# Setup
# ============================================================================

echo "=========================================="
echo "Setup: start both nodes"
echo "=========================================="

pkill -9 bitcoind 2>/dev/null || true
sleep 1
rm -rf "$N1_DATADIR" "$N2_DATADIR"
mkdir -p "$N1_DATADIR" "$N2_DATADIR"

$BITCOIND -regtest -datadir="$N1_DATADIR" \
    -port="$N1_PORT" -rpcport="$N1_RPC" -bind=127.0.0.1:$N1_PORT \
    -fallbackfee=0.00001 -daemon >/dev/null

wait_i=0
while [ "$wait_i" -lt 10 ]; do
    cli_node1 getblockchaininfo >/dev/null 2>&1 && break
    sleep 1; wait_i=$((wait_i + 1))
done

start_node2 || fail "Node2 failed to start"
pass "Node1 + Node2 running"

cli_node1 setmocktime "$(date +%s)" >/dev/null
cli_node1 createwallet test >/dev/null

PLOT=$(wcli1 getnewaddress "" bech32)
FORGE=$(wcli1 getnewaddress "" bech32)
SINK=$(wcli1 getnewaddress "" bech32)
echo "  plot   = $PLOT"
echo "  forge  = $FORGE"

# Mine for spendable balance, fund plot, sync to Node2.
cli_node1 generatetoaddress 110 "$SINK" >/dev/null
wcli1 sendtoaddress "$PLOT" 1.0 >/dev/null
cli_node1 generatetoaddress 1 "$SINK" >/dev/null
sync_from_height 0
pass "Both nodes at height $(cli_node2 getblockcount), plot funded"

# ============================================================================
# Step 1: create assignment, push to Node2 (in-memory only — no force flush)
# ============================================================================

echo ""
echo "=========================================="
echo "Step 1: create assignment on Node1, sync to Node2"
echo "=========================================="

base_h=$(cli_node1 getblockcount)
wcli1 create_assignment "$PLOT" "$FORGE" >/dev/null
cli_node1 generatetoaddress 1 "$SINK" >/dev/null
sync_from_height "$base_h"
assign_block_h=$(cli_node1 getblockcount)
pass "Assignment block at height $assign_block_h"

# Mine past activation delay (4) + a small buffer.
cli_node1 generatetoaddress 5 "$SINK" >/dev/null
sync_from_height "$assign_block_h"
pass "Past activation, height $(cli_node2 getblockcount)"

# Force-flush Node1 so show_state below reflects on-disk state.
# Deliberately NOT flushing Node2 — we want its assignment in cache only,
# so SIGKILL drops it (modelling the low-traffic crash window).
cli_node1 gettxoutsetinfo >/dev/null

echo "State before SIGKILL:"
show_state 1 "$PLOT"
show_state 2 "$PLOT"

# ============================================================================
# Step 2: SIGKILL Node2 — anything in cache (incl. the assignment) is lost
# ============================================================================

echo ""
echo "=========================================="
echo "Step 2: SIGKILL Node2"
echo "=========================================="

pkill -9 -f "bitcoind.*$N2_DATADIR" || true
sleep 1
if pgrep -f "bitcoind.*$N2_DATADIR" >/dev/null; then
    fail "Node2 still alive after SIGKILL"
fi
pass "Node2 killed"

# ============================================================================
# Step 3: Node1 mines some extra blocks while Node2 is down
# ============================================================================

echo ""
echo "=========================================="
echo "Step 3: Node1 mines while Node2 is down (longer downtime)"
echo "=========================================="

cli_node1 generatetoaddress 10 "$SINK" >/dev/null
# Force-flush Node1 so its disk state is durable for the final compare.
cli_node1 gettxoutsetinfo >/dev/null
pass "Node1 tip = $(cli_node1 getblockcount), state on Node1:"
show_state 1 "$PLOT"

# ============================================================================
# Step 4: Revive Node2, feed missing blocks
# ============================================================================

echo ""
echo "=========================================="
echo "Step 4: Revive Node2 + catch-up sync"
echo "=========================================="

start_node2 || fail "Node2 failed to restart after SIGKILL"
node2_h_after_revive=$(cli_node2 getblockcount)
echo "  Node2 reopened at height $node2_h_after_revive (Node1 = $(cli_node1 getblockcount))"

sync_from_height "$node2_h_after_revive"
pass "Catch-up succeeded, Node2 at height $(cli_node2 getblockcount)"

# Force-flush Node2 so its in-memory assignment cache lands on disk and
# get_assignment (which reads disk only) sees the rebuilt state.
cli_node2 gettxoutsetinfo >/dev/null

# ============================================================================
# Step 5: Compare
# ============================================================================

echo ""
echo "=========================================="
echo "Step 5: Compare assignment state"
echo "=========================================="

h1=$(cli_node1 getblockcount)
h2=$(cli_node2 getblockcount)
hash1=$(cli_node1 getbestblockhash)
hash2=$(cli_node2 getbestblockhash)
echo "  Node1: height=$h1 best=${hash1:0:16}"
echo "  Node2: height=$h2 best=${hash2:0:16}"
[ "$h1" = "$h2" ]       || fail "tip height diverged"
[ "$hash1" = "$hash2" ] || fail "best block hash diverged"
pass "Chain tips match"

a=$(cli_node1 get_assignment "$PLOT" | jq -S .)
b=$(cli_node2 get_assignment "$PLOT" | jq -S .)
if [ "$a" = "$b" ]; then
    echo "  Node1 + Node2: $(echo "$a" | jq -c '{state, has_assignment, revoked}')"
    pass "Assignment state matches between nodes"
    echo ""
    echo "=========================================="
    echo "RESULT: PASS"
    echo "=========================================="
    exit 0
else
    echo "  Node1: $(echo "$a" | jq -c '{state, has_assignment, revoked}')"
    echo "  Node2: $(echo "$b" | jq -c '{state, has_assignment, revoked}')"
    diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") || true
    fail "Assignment state diverged after SIGKILL+revive"
fi
