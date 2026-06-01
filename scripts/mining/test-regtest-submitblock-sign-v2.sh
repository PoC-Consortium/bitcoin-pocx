#!/bin/bash
# PoCX regtestv2: submitblock signs unsigned blocks (pool non-custodial path).
#
# Exercises the always-on submitblock auto-sign feature (MaybeSignPoCXBlock):
# when a submitted PoCX block has an all-zero signature, the node signs it in
# place using a loaded, unlocked wallet that holds the effective signer's key,
# then processes it normally. A block that is already signed is processed as-is.
#
#   Case A  Positive       — unsigned single-output block, wallet holds the key
#                            (unlocked). Expect accept, tip advances, the accepted
#                            block carries a non-zero signature (node signed it).
#   Case B  Back-compat     — already-signed block, NO forging wallet loaded.
#                            Expect accept (helper is a no-op on signed blocks).
#   Case C  Absent          — unsigned block, no loaded wallet holds the key.
#                            Expect error -5 (RPC_INVALID_ADDRESS_OR_KEY), bech32
#                            effective-signer address in the message, tip unchanged.
#   Case D  Locked          — unsigned block, wallet holds the key but is locked.
#                            Expect error, "walletpassphrase" hint, tip unchanged.
#   Case E  Split coinbase  — unsigned block rebuilt with a 2-output coinbase (the
#                            real pool goal: pay miners directly). Expect accept,
#                            both payout outputs present, block signed.
#
# Notes on the on-the-wire format used by the strip/rebuild helpers below.
# The PoCX block header is fixed-width (ENABLE_POCX, primitives/block.h):
#   nVersion(4) prevBlock(32) merkleRoot(32) nTime(4) nHeight(4)
#   generationSignature(32) nBaseTarget(8)
#   pocxProof{ seed(32) account_id(20) compression(4) nonce(8) quality(8) }=72
#   vchPubKey(33) vchSignature(65)  => 286 bytes total.
# So in the serialized block hex (2 chars/byte):
#   hashMerkleRoot = chars [136,200)   vchSignature = chars [442,572)
# vchSignature is the last header field; the tx section follows it.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
DATADIR="$HOME/.bitcoin-pocx/regtestv2-submitblock-sign"

# The regtest forging key (src/pocx/regtest/forging.cpp kRegtestForgingPrivKey,
# raw hex 0a1590dc8867ab2a1fc28432dcc1c614fc0e5e0b169b9cc9f4dd7263232c8ff8).
# generateblock forges + signs regtest blocks with this key, so the effective
# signer of every generated block is this key's P2WPKH address. The signing
# wallet must therefore hold THIS key for the node to auto-sign on submitblock.
# WIF is the regtest/testnet (compressed) encoding of that raw key.
FORGING_WIF="cMvJbCxo3qCee5EFHSYVuK7UP69ijvHtXmrikzKtjbtEvzUYU5T5"
PASSPHRASE="hodor"

ZSIG=$(printf '0%.0s' $(seq 1 130))   # 65 zero bytes, hex

echo "PoCX Regtestv2 submitblock Auto-Sign Test"
echo "========================================="

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
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
MOCK=$(date +%s)
$CLI setmocktime "$MOCK" >/dev/null

fail() {
    echo ""
    echo "FAIL: $1"
    $CLI stop >/dev/null 2>&1 || true
    exit 1
}

# Canonical pubkey descriptor + bech32 address (the effective signer) for the key.
DESC_INFO=$($CLI getdescriptorinfo "wpkh($FORGING_WIF)")
PUBKEY_DESC=$(echo "$DESC_INFO" | jq -r '.descriptor')
CHECKSUM=$(echo "$DESC_INFO" | jq -r '.checksum')
PRIVKEY_DESC="wpkh($FORGING_WIF)#$CHECKSUM"
FORGING_ADDR=$($CLI deriveaddresses "$PUBKEY_DESC" | jq -r '.[0]')
[ -n "$FORGING_ADDR" ] && [ "$FORGING_ADDR" != "null" ] || fail "could not derive forging address"
echo "Effective signer (forging) address: $FORGING_ADDR"

import_forging_key() {  # $1 = wallet name (descriptor wallet, with private keys)
    $CLI createwallet "$1" false true "" false true >/dev/null
    $CLI -rpcwallet="$1" importdescriptors "[{\"desc\": \"$PRIVKEY_DESC\", \"timestamp\": \"now\"}]" >/dev/null
}

