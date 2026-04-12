#!/bin/bash
# Mark a suite PASS in the manifest (after fixing it).
#
# Usage: ./promote.sh <qt|unit> <suite>

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${1:-}"
SUITE="${2:-}"

if [[ -z "$TARGET" || -z "$SUITE" ]]; then
    echo "usage: $0 <qt|unit> <suite>"
    exit 2
fi

MANIFEST="$SCRIPT_DIR/manifest-$TARGET.txt"
[[ -f "$MANIFEST" ]] || { echo "no such manifest: $MANIFEST" >&2; exit 2; }

if ! grep -qE "^${SUITE}[[:space:]]" "$MANIFEST"; then
    echo "suite '$SUITE' not found in $MANIFEST" >&2
    exit 2
fi

# Replace the status column with PASS, keep any inline comment.
awk -v suite="$SUITE" '
    $1 == suite {
        # Rebuild line: name PASS [# note]
        note=""
        for (i = 3; i <= NF; ++i) {
            if (note == "" && $i ~ /^#/) note = substr($0, index($0, $i))
        }
        printf "%-40s PASS", suite
        if (note != "") printf "    %s", note
        printf "\n"
        next
    }
    { print }
' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"

echo "promoted $TARGET:$SUITE -> PASS"
