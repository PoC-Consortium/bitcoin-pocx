#!/bin/bash
# PoCX regtestv2: submit_nonce wallet-key gate (all three states).
#
# Covers every branch of the receive-path probe (HaveAccountKey):
#   Case A  Absent     — wallet has the script but no private key (watch-only
#                        descriptor). Expect error -5 (RPC_INVALID_ADDRESS_OR_KEY),
#                        bech32 signer in the message, no raw hash160 leakage.
#   Case B  Locked     — wallet holds the encrypted private key but is locked.
#                        Expect error -13 (RPC_WALLET_UNLOCK_NEEDED), "unlock with
#                        walletpassphrase first" in the message.
#   Case C  Available  — wallet holds the private key, unlocked.
#                        Expect exit 0 and a JSON result with raw_quality/poc_time.
#   Case D  Multi-wallet — Locked + Available loaded simultaneously, Locked first
#                        in iteration order. The probe must continue past the
#                        Locked match and pick the Available wallet (expect exit 0).
#   Case E  Multi-wallet — same as D but Available is loaded first. Proves the
#                        result is order-independent and rules out a "Locked
#                        overrides Available when seen later" bug.
#
# Regression guards for:
#   - PoC-Consortium/bitcoin-pocx#4 (PR PoC-Consortium/bitcoin#3) — Absent/Locked split
#   - PoC-Consortium/bitcoin-pocx#3 (PR PoC-Consortium/bitcoin#2) — bech32 rendering
#
# Each case runs against the same daemon with the relevant wallet loaded in
# isolation (others unloaded), so the probe state under test is unambiguous.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtestv2-submitnonce-key-gate"

# Static keypair (same WIF as test-regtest-mining-legacy-v2.sh) for reproducibility.
WIF_KEY="cNgs3AUH8xu2faRgLBR5kT7mAB6tUJZDDRH5YeKtZw4LqhbapNWd"
PASSPHRASE="hodor"

echo "PoCX Regtestv2 submit_nonce Key-Gate Test (Absent / Locked / Available)"
echo "======================================================================="

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

# Derive the bech32 address and hash160 of the target account up-front.
# getdescriptorinfo on a privkey-bearing descriptor returns the canonical
# PUBKEY-only descriptor in .descriptor, which is what the watch-only case
# imports below. We reuse the privkey descriptor with checksum for the
# privkey-bearing cases.
DESC_INFO=$($CLI getdescriptorinfo "wpkh($WIF_KEY)")
PUBKEY_DESC=$(echo "$DESC_INFO" | jq -r '.descriptor')
CHECKSUM=$(echo "$DESC_INFO" | jq -r '.checksum')
PRIVKEY_DESC="wpkh($WIF_KEY)#$CHECKSUM"
ADDRESS=$($CLI deriveaddresses "$PUBKEY_DESC" | jq -r '.[0]')
echo "Target address: $ADDRESS"

# Fetch hash160 (used as account_id) once via a throwaway wallet, then unload.
$CLI createwallet probe true true "" false true >/dev/null
$CLI -rpcwallet=probe importdescriptors "[{\"desc\": \"$PUBKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
WITNESS_PROGRAM=$($CLI -rpcwallet=probe getaddressinfo "$ADDRESS" | jq -r '.witness_program')
$CLI unloadwallet probe >/dev/null
if [ -z "$WITNESS_PROGRAM" ] || [ "$WITNESS_PROGRAM" = "null" ]; then
    echo "ERROR: could not derive witness_program for $ADDRESS"
    $CLI stop >/dev/null 2>&1 || true
    exit 1
fi
echo "Account ID (hash160): $WITNESS_PROGRAM"

# Mining context — submit_nonce step 4 (wallet check) fires after steps 1-3
# (format / height / block_hash / gen_sig / base_target) and before step 5
# (compression) and step 6 (proof validation). So context fields must match
# the current tip; nonce/seed/compression just need to parse.
CTX=$($CLI get_mining_info)
HEIGHT=$(echo "$CTX" | jq -r '.height')
BLOCK_HASH=$(echo "$CTX" | jq -r '.block_hash')
GEN_SIG=$(echo "$CTX" | jq -r '.generation_signature')
BASE_TARGET=$(echo "$CTX" | jq -r '.base_target')
MIN_COMPRESSION=$(echo "$CTX" | jq -r '.minimum_compression_level')
SEED=$(printf '0%.0s' $(seq 1 64))  # 64-hex zeros, parses fine