bump_time() { MOCK=$((MOCK + 600)); $CLI setmocktime "$MOCK" >/dev/null; }

# Forge a valid (signed) block for the current tip without submitting it.
# Sets SIGNED (block hex) and GHASH (block hash). generateblock forges with the
# hardcoded regtest key regardless of loaded wallets.
gen_block() {
    bump_time
    local res; res=$($CLI generateblock "$FORGING_ADDR" '[]' false)
    GHASH=$(echo "$res" | jq -r '.hash')
    SIGNED=$(echo "$res" | jq -r '.hex')
    [ -n "$SIGNED" ] && [ "$SIGNED" != "null" ] || fail "generateblock returned no hex"
    [ "${SIGNED:442:130}" != "$ZSIG" ] || fail "generated block has no signature to strip"
}

# Zero the 65-byte vchSignature (last header field) -> unsigned block hex.
strip_signature() { printf '%s%s%s' "${1:0:442}" "$ZSIG" "${1:572}"; }

# submitblock wrapper capturing exit code + stdout/stderr together.
submitblock_raw() {
    set +e
    SB_RAW=$($CLI submitblock "$1" 2>&1)
    SB_RC=$?
    set -e
}

# -----------------------------------------------------------------------------
# Case A — Positive: unsigned block, unlocked wallet holds the forging key.
# -----------------------------------------------------------------------------
echo ""
echo "Case A — unsigned block, wallet holds key, unlocked (accept expected)"
echo "--------------------------------------------------------------------"
import_forging_key keyed
gen_block
UNSIGNED=$(strip_signature "$SIGNED")
[ "${UNSIGNED:442:130}" = "$ZSIG" ] || fail "strip_signature did not zero the signature"
H0=$($CLI getblockcount)

submitblock_raw "$UNSIGNED"
echo "submitblock exit: $SB_RC  result: '${SB_RAW:-<null>}'"
[ "$SB_RC" -eq 0 ] || fail "submitblock errored on signable unsigned block: $SB_RAW"
[ -z "$SB_RAW" ] || fail "block not accepted cleanly (got '$SB_RAW')"
H1=$($CLI getblockcount)
[ "$H1" -eq "$((H0 + 1))" ] || fail "tip did not advance ($H0 -> $H1)"
TIP=$($CLI getbestblockhash)
[ "$TIP" = "$GHASH" ] || fail "tip $TIP != expected block hash $GHASH"
TIPHEX=$($CLI getblock "$TIP" 0)
[ "${TIPHEX:442:130}" != "$ZSIG" ] || fail "accepted block has zero signature — node did not sign"
echo "Case A PASS  (unsigned block signed by node and accepted; tip $TIP)"
$CLI unloadwallet keyed >/dev/null

# -----------------------------------------------------------------------------
# Case B — Back-compat: already-signed block, no forging wallet loaded.
# The helper must no-op on a signed block, so it is processed exactly as before.
# -----------------------------------------------------------------------------
echo ""
echo "Case B — already-signed block, no signing wallet (accept as-is expected)"
echo "-----------------------------------------------------------------------"
gen_block
H0=$($CLI getblockcount)
submitblock_raw "$SIGNED"
echo "submitblock exit: $SB_RC  result: '${SB_RAW:-<null>}'"
[ "$SB_RC" -eq 0 ] || fail "submitblock errored on already-signed block: $SB_RAW"
[ -z "$SB_RAW" ] || fail "signed block not accepted cleanly (got '$SB_RAW')"
H1=$($CLI getblockcount)
[ "$H1" -eq "$((H0 + 1))" ] || fail "tip did not advance for signed block ($H0 -> $H1)"
[ "$($CLI getbestblockhash)" = "$GHASH" ] || fail "tip != signed block hash"
echo "Case B PASS  (signed block processed as-is, feature did not interfere)"

