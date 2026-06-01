#!/bin/bash
# PoCX regtestv2: submit_nonce optional coinbase payout split (Q1) - RPC boundary.
#
# Q1 adds an OPTIONAL trailing `coinbase_outputs` parameter to submit_nonce: a pool
# payout map [{address, amount_sat}, ...]. When present, the node builds the coinbase
# from these outputs and routes the remainder (unallocated reward + all fees) to the
# effective signer. Absent => today's single-output coinbase (legacy), unchanged.
#
# SCOPE - this script verifies the RPC boundary, which is deterministic and needs no
# forging:
#   Case A  Legacy 9-arg submit_nonce              -> ACK (backward compatible).
#   Case B  Valid 2-recipient payout map           -> ACK (param parsed + accepted).
#   Case C  Invalid address in the map             -> error -5  (RPC_INVALID_ADDRESS_OR_KEY).
#   Case D  Negative amount_sat                     -> error -3  (RPC_TYPE_ERROR, MoneyRange).
#   Case E  amount_sat above MAX_MONEY              -> error -3  (RPC_TYPE_ERROR, MoneyRange).
#   Case F  Entry missing amount_sat                -> error -8  (RPC_INVALID_PARAMETER).
#
# Boundary validation is done in submit_nonce BEFORE proof/context checks, on purpose:
# a bad address can't be caught downstream (Core would pay an unspendable script), and
# amounts are validated at parse with MoneyRange.
#
# NOT covered here: the forged block actually carrying the split coinbase, the
# remainder going to the effective signer, and the forge-time over-budget rejection
# (sum > subsidy + fees). Those only occur once the async scheduler forges at the
# time-bended deadline, which requires a winning nonce that isn't reliably producible
# in a shell script. They belong in the block_builder unit test for ApplyCoinbaseOutputs
# (coinbase rewrite + merkle recompute + sum validation), per the work order.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtestv2-submitnonce-payout"

# WIF for the regtest forging key (src/pocx/regtest/forging.cpp kRegtestForgingPrivKey).
# Used only so the wallet-key gate passes (Available, unlocked) and submit_nonce can ACK.
FORGING_WIF="cMvJbCxo3qCee5EFHSYVuK7UP69ijvHtXmrikzKtjbtEvzUYU5T5"

# Consensus money cap (MAX_MONEY = 21e6 * COIN), for the out-of-range case.
MAX_MONEY=2100000000000000

echo "PoCX Regtestv2 submit_nonce Payout-Split Test (Q1 - RPC boundary)"
echo "================================================================="

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }

pkill -9 bitcoind 2>/dev/null || true
sleep 1
rm -rf "$DATADIR"
mkdir -p "$DATADIR"

$BITCOIND -regtest -datadir="$DATADIR" -daemon >/dev/null
for i in 1 2 3 4 5; do
    $BITCOIN_CLI -regtest -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

CLI="$BITCOIN_CLI -regtest -datadir=$DATADIR"
$CLI setmocktime "$(date +%s)" >/dev/null

fail() {
    echo ""
    echo "FAIL: $1"
    $CLI stop >/dev/null 2>&1 || true
    exit 1
}

# Wallet holding the forging key (unlocked) so the receive-path key gate is satisfied.
DESC_INFO=$($CLI getdescriptorinfo "wpkh($FORGING_WIF)")
PUBKEY_DESC=$(echo "$DESC_INFO" | jq -r '.descriptor')
CHECKSUM=$(echo "$DESC_INFO" | jq -r '.checksum')
PRIVKEY_DESC="wpkh($FORGING_WIF)#$CHECKSUM"
FORGING_ADDR=$($CLI deriveaddresses "$PUBKEY_DESC" | jq -r '.[0]')

# createwallet: name, disable_private_keys, blank, passphrase, avoid_reuse, descriptors
$CLI createwallet keyed false true "" false true >/dev/null
$CLI -rpcwallet=keyed importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
ACCOUNT=$($CLI -rpcwallet=keyed getaddressinfo "$FORGING_ADDR" | jq -r '.witness_program')
[ -n "$ACCOUNT" ] && [ "$ACCOUNT" != "null" ] || fail "could not derive account_id (witness_program)"
ADDR2=$($CLI -rpcwallet=keyed getnewaddress)
echo "Signer address: $FORGING_ADDR"
echo "Account ID:     $ACCOUNT"
echo "Second payout:  $ADDR2"

SEED=$(printf '0%.0s' $(seq 1 64))   # 64-hex zeros; any well-formed nonce validates on regtest

refresh_ctx() {
    local ctx; ctx=$($CLI get_mining_info)
    HEIGHT=$(echo "$ctx" | jq -r '.height')
    BLOCK_HASH=$(echo "$ctx" | jq -r '.block_hash')
    GEN_SIG=$(echo "$ctx" | jq -r '.generation_signature')
    BASE_TARGET=$(echo "$ctx" | jq -r '.base_target')
    MIN_COMPRESSION=$(echo "$ctx" | jq -r '.minimum_compression_level')
}

