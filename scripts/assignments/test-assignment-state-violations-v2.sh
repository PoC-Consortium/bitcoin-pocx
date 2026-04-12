#!/bin/bash
# Regtestv2: state-machine violation tests (2-layer defense).
# Mempool + block-consensus rejection for every invalid state transition.
#
# Coverage:
#   Assignment in ASSIGNING, ASSIGNED, REVOKING
#   Revocation in UNASSIGNED, ASSIGNING, REVOKING, REVOKED

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-violations"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "State Machine Violation Tests (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
pass "Bootstrap complete"

# Fund given plot address with a single 1 BTCX UTXO, waiting until visible.
fund_single_utxo() {
    local plot_addr=$1
    local h=$($CLI getblockcount)
    $WCLI sendtoaddress "$plot_addr" 1.0 >/dev/null
    $CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
    $CLI waitforblockheight $((h + 1)) 10000 >/dev/null
    for i in {1..10}; do
        local n=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
        [ "$n" -gt 0 ] && return 0
        sleep 0.2
    done
    fail "Could not fund $plot_addr"
}

expect_state() {
    local plot=$1 want=$2
    local got=$($CLI get_assignment "$plot" | jq -r '.state')
    [ "$got" = "$want" ] || fail "Expected state $want for $plot, got $got"
}

# Assert mempool rejects a hex tx, and block construction via generateblock
# either rejects the block or excludes the tx.
assert_tx_rejected() {
    local label=$1 hex=$2

    local mempool_result mempool_exit
    set +e
    mempool_result=$($CLI sendrawtransaction "$hex" 2>&1)
    mempool_exit=$?
    set -e
    [ $mempool_exit -eq 0 ] && fail "$label: mempool accepted invalid tx"
    pass "$label: mempool rejected"

    local block_result block_exit
    set +e
    block_result=$($CLI generateblock "$MINING_ADDR" "[\"$hex\"]" 2>&1)
    block_exit=$?
    set -e
    if [ $block_exit -eq 0 ]; then
        local blockhash tx_count
        blockhash=$(echo "$block_result" | jq -r '.hash')
        tx_count=$($CLI getblock "$blockhash" 2 | jq '.tx | length')
        if [ "$tx_count" -eq 1 ]; then
            pass "$label: block excluded the invalid tx (coinbase only)"
        else
            fail "$label: block included invalid tx (tx_count=$tx_count)"
        fi
    else
        pass "$label: block rejected"
    fi
}

echo ""
echo "=========================================="
echo "Test 1: Assignment → ASSIGNING"
echo "=========================================="
PLOT1=$($WCLI getnewaddress "" "bech32")
FORGE1A=$($WCLI getnewaddress "" "bech32")
FORGE1B=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT1"
fund_single_utxo "$PLOT1"
pass "Funded PLOT1 with 2 UTXOs"
$WCLI create_assignment "$PLOT1" "$FORGE1A" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
expect_state "$PLOT1" "ASSIGNING"
pass "PLOT1 in ASSIGNING state"

HEX=$($WCLI create_assignment "$PLOT1" "$FORGE1B" 0.0001 | jq -r '.hex')
assert_tx_rejected "assignment-in-ASSIGNING" "$HEX"

echo ""
echo "=========================================="
echo "Test 2: Assignment → ASSIGNED"
echo "=========================================="
PLOT2=$($WCLI getnewaddress "" "bech32")
FORGE2A=$($WCLI getnewaddress "" "bech32")
FORGE2B=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT2"
$WCLI create_assignment "$PLOT2" "$FORGE2A" 0.0001 >/dev/null
$CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null
expect_state "$PLOT2" "ASSIGNED"
pass "PLOT2 in ASSIGNED state"
fund_single_utxo "$PLOT2"
HEX=$($WCLI create_assignment "$PLOT2" "$FORGE2B" 0.0001 | jq -r '.hex')
assert_tx_rejected "assignment-in-ASSIGNED" "$HEX"

echo ""
echo "=========================================="
echo "Test 3: Assignment → REVOKING"
echo "=========================================="
PLOT3=$($WCLI getnewaddress "" "bech32")
FORGE3A=$($WCLI getnewaddress "" "bech32")
FORGE3B=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT3"
$WCLI create_assignment "$PLOT3" "$FORGE3A" 0.0001 >/dev/null
$CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null
fund_single_utxo "$PLOT3"
$WCLI revoke_assignment "$PLOT3" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
expect_state "$PLOT3" "REVOKING"
pass "PLOT3 in REVOKING state"
fund_single_utxo "$PLOT3"
HEX=$($WCLI create_assignment "$PLOT3" "$FORGE3B" 0.0001 | jq -r '.hex')
assert_tx_rejected "assignment-in-REVOKING" "$HEX"

echo ""
echo "=========================================="
echo "Test 4: Revocation → UNASSIGNED"
echo "=========================================="
PLOT4=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT4"
expect_state "$PLOT4" "UNASSIGNED"
pass "PLOT4 in UNASSIGNED state"
HEX=$($WCLI revoke_assignment "$PLOT4" 0.0001 | jq -r '.hex')
assert_tx_rejected "revocation-in-UNASSIGNED" "$HEX"

echo ""
echo "=========================================="
echo "Test 5: Revocation → ASSIGNING"
echo "=========================================="
PLOT5=$($WCLI getnewaddress "" "bech32")
FORGE5=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT5"
$WCLI create_assignment "$PLOT5" "$FORGE5" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
expect_state "$PLOT5" "ASSIGNING"
pass "PLOT5 in ASSIGNING state"
fund_single_utxo "$PLOT5"
HEX=$($WCLI revoke_assignment "$PLOT5" 0.0001 | jq -r '.hex')
assert_tx_rejected "revocation-in-ASSIGNING" "$HEX"

echo ""
echo "=========================================="
echo "Test 6: Revocation → REVOKING"
echo "=========================================="
PLOT6=$($WCLI getnewaddress "" "bech32")
FORGE6=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT6"
$WCLI create_assignment "$PLOT6" "$FORGE6" 0.0001 >/dev/null
$CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null
fund_single_utxo "$PLOT6"
$WCLI revoke_assignment "$PLOT6" 0.0001 >/dev/null
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
expect_state "$PLOT6" "REVOKING"
pass "PLOT6 in REVOKING state"
fund_single_utxo "$PLOT6"
HEX=$($WCLI revoke_assignment "$PLOT6" 0.0001 | jq -r '.hex')
assert_tx_rejected "revocation-in-REVOKING" "$HEX"

echo ""
echo "=========================================="
echo "Test 7: Revocation → REVOKED"
echo "=========================================="
PLOT7=$($WCLI getnewaddress "" "bech32")
FORGE7=$($WCLI getnewaddress "" "bech32")
fund_single_utxo "$PLOT7"
$WCLI create_assignment "$PLOT7" "$FORGE7" 0.0001 >/dev/null
$CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null
fund_single_utxo "$PLOT7"
$WCLI revoke_assignment "$PLOT7" 0.0001 >/dev/null
$CLI generatetoaddress 10 "$MINING_ADDR" >/dev/null
expect_state "$PLOT7" "REVOKED"
pass "PLOT7 in REVOKED state"
fund_single_utxo "$PLOT7"
HEX=$($WCLI revoke_assignment "$PLOT7" 0.0001 | jq -r '.hex')
assert_tx_rejected "revocation-in-REVOKED" "$HEX"

regtestv2_stop
echo ""
echo -e "${GREEN}✓ ALL 7 STATE MACHINE VIOLATION TESTS PASSED${NC}"