# -----------------------------------------------------------------------------
# Case C — Absent: unsigned block, a wallet is loaded but holds no forging key.
# -----------------------------------------------------------------------------
echo ""
echo "Case C — unsigned block, no wallet holds the key (error -5 expected)"
echo "-------------------------------------------------------------------"
$CLI createwallet other false true "" false true >/dev/null   # fresh keys, not the forging key
gen_block
UNSIGNED=$(strip_signature "$SIGNED")
H0=$($CLI getblockcount)
submitblock_raw "$UNSIGNED"
echo "submitblock exit: $SB_RC"
echo "$SB_RAW"
[ "$SB_RC" -ne 0 ] || fail "submitblock accepted an unsignable unsigned block (gate broken)"
ERR_CODE=$(echo "$SB_RAW" | sed -n 's/^error code: //p' | head -1)
[ "$ERR_CODE" = "-5" ] || fail "expected error code -5 (RPC_INVALID_ADDRESS_OR_KEY), got '$ERR_CODE'"
echo "$SB_RAW" | grep -q "$FORGING_ADDR" || fail "error message lacks bech32 signer address $FORGING_ADDR"
[ "$($CLI getblockcount)" -eq "$H0" ] || fail "tip advanced on a rejected block"
echo "Case C PASS  (-5, bech32 signer rendered, tip unchanged)"
$CLI unloadwallet other >/dev/null

# -----------------------------------------------------------------------------
# Case D — Locked: unsigned block, wallet holds the key but is encrypted+locked.
# -----------------------------------------------------------------------------
echo ""
echo "Case D — unsigned block, wallet holds key but is locked (error expected)"
echo "-----------------------------------------------------------------------"
import_forging_key keyed_locked
$CLI -rpcwallet=keyed_locked encryptwallet "$PASSPHRASE" >/dev/null   # encrypt locks the wallet
UNLOCKED_UNTIL=$($CLI -rpcwallet=keyed_locked getwalletinfo | jq -r '.unlocked_until // 0')
[ "$UNLOCKED_UNTIL" = "0" ] || fail "wallet not locked after encryptwallet (unlocked_until=$UNLOCKED_UNTIL)"
gen_block
UNSIGNED=$(strip_signature "$SIGNED")
H0=$($CLI getblockcount)
submitblock_raw "$UNSIGNED"
echo "submitblock exit: $SB_RC"
echo "$SB_RAW"
[ "$SB_RC" -ne 0 ] || fail "submitblock accepted unsigned block against a locked wallet"
echo "$SB_RAW" | grep -qi "walletpassphrase" || fail "error message lacks the walletpassphrase hint"
echo "$SB_RAW" | grep -q "$FORGING_ADDR" || fail "error message lacks bech32 signer address"
[ "$($CLI getblockcount)" -eq "$H0" ] || fail "tip advanced on a rejected (locked) block"
echo "Case D PASS  (locked wallet rejected with unlock hint, tip unchanged)"
$CLI unloadwallet keyed_locked >/dev/null

# -----------------------------------------------------------------------------
# Case E — Split coinbase (the pool goal): rebuild the coinbase with two payout
# outputs, recompute the merkle root, zero the signature, submit. The node signs
# and accepts; both payout outputs must land. Coinbase surgery is done in python
# (stdlib only) because it requires tx re-serialization + merkle recompute.
# -----------------------------------------------------------------------------
echo ""
echo "Case E — unsigned 2-output split coinbase (accept + both outputs expected)"
echo "-------------------------------------------------------------------------"
import_forging_key keyed2
gen_block

