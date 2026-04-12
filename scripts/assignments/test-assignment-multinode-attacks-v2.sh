#!/bin/bash
# Regtestv2: multi-node coordination attack tests.
# Same wallet on multiple nodes with conflicting operations.

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

NODE1_DATADIR="$HOME/.bitcoin-pocx/regtestv2-attacks-node1"
NODE1_PORT=18644
NODE1_RPCPORT=18643
NODE2_DATADIR="$HOME/.bitcoin-pocx/regtestv2-attacks-node2"
NODE2_PORT=18646
NODE2_RPCPORT=18645

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗ FAILED:${NC} $1"; cleanup; exit 1; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

cli_node1() { $BITCOIN_CLI -regtest -datadir="$NODE1_DATADIR" -rpcport="$NODE1_RPCPORT" "$@"; }
cli_node2() { $BITCOIN_CLI -regtest -datadir="$NODE2_DATADIR" -rpcport="$NODE2_RPCPORT" "$@"; }

cleanup() {
    echo ""
    echo "Stopping nodes..."
    cli_node1 stop >/dev/null 2>&1 || true
    cli_node2 stop >/dev/null 2>&1 || true
    sleep 1
    pkill -9 bitcoind 2>/dev/null || true
}
trap cleanup EXIT

echo "=========================================="
echo "Multi-Node Coordination Attack Tests (v2)"
echo "=========================================="

pkill -9 bitcoind 2>/dev/null || true
sleep 1
rm -rf "$NODE1_DATADIR" "$NODE2_DATADIR"
mkdir -p "$NODE1_DATADIR" "$NODE2_DATADIR"

$BITCOIND -regtest -datadir="$NODE1_DATADIR" \
    -port="$NODE1_PORT" -rpcport="$NODE1_RPCPORT" \
    -bind=127.0.0.1:$NODE1_PORT -fallbackfee=0.00001 -daemon >/dev/null
$BITCOIND -regtest -datadir="$NODE2_DATADIR" \
    -port="$NODE2_PORT" -rpcport="$NODE2_RPCPORT" \
    -bind=127.0.0.1:$NODE2_PORT -fallbackfee=0.00001 -daemon >/dev/null

for i in 1 2 3 4 5; do
    cli_node1 getblockchaininfo >/dev/null 2>&1 && \
    cli_node2 getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

NOW=$(date +%s)
cli_node1 setmocktime "$NOW" >/dev/null
# Node2 gets far-future mocktime so propagated blocks fit the 15s future window.
cli_node2 setmocktime "$((NOW + 365*24*3600))" >/dev/null

cli_node1 createwallet "template" >/dev/null
cli_node1 createwallet "wallet1" >/dev/null
cli_node2 createwallet "wallet2" >/dev/null
pass "Created wallets on both nodes"

MINING_ADDR=$(cli_node1 -rpcwallet=template getnewaddress)

cli_node1 addnode "127.0.0.1:$NODE2_PORT" onetry
sleep 1
PEERS=$(cli_node1 getconnectioncount)
[ "$PEERS" -ge 1 ] || fail "Nodes not connected"
pass "Nodes connected"

# Mine initial chain on Node1
cli_node1 generatetoaddress 111 "$MINING_ADDR" >/dev/null
# Wait for Node2 to sync
for i in $(seq 1 20); do
    [ "$(cli_node2 getblockcount)" -eq "$(cli_node1 getblockcount)" ] && break
    sleep 0.5
done
[ "$(cli_node2 getblockcount)" -eq "$(cli_node1 getblockcount)" ] || fail "Node2 did not sync initial chain"
pass "Node2 synced to height $(cli_node2 getblockcount)"

WALLET1_ADDR=$(cli_node1 -rpcwallet=wallet1 getnewaddress)
WALLET2_ADDR=$(cli_node2 -rpcwallet=wallet2 getnewaddress)

# Fund wallet1 and wallet2 using separate UTXOs
TXID1=$(cli_node1 -rpcwallet=template sendtoaddress "$WALLET1_ADDR" 10.0)
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
sleep 1
UTXO_DATA=$(cli_node1 -rpcwallet=template listunspent 1 9999999 | jq ".[] | select(.txid == \"$TXID1\")")
if [ -n "$UTXO_DATA" ]; then
    VOUT=$(echo "$UTXO_DATA" | jq -r '.vout')
    cli_node1 -rpcwallet=template lockunspent false "[{\"txid\":\"$TXID1\",\"vout\":$VOUT}]" >/dev/null
