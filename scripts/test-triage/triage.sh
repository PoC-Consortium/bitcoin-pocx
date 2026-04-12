#!/bin/bash
# Run non-PASS suites for a given target (qt|unit), in parallel.
# Captures output to results/<target>/<suite>.log, prints one-line summary.
#
# Usage:
#   ./triage.sh qt                      # run all non-PASS Qt test classes
#   ./triage.sh unit                    # run all non-PASS unit test suites
#   ./triage.sh unit <suite>            # run just <suite> (even if PASS)
#   ./triage.sh unit --seed             # populate manifest-unit.txt from the binary
#   ./triage.sh unit --repeat=N         # run each suite N times (flake detection)
#
# Exit code: 0 if every attempted suite passed, 1 otherwise.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN_DIR="$REPO_ROOT/bitcoin/build/bin"

TARGET="${1:-}"
shift || true

if [[ "$TARGET" != "qt" && "$TARGET" != "unit" ]]; then
    echo "usage: $0 <qt|unit> [suite | --seed | --repeat=N]"
    exit 2
fi

MANIFEST="$SCRIPT_DIR/manifest-$TARGET.txt"
RESULTS_DIR="$SCRIPT_DIR/results/$TARGET"
mkdir -p "$RESULTS_DIR"

case "$TARGET" in
    qt)   BINARY="$BIN_DIR/test_bitcoin-qt" ;;
    unit) BINARY="$BIN_DIR/test_bitcoin"    ;;
esac

if [[ ! -x "$BINARY" ]]; then
    echo "error: $BINARY not built. Run cmake --build bitcoin/build --target $(basename "$BINARY")" >&2
    exit 2
fi

# --seed (unit only): enumerate suites from the binary, write PENDING manifest.
if [[ "${1:-}" == "--seed" ]]; then
    if [[ "$TARGET" != "unit" ]]; then
        echo "--seed is only supported for the unit target" >&2
        exit 2
    fi
    echo "# Boost unit test suites. One per line: <name> <STATUS> [# note]" > "$MANIFEST"
    echo "# STATUS: PENDING | PASS | FIX-TRIVIAL | FIX-SUBSTANTIVE | DISABLE-INAPPLICABLE | DISABLE-DEFERRED" >> "$MANIFEST"
    "$BINARY" --list_content 2>&1 \
        | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\*?$' \
        | sed 's/\*$//' \
        | sort -u \
        | awk '{printf "%-40s PENDING\n", $1}' >> "$MANIFEST"
    wc -l < "$MANIFEST" | xargs -I{} echo "seeded manifest-unit.txt with {} lines"
    exit 0
fi

REPEAT=1
EXPLICIT_SUITE=""
for arg in "$@"; do
    case "$arg" in
        --repeat=*) REPEAT="${arg#--repeat=}" ;;
        --*)        echo "unknown option: $arg" >&2; exit 2 ;;
        *)          EXPLICIT_SUITE="$arg" ;;
    esac
done

# Extract suites from manifest: everything non-comment, non-blank.
suites_all=$(awk '/^[^#[:space:]]/ {print $1}' "$MANIFEST")

if [[ -n "$EXPLICIT_SUITE" ]]; then
    suites="$EXPLICIT_SUITE"
elif [[ "$TARGET" == "qt" ]]; then
    # Qt tests run as a single binary; we run each class one at a time.
    suites=$(awk '/^[^#[:space:]]/ && $2 != "PASS" {print $1}' "$MANIFEST")
else
    suites=$(awk '/^[^#[:space:]]/ && $2 != "PASS" {print $1}' "$MANIFEST")
fi

if [[ -z "$suites" ]]; then
    echo "nothing to run (all suites are PASS, or manifest is empty)"
    exit 0
fi

export BINARY RESULTS_DIR TARGET REPEAT

run_one() {
    local suite=$1
    local log="$RESULTS_DIR/$suite.log"
    local rc=0
    local attempts=0
    for ((i = 1; i <= REPEAT; ++i)); do
        attempts=$i
        case "$TARGET" in
            qt)   "$BINARY" "$suite"                > "$log" 2>&1 || rc=$? ;;
            unit) "$BINARY" --run_test="$suite"     > "$log" 2>&1 || rc=$? ;;
        esac
        [[ $rc -ne 0 ]] && break
    done
    if [[ $rc -eq 0 ]]; then
        printf "  PASS  %-40s (%d attempt%s)\n" "$suite" "$attempts" "$([[ $attempts -eq 1 ]] || echo s)"
    else
        # Last-line error summary from the log.
        local hint
        hint=$(grep -E 'fatal error|critical check|FAILED|ERROR' "$log" | head -1 | cut -c1-120)
        printf "  FAIL  %-40s  %s\n" "$suite" "${hint:-see log}"
    fi
    return $rc
}
export -f run_one

PARALLEL="${PARALLEL:-$(nproc)}"
echo "[$TARGET] running $(echo "$suites" | wc -w) suites in parallel (j=$PARALLEL, repeat=$REPEAT)"
failed=0
if ! echo "$suites" | xargs -n1 -P "$PARALLEL" bash -c 'run_one "$@"' _; then
    failed=1
fi

pass_count=$(grep -cE '^ *PASS' <(:) || true)  # placeholder
echo
echo "[$TARGET] triage done. Logs in $RESULTS_DIR/"
exit "$failed"
