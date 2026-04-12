#!/bin/bash
# Regtestv2: Invalid OP_RETURN format tests.
# Verifies PoCX parsing rejects malformed assignment/revocation data.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-format"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "Invalid OP_RETURN Format Tests (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
pass "Bootstrap complete"

FORGE_ADDR=$($WCLI getnewaddress "" "bech32")

# Helper: fund plot address with 1 UTXO of 1 BTCX, broadcast custom OP_RETURN,
# mine it, and assert the plot remains UNASSIGNED (or no assignment).
check_malformed() {
    local label=$1
    local op_return_hex=$2

    local plot_addr=$($WCLI getnewaddress "" "bech32")
    $WCLI sendtoaddress "$plot_addr" 1.0 >/dev/null
    local h=$($CLI getblockcount)
    $CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
    $CLI waitforblockheight $((h + 1)) 10000 >/dev/null

    for i in {1..10}; do
        local utxo_count=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
        [ "$utxo_count" -ge 1 ] && break
        sleep 0.2
    done

    local utxo=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq -r '.[0]')
    local utxo_txid=$(echo "$utxo" | jq -r '.txid')
    local utxo_vout=$(echo "$utxo" | jq -r '.vout')
    local change_addr=$($WCLI getrawchangeaddress)

    local bad_raw
    bad_raw=$($WCLI createrawtransaction \
        "[{\"txid\":\"$utxo_txid\",\"vout\":$utxo_vout}]" \
        "[{\"data\":\"$op_return_hex\"},{\"$FORGE_ADDR\":0.0001},{\"$change_addr\":0.9998}]")
    local bad_signed=$($WCLI signrawtransactionwithwallet "$bad_raw" | jq -r '.hex')

    set +e
    local bad_txid=$($CLI sendrawtransaction "$bad_signed" 2>&1)
    local broadcast_exit=$?
    set -e

    if [ $broadcast_exit -ne 0 ]; then
        pass "$label: Bitcoin rejected broadcast ($bad_txid)"
        return
    fi
    pass "$label: broadcasted ${bad_txid:0:16}..."

    $CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null

    set +e
    local state=$($CLI get_assignment "$plot_addr" 2>&1)
    local state_exit=$?
    set -e

    if [ $state_exit -ne 0 ] || echo "$state" | grep -q "No assignment found"; then
        pass "$label: PoCX correctly ignored the malformed OP_RETURN"
        return
    fi

    local current_state=$(echo "$state" | jq -r '.state // "UNKNOWN"')
    if [ "$current_state" = "UNASSIGNED" ]; then
        pass "$label: state remains UNASSIGNED"
    else
        fail "$label: unexpected state $current_state"
    fi
}

# PoCX OP_RETURN format: MAGIC(4) + TYPE(1) + PLOTID(32) + RESERVED(8) = 45 bytes
# Valid assignment magic: 504f4358 (POCX)
# Valid revocation magic: 58434f50 (XCOP)
PLOT_ID="c081d70a692c2e8bdb5e57f2b8310a8fe421ad8bdb7c052401f28f5c44eaf5f0"
RESERVED="a30d89499f8000ca"

echo ""
echo "=== Test 1: Wrong magic bytes (DEAD) ==="
check_malformed "wrong-magic" "4445414400${PLOT_ID}${RESERVED}"

echo ""
echo "=== Test 2: Truncated OP_RETURN (missing reserved) ==="
check_malformed "truncated" "504f435800${PLOT_ID}"

echo ""
echo "=== Test 3: Wrong assignment magic (XCOP instead of POCX) ==="
check_malformed "wrong-assignment-magic" "58434f5000${PLOT_ID}${RESERVED}"

echo ""
echo "=== Test 4: Oversized OP_RETURN (extra garbage) ==="
check_malformed "oversized" "504f435800${PLOT_ID}${RESERVED}deadbeefdeadbeefdeadbeefdeadbeef"

regtestv2_stop
echo ""
echo -e "${GREEN}✓ ALL FORMAT VALIDATION TESTS PASSED${NC}"
