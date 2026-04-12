#!/bin/bash
# Mark a suite DISABLE-INAPPLICABLE or DISABLE-DEFERRED in the manifest.
#
# Usage:
#   ./disable.sh <qt|unit> <suite> INAPPLICABLE "reason"
#   ./disable.sh <qt|unit> <suite> DEFERRED    "reason"

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${1:-}"
SUITE="${2:-}"
KIND="${3:-}"
REASON="${4:-}"

if [[ -z "$TARGET" || -z "$SUITE" || -z "$KIND" ]]; then
    echo "usage: $0 <qt|unit> <suite> <INAPPLICABLE|DEFERRED> \"reason\""
    exit 2
fi

case "$KIND" in
    INAPPLICABLE) STATUS="DISABLE-INAPPLICABLE" ;;
    DEFERRED)     STATUS="DISABLE-DEFERRED"    ;;
    *) echo "kind must be INAPPLICABLE or DEFERRED"; exit 2 ;;
esac

MANIFEST="$SCRIPT_DIR/manifest-$TARGET.txt"
[[ -f "$MANIFEST" ]] || { echo "no such manifest: $MANIFEST" >&2; exit 2; }

if ! grep -qE "^${SUITE}[[:space:]]" "$MANIFEST"; then
    echo "suite '$SUITE' not found in $MANIFEST" >&2
    exit 2
fi

awk -v suite="$SUITE" -v status="$STATUS" -v reason="$REASON" '
    $1 == suite {
        printf "%-40s %-22s", suite, status
        if (reason != "") printf "    # %s", reason
        printf "\n"
        next
    }
    { print }
' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"

echo "disabled $TARGET:$SUITE as $STATUS${REASON:+ ($REASON)}"