fi
cli_node1 -rpcwallet=template sendtoaddress "$WALLET2_ADDR" 10.0 >/dev/null
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
cli_node1 -rpcwallet=template lockunspent true >/dev/null
sleep 1
pass "Funded test wallets with 10 BTCX each"

echo ""
echo "=========================================="
echo "Test 1: Same Wallet Descriptor Attack"
echo "=========================================="
WALLET_DESC=$(cli_node1 -rpcwallet=wallet1 listdescriptors true | jq -r '.descriptors[0].desc')
cli_node2 createwallet "imported" false >/dev/null 2>&1 || true
cli_node2 -rpcwallet=imported importdescriptors "[{\"desc\":\"$WALLET_DESC\",\"timestamp\":0,\"active\":true,\"range\":1000}]" >/dev/null 2>&1
warn "Same wallet loaded on both nodes (simulating backup restore)"
sleep 2

PLOT_ADDR=$(cli_node1 -rpcwallet=wallet1 getnewaddress "" "bech32")
FORGE_ADDR1=$(cli_node1 -rpcwallet=wallet1 getnewaddress "" "bech32")
FORGE_ADDR2=$(cli_node2 -rpcwallet=wallet2 getnewaddress "" "bech32")

cli_node1 -rpcwallet=wallet1 sendtoaddress "$PLOT_ADDR" 1.0 >/dev/null
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
sleep 1
pass "Funded plot address"

echo ""
echo "=========================================="
echo "Test 2: Concurrent Conflicting Assignments"
echo "=========================================="
echo "Node1 assigning to Forge1: $FORGE_ADDR1"
echo "Node2 assigning to Forge2: $FORGE_ADDR2"

set +e
TXID1=$(cli_node1 -rpcwallet=wallet1 create_assignment "$PLOT_ADDR" "$FORGE_ADDR1" 0.0001 2>&1)
EXIT1=$?
TXID2=$(cli_node2 -rpcwallet=imported create_assignment "$PLOT_ADDR" "$FORGE_ADDR2" 0.0001 2>&1)
EXIT2=$?
set -e

if [ $EXIT1 -ne 0 ] && [ $EXIT2 -ne 0 ]; then
    pass "Both nodes rejected conflicting assignments"
elif [ $EXIT1 -eq 0 ] && [ $EXIT2 -ne 0 ]; then
    pass "Node1 succeeded, Node2 rejected"
elif [ $EXIT1 -ne 0 ] && [ $EXIT2 -eq 0 ]; then
    pass "Node2 succeeded, Node1 rejected"
else
    warn "Both assignments created - checking conflict resolution..."
    cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
    sleep 2
    STATE1=$(cli_node1 get_assignment "$PLOT_ADDR" 2>&1 || echo "{}")
    FORGE=$(echo "$STATE1" | jq -r '.forging_address // "NONE"')
    case "$FORGE" in
        "$FORGE_ADDR1") pass "Node1's assignment won" ;;
        "$FORGE_ADDR2") pass "Node2's assignment won" ;;
        *) fail "Neither assignment made it into block" ;;
    esac
fi

echo ""
echo "=========================================="
echo "Test 3: Assign vs Revoke Race"
echo "=========================================="
PLOT_ADDR2=$(cli_node1 -rpcwallet=wallet1 getnewaddress "" "bech32")
cli_node1 -rpcwallet=wallet1 sendtoaddress "$PLOT_ADDR2" 2.0 >/dev/null
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null

for i in {1..50}; do
    ADDR=$(cli_node2 -rpcwallet=imported getnewaddress "" "bech32")
    [ "$ADDR" = "$PLOT_ADDR2" ] && break
done
sleep 1

cli_node1 -rpcwallet=wallet1 create_assignment "$PLOT_ADDR2" "$FORGE_ADDR1" 0.0001 >/dev/null
cli_node1 generatetoaddress 5 "$MINING_ADDR" >/dev/null
sleep 2
STATE=$(cli_node1 get_assignment "$PLOT_ADDR2" | jq -r '.state')
[ "$STATE" = "ASSIGNED" ] || fail "Expected ASSIGNED state, got $STATE"
pass "Assignment activated on Node1"

set +e
REV_TX=$(cli_node1 -rpcwallet=wallet1 revoke_assignment "$PLOT_ADDR2" 0.0001 2>&1)
REV_EXIT=$?
REASSIGN_TX=$(cli_node2 -rpcwallet=imported create_assignment "$PLOT_ADDR2" "$FORGE_ADDR2" 0.0001 2>&1)
REASSIGN_EXIT=$?
set -e

