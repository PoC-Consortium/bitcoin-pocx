#!/bin/bash
# Regtestv2 regression: verifychain level 4 across assignment operations.
#
# Level-4 verification disconnects and reconnects blocks through one shared
# coins cache. ConnectBlock's same-block guards used the cache's pending
# assignment rows, which in that shared cache carry entries restored or added
# by other blocks, so reconnecting a revocation block failed with
# revoke-after-assign-in-block. The guards now use per-ConnectBlock tracking.
#
# Also confirms that genuine same-block conflicts are still rejected.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-verifychain"
ASSIGNMENT_DELAY=4

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "Regression Test: verifychain level 4 (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
LOG="$DATADIR/regtest/debug.log"
pass "Started regtest node and mined 101 blocks to maturity"

FORGE_ADDR=$($WCLI getnewaddress "" "bech32")
PLOT_ADDR=$($WCLI getnewaddress "" "bech32")
$WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null

# --- assignment, activation, revocation ---
$WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
H_ASSIGN=$($CLI getblockcount)
$CLI generatetoaddress $ASSIGNMENT_DELAY "$MINING_ADDR" >/dev/null
[ "$($CLI get_assignment "$PLOT_ADDR" | jq -r .state)" = "ASSIGNED" ] || fail "assignment did not activate"
$WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null   # revocation must also spend from the plot address
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
$WCLI revoke_assignment "$PLOT_ADDR" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
H_REVOKE=$($CLI getblockcount)
pass "Assignment confirmed at $H_ASSIGN, active, revocation confirmed at $H_REVOKE (state $($CLI get_assignment "$PLOT_ADDR" | jq -r .state))"

# verifychain must reach level-4 reconnection: the "No coin database
# inconsistencies" line is only logged after the reconnect loop completed.
verify_span() {
    local depth=$1 desc=$2 mark result
    mark=$(wc -l < "$LOG")
    result=$($CLI verifychain 4 "$depth")
    local tail; tail=$(tail -n +$((mark + 1)) "$LOG")
    echo "$tail" | grep -q "Verifying last $depth blocks at level 4" || fail "$desc: level-4 verification did not start"
    if [ "$result" != "true" ]; then
        echo "$tail" | grep -E 'Verification error|unconnectable|ConnectBlock' | sed 's/.*\] //' | head -3
        fail "$desc: verifychain 4 $depth returned $result"
    fi
    echo "$tail" | grep -q "No coin database inconsistencies in last $depth blocks" || fail "$desc: level-4 reconnection did not complete"
    pass "$desc: verifychain 4 $depth = true, level-4 reconnection completed"
}
verify_span 1 "Revocation block only"
verify_span $(( $($CLI getblockcount) - H_ASSIGN + 1 )) "Span covering assignment creation and revocation"

# --- same-block conflicts must still be rejected ---
raw_marker_tx() { # $1=plot addr, $2=txid:vout to spend, $3=marker hex ("504f4358"+plot+forge or "58434f50"+plot); prints signed hex
    local plot=$1 txid=${2%:*} vout=${2#*:} marker=$3 raw
    raw=$($CLI createrawtransaction "[{\"txid\":\"$txid\",\"vout\":$vout}]" "[{\"data\":\"$marker\"},{\"$plot\":0.999}]")
    $WCLI signrawtransactionwithwallet "$raw" | jq -r .hex
}
fund_plot() { # $1=plot addr; prints txid:vout of a new 1.0 output, mined, and locks it
    local plot=$1 txid vout
    txid=$($WCLI sendtoaddress "$plot" 1.0); $CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
    vout=$($WCLI gettransaction "$txid" true true | jq -r --arg a "$plot" '.decoded.vout[] | select(.scriptPubKey.address==$a) | .n')
    $WCLI lockunspent false "[{\"txid\":\"$txid\",\"vout\":$vout}]" >/dev/null
    echo "$txid:$vout"
}
expect_block_rejected() { # $1=desc, remaining: raw tx hexes
    local desc=$1; shift; local list out reason
    for hex in "$@"; do [ -n "$hex" ] && [ "$hex" != "null" ] || fail "$desc: raw transaction construction failed"; done
    list=$(printf '"%s",' "$@"); list="[${list%,}]"
    if out=$($CLI generateblock "$MINING_ADDR" "$list" 2>&1); then fail "$desc: block was accepted"; fi
    reason=$(echo "$out" | grep -o 'TestBlockValidity failed: [a-z-]*' | head -1)
    [ -n "$reason" ] || fail "$desc: block failed for another reason: $(echo "$out" | tr '\n' ' ' | cut -c1-120)"
    pass "$desc: rejected ($reason)"
}
# Fund PLOT2/PLOT3 with two outputs each, locked so the wallet does not spend
# them as inputs of later transactions; the raw conflict txs spend them explicitly.
PLOT2=$($WCLI getnewaddress "" "bech32"); PLOT3=$($WCLI getnewaddress "" "bech32")
U2A=$(fund_plot "$PLOT2"); U2B=$(fund_plot "$PLOT2"); U3A=$(fund_plot "$PLOT3"); U3B=$(fund_plot "$PLOT3"); U3C=$(fund_plot "$PLOT3")
# release one PLOT3 output for the wallet-built assignment
$WCLI lockunspent true "[{\"txid\":\"${U3C%:*}\",\"vout\":${U3C#*:}}]" >/dev/null
$WCLI create_assignment "$PLOT3" "$FORGE_ADDR" 0.0001 >/dev/null
$CLI generatetoaddress $((ASSIGNMENT_DELAY + 1)) "$MINING_ADDR" >/dev/null
[ "$($CLI get_assignment "$PLOT3" | jq -r .state)" = "ASSIGNED" ] || fail "plot3 assignment did not activate"
W2=$($CLI validateaddress "$PLOT2" | jq -r .witness_program); W3=$($CLI validateaddress "$PLOT3" | jq -r .witness_program); WF=$($CLI validateaddress "$FORGE_ADDR" | jq -r .witness_program)
A2a=$(raw_marker_tx "$PLOT2" "$U2A" "504f4358${W2}${WF}"); A2b=$(raw_marker_tx "$PLOT2" "$U2B" "504f4358${W2}${WF}")
expect_block_rejected "Two assignments for one plot in one block" "$A2a" "$A2b"
R3=$(raw_marker_tx "$PLOT3" "$U3A" "58434f50${W3}"); A3=$(raw_marker_tx "$PLOT3" "$U3B" "504f4358${W3}${WF}")
expect_block_rejected "Revocation and re-assignment for one plot in one block" "$R3" "$A3"
$WCLI lockunspent true >/dev/null
# valid single operations still mine
$CLI generateblock "$MINING_ADDR" "[\"$A2a\"]" >/dev/null && pass "Single assignment block accepted (height $($CLI getblockcount))"
verify_span 3 "Span after conflict tests"

regtestv2_stop
echo ""
echo -e "${GREEN}✓ ALL VERIFYCHAIN TESTS PASSED${NC}"
