#!/bin/sh
# Apply HarmonyOS patches to a specific R version.
# Usage:  bash apply-patches.sh [version]
#
# If no version is given, defaults to 4.4.3.
# Examples:
#   bash apply-patches.sh          # patches src/R-4.4.3/
#   bash apply-patches.sh 4.6.0    # patches src/R-4.6.0/
#
# The actual patches live in versions/<version>/patches/.
# This wrapper delegates to the version-specific script.

set -e

VERSION="${1:-4.4.3}"

SCRIPT="versions/$VERSION/apply-patches.sh"

if [ ! -f "$SCRIPT" ]; then
    echo "Error: no patches found for R-$VERSION"
    echo "  Expected: $SCRIPT"
    echo ""
    echo "Available versions:"
    ls -d versions/*/ 2>/dev/null | sed 's/versions\//  /; s|/||'
    exit 1
fi

echo "=== Applying R-$VERSION HarmonyOS patches ==="
bash "$SCRIPT"
echo "=== Done ==="
