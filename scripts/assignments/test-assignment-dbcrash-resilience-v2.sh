#!/bin/bash
# Regtestv2: forging-assignment DB crash-recovery.
#
# Two nodes side by side:
#   Node1 (operator): clean, drives the chain via the wallet.
#   Node2 (validator): started with -dbcrashratio, -dbcache, -dbbatchsize so
#                      that BatchWrite flushes frequent intermediate batches
#                      and is randomly _Exit(0)-ed mid-flush.
#
# Every block Node1 mines is pushed to Node2 via submitblock. If Node2 is
# down (from -dbcrashratio) the push retries after restarting it. After
# many assign/revoke cycles plus coin-churn spam, the script compares
# get_assignment output on each plot between Node1 and Node2 — they must
# match byte-for-byte. Best block hash and tip height must also match.
#
# Why this exercises the fix: -dbcrashratio's _Exit(0) fires after an
# intermediate batch in CCoinsViewDB::BatchWrite, leaving DB_HEAD_BLOCKS
# on disk and the final batch (with DB_BEST_BLOCK and now the assignment
# updates) unwritten. On restart, HEAD_BLOCKS recovery triggers
# Chainstate::ReplayBlocks → RollforwardBlock. Pre-fix, RollforwardBlock
# only re-applied coin ops and the assignment DB stayed stale forever.
# Post-fix, RollforwardBlock re-applies assignment OP_RETURNs and state
# converges, so this script PASSes; pre-fix it FAILs on the final
# get_assignment compare.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

NODE1_DATADIR="$HOME/.bitcoin-pocx/regtestv2-dbcrash-node1"
NODE1_PORT=18554
NODE1_RPCPORT=18553
NODE2_DATADIR="$HOME/.bitcoin-pocx/regtestv2-dbcrash-node2"
NODE2_PORT=18556
NODE2_RPCPORT=18555

# Test knobs (override via env).
CYCLES=${CYCLES:-20}
NUM_PLOTS=${NUM_PLOTS:-3}
DBCRASHRATIO=${DBCRASHRATIO:-8}
DBCACHE=${DBCACHE:-4}
DBBATCHSIZE=${DBBATCHSIZE:-200000}
SPAM_TXS_PER_BLOCK=${SPAM_TXS_PER_BLOCK:-40}

# Regtest consensus delays — kept here for clarity, not actually queried.
ASSIGNMENT_DELAY=4
REVOCATION_DELAY=8

TESTS_PASSED=0
declare -a PLOTS FORGES
SINK=""

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

start_node2() {
    $BITCOIND -regtest -datadir="$NODE2_DATADIR" \
        -port="$NODE2_PORT" -rpcport="$NODE2_RPCPORT" \
        -bind=127.0.0.1:$NODE2_PORT \
        -fallbackfee=0.00001 -daemon \
        -dbcrashratio="$DBCRASHRATIO" -dbcache="$DBCACHE" -dbbatchsize="$DBBATCHSIZE" \
        >/dev/null

    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if cli_node2 getblockchaininfo >/dev/null 2>&1; then
            # Park Node2's clock far ahead so propagated blocks always satisfy
            # MAX_FUTURE_BLOCK_TIME without per-block mocktime sync.
            cli_node2 setmocktime "$(( $(date +%s) + 365*24*3600 ))" >/dev/null 2>&1 || true
            return 0
        fi
        sleep 1
    done
    return 1
}

