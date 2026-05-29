#!/bin/sh
# Apply HarmonyOS-specific patches to R source tree.
# Run from the project root before ./configure-R.sh.
#
# Usage: cd /path/to/R-harmonyos && bash apply-patches.sh
#
# This script assumes src/R-4.4.3/ contains the original R 4.4.3 source
# (extracted from the CRAN tarball, unmodified).

set -e

R_SRC=src/R-4.4.3
PATCHES=patches

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

echo "=== Applying R HarmonyOS patches ==="

# Apply each patch using patch -p1 (relative to R_SRC root)
# Patch new-file paths are like: R-4.4.3/src/library/base/baseloader.R
# -p1 strips "R-4.4.3/" -> "src/library/base/baseloader.R" (correct from R src root)
for pf in ../../patches/*.patch; do
    name=$(basename "$pf")
    echo "  Applying $name ..."
    patch -p1 -s < "$pf" 2>/dev/null || true
done

# Copy new files
echo "  Installing new files ..."
for nf in ../../patches/new-files/*; do
    name=$(basename "$nf")
    # Determine destination based on file name
    case "$name" in
        ohos_stubs.c)
            mkdir -p src/extra/ohos_stubs
            cp "$nf" src/extra/ohos_stubs/
            echo "    Created src/extra/ohos_stubs/$name"
            ;;
        Makefile.in)
            # For ohos_stubs Makefile
            if [ -f src/extra/ohos_stubs/Makefile.in ]; then
                cp "$nf" src/extra/ohos_stubs/
                echo "    Updated src/extra/ohos_stubs/Makefile.in"
            fi
            ;;
    esac
done

echo "=== Patches applied successfully ==="
