#!/bin/bash
# Regtestv2: Block-level (Layer 2) assignment validation.
# Ensures block validation catches state violations even when tx bypass mempool.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-block"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "Block-Level Validation Tests (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
pass "Bootstrap complete"

# Fund the given plot address with `count` separate 1 BTCX UTXOs,
# locking each so the wallet doesn't consolidate them.
fund_utxos() {
    local plot_addr=$1
    local count=$2
    for utxo_num in $(seq 1 "$count"); do
        local h=$($CLI getblockcount)
        local txid=$($WCLI sendtoaddress "$plot_addr" 1.0)
        $CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
        $CLI waitforblockheight $((h + 1)) 10000 >/dev/null
        for i in {1..10}; do
            local n=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
            [ "$n" -ge "$utxo_num" ] && break
            sleep 0.2
        done
        local utxo=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq ".[] | select(.txid == \"$txid\")")
        if [ -n "$utxo" ]; then
            local vout=$(echo "$utxo" | jq -r '.vout')
            $WCLI lockunspent false "[{\"txid\":\"$txid\",\"vout\":$vout}]" >/dev/null
        fi
    done
    $WCLI lockunspent true >/dev/null
    local got=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
    [ "$got" -ge "$count" ] || fail "Expected $count UTXOs, got $got"
}

echo ""
echo "=========================================="
echo "Test 1: Double Assignment via generateblock"
echo "=========================================="
PLOT_ADDR1=$($WCLI getnewaddress "" "bech32")
fund_utxos "$PLOT_ADDR1" 2
pass "Funded plot addr 1 with 2 UTXOs"

FORGE_ADDR1=$($WCLI getnewaddress "" "bech32")
RESULT1=$($WCLI create_assignment "$PLOT_ADDR1" "$FORGE_ADDR1" 0.0001)
TXID1=$(echo "$RESULT1" | jq -r '.txid'); HEX1=$(echo "$RESULT1" | jq -r '.hex')
pass "Created first assignment in mempool"
$CLI getmempoolentry "$TXID1" >/dev/null 2>&1 || fail "First assignment not in mempool"

FORGE_ADDR2=$($WCLI getnewaddress "" "bech32")
set +e
RESULT2=$($WCLI create_assignment "$PLOT_ADDR1" "$FORGE_ADDR2" 0.0001 2>&1)
set -e
TXID2=$(echo "$RESULT2" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$TXID2" ]; then
    HEX2=$(echo "$RESULT2" | jq -r '.hex')
    pass "Created second assignment tx"

    if $CLI getmempoolentry "$TXID2" >/dev/null 2>&1; then
        fail "Mempool accepted double assignment"
    fi
    set +e
    $CLI sendrawtransaction "$HEX2" >/dev/null 2>&1
    [ $? -eq 0 ] && fail "Mempool accepted double assignment via sendrawtransaction"
    set -e
    pass "Mempool rejected double assignment"

    set +e
    BLOCK_RESULT=$($CLI generateblock "$MINING_ADDR" "[\"$HEX1\",\"$HEX2\"]" 2>&1)
    BLOCK_EXIT=$?
    set -e
    if [ $BLOCK_EXIT -eq 0 ]; then
        BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
        BLOCK_DATA=$($CLI getblock "$BLOCKHASH" 2)
        TX1_IN=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$TXID1\")" >/dev/null 2>&1 && echo yes || echo no)
        TX2_IN=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$TXID2\")" >/dev/null 2>&1 && echo yes || echo no)
        [ "$TX2_IN" = "yes" ] && fail "Block accepted BOTH assignments"
        [ "$TX1_IN" = "yes" ] || fail "Block rejected BOTH assignments"
        pass "Block kept first, excluded second (consensus enforced)"
    else
        pass "Block validation rejected the block: $BLOCK_RESULT"
    fi
else
    pass "RPC refused to create second assignment (expected)"
fi

echo ""
echo "=========================================="
echo "Test 2: Double Revocation via generateblock"
echo "=========================================="
$CLI generatetoaddress 6 "$MINING_ADDR" >/dev/null

PLOT_ADDR2=$($WCLI getnewaddress "" "bech32")
fund_utxos "$PLOT_ADDR2" 3
pass "Funded plot addr 2 with 3 UTXOs"

FORGE_ADDR3=$($WCLI getnewaddress "" "bech32")
$WCLI create_assignment "$PLOT_ADDR2" "$FORGE_ADDR3" 0.0001 >/dev/null
$CLI generatetoaddress 5 "$MINING_ADDR" >/dev/null
pass "Created and mined initial assignment"

STATE=$($CLI get_assignment "$PLOT_ADDR2" | jq -r '.state')
[ "$STATE" = "ASSIGNED" ] || fail "Expected ASSIGNED, got $STATE"
pass "State = ASSIGNED"

# Top up UTXOs for two revocation attempts.
fund_utxos "$PLOT_ADDR2" 2
pass "Topped up plot addr 2 with extra UTXOs"

REV_RESULT1=$($WCLI revoke_assignment "$PLOT_ADDR2" 0.0001)
REV_TXID1=$(echo "$REV_RESULT1" | jq -r '.txid'); REV_HEX1=$(echo "$REV_RESULT1" | jq -r '.hex')
pass "Created first revocation in mempool"
$CLI getmempoolentry "$REV_TXID1" >/dev/null 2>&1 || fail "First revocation not in mempool"

set +e
REV_RESULT2=$($WCLI revoke_assignment "$PLOT_ADDR2" 0.0001 2>&1)
set -e
REV_TXID2=$(echo "$REV_RESULT2" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$REV_TXID2" ]; then
    REV_HEX2=$(echo "$REV_RESULT2" | jq -r '.hex')
    pass "Created second revocation tx"

    if $CLI getmempoolentry "$REV_TXID2" >/dev/null 2>&1; then
        fail "Mempool accepted double revocation"
    fi
    set +e
    $CLI sendrawtransaction "$REV_HEX2" >/dev/null 2>&1
    [ $? -eq 0 ] && fail "Mempool accepted double revocation via sendrawtransaction"
    set -e
    pass "Mempool rejected double revocation"

    set +e
    BLOCK_RESULT=$($CLI generateblock "$MINING_ADDR" "[\"$REV_HEX1\",\"$REV_HEX2\"]" 2>&1)
    BLOCK_EXIT=$?
    set -e
    if [ $BLOCK_EXIT -eq 0 ]; then
        BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
        BLOCK_DATA=$($CLI getblock "$BLOCKHASH" 2)
        R1=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$REV_TXID1\")" >/dev/null 2>&1 && echo yes || echo no)
        R2=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$REV_TXID2\")" >/dev/null 2>&1 && echo yes || echo no)
        [ "$R2" = "yes" ] && fail "Block accepted BOTH revocations"
        [ "$R1" = "yes" ] || fail "Block rejected BOTH revocations"
        pass "Block kept first, excluded second (consensus enforced)"
    else
        pass "Block validation rejected the block: $BLOCK_RESULT"
    fi
else
    pass "RPC refused to create second revocation"
fi

regtestv2_stop
echo ""
echo -e "${GREEN}✓ ALL BLOCK-LEVEL VALIDATION TESTS PASSED${NC}"
