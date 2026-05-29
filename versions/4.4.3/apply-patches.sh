#!/bin/sh
# Apply HarmonyOS-specific patches to R 4.4.3 source tree.
# Run from the project root:  bash versions/4.4.3/apply-patches.sh
#
# This script assumes src/R-4.4.3/ contains the original R 4.4.3 source
# (extracted from the CRAN tarball, unmodified).

set -e

R_SRC=src/R-4.4.3
PATCHES=versions/4.4.3/patches

if [ ! -d "$R_SRC" ]; then
    echo "Error: $R_SRC not found. Extract R-4.4.3 source first:"
    echo "  tar xzf src/R-4.4.3.tar.gz -C src/"
    exit 1
fi

if [ ! -d "$PATCHES" ]; then
    echo "Error: $PATCHES directory not found."
    exit 1
fi

cd "$R_SRC"

echo "=== Applying R 4.4.3 HarmonyOS patches ==="

for pf in ../../$PATCHES/*.patch; do
    name=$(basename "$pf")
    echo "  Applying $name ..."
    patch -p1 -s < "$pf" 2>/dev/null || true
done

# Copy new files
echo "  Installing new files ..."
for nf in ../../$PATCHES/new-files/*; do
    name=$(basename "$nf")
    case "$name" in
        ohos_stubs.c)
            mkdir -p src/extra/ohos_stubs
            cp "$nf" src/extra/ohos_stubs/
            echo "    Created src/extra/ohos_stubs/$name"
            ;;
        Makefile.in)
            if [ -f src/extra/ohos_stubs/Makefile.in ]; then
                cp "$nf" src/extra/ohos_stubs/
                echo "    Updated src/extra/ohos_stubs/Makefile.in"
            fi
            ;;
    esac
done

echo "=== Patches applied successfully ==="