SPLIT=$(python3 - "$SIGNED" <<'PY'
import sys, hashlib
b = bytearray.fromhex(sys.argv[1].strip())
HDR = 286
# Two distinct P2WPKH payout scripts (destinations are consensus-irrelevant).
HASH_A = bytes.fromhex('11' * 20)
HASH_B = bytes.fromhex('22' * 20)
p2wpkh = lambda h: bytes([0x00, 0x14]) + h

def rd_varint(buf, p):
    n = buf[p]; p += 1
    if n < 0xfd: return n, p
    if n == 0xfd: return int.from_bytes(buf[p:p+2], 'little'), p + 2
    if n == 0xfe: return int.from_bytes(buf[p:p+4], 'little'), p + 4
    return int.from_bytes(buf[p:p+8], 'little'), p + 8

def wr_varint(n):
    if n < 0xfd: return bytes([n])
    if n <= 0xffff: return b'\xfd' + n.to_bytes(2, 'little')
    if n <= 0xffffffff: return b'\xfe' + n.to_bytes(4, 'little')
    return b'\xff' + n.to_bytes(8, 'little')

pos = HDR
txcount, pos = rd_varint(b, pos)
assert txcount == 1, "expected a single coinbase tx, got %d" % txcount

version = b[pos:pos+4]; pos += 4
segwit = (b[pos] == 0x00 and b[pos+1] == 0x01)
if segwit: pos += 2
nin, pos = rd_varint(b, pos)
vins = []
for _ in range(nin):
    op = b[pos:pos+36]; pos += 36
    sl, pos = rd_varint(b, pos)
    script = b[pos:pos+sl]; pos += sl
    seq = b[pos:pos+4]; pos += 4
    vins.append((op, script, seq))
nout, pos = rd_varint(b, pos)
vouts = []
for _ in range(nout):
    val = int.from_bytes(b[pos:pos+8], 'little'); pos += 8
    sl, pos = rd_varint(b, pos)
    spk = b[pos:pos+sl]; pos += sl
    vouts.append((val, spk))
wit_start = pos
if segwit:
    for _ in range(nin):
        ni, pos = rd_varint(b, pos)
        for _ in range(ni):
            il, pos = rd_varint(b, pos)
            pos += il
wit_bytes = bytes(b[wit_start:pos])
locktime = b[pos:pos+4]; pos += 4

# Split the reward output (first non-OP_RETURN) into two P2WPKH outputs.
new_vouts, done = [], False
for val, spk in vouts:
    if not done and spk and spk[0] != 0x6a:
        a = val // 2
        new_vouts.append((a, p2wpkh(HASH_A)))
        new_vouts.append((val - a, p2wpkh(HASH_B)))
        done = True
    else:
        new_vouts.append((val, spk))
assert done, "no splittable reward output found"

def ser_vouts(vs):
    out = wr_varint(len(vs))
    for val, spk in vs:
        out += val.to_bytes(8, 'little') + wr_varint(len(spk)) + spk
    return out

def ser_vins(vs):
    out = wr_varint(len(vs))
    for op, script, seq in vs:
        out += op + wr_varint(len(script)) + script + seq
    return out

# Legacy (no-witness) serialization -> txid -> merkle root (single tx, internal order).
legacy = bytes(version) + ser_vins(vins) + ser_vouts(new_vouts) + bytes(locktime)
merkle = hashlib.sha256(hashlib.sha256(legacy).digest()).digest()

# Full coinbase (witness preserved) for the block body.
full = bytearray(version)
if segwit: full += bytes([0x00, 0x01])
full += ser_vins(vins) + ser_vouts(new_vouts) + wit_bytes + bytes(locktime)

hdr = bytearray(b[:HDR])
hdr[68:100] = merkle        # hashMerkleRoot
hdr[221:286] = bytes(65)    # vchSignature -> zero
print((bytes(hdr) + wr_varint(1) + bytes(full)).hex())
PY
)
[ -n "$SPLIT" ] || fail "python split-coinbase helper produced no output"
[ "${SPLIT:442:130}" = "$ZSIG" ] || fail "split block signature is not zeroed"
H0=$($CLI getblockcount)
submitblock_raw "$SPLIT"
echo "submitblock exit: $SB_RC  result: '${SB_RAW:-<null>}'"
[ "$SB_RC" -eq 0 ] || fail "submitblock errored on split-coinbase block: $SB_RAW"
[ -z "$SB_RAW" ] || fail "split-coinbase block not accepted cleanly (got '$SB_RAW')"
H1=$($CLI getblockcount)
[ "$H1" -eq "$((H0 + 1))" ] || fail "tip did not advance for split-coinbase block ($H0 -> $H1)"
TIP=$($CLI getbestblockhash)
CB_SPKS=$($CLI getblock "$TIP" 2 | jq -r '.tx[0].vout[].scriptPubKey.hex')
echo "$CB_SPKS" | grep -q "0014$(printf '11%.0s' {1..20})" || fail "payout output A missing from accepted coinbase"
echo "$CB_SPKS" | grep -q "0014$(printf '22%.0s' {1..20})" || fail "payout output B missing from accepted coinbase"
TIPHEX=$($CLI getblock "$TIP" 0)
[ "${TIPHEX:442:130}" != "$ZSIG" ] || fail "accepted split block has zero signature — node did not sign"
echo "Case E PASS  (2-output split coinbase signed and accepted; both payouts landed)"
$CLI unloadwallet keyed2 >/dev/null

$CLI stop >/dev/null
sleep 1

echo ""
echo "ALL CASES PASS"