# submit_nonce wrapper that captures exit code + stdout/stderr together.
submit_nonce_against() {
    local _account="$1"
    set +e
    SN_RAW=$($CLI submit_nonce "$BLOCK_HASH" "$HEIGHT" "$GEN_SIG" "$BASE_TARGET" \
                "$_account" "$SEED" 1 "$MIN_COMPRESSION" 0 2>&1)
    SN_RC=$?
    set -e
}

fail() {
    echo ""
    echo "FAIL: $1"
    $CLI stop >/dev/null 2>&1 || true
    exit 1
}

# -----------------------------------------------------------------------------
# Case A — Absent: pubkey-only descriptor loaded, no private key.
# Pre-fix bug: IsMine returned true on the registered script and submit_nonce
# ACK'd; the scheduler then built unsigned blocks that signing dropped.
# Post-fix: GetPoCXPubKey rejects, availability=Absent, RPC throws -5.
# -----------------------------------------------------------------------------
echo ""
echo "Case A — watch-only descriptor (Absent expected)"
echo "------------------------------------------------"
# createwallet args: name, disable_private_keys, blank, passphrase, avoid_reuse, descriptors
$CLI createwallet wo true true "" false true >/dev/null
$CLI -rpcwallet=wo importdescriptors "[{\"desc\": \"$PUBKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null

INFO=$($CLI -rpcwallet=wo getaddressinfo "$ADDRESS")
IS_MINE=$(echo "$INFO" | jq -r '.ismine')
IS_SOLVABLE=$(echo "$INFO" | jq -r '.solvable')
[ "$IS_MINE" = "true" ] && [ "$IS_SOLVABLE" = "true" ] \
    || fail "watch-only wallet sanity: ismine=$IS_MINE solvable=$IS_SOLVABLE (want both true)"
echo "Wallet sees script (ismine=true solvable=true), no privkey loaded"

submit_nonce_against "$WITNESS_PROGRAM"
echo "submit_nonce exit: $SN_RC"
echo "$SN_RAW"

[ "$SN_RC" -ne 0 ] || fail "submit_nonce returned success — wallet-key gate is broken (issue #4 regression)"
ERR_CODE=$(echo "$SN_RAW" | sed -n 's/^error code: //p' | head -1)
[ "$ERR_CODE" = "-5" ] || fail "expected error code -5 (RPC_INVALID_ADDRESS_OR_KEY), got '$ERR_CODE'"
echo "$SN_RAW" | grep -q "$ADDRESS" || fail "error message does not contain bech32 address $ADDRESS"
if echo "$SN_RAW" | grep -Eq "[^0-9a-f]$WITNESS_PROGRAM[^0-9a-f]|[^0-9a-f]$WITNESS_PROGRAM\$|^$WITNESS_PROGRAM"; then
    fail "error message contains raw hash160 hex $WITNESS_PROGRAM (bech32 regression)"
fi
echo "Case A PASS  (-5, bech32 rendered, no raw-hex regression)"

$CLI unloadwallet wo >/dev/null

# -----------------------------------------------------------------------------
# Case B — Locked: descriptor wallet with privkey, encrypted, locked.
# encryptwallet on a descriptor wallet encrypts in-place and locks. The wallet
# stays loaded. CanProvide still matches; GetPoCXPubKey fails because the
# privkey is sealed; cwallet->IsLocked() is true → availability=Locked.
# RPC throws -13 with the "unlock with walletpassphrase first" hint.
# -----------------------------------------------------------------------------
echo ""
echo "Case B — encrypted + locked wallet with privkey (Locked expected)"
echo "-----------------------------------------------------------------"
$CLI createwallet locked false true "" false true >/dev/null
$CLI -rpcwallet=locked importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
# encryptwallet locks the wallet as part of encryption.
$CLI -rpcwallet=locked encryptwallet "$PASSPHRASE" >/dev/null
# Sanity: walletinfo reports the wallet as locked (unlocked_until == 0 or missing).
WALLET_INFO=$($CLI -rpcwallet=locked getwalletinfo)
UNLOCKED_UNTIL=$(echo "$WALLET_INFO" | jq -r '.unlocked_until // 0')
[ "$UNLOCKED_UNTIL" = "0" ] || fail "expected wallet to be locked after encryptwallet (unlocked_until=$UNLOCKED_UNTIL)"
echo "Wallet encrypted and locked (unlocked_until=0)"

