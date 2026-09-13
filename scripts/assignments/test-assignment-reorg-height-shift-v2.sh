#!/bin/bash
# Regtestv2: reorg that re-mines an assignment tx at a DIFFERENT height.
#
# Production scenario: an assignment tx T is confirmed at height N and the
# chainstate is written to disk (periodic write, cache pressure, or a clean
# shutdown). The block at N is then orphaned and T is re-mined on the winning
# branch at another height. The cache identifies assignment rows by
# (plot, txid) while the DB keys them by (plot, height, txid); re-adding T
# cancels the pending deletion of the old row, so the old DB row is never
# erased and the plot ends up with two rows for one txid.
#
# Direction "later"   (common 1-block orphan, T lands 2 blocks higher):
#   the stale LOWER row is dormant while T is canonical, then survives when
#   T is later dropped from the chain -> node believes an assignment that the
#   chain does not have.
# Direction "earlier" (longer competing branch, T lands 1 block lower):
#   the stale HIGHER row wins the lookup immediately -> activation height is
#   off by one and the node disagrees with the network about the signer for
#   one block.
#
# Each direction runs twice: with the node kept up between the disk write
# and the reorg, and with a full stop/start in between (the most likely way a
# mainnet node gets the on-disk precondition). Each scenario ends with a
# -reindex-chainstate rebuild as an implementation-independent oracle.
#
# Pre-fix: the explicit checks fail. Post-fix: everything passes and the
# reindexed state equals the live state at every height.
#
# Run from the repository root. Overridable for non-standard builds:
#   BITCOIN_CLI / BITCOIND  path to binaries
#   DATADIR                 regtest datadir (recreated per scenario)
#   SCENARIOS               subset to run, e.g. "later:no earlier:yes"
#   CONTINUE_ON_FAIL=1      record assertion failures instead of exiting

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="${BITCOIN_CLI:-$BITCOIN_DIR/build/bin/bitcoin-cli}"
BITCOIND="${BITCOIND:-$BITCOIN_DIR/build/bin/bitcoind}"
DATADIR="${DATADIR:-$HOME/.bitcoin-pocx/regtestv2-reorg-height-shift}"
WALLET="test"

ASSIGNMENT_DELAY=4

CLI=""; WCLI=""
PLOT_ADDR=""; FORGE_ADDR=""; MINING_ADDR=""
TESTS_PASSED=0
SCENARIO=""

TESTS_FAILED=0
GROUP_FAILED=0

pass() {
    if [ "$GROUP_FAILED" = "1" ]; then
        echo "  – $1 (not counted: failures above)"
        GROUP_FAILED=0
        return 0
    fi
    echo "  ✓ $1"; TESTS_PASSED=$((TESTS_PASSED + 1))
}
# Assertion failure. Exits unless CONTINUE_ON_FAIL=1, which records it and
# carries on so the full pre-fix failure pattern is visible in one run.
fail() {
    echo "  ✗ FAILED [$SCENARIO]: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    GROUP_FAILED=1
    if [ -n "$PLOT_ADDR" ] && [ -n "$CLI" ]; then
        echo "  get_assignment at tip:"
        $CLI get_assignment "$PLOT_ADDR" 2>/dev/null | jq -c . | sed 's/^/    /' || true
    fi
    [ "${CONTINUE_ON_FAIL:-0}" = "1" ] && return 0
    stop_node
    exit 1
}
# Harness failure (node down etc.): always exits.
fatal() {
    echo "  ✗ FATAL [$SCENARIO]: $1"
    stop_node
    exit 1
}

# ----------------------------------------------------------------------------
# Node lifecycle (own helpers: the restart variants need start/stop without
# wiping the datadir, which setup-regtestv2.sh does not offer)
# ----------------------------------------------------------------------------

