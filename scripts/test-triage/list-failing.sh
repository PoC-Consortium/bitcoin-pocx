#!/bin/bash
# Print one-liner summary of every non-PASS entry in a manifest plus last
# error hint from the captured log (if any).
#
# Usage: ./list-failing.sh <qt|unit>

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${1:-}"
if [[ "$TARGET" != "qt" && "$TARGET" != "unit" ]]; then
    echo "usage: $0 <qt|unit>"
    exit 2
fi

MANIFEST="$SCRIPT_DIR/manifest-$TARGET.txt"
RESULTS_DIR="$SCRIPT_DIR/results/$TARGET"

awk '/^[^#[:space:]]/ && $2 != "PASS" {print $0}' "$MANIFEST" \
    | while read -r name status rest; do
        log="$RESULTS_DIR/$name.log"
        hint=""
        if [[ -f "$log" ]]; then
            hint=$(grep -E 'fatal error|critical check|FAILED|ERROR' "$log" 2>/dev/null | head -1 | cut -c1-100)
        fi
        printf "  %-22s %-40s %s\n" "$status" "$name" "${hint:-}"
    done
