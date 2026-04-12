#!/bin/bash
# Regtestv2: Intra-block conflict test.
# Verifies that conflicting assignments/revocations are rejected within a
# single block, regardless of transaction ordering.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-intrablock"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; regtestv2_stop; exit 1; }

echo "=========================================="
echo "Intra-Block Conflict Tests (v2)"
echo "=========================================="

regtestv2_start "$DATADIR" -fallbackfee=0.00001
MINING_ADDR=$(regtestv2_mine_to_maturity)
CLI="$REGTESTV2_CLI"
WCLI="$REGTESTV2_CLI_WALLET"
pass "Bootstrap complete"

fund_two_utxos() {
    local plot_addr=$1
    for utxo_num in 1 2; do
        HEIGHT=$($CLI getblockcount)
        TXID=$($WCLI sendtoaddress "$plot_addr" 1.0)
        $CLI generatetoaddress 1 "$MINING_ADDR" >/dev/null
        $CLI waitforblockheight $((HEIGHT + 1)) 10000 >/dev/null
        for i in {1..10}; do
            UTXO_COUNT=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
            [ "$UTXO_COUNT" -ge $utxo_num ] && break
            sleep 0.2
        done
        UTXO_DATA=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq ".[] | select(.txid == \"$TXID\")")
        if [ -n "$UTXO_DATA" ]; then
            VOUT=$(echo "$UTXO_DATA" | jq -r '.vout')
            $WCLI lockunspent false "[{\"txid\":\"$TXID\",\"vout\":$VOUT}]" >/dev/null
        fi
    done
    $WCLI lockunspent true >/dev/null
    UTXO_COUNT=$($WCLI listunspent 1 9999999 "[\"$plot_addr\"]" | jq 'length')
    [ "$UTXO_COUNT" -ge 2 ] || fail "Expected 2 UTXOs, got $UTXO_COUNT"
}

echo ""
echo "=========================================="
echo "Test 1: Assignment THEN Revocation"
echo "=========================================="
PLOT_ADDR=$($WCLI getnewaddress "" "bech32")
FORGE_ADDR=$($WCLI getnewaddress "" "bech32")

fund_two_utxos "$PLOT_ADDR"
pass "Funded plot address with 2 UTXOs"

RESULT1=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
TXID1=$(echo "$RESULT1" | jq -r '.txid')
HEX1=$(echo "$RESULT1" | jq -r '.hex')
pass "Created assignment in mempool"
$CLI getmempoolentry "$TXID1" >/dev/null 2>&1 || fail "Assignment not in mempool"

set +e
REV_RESULT=$($WCLI revoke_assignment "$PLOT_ADDR" 0.0001 2>&1)
set -e
REV_TXID=$(echo "$REV_RESULT" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$REV_TXID" ]; then
    REV_HEX=$(echo "$REV_RESULT" | jq -r '.hex')
    pass "Created revocation tx (unconfirmed assignment path)"

    if $CLI getmempoolentry "$REV_TXID" >/dev/null 2>&1; then
        fail "Mempool ACCEPTED revocation of unconfirmed assignment"
    fi
    set +e
    MEMPOOL_RESULT=$($CLI sendrawtransaction "$REV_HEX" 2>&1)
    MEMPOOL_EXIT=$?
    set -e
    [ $MEMPOOL_EXIT -eq 0 ] && fail "Mempool accepted revocation via sendrawtransaction"
    pass "Mempool rejected revocation"

    set +e
    BLOCK_RESULT=$($CLI generateblock "$MINING_ADDR" "[\"$HEX1\",\"$REV_HEX\"]" 2>&1)
    BLOCK_EXIT=$?
    set -e
    if [ $BLOCK_EXIT -eq 0 ]; then
        BLOCKHASH=$(echo "$BLOCK_RESULT" | jq -r '.hash')
        BLOCK_DATA=$($CLI getblock "$BLOCKHASH" 2)
        TX1_IN=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$TXID1\")" >/dev/null 2>&1 && echo yes || echo no)
        TX2_IN=$(echo "$BLOCK_DATA" | jq -e ".tx[] | select(.txid == \"$REV_TXID\")" >/dev/null 2>&1 && echo yes || echo no)
        echo "Assignment in block: $TX1_IN; Revocation in block: $TX2_IN"
        [ "$TX2_IN" = "yes" ] && fail "Block accepted revocation of unconfirmed assignment"
        [ "$TX1_IN" = "yes" ] || fail "Block rejected BOTH transactions"
        pass "Block accepted assignment, excluded revocation"
        STATE=$($CLI get_assignment "$PLOT_ADDR" | jq -r '.state')
        [ "$STATE" = "ASSIGNING" ] || fail "Expected ASSIGNING, got $STATE"
        pass "State = ASSIGNING"
    else
        pass "Block validation rejected the invalid block: $BLOCK_RESULT"
    fi
