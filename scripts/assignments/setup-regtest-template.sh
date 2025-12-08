#!/bin/bash
# Regtest Template Manager
# Creates and manages a cached regtest chain with 101 spendable blocks
# This dramatically speeds up test execution by avoiding repeated mining

set -e

BITCOIN_DIR="bitcoin"
BITCOIN_CLI="$BITCOIN_DIR/build/bin/bitcoin-cli"
BITCOIND="$BITCOIN_DIR/build/bin/bitcoind"

TEMPLATE_DIR="$HOME/.bitcoin/regtest-template"
TEMPLATE_WALLET="template"
TEMPLATE_MARKER="$TEMPLATE_DIR/.setup_complete"
TEMPLATE_INFO="$TEMPLATE_DIR/.template_info"

#
# Create or verify regtest template
#
setup_regtest_template() {
    # Check if template exists and is valid
    if [ -f "$TEMPLATE_MARKER" ]; then
        if [ "${VERBOSE:-0}" -eq 1 ]; then
            echo "✓ Using cached regtest template (101 blocks)"
            if [ -f "$TEMPLATE_INFO" ]; then
                cat "$TEMPLATE_INFO"
            fi
        fi
        return 0
    fi

    echo "Creating regtest template (first run - this will take ~3 minutes)..."

    # Clean old template if it exists
    rm -rf "$TEMPLATE_DIR"

    # Create template directory
    mkdir -p "$TEMPLATE_DIR"

    # Stop any running bitcoind instances
    pkill -9 bitcoind 2>/dev/null || true
    sleep 2

    # Start bitcoind with template datadir
    $BITCOIND -regtest -datadir="$TEMPLATE_DIR" -fallbackfee=0.00001 -daemon
    sleep 5

    # Create wallet
    $BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" createwallet "$TEMPLATE_WALLET" >/dev/null
    echo "  ✓ Created template wallet"

    # Mine 101 blocks (100 for maturity + 1 spendable coinbase)
    MINING_ADDR=$($BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" getnewaddress)
    $BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" generatetoaddress 101 "$MINING_ADDR" >/dev/null
    echo "  ✓ Mined 101 blocks"

    # Get balance and block info
    BALANCE=$($BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" getbalance)
    BLOCKHASH=$($BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" getblockhash 101)

    # Stop bitcoind cleanly
    $BITCOIN_CLI -regtest -datadir="$TEMPLATE_DIR" stop >/dev/null
    sleep 3
    pkill -9 bitcoind 2>/dev/null || true
    sleep 1

    # Create template info file
    cat > "$TEMPLATE_INFO" <<EOF
Template created: $(date)
Blocks: 101
Balance: $BALANCE BTCX
Tip hash: $BLOCKHASH
Mining address: $MINING_ADDR
EOF

    # Mark template as complete
    touch "$TEMPLATE_MARKER"

    echo "✓ Template created successfully"
    echo ""
    cat "$TEMPLATE_INFO"
}

#
# Copy template to target datadir
#
copy_template_to_datadir() {
    local target_dir=$1

    if [ ! -f "$TEMPLATE_MARKER" ]; then
        echo "ERROR: Template not initialized. Call setup_regtest_template first."
        exit 1
    fi

    if [ "${VERBOSE:-0}" -eq 1 ]; then
        echo "Copying template to $target_dir..."
    fi

    # Remove existing datadir
    rm -rf "$target_dir"

    # Copy template (fast - just copying files)
    cp -r "$TEMPLATE_DIR" "$target_dir"

    # Remove template markers from copy
    rm -f "$target_dir/.setup_complete"
    rm -f "$target_dir/.template_info"

    if [ "${VERBOSE:-0}" -eq 1 ]; then
        echo "✓ Template copied to $target_dir"
    fi
}

#
# Force template regeneration
#
reset_regtest_template() {
    echo "Resetting regtest template..."
    pkill -9 bitcoind 2>/dev/null || true
    sleep 2
    rm -rf "$TEMPLATE_DIR"
    echo "✓ Template reset. Next test run will recreate it."
}

#
# Show template info
#
show_template_info() {
    if [ ! -f "$TEMPLATE_MARKER" ]; then
        echo "No template found. Run setup_regtest_template to create one."
        return 1
    fi

    echo "Regtest Template Information:"
    echo "=============================="
    cat "$TEMPLATE_INFO"

    # Calculate template size
    TEMPLATE_SIZE=$(du -sh "$TEMPLATE_DIR" | cut -f1)
    echo "Template size: $TEMPLATE_SIZE"
}

# Export functions for use in other scripts
export -f setup_regtest_template
export -f copy_template_to_datadir
export -f reset_regtest_template
export -f show_template_info