# Push everything Node1 has past Node2's tip via submitblock. If Node2 is
# down (likely from -dbcrashratio), restart and retry. This is the recovery
# stress loop — Node2 may crash repeatedly during this function.
sync_node2() {
    local target current h1 h2 h hash blockhex tries
    target=$(cli_node1 getbestblockhash)
    current=$(cli_node2 getbestblockhash 2>/dev/null || echo NONE)
    [ "$target" = "$current" ] && return 0

    h1=$(cli_node1 getblockcount)
    h2=$(cli_node2 getblockcount 2>/dev/null || echo 0)

    for h in $(seq $((h2 + 1)) "$h1"); do
        hash=$(cli_node1 getblockhash "$h")
        blockhex=$(cli_node1 getblock "$hash" 0)
        tries=0
        while ! cli_node2 submitblock "$blockhex" >/dev/null 2>&1; do
            tries=$((tries + 1))
            if [ "$tries" -gt 60 ]; then
                fail "Node2 refuses block $h after $tries attempts"
            fi
            sleep 0.5
            if ! cli_node2 getblockcount >/dev/null 2>&1; then
                echo "  💥 Node2 down (dbcrashratio), restart attempt $tries"
                start_node2 || fail "Node2 failed to restart"
            fi
        done
    done
}

# Small wallet txs to inflate the coin batch and increase crash frequency
# inside CCoinsViewDB::BatchWrite.
spam_txs() {
    local i addr
    for i in $(seq 1 "$SPAM_TXS_PER_BLOCK"); do
        addr=$(wcli1 getnewaddress "" bech32)
        wcli1 sendtoaddress "$addr" 0.0001 >/dev/null 2>&1 || true
    done
}

# Phase 1: top up plot UTXOs so the next assign/revoke tx can spend from
# the plot address (ownership proof).
plot_phase1() {
    local plot="$1" state
    state=$(cli_node1 get_assignment "$plot" 2>/dev/null | jq -r '.state // "UNASSIGNED"')
    case "$state" in
        UNASSIGNED|REVOKED|ASSIGNED)
            wcli1 sendtoaddress "$plot" 1.0 >/dev/null 2>&1 || true
            ;;
    esac
}

# Phase 2: issue the assign or revoke tx, depending on current state.
# ASSIGNING / REVOKING means we're inside the delay window — skip.
plot_phase2() {
    local plot="$1" forge="$2" state
    state=$(cli_node1 get_assignment "$plot" 2>/dev/null | jq -r '.state // "UNASSIGNED"')
    case "$state" in
        UNASSIGNED|REVOKED)
            wcli1 create_assignment "$plot" "$forge" >/dev/null 2>&1 || true
            ;;
        ASSIGNED)
            wcli1 revoke_assignment "$plot" >/dev/null 2>&1 || true
            ;;
    esac
}

# ============================================================================
# Setup
# ============================================================================

setup_nodes() {
    echo "=========================================="
    echo "Setup: starting both nodes"
    echo "=========================================="

    pkill -9 bitcoind 2>/dev/null || true
    sleep 1
    rm -rf "$NODE1_DATADIR" "$NODE2_DATADIR"
    mkdir -p "$NODE1_DATADIR" "$NODE2_DATADIR"

    echo "Starting Node1 (operator) on port $NODE1_PORT / rpc $NODE1_RPCPORT..."
    $BITCOIND -regtest -datadir="$NODE1_DATADIR" \
        -port="$NODE1_PORT" -rpcport="$NODE1_RPCPORT" \
        -bind=127.0.0.1:$NODE1_PORT \
        -fallbackfee=0.00001 -daemon \
        -dbbatchsize="$DBBATCHSIZE" \
        -limitancestorcount=200 -limitdescendantcount=200 >/dev/null

    echo "Starting Node2 (validator) on port $NODE2_PORT / rpc $NODE2_RPCPORT"
    echo "  (dbcrashratio=$DBCRASHRATIO dbcache=$DBCACHE dbbatchsize=$DBBATCHSIZE)..."
    start_node2 || fail "Node2 failed to start"

    local i
    for i in 1 2 3 4 5; do
        cli_node1 getblockchaininfo >/dev/null 2>&1 && break
        sleep 1
    done

    cli_node1 setmocktime "$(date +%s)" >/dev/null
    cli_node1 createwallet test >/dev/null
    pass "Node1 wallet loaded"
    pass "Node2 running (no wallet, query-only)"
}