submit_nonce_against "$WITNESS_PROGRAM"
echo "submit_nonce exit: $SN_RC"
echo "$SN_RAW"

[ "$SN_RC" -ne 0 ] || fail "submit_nonce returned success — Locked branch is broken"
ERR_CODE=$(echo "$SN_RAW" | sed -n 's/^error code: //p' | head -1)
[ "$ERR_CODE" = "-13" ] || fail "expected error code -13 (RPC_WALLET_UNLOCK_NEEDED), got '$ERR_CODE'"
echo "$SN_RAW" | grep -qi "walletpassphrase" \
    || fail "error message does not mention walletpassphrase — operator hint regressed"
echo "$SN_RAW" | grep -q "$ADDRESS" || fail "error message does not contain bech32 address $ADDRESS"
echo "Case B PASS  (-13, walletpassphrase hint present)"

$CLI unloadwallet locked >/dev/null

# -----------------------------------------------------------------------------
# Case C — Available: descriptor wallet with privkey, unlocked.
# CanProvide matches and GetPoCXPubKey returns the pubkey. submit_nonce
# proceeds through compression bounds + proof validation. Any nonce parses
# (proofs are not gate-checked for "winning"); a successful JSON result
# carries raw_quality and poc_time.
# -----------------------------------------------------------------------------
echo ""
echo "Case C — unlocked wallet with privkey (Available expected)"
echo "----------------------------------------------------------"
$CLI createwallet keyed false true "" false true >/dev/null
$CLI -rpcwallet=keyed importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null

# Refresh mining context — height may have advanced if anything mined; for
# this script's lifetime no blocks are produced, but it's cheap insurance.
CTX=$($CLI get_mining_info)
HEIGHT=$(echo "$CTX" | jq -r '.height')
BLOCK_HASH=$(echo "$CTX" | jq -r '.block_hash')
GEN_SIG=$(echo "$CTX" | jq -r '.generation_signature')
BASE_TARGET=$(echo "$CTX" | jq -r '.base_target')
MIN_COMPRESSION=$(echo "$CTX" | jq -r '.minimum_compression_level')

submit_nonce_against "$WITNESS_PROGRAM"
echo "submit_nonce exit: $SN_RC"
echo "$SN_RAW"

[ "$SN_RC" -eq 0 ] || fail "submit_nonce did not succeed for unlocked privkey wallet"
RAW_QUALITY=$(echo "$SN_RAW" | jq -r '.raw_quality // empty')
POC_TIME=$(echo "$SN_RAW" | jq -r '.poc_time // empty')
[ -n "$RAW_QUALITY" ] || fail "success response missing raw_quality"
[ -n "$POC_TIME" ]    || fail "success response missing poc_time"
echo "Case C PASS  (raw_quality=$RAW_QUALITY poc_time=${POC_TIME}s)"

$CLI unloadwallet keyed >/dev/null

# -----------------------------------------------------------------------------
# Case D — multi-wallet probe: Locked wallet loaded alongside an Available
# wallet. The receive-path loop must iterate past the locked match and pick
# the unlocked one. A naive "break on first match" or "break on first Locked"
# refactor would mis-route to RPC_WALLET_UNLOCK_NEEDED here. The locked wallet
# is loaded FIRST so it appears first in the iteration order — that's the
# ordering that exercises the failure mode.
#
# The forger (scheduler.cpp ForgeBlock) uses the same iteration shape with
# the same Available-only short-circuit (&&), so structural correctness
# carries over; the actual forge path is out of scope here.
# -----------------------------------------------------------------------------
echo ""
echo "Case D — Locked wallet + Available wallet (Available must win across wallets)"
echo "-----------------------------------------------------------------------------"
$CLI createwallet locked_first false true "" false true >/dev/null
$CLI -rpcwallet=locked_first importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
$CLI -rpcwallet=locked_first encryptwallet "$PASSPHRASE" >/dev/null
LF_UNLOCKED_UNTIL=$($CLI -rpcwallet=locked_first getwalletinfo | jq -r '.unlocked_until // 0')
[ "$LF_UNLOCKED_UNTIL" = "0" ] || fail "locked_first did not lock (unlocked_until=$LF_UNLOCKED_UNTIL)"

