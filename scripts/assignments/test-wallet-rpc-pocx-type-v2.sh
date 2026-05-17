#!/bin/bash
# Regtestv2: pocx_type field in wallet RPC responses.
# Verifies that listtransactions, gettransaction, and listsinceblock include
# pocx_type="assignment" / "revocation" for PoCX OP_RETURN txs, and that the
# field is absent for ordinary sends/receives.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-regtestv2.sh"

DATADIR="$HOME/.bitcoin-pocx/regtestv2-wallet-rpc-pocx-type"

ASSIGNMENT_DELAY=4

ASSIGNMENT_TXID=""
REVOCATION_TXID=""
ORDINARY_TXID=""
PLOT_ADDR=""
FORGE_ADDR=""
MINING_ADDR=""
OTHER_ADDR=""
TESTS_PASSED=0

pass() { echo "  ✓ $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  ✗ FAILED: $1"; regtestv2_stop; exit 1; }

mine_blocks() {
    local count=$1 desc=$2
    [ -n "$desc" ] && echo "  ⛏️  Mining $count blocks ($desc)..."
    $CLI generatetoaddress "$count" "$MINING_ADDR" >/dev/null
}

# Asserts that pocx_type at the top level of `gettransaction` matches $expected,
# or — when $expected is empty — that the field is absent altogether.
assert_gettransaction_pocx_type() {
    local txid=$1 expected=$2
    local entry=$($WCLI gettransaction "$txid")
    if [ -z "$expected" ]; then
        if echo "$entry" | jq -e 'has("pocx_type")' >/dev/null; then
            local got=$(echo "$entry" | jq -r '.pocx_type')
            fail "gettransaction $txid: expected pocx_type absent, got '$got'"
        fi
    else
        local got=$(echo "$entry" | jq -r '.pocx_type // ""')
        [ "$got" = "$expected" ] || fail "gettransaction $txid: expected pocx_type='$expected', got '$got'"
    fi
}

# Same assertion against every row that listtransactions emits for the txid.
assert_listtransactions_pocx_type() {
    local txid=$1 expected=$2
    local rows=$($WCLI listtransactions "*" 1000 | jq -c ".[] | select(.txid==\"$txid\")")
    [ -n "$rows" ] || fail "listtransactions: no row for $txid"

    while IFS= read -r row; do
        if [ -z "$expected" ]; then
            if echo "$row" | jq -e 'has("pocx_type")' >/dev/null; then
                local got=$(echo "$row" | jq -r '.pocx_type')
                fail "listtransactions row for $txid: expected pocx_type absent, got '$got'"
            fi
        else
            local got=$(echo "$row" | jq -r '.pocx_type // ""')
            [ "$got" = "$expected" ] || fail "listtransactions row for $txid: expected pocx_type='$expected', got '$got'"
        fi
    done <<< "$rows"
}

# Same assertion against every row listsinceblock emits for the txid.
assert_listsinceblock_pocx_type() {
    local txid=$1 expected=$2
    local rows=$($WCLI listsinceblock | jq -c ".transactions[] | select(.txid==\"$txid\")")
    [ -n "$rows" ] || fail "listsinceblock: no row for $txid"

    while IFS= read -r row; do
        if [ -z "$expected" ]; then
            if echo "$row" | jq -e 'has("pocx_type")' >/dev/null; then
                local got=$(echo "$row" | jq -r '.pocx_type')
                fail "listsinceblock row for $txid: expected pocx_type absent, got '$got'"
            fi
        else
            local got=$(echo "$row" | jq -r '.pocx_type // ""')
            [ "$got" = "$expected" ] || fail "listsinceblock row for $txid: expected pocx_type='$expected', got '$got'"
        fi
    done <<< "$rows"
}

assert_all_three() {
    local txid=$1 expected=$2 label=$3
    assert_gettransaction_pocx_type   "$txid" "$expected"
    pass "$label: gettransaction pocx_type matches"
    assert_listtransactions_pocx_type "$txid" "$expected"
    pass "$label: listtransactions pocx_type matches"
    assert_listsinceblock_pocx_type   "$txid" "$expected"
    pass "$label: listsinceblock pocx_type matches"
}

phase1_setup() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Setup"
    echo "=========================================="
    regtestv2_start "$DATADIR" -fallbackfee=0.00001
    CLI="$REGTESTV2_CLI"
    WCLI="$REGTESTV2_CLI_WALLET"
    MINING_ADDR=$(regtestv2_mine_to_maturity)
    pass "Bootstrap complete"

    PLOT_ADDR=$($WCLI getnewaddress "" "bech32")
    FORGE_ADDR=$($WCLI getnewaddress "" "bech32")
    OTHER_ADDR=$($WCLI getnewaddress "" "bech32")
    echo "  Plot:  $PLOT_ADDR"
    echo "  Forge: $FORGE_ADDR"
    echo "  Other: $OTHER_ADDR"
}

phase2_ordinary_send() {
    echo ""
    echo "=========================================="
    echo "Phase 2: Ordinary Send (pocx_type absent)"
    echo "=========================================="
    # Spend before the plot is funded so coin selection cannot consume the
    # plot UTXO required by create_assignment in the next phase.
    ORDINARY_TXID=$($WCLI sendtoaddress "$OTHER_ADDR" 0.5)
    echo "  Ordinary TXID: $ORDINARY_TXID"
    mine_blocks 1 "confirm ordinary send"
    pass "Sent ordinary transaction"

    assert_all_three "$ORDINARY_TXID" "" "ordinary send"
}

phase3_assignment() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Assignment (pocx_type=\"assignment\")"
    echo "=========================================="
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm plot funding"
    pass "Funded plot address"

    local result=$($WCLI create_assignment "$PLOT_ADDR" "$FORGE_ADDR" 0.0001)
    ASSIGNMENT_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Assignment TXID: $ASSIGNMENT_TXID"
    mine_blocks 1 "confirm assignment"
    pass "Created assignment transaction"

    assert_all_three "$ASSIGNMENT_TXID" "assignment" "assignment tx"
}

phase4_revocation() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Revocation (pocx_type=\"revocation\")"
    echo "=========================================="
    # Refund the plot so the revocation can be signed.
    $WCLI sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
    mine_blocks 1 "confirm revocation funding"
    mine_blocks $ASSIGNMENT_DELAY "activate assignment"
    pass "Activated assignment"

    local result=$($WCLI revoke_assignment "$PLOT_ADDR" 0.0001)
    REVOCATION_TXID=$(echo "$result" | jq -r '.txid')
    echo "  Revocation TXID: $REVOCATION_TXID"
    mine_blocks 1 "confirm revocation"
    pass "Created revocation transaction"

    assert_all_three "$REVOCATION_TXID" "revocation" "revocation tx"
}

phase5_recheck_ordinary() {
    echo ""
    echo "=========================================="
    echo "Phase 5: Re-check ordinary send is still clean"
    echo "=========================================="
    # Defensive: after assignment + revocation, the original ordinary tx
    # must still report pocx_type absent — nothing should bleed across txs.
    assert_all_three "$ORDINARY_TXID" "" "ordinary send (re-check)"
}

echo "Wallet RPC pocx_type Field Test (v2)"
echo "Assignment delay: $ASSIGNMENT_DELAY"

phase1_setup
phase2_ordinary_send
phase3_assignment
phase4_revocation
phase5_recheck_ordinary

regtestv2_stop
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "✓ ALL POCX_TYPE TESTS PASSED"