setup_plots() {
    echo ""
    echo "=========================================="
    echo "Setup: addresses + initial funding"
    echo "=========================================="

    SINK=$(wcli1 getnewaddress "" bech32)
    local i
    for i in $(seq 0 $((NUM_PLOTS - 1))); do
        PLOTS[i]=$(wcli1 getnewaddress "" bech32)
        FORGES[i]=$(wcli1 getnewaddress "" bech32)
        echo "  plot[$i]  = ${PLOTS[$i]}"
        echo "  forge[$i] = ${FORGES[$i]}"
    done

    echo "  ⛏️  Mining 110 blocks for spendable balance..."
    cli_node1 generatetoaddress 110 "$SINK" >/dev/null

    for i in $(seq 0 $((NUM_PLOTS - 1))); do
        wcli1 sendtoaddress "${PLOTS[$i]}" 5.0 >/dev/null
    done
    cli_node1 generatetoaddress 1 "$SINK" >/dev/null

    echo "  ⏩ Initial sync to Node2..."
    sync_node2
    pass "Both nodes at height $(cli_node1 getblockcount), plots funded"
}

# ============================================================================
# Main: assignment lifecycle cycles
# ============================================================================

run_cycles() {
    echo ""
    echo "=========================================="
    echo "Cycling $CYCLES times across $NUM_PLOTS plots"
    echo "=========================================="

    local cycle i
    for cycle in $(seq 1 "$CYCLES"); do
        echo "Cycle $cycle / $CYCLES (tip=$(cli_node1 getblockcount))"

        for i in $(seq 0 $((NUM_PLOTS - 1))); do
            plot_phase1 "${PLOTS[$i]}"
        done
        spam_txs
        cli_node1 generatetoaddress 1 "$SINK" >/dev/null

        for i in $(seq 0 $((NUM_PLOTS - 1))); do
            plot_phase2 "${PLOTS[$i]}" "${FORGES[$i]}"
        done
        spam_txs
        # 5 blocks advances assignments past activation (delay 4) and
        # revocations partway through their delay (8); over the run plots
        # cycle through all five ForgingState values.
        cli_node1 generatetoaddress 5 "$SINK" >/dev/null

        sync_node2
    done
}

# ============================================================================
# Verification
# ============================================================================

compare_state() {
    echo ""
    echo "=========================================="
    echo "Final comparison"
    echo "=========================================="

    local h1 h2 hash1 hash2
    h1=$(cli_node1 getblockcount)
    h2=$(cli_node2 getblockcount)
    hash1=$(cli_node1 getbestblockhash)
    hash2=$(cli_node2 getbestblockhash)
    echo "  Node1: height=$h1 best=${hash1:0:16}..."
    echo "  Node2: height=$h2 best=${hash2:0:16}..."
    [ "$h1" = "$h2" ]       || fail "tip height diverged"
    [ "$hash1" = "$hash2" ] || fail "best block hash diverged"
    pass "Tip height and best hash match"

    local i plot a b
    local diverged=0
    for i in $(seq 0 $((NUM_PLOTS - 1))); do
        plot="${PLOTS[$i]}"
        a=$(cli_node1 get_assignment "$plot" 2>/dev/null | jq -S .)
        b=$(cli_node2 get_assignment "$plot" 2>/dev/null | jq -S .)
        if [ "$a" != "$b" ]; then
            echo "  ✗ MISMATCH plot $plot"
            diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") || true
            diverged=1
        else
            local summary
            summary=$(echo "$a" | jq -c '{state, has_assignment, revoked}')
            pass "plot $plot: $summary"
        fi
    done

    [ "$diverged" -eq 0 ] || fail "assignment-DB state diverged on $diverged plot(s)"
}

# ============================================================================
# Main
# ============================================================================

setup_nodes
setup_plots
run_cycles
compare_state

echo ""
echo "=========================================="
echo "RESULT: PASS ($TESTS_PASSED checks)"
echo "=========================================="
exit 0