else
    pass "RPC refused to create revocation for unconfirmed assignment"
fi

echo ""
echo "=========================================="
echo "Test 2: Revocation THEN Assignment (swapped order)"
echo "=========================================="
# Clear mempool and advance some blocks
$CLI generatetoaddress 6 "$MINING_ADDR" >/dev/null

PLOT_ADDR2=$($WCLI getnewaddress "" "bech32")
FORGE_ADDR2=$($WCLI getnewaddress "" "bech32")

fund_two_utxos "$PLOT_ADDR2"
pass "Funded second plot address with 2 UTXOs"

RESULT2=$($WCLI create_assignment "$PLOT_ADDR2" "$FORGE_ADDR2" 0.0001)
TXID2=$(echo "$RESULT2" | jq -r '.txid')
HEX2=$(echo "$RESULT2" | jq -r '.hex')
pass "Created assignment in mempool"

set +e
REV_RESULT2=$($WCLI revoke_assignment "$PLOT_ADDR2" 0.0001 2>&1)
set -e
REV_TXID2=$(echo "$REV_RESULT2" | jq -r '.txid // empty' 2>/dev/null || echo "")

if [ -n "$REV_TXID2" ]; then
    REV_HEX2=$(echo "$REV_RESULT2" | jq -r '.hex')
    pass "Created revocation tx"

    set +e
    BLOCK_RESULT2=$($CLI generateblock "$MINING_ADDR" "[\"$REV_HEX2\",\"$HEX2\"]" 2>&1)
    BLOCK_EXIT2=$?
    set -e
    if [ $BLOCK_EXIT2 -eq 0 ]; then
        BLOCKHASH2=$(echo "$BLOCK_RESULT2" | jq -r '.hash')
        BLOCK_DATA2=$($CLI getblock "$BLOCKHASH2" 2)
        REV_IN=$(echo "$BLOCK_DATA2" | jq -e ".tx[] | select(.txid == \"$REV_TXID2\")" >/dev/null 2>&1 && echo yes || echo no)
        ASN_IN=$(echo "$BLOCK_DATA2" | jq -e ".tx[] | select(.txid == \"$TXID2\")" >/dev/null 2>&1 && echo yes || echo no)
        echo "Revocation in block: $REV_IN; Assignment in block: $ASN_IN"
        [ "$REV_IN" = "yes" ] && fail "Block accepted revocation before assignment"
        [ "$ASN_IN" = "yes" ] || fail "Block rejected BOTH transactions"
        pass "Block accepted assignment, excluded revocation (swapped order)"
        STATE2=$($CLI get_assignment "$PLOT_ADDR2" | jq -r '.state')
        [ "$STATE2" = "ASSIGNING" ] || fail "Expected ASSIGNING, got $STATE2"
        pass "State = ASSIGNING"
    else
        pass "Block validation rejected the invalid block: $BLOCK_RESULT2"
    fi
else
    pass "RPC refused to create revocation"
fi

regtestv2_stop
echo ""
echo -e "${GREEN}✓ ALL INTRA-BLOCK CONFLICT TESTS PASSED${NC}"