$CLI createwallet keyed_second false true "" false true >/dev/null
$CLI -rpcwallet=keyed_second importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null

echo "Loaded wallets (probe order): $($CLI listwallets | jq -c '.')"

CTX=$($CLI get_mining_info)
HEIGHT=$(echo "$CTX" | jq -r '.height')
BLOCK_HASH=$(echo "$CTX" | jq -r '.block_hash')
GEN_SIG=$(echo "$CTX" | jq -r '.generation_signature')
BASE_TARGET=$(echo "$CTX" | jq -r '.base_target')
MIN_COMPRESSION=$(echo "$CTX" | jq -r '.minimum_compression_level')

submit_nonce_against "$WITNESS_PROGRAM"
echo "submit_nonce exit: $SN_RC"
echo "$SN_RAW"

[ "$SN_RC" -eq 0 ] || fail "multi-wallet probe failed: expected Available to win over Locked, got exit $SN_RC"
RAW_QUALITY=$(echo "$SN_RAW" | jq -r '.raw_quality // empty')
POC_TIME=$(echo "$SN_RAW" | jq -r '.poc_time // empty')
[ -n "$RAW_QUALITY" ] || fail "multi-wallet success response missing raw_quality"
[ -n "$POC_TIME" ]    || fail "multi-wallet success response missing poc_time"
echo "Case D PASS  (Available won across wallets; raw_quality=$RAW_QUALITY poc_time=${POC_TIME}s)"

$CLI unloadwallet locked_first >/dev/null
$CLI unloadwallet keyed_second >/dev/null

# -----------------------------------------------------------------------------
# Case E — same multi-wallet setup as Case D, but Available is loaded FIRST.
# Once availability=Available the loop breaks, so a later Locked match must
# never downgrade the result. Together with D this proves the probe outcome
# is order-independent for the {Locked, Available} pair.
# -----------------------------------------------------------------------------
echo ""
echo "Case E — Available wallet + Locked wallet (Available must win, regardless of order)"
echo "-----------------------------------------------------------------------------------"
$CLI createwallet keyed_first false true "" false true >/dev/null
$CLI -rpcwallet=keyed_first importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null

$CLI createwallet locked_second false true "" false true >/dev/null
$CLI -rpcwallet=locked_second importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
$CLI -rpcwallet=locked_second encryptwallet "$PASSPHRASE" >/dev/null
LS_UNLOCKED_UNTIL=$($CLI -rpcwallet=locked_second getwalletinfo | jq -r '.unlocked_until // 0')
[ "$LS_UNLOCKED_UNTIL" = "0" ] || fail "locked_second did not lock (unlocked_until=$LS_UNLOCKED_UNTIL)"

echo "Loaded wallets (probe order): $($CLI listwallets | jq -c '.')"

CTX=$($CLI get_mining_info)
HEIGHT=$(echo "$CTX" | jq -r '.height')
BLOCK_HASH=$(echo "$CTX" | jq -r '.block_hash')
GEN_SIG=$(echo "$CTX" | jq -r '.generation_signature')
BASE_TARGET=$(echo "$CTX" | jq -r '.base_target')
MIN_COMPRESSION=$(echo "$CTX" | jq -r '.minimum_compression_level')

submit_nonce_against "$WITNESS_PROGRAM"
echo "submit_nonce exit: $SN_RC"
echo "$SN_RAW"

[ "$SN_RC" -eq 0 ] || fail "multi-wallet probe failed (Available first): expected exit 0, got $SN_RC"
RAW_QUALITY=$(echo "$SN_RAW" | jq -r '.raw_quality // empty')
POC_TIME=$(echo "$SN_RAW" | jq -r '.poc_time // empty')
[ -n "$RAW_QUALITY" ] || fail "Available-first success response missing raw_quality"
[ -n "$POC_TIME" ]    || fail "Available-first success response missing poc_time"
echo "Case E PASS  (Available won; order-independent; raw_quality=$RAW_QUALITY poc_time=${POC_TIME}s)"

$CLI unloadwallet keyed_first >/dev/null
$CLI unloadwallet locked_second >/dev/null

$CLI stop >/dev/null
sleep 1

echo ""
echo "ALL CASES PASS"
