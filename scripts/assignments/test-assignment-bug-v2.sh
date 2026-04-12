#!/bin/bash
# Regtestv2 regression: multiple consecutive assignments (segfault bug fix)
#
# Historical: GetForgingAssignment() only queried LevelDB base layer, never
# the cache for recent assignments, causing a segfault on assignment #2.
# Fix: proper cache layer with duplicate detection.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-bugfix"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "Regression Test: Segfault Bug Fix (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
pass "Started regtest node and mined 101 blocks to maturity"

FORGE_ADDR=$($WCLI getnewaddress "" "bech32")
echo "Forge address: $FORGE_ADDR"

echo ""
echo "Creating 5 plot addresses..."
PLOT_ADDRS=()
for i in {1..5}; do
    addr=$($WCLI getnewaddress "" "bech32")
    PLOT_ADDRS+=("$addr")
    echo "  Plot $i: $addr"
done

echo ""
echo "Funding all 5 plot addresses with sendmany..."
$WCLI sendmany "" "{\"${PLOT_ADDRS[0]}\":1.0,\"${PLOT_ADDRS[1]}\":1.0,\"${PLOT_ADDRS[2]}\":1.0,\"${PLOT_ADDRS[3]}\":1.0,\"${PLOT_ADDRS[4]}\":1.0}" >/dev/null
HEIGHT=$($CLI getblockcount)
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
$CLI waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null

for i in {1..20}; do
    UTXO_COUNT=$($WCLI listunspent 1 9999999 "[\"${PLOT_ADDRS[0]}\",\"${PLOT_ADDRS[1]}\",\"${PLOT_ADDRS[2]}\",\"${PLOT_ADDRS[3]}\",\"${PLOT_ADDRS[4]}\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 5 ] && break
    sleep 0.5
done
[ "$UTXO_COUNT" -eq 5 ] || fail "Expected 5 UTXOs for funding, got $UTXO_COUNT"
pass "Funded all 5 plot addresses"

echo ""
echo "Creating 5 consecutive assignments to the same forge address..."
ASSIGNMENT_TXIDS=()
for i in "${!PLOT_ADDRS[@]}"; do
    num=$((i + 1))
    addr="${PLOT_ADDRS[$i]}"
    if RESULT=$($WCLI create_assignment "$addr" "$FORGE_ADDR" 0.0001 2>&1); then
        TXID=$(echo "$RESULT" | jq -r '.txid')
        ASSIGNMENT_TXIDS+=("$TXID")
        pass "Assignment $num (txid: ${TXID:0:16}...)"
        $CLI getmempoolentry "$TXID" >/dev/null 2>&1 || fail "Assignment $num not in mempool"
    else
        pgrep bitcoind >/dev/null || { echo -e "${RED}💥 DAEMON CRASHED — segfault bug returned${NC}"; exit 1; }
        fail "Assignment $num failed but daemon still running"
    fi
done

echo ""
echo "Mining all assignments into a block..."
HEIGHT=$($CLI getblockcount)
$CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
$CLI waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
pass "All assignments mined into block $((HEIGHT + 1))"

for i in "${!ASSIGNMENT_TXIDS[@]}"; do
    num=$((i + 1))
    TXID="${ASSIGNMENT_TXIDS[$i]}"
    $CLI getmempoolentry "$TXID" >/dev/null 2>&1 && fail "Assignment $num still in mempool"
    TX_INFO=$($WCLI gettransaction "$TXID" 2>&1) || fail "Assignment $num not found"
    CONFIRMATIONS=$(echo "$TX_INFO" | jq -r '.confirmations')
    [ "$CONFIRMATIONS" -ge 1 ] || fail "Assignment $num has 0 confirmations"
    pass "Assignment $num confirmed ($CONFIRMATIONS confirmations)"
done

echo ""
echo "Verifying final state with get_assignment..."
for i in "${!PLOT_ADDRS[@]}"; do
    num=$((i + 1))
    addr="${PLOT_ADDRS[$i]}"
    INFO=$($CLI get_assignment "$addr")
    STATE=$(echo "$INFO" | jq -r '.state')
    FORGE_CHECK=$(echo "$INFO" | jq -r '.forging_address // empty')
    case "$STATE" in
        ASSIGNING|ASSIGNED) ;;
        *) fail "Plot $num state is '$STATE'" ;;
    esac
    [ "$FORGE_CHECK" = "$FORGE_ADDR" ] || fail "Plot $num forge address mismatch"
    pass "Plot $num: state=$STATE"
done

regtestv2_stop
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}✓ REGRESSION TEST PASSED${NC}"
echo -e "${GREEN}==========================================${NC}"