# submit_nonce wrapper. With no argument => legacy 9-arg call; with an argument =>
# append it as the coinbase_outputs (10th) param. Captures exit code + output.
submit() {
    set +e
    if [ "$#" -eq 0 ]; then
        SN_RAW=$($CLI submit_nonce "$BLOCK_HASH" "$HEIGHT" "$GEN_SIG" "$BASE_TARGET" \
                    "$ACCOUNT" "$SEED" 1 "$MIN_COMPRESSION" 0 2>&1)
    else
        SN_RAW=$($CLI submit_nonce "$BLOCK_HASH" "$HEIGHT" "$GEN_SIG" "$BASE_TARGET" \
                    "$ACCOUNT" "$SEED" 1 "$MIN_COMPRESSION" 0 "$1" 2>&1)
    fi
    SN_RC=$?
    set -e
}

err_code() { echo "$SN_RAW" | sed -n 's/^error code: //p' | head -1; }

# -----------------------------------------------------------------------------
# Error cases first: coinbase_outputs is parsed before proof/context checks, so
# these throw regardless of chain state and never queue a submission.
# -----------------------------------------------------------------------------
refresh_ctx

echo ""
echo "Case C - invalid address in payout map (expect -5)"
echo "--------------------------------------------------"
submit "[{\"address\":\"notanaddress\",\"amount_sat\":100000000}]"
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -ne 0 ] || fail "accepted a payout map with an invalid address"
[ "$(err_code)" = "-5" ] || fail "expected -5 (RPC_INVALID_ADDRESS_OR_KEY), got '$(err_code)'"
echo "Case C PASS"

echo ""
echo "Case D - negative amount_sat (expect -3)"
echo "----------------------------------------"
submit "[{\"address\":\"$FORGING_ADDR\",\"amount_sat\":-1}]"
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -ne 0 ] || fail "accepted a negative amount_sat"
[ "$(err_code)" = "-3" ] || fail "expected -3 (RPC_TYPE_ERROR), got '$(err_code)'"
echo "Case D PASS"

echo ""
echo "Case E - amount_sat above MAX_MONEY (expect -3)"
echo "-----------------------------------------------"
submit "[{\"address\":\"$FORGING_ADDR\",\"amount_sat\":$((MAX_MONEY + 1))}]"
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -ne 0 ] || fail "accepted an out-of-range amount_sat"
[ "$(err_code)" = "-3" ] || fail "expected -3 (RPC_TYPE_ERROR), got '$(err_code)'"
echo "Case E PASS"

echo ""
echo "Case F - entry missing amount_sat (expect -8)"
echo "---------------------------------------------"
submit "[{\"address\":\"$FORGING_ADDR\"}]"
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -ne 0 ] || fail "accepted a payout entry with no amount_sat"
[ "$(err_code)" = "-8" ] || fail "expected -8 (RPC_INVALID_PARAMETER), got '$(err_code)'"
echo "Case F PASS"

# -----------------------------------------------------------------------------
# ACK cases: full valid context required (height/block_hash/gen_sig/base_target,
# key gate, proof). Refresh context immediately before each.
# -----------------------------------------------------------------------------
echo ""
echo "Case A - legacy 9-arg submit_nonce, no payout map (expect ACK)"
echo "-------------------------------------------------------------"
refresh_ctx
submit
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -eq 0 ] || fail "legacy submit_nonce errored: $SN_RAW"
[ -n "$(echo "$SN_RAW" | jq -r '.raw_quality // empty')" ] || fail "legacy ACK missing raw_quality (backward-compat broken)"
echo "Case A PASS  (backward compatible)"

echo ""
echo "Case B - valid 2-recipient payout map (expect ACK)"
echo "--------------------------------------------------"
refresh_ctx
submit "[{\"address\":\"$FORGING_ADDR\",\"amount_sat\":100000000},{\"address\":\"$ADDR2\",\"amount_sat\":50000000}]"
echo "exit: $SN_RC  $SN_RAW"
[ "$SN_RC" -eq 0 ] || fail "submit_nonce rejected a valid payout map: $SN_RAW"
[ -n "$(echo "$SN_RAW" | jq -r '.raw_quality // empty')" ] || fail "payout-map ACK missing raw_quality"
echo "Case B PASS  (payout map parsed and accepted)"

$CLI unloadwallet keyed >/dev/null
$CLI stop >/dev/null
sleep 1

echo ""
echo "ALL CASES PASS"
echo ""
echo "Note: forged-block split coinbase, remainder->signer, and forge-time"
echo "over-budget rejection are covered by the block_builder ApplyCoinbaseOutputs"
echo "unit test (they require the scheduler to forge with a winning nonce)."
