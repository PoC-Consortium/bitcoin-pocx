#!/bin/bash
# PoCX regtestv2 bootstrap helper.
# Replaces the template-caching layer from setup-regtest-template.sh.
# The new regtest mines 101 blocks in ~0.5s, so caching is unnecessary.
#
# Usage (sourced from a test script):
#   source "$SCRIPT_DIR/setup-regtestv2.sh"
#   regtestv2_start "$DATADIR"          # starts bitcoind, creates wallet
#   regtestv2_mine_to_maturity           # 101 blocks → spendable balance
#   regtestv2_stop

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"
REGTESTV2_WALLET="${REGTESTV2_WALLET:-test}"

# Current datadir / cli state (set by regtestv2_start)
REGTESTV2_DATADIR=""
REGTESTV2_CLI=""

regtestv2_start() {
    local datadir=$1
    shift || true
    local extra_args=("$@")

    pkill -9 bitcoind 2>/dev/null || true
    sleep 1
    rm -rf "$datadir"
    mkdir -p "$datadir"

    $BITCOIND -regtest -datadir="$datadir" -daemon "${extra_args[@]}" >/dev/null

    REGTESTV2_DATADIR="$datadir"
    REGTESTV2_CLI="$BITCOIN_CLI -regtest -datadir=$datadir"

    for i in 1 2 3 4 5; do
        $REGTESTV2_CLI getblockchaininfo >/dev/null 2>&1 && break
        sleep 1
    done

    # Align mocktime with wall clock so block.nTime tracks reality and
    # wallets (birthday-filtered) see newly-mined coinbases automatically.
    $REGTESTV2_CLI setmocktime "$(date +%s)" >/dev/null

    $REGTESTV2_CLI createwallet "$REGTESTV2_WALLET" >/dev/null
    REGTESTV2_CLI_WALLET="$BITCOIN_CLI -regtest -datadir=$datadir -rpcwallet=$REGTESTV2_WALLET"
}

regtestv2_mine_to_maturity() {
    # 101 blocks: 100 for maturity + 1 spendable coinbase
    local addr=$($REGTESTV2_CLI_WALLET getnewaddress)
    $REGTESTV2_CLI generatetoaddress 101 "$addr" >/dev/null
    echo "$addr"
}

regtestv2_stop() {
    [ -z "$REGTESTV2_CLI" ] && return 0
    $REGTESTV2_CLI stop >/dev/null 2>&1 || true
    sleep 1
    pkill -9 bitcoind 2>/dev/null || true
}

export -f regtestv2_start
export -f regtestv2_mine_to_maturity
export -f regtestv2_stop
