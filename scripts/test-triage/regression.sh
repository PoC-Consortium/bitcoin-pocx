#!/bin/bash
# Run every suite marked PASS in the manifest, in parallel. Fails loud on any red.
#
# Usage:
#   ./regression.sh qt
#   ./regression.sh unit
#   ./regression.sh all

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN_DIR="$REPO_ROOT/bitcoin/build/bin"

TARGET="${1:-all}"

run_target() {
    local target=$1
    local manifest="$SCRIPT_DIR/manifest-$target.txt"
    local binary
    case "$target" in
        qt)   binary="$BIN_DIR/test_bitcoin-qt" ;;
        unit) binary="$BIN_DIR/test_bitcoin"    ;;
        *)    echo "unknown target: $target" >&2; return 2 ;;
    esac
    if [[ ! -x "$binary" ]]; then
        echo "error: $binary not built" >&2
        return 2
    fi

    local suites
    suites=$(awk '/^[^#[:space:]]/ && $2 == "PASS" {print $1}' "$manifest")
    if [[ -z "$suites" ]]; then
        echo "[$target] no PASS suites in manifest"
        return 0
    fi

    local results_dir="$SCRIPT_DIR/results/$target"
    mkdir -p "$results_dir"
    export binary target results_dir

    run_one() {
        local suite=$1
        local log="$results_dir/$suite.log"
        local rc=0
        case "$target" in
            qt)   "$binary" "$suite"              > "$log" 2>&1 || rc=$? ;;
            unit) "$binary" --run_test="$suite"   > "$log" 2>&1 || rc=$? ;;
        esac
        if [[ $rc -eq 0 ]]; then
            printf "  PASS  %s\n" "$suite"
        else
            printf "  FAIL  %s  (REGRESSION!)\n" "$suite"
            return 1
        fi
    }
    export -f run_one

    local parallel="${PARALLEL:-$(nproc)}"
    echo "[$target] regression: $(echo "$suites" | wc -w) suites (j=$parallel)"
    if echo "$suites" | xargs -n1 -P "$parallel" bash -c 'run_one "$@"' _; then
        return 0
    else
        return 1
    fi
}

case "$TARGET" in
    qt|unit) run_target "$TARGET" ;;
    all)
        run_target qt;   qt_rc=$?
        run_target unit; unit_rc=$?
        [[ $qt_rc -eq 0 && $unit_rc -eq 0 ]] || exit 1
        ;;
    *) echo "usage: $0 <qt|unit|all>"; exit 2 ;;
esac