wait_for_rpc() {
    local i
    for i in $(seq 1 30); do
        $CLI getblockchaininfo >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

# PoCX regtest auto-advances mocktime with forging deadlines, so block times
# run ahead of the wall clock. A restart must therefore pin -mocktime at or
# after the tip time, or startup aborts with "block appears to be from the
# future" (same trick as test-assignment-crash-revive-v2.sh).
NODE_PID=""
MOCKTIME=""

start_node() {
    # extra args: e.g. -reindex-chainstate
    local args=(-regtest -datadir="$DATADIR" -fallbackfee=0.00001 "$@")
    [ -n "$MOCKTIME" ] && args+=(-mocktime="$MOCKTIME")
    if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
        "$BITCOIND" "${args[@]}" >/dev/null 2>&1 &
        NODE_PID=$!
    else
        $BITCOIND "${args[@]}" -daemon >/dev/null
    fi
    CLI="$BITCOIN_CLI -regtest -datadir=$DATADIR"
    WCLI="$CLI -rpcwallet=$WALLET"
    wait_for_rpc || fatal "bitcoind did not come up"
    if [ -n "$MOCKTIME" ]; then
        $CLI setmocktime "$MOCKTIME" >/dev/null
    else
        # Fresh chain: align mocktime with wall clock (see setup-regtestv2.sh).
        $CLI setmocktime "$(date +%s)" >/dev/null
    fi
}

stop_node() {
    [ -z "$CLI" ] && return 0
    $CLI stop >/dev/null 2>&1 || true
    local i
    for i in $(seq 1 60); do
        $CLI getblockcount >/dev/null 2>&1 || break
        sleep 1
    done
    if [ -n "$NODE_PID" ]; then
        wait "$NODE_PID" 2>/dev/null || true
        NODE_PID=""
    else
        # -daemon: the pid file disappears when the process has fully exited.
        for i in $(seq 1 60); do
            [ -e "$DATADIR/regtest/bitcoind.pid" ] || break
            sleep 1
        done
    fi
}

restart_node() {
    # $1 = description, remaining args passed to bitcoind (e.g. -reindex-chainstate)
    local desc=$1; shift
    echo "  🔁 Restarting node ($desc)..."
    MOCKTIME=$(( $($CLI getblockchaininfo | jq -r '.time') + 1 ))
    stop_node
    start_node "$@"
    $WCLI getwalletinfo >/dev/null 2>&1 || $CLI loadwallet "$WALLET" >/dev/null
}

fresh_node() {
    pkill -9 bitcoind 2>/dev/null || true
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR"
    MOCKTIME=""
    start_node
    $CLI createwallet "$WALLET" >/dev/null
}

# ----------------------------------------------------------------------------
# Chain helpers
# ----------------------------------------------------------------------------

get_block_count() { $CLI getblockcount; }
get_block_hash()  { $CLI getblockhash "$1"; }

mine_blocks() {
    local count=$1 desc=$2
    [ -n "$desc" ] && echo "  ⛏️  Mining $count blocks ($desc)..."
    $CLI generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

# Mine exactly one block containing only the listed mempool txids ('[]' = coinbase only).
mine_block_with() {
    local txs=$1 desc=$2
    echo "  ⛏️  Mining 1 block with txs $txs ($desc)..."
    $CLI generateblock "$MINING_ADDR" "$txs" >/dev/null
}

# Coinbase-only blocks. Used wherever the orphaned assignment tx is sitting in
# the mempool: generatetoaddress would pull it back into a block (post-fix), or
# make block assembly throw on it (pre-fix, the stale row makes it invalid).
mine_empty_blocks() {
    local count=$1 desc=$2 i
    echo "  ⛏️  Mining $count empty blocks ($desc)..."
    for i in $(seq 1 "$count"); do
        $CLI generateblock "$MINING_ADDR" '[]' >/dev/null
    done
}

# Force the coins + assignment cache to disk (ForceFlushStateToDisk).
flush_to_disk() {
    echo "  💾 Forcing chainstate write to disk..."
    $CLI gettxoutsetinfo >/dev/null
}

invalidate_block() {
    local hash=$1 desc=$2
    echo "  ↩️  Invalidating block ${hash:0:16}... ($desc)"
    $CLI invalidateblock "$hash"
}

verify_mempool_contains() {
    local txid=$1
    $CLI getrawmempool | jq -e ". | index(\"$txid\")" >/dev/null || fail "Tx $txid not in mempool"
}

verify_tx_in_block_at_height() {
    local txid=$1 height=$2
    local hash
    hash=$(get_block_hash "$height")
    $CLI getblock "$hash" 1 | jq -e ".tx | index(\"$txid\")" >/dev/null \
        || fail "Tx ${txid:0:16}... not in block at height $height"
}

# get_assignment field at a height ("" = tip).
assignment_field() {
    local plot=$1 field=$2 height=$3
    if [ -n "$height" ]; then
        $CLI get_assignment "$plot" "$height" | jq -r ".$field"
    else
        $CLI get_assignment "$plot" | jq -r ".$field"
    fi
}

expect_field() {
    local field=$1 expected=$2 height=$3 desc=$4
    local where="tip"; [ -n "$height" ] && where="height $height"
    local actual
    actual=$(assignment_field "$PLOT_ADDR" "$field" "$height")
    [ "$actual" = "$expected" ] || fail "$desc: at $where expected $field=$expected, got $field=$actual"
}

# ----------------------------------------------------------------------------
# Oracle: rebuild the assignment DB from blocks and compare with live state
# ----------------------------------------------------------------------------

dump_assignment_states() {
    local from=$1 to=$2 h
    for h in $(seq "$from" "$to"); do
        echo "h=$h $($CLI get_assignment "$PLOT_ADDR" "$h" | jq -c -S .)"
    done
}

verify_against_reindex() {
    local from=$1
    local tip live rebuilt
    tip=$(get_block_count)
    live=$(dump_assignment_states "$from" "$tip")

    restart_node "-reindex-chainstate, rebuild assignment DB from blocks (oracle)" -reindex-chainstate
    local i
    for i in $(seq 1 60); do
        if [ "$($CLI getblockcount 2>/dev/null)" = "$tip" ] && \
           [ "$($CLI getblockchaininfo | jq -r .initialblockdownload)" = "false" ]; then
            break
        fi
        sleep 1
    done
    [ "$(get_block_count)" = "$tip" ] || fatal "reindex did not reach tip $tip"
    flush_to_disk
    rebuilt=$(dump_assignment_states "$from" "$tip")

    if [ "$live" != "$rebuilt" ]; then
        echo "  live vs rebuilt-from-blocks (heights $from..$tip):"
        diff <(printf '%s\n' "$live") <(printf '%s\n' "$rebuilt") | sed 's/^/    /' || true
        fail "assignment state differs from a fresh rebuild of the same chain"
    fi
    pass "Live assignment state equals reindex-chainstate rebuild (heights $from..$tip)"
}

# ----------------------------------------------------------------------------
# Common setup: fresh chain, funded plot address
# ----------------------------------------------------------------------------

setup_chain() {
    fresh_node
    MINING_ADDR=$($WCLI getnewaddress "" "bech32")
    $CLI generatetoaddress 101 "$MINING_ADDR" >/dev/null
    PLOT_ADDR=$($WCLI getnewaddress "" "bech32")
    FORGE_ADDR=$($WCLI getnewaddress "" "bech32")
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm plot funding"
    expect_field "has_assignment" "false" "" "setup"
    pass "Fresh chain at height $(get_block_count), plot funded, UNASSIGNED"
}

create_assignment_tx() {
    local txid
    txid=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001 | jq -r '.txid')
    verify_mempool_contains "$txid"
    echo "$txid"
}

# ----------------------------------------------------------------------------
# Scenario A: T re-mined LATER (N -> N+2)
# ----------------------------------------------------------------------------

scenario_later() {
    local restart=$1
    SCENARIO="later restart=$restart"
    echo ""
    echo "=========================================="
    echo "Scenario: T re-mined 2 blocks LATER (restart between flush and reorg: $restart)"
    echo "=========================================="
    setup_chain

    local txid n hash_n
    txid=$(create_assignment_tx)
    mine_blocks 1 "confirm assignment T"
    n=$(get_block_count); hash_n=$(get_block_hash "$n")
    verify_tx_in_block_at_height "$txid" "$n"
    expect_field "assignment_height" "$n" "" "before reorg"
    pass "T=${txid:0:16}... confirmed at height N=$n"

    flush_to_disk
    [ "$restart" = "yes" ] && restart_node "between disk write and reorg"

    invalidate_block "$hash_n" "orphan block N"
    verify_mempool_contains "$txid"
    expect_field "has_assignment" "false" "" "after disconnect"
    pass "Block N orphaned, T back in mempool, plot UNASSIGNED"

    mine_block_with '[]' "replacement block N, without T"
    mine_block_with '[]' "block N+1, without T"
    mine_block_with "[\"$txid\"]" "block N+2, T re-mined"
    verify_tx_in_block_at_height "$txid" $((n + 2))
    flush_to_disk
    pass "T re-mined at N+2=$((n + 2)) and written to disk"

    # The in-memory cache overlays DB rows by txid and can mask a stale row
    # until the cache is dropped, so every check runs warm and then cold.
    local pass_no
    for pass_no in warm cold; do
        [ "$pass_no" = "cold" ] && restart_node "drop cache before re-checking"
        echo "Check 1 ($pass_no cache): no stale row at the old height"
        expect_field "has_assignment" "false" "$n" "stale lower row ($pass_no)"
        expect_field "has_assignment" "false" $((n + 1)) "stale lower row ($pass_no)"
        pass "No assignment visible at heights N and N+1 ($pass_no cache)"

        echo "Check 2 ($pass_no cache): current row is the re-mined one"
        expect_field "assignment_txid"   "$txid"       "" "re-mined row ($pass_no)"
        expect_field "assignment_height" $((n + 2))    "" "re-mined row ($pass_no)"
        expect_field "activation_height" $((n + 2 + ASSIGNMENT_DELAY)) "" "re-mined row ($pass_no)"
        pass "Assignment at tip has height N+2 and activation N+2+$ASSIGNMENT_DELAY ($pass_no cache)"
    done

    echo "Check 3: drop T from the chain for good"
    invalidate_block "$(get_block_hash $((n + 2)))" "orphan block N+2 (contains T)"
    verify_mempool_contains "$txid"
    mine_block_with '[]' "replacement N+2, without T"
    mine_block_with '[]' "N+3, without T"
    mine_block_with '[]' "N+4, without T"
    flush_to_disk
    expect_field "has_assignment" "false" "" "after dropping T"
    mine_empty_blocks $((ASSIGNMENT_DELAY + 2)) "past the would-be activation"
    expect_field "has_assignment" "false" "" "after dropping T, past activation"
    expect_field "state" "UNASSIGNED" "" "after dropping T, past activation"
    pass "Plot UNASSIGNED after T left the chain (no surviving row)"

    verify_against_reindex $((n - 1))
    stop_node
}

# ----------------------------------------------------------------------------
# Scenario B: T re-mined EARLIER (N+1 -> N)
# ----------------------------------------------------------------------------

scenario_earlier() {
    local restart=$1
    SCENARIO="earlier restart=$restart"
    echo ""
    echo "=========================================="
    echo "Scenario: T re-mined 1 block EARLIER (restart between flush and reorg: $restart)"
    echo "=========================================="
    setup_chain

    local txid n hash_n
    mine_block_with '[]' "block N, empty"
    n=$(get_block_count); hash_n=$(get_block_hash "$n")
    txid=$(create_assignment_tx)
    mine_blocks 1 "confirm assignment T at N+1"
    verify_tx_in_block_at_height "$txid" $((n + 1))
    expect_field "assignment_height" $((n + 1)) "" "before reorg"
    pass "T=${txid:0:16}... confirmed at height N+1=$((n + 1))"

    flush_to_disk
    [ "$restart" = "yes" ] && restart_node "between disk write and reorg"

    invalidate_block "$hash_n" "orphan blocks N and N+1"
    verify_mempool_contains "$txid"
    expect_field "has_assignment" "false" "" "after disconnect"
    pass "Blocks N..N+1 orphaned, T back in mempool, plot UNASSIGNED"

    mine_block_with "[\"$txid\"]" "replacement block N, T re-mined"
    mine_block_with '[]' "N+1"
    mine_block_with '[]' "N+2 (branch now longer than the orphaned one)"
    verify_tx_in_block_at_height "$txid" "$n"
    flush_to_disk
    pass "T re-mined at N=$n and written to disk"

    local pass_no
    for pass_no in warm cold; do
        [ "$pass_no" = "cold" ] && restart_node "drop cache before re-checking"
        echo "Check 1 ($pass_no cache): the row at the old height must not win the lookup"
        expect_field "assignment_txid"   "$txid"       "" "stale higher row ($pass_no)"
        expect_field "assignment_height" "$n"          "" "stale higher row ($pass_no)"
        expect_field "activation_height" $((n + ASSIGNMENT_DELAY)) "" "stale higher row ($pass_no)"
        expect_field "has_assignment"    "false"       $((n - 1)) "stale higher row ($pass_no)"
        pass "Assignment at tip has height N and activation N+$ASSIGNMENT_DELAY ($pass_no cache)"
    done

    echo "Check 2: activation happens at N+$ASSIGNMENT_DELAY, not one block late"
    local tip; tip=$(get_block_count)
    mine_empty_blocks $((n + ASSIGNMENT_DELAY - tip)) "reach activation height"
    [ "$(get_block_count)" = $((n + ASSIGNMENT_DELAY)) ] || fail "height bookkeeping"
    expect_field "state" "ASSIGNED" "" "activation window"
    expect_field "state" "ASSIGNING" $((n + ASSIGNMENT_DELAY - 1)) "activation window"
    pass "ASSIGNED exactly at N+$ASSIGNMENT_DELAY (no one-block divergence window)"

    verify_against_reindex $((n - 1))
    stop_node
}

# ----------------------------------------------------------------------------

echo "Assignment Reorg Height-Shift Test (v2)"
echo "Assignment delay: $ASSIGNMENT_DELAY"

# Never leave a regtest node behind, whatever aborts the script (set -e included).
trap stop_node EXIT

# SCENARIOS="later:no earlier:yes" runs a subset (direction:restart).
for spec in ${SCENARIOS:-later:no later:yes earlier:no earlier:yes}; do
    case "$spec" in
        later:*)   scenario_later   "${spec#later:}" ;;
        earlier:*) scenario_earlier "${spec#earlier:}" ;;
        *) echo "unknown scenario '$spec'"; exit 2 ;;
    esac
done

echo ""
echo "Tests passed: $TESTS_PASSED"
if [ "$TESTS_FAILED" -gt 0 ]; then
    echo "✗ $TESTS_FAILED CHECK(S) FAILED"
    exit 1
fi
echo "✓ ALL REORG HEIGHT-SHIFT TESTS PASSED"