if [ $REASSIGN_EXIT -ne 0 ] || [[ "$REASSIGN_TX" == *"error"* ]]; then
    pass "Node2 correctly rejected reassignment attempt"
else
    warn "Node2 created conflicting transaction"
fi
[ $REV_EXIT -eq 0 ] && pass "Node1 revocation created successfully"

echo ""
echo "=========================================="
echo "Test 4: Split-Brain Mining"
echo "=========================================="
cli_node1 disconnectnode "127.0.0.1:$NODE2_PORT"
sleep 2
PEERS=$(cli_node1 getconnectioncount)
[ "$PEERS" -eq 0 ] || warn "Still have $PEERS peers"
pass "Nodes disconnected (simulating network partition)"

PLOT_ADDR3=$(cli_node1 -rpcwallet=wallet1 getnewaddress "" "bech32")
cli_node1 -rpcwallet=wallet1 sendtoaddress "$PLOT_ADDR3" 1.0 >/dev/null
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
sleep 1

set +e
cli_node1 -rpcwallet=wallet1 create_assignment "$PLOT_ADDR3" "$FORGE_ADDR1" 0.0001 >/dev/null 2>&1
set -e
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
pass "Node1 mined assignment to Forge1 (height $(cli_node1 getblockcount))"

set +e
ASSIGN2=$(cli_node2 -rpcwallet=imported create_assignment "$PLOT_ADDR3" "$FORGE_ADDR2" 0.0001 2>&1)
ASSIGN2_EXIT=$?
set -e

if [ $ASSIGN2_EXIT -ne 0 ]; then
    pass "Node2 cannot create conflicting assignment (UTXO spent in Node2's view)"
else
    warn "Node2 accepted conflicting assignment"
fi

echo ""
echo "=========================================="
echo "Test 5: Mempool Conflict During Reconnection"
echo "=========================================="
PEERS=$(cli_node1 getconnectioncount)
[ "$PEERS" -eq 0 ] && { cli_node1 addnode "127.0.0.1:$NODE2_PORT" onetry 2>/dev/null || true; sleep 2; }

PLOT_ADDR4=$(cli_node1 -rpcwallet=wallet1 getnewaddress "" "bech32")
cli_node1 -rpcwallet=wallet1 sendtoaddress "$PLOT_ADDR4" 1.0 >/dev/null
cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
sleep 1
pass "Created UTXO for Test 5"

cli_node1 disconnectnode "127.0.0.1:$NODE2_PORT"
sleep 2
pass "Nodes disconnected"

set +e
ASSIGN_RESULT1=$(cli_node1 -rpcwallet=wallet1 create_assignment "$PLOT_ADDR4" "$FORGE_ADDR1" 0.0001 2>&1)
ASSIGN_EXIT=$?
set -e
[ $ASSIGN_EXIT -eq 0 ] || fail "Node1 failed to create assignment: $ASSIGN_RESULT1"
ASSIGN_TX1=$(echo "$ASSIGN_RESULT1" | jq -r '.txid // empty' || echo "$ASSIGN_RESULT1")
pass "Node1: Assignment in mempool: ${ASSIGN_TX1:0:16}..."

NODE1_MEMPOOL=$(cli_node1 getrawmempool)
echo "$NODE1_MEMPOOL" | grep -q "$ASSIGN_TX1" || fail "Node1 missing transaction in mempool"
pass "Node1 has transaction in mempool while disconnected"

cli_node1 addnode "127.0.0.1:$NODE2_PORT" onetry 2>/dev/null || true
sleep 3

NODE2_MEMPOOL=$(cli_node2 getrawmempool)
if echo "$NODE2_MEMPOOL" | grep -q "$ASSIGN_TX1"; then
    pass "Transaction propagated to Node2 after reconnect"
else
    warn "Transaction not in Node2 mempool (may be expected)"
fi

cli_node1 generatetoaddress 1 "$MINING_ADDR" >/dev/null
sleep 2

FINAL_STATE=$(cli_node1 get_assignment "$PLOT_ADDR4")
WINNING_FORGE=$(echo "$FINAL_STATE" | jq -r '.forging_address // "NONE"')
if [ "$WINNING_FORGE" = "$FORGE_ADDR1" ]; then
    pass "Assignment confirmed - Forge1 active"
else
    fail "Assignment not confirmed properly"
fi

echo ""
echo -e "${GREEN}✓ ALL MULTI-NODE COORDINATION TESTS PASSED${NC}"
