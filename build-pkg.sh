#!/data/service/hnp/bin/bash
# Build and install an R package with native code for HarmonyOS
# Usage: ./build-pkg.sh <tarball> [install_dir]
#
# Extracts a CRAN source tarball and calls install-package to handle
# metadata installation, C/C++/Fortran/Java compilation, and lazy-load DB creation.
# All compilation is handled by install-package (no duplicate logic here).

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DIR}/build"
TMPDIR="${TMPDIR:-${DIR}/tmp}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <tarball> [install_dir]"
    exit 1
fi

TARBALL="$1"
LIB_DEST="${2:-${BUILD_DIR}/library}"
mkdir -p "$TMPDIR"

# Extract
PKG_DIR="$TMPDIR/build_$$"
mkdir -p "$PKG_DIR"
echo "Extracting $(basename "$TARBALL")..."
tar xzf "$TARBALL" -C "$PKG_DIR"

PKG_NAME=$(ls "$PKG_DIR")
PKG_SRC="$PKG_DIR/$PKG_NAME"
echo "Package: $PKG_NAME"

# Delegate everything to install-package (handles metadata, compilation, lazy-loading)
"$DIR/install-package" "$PKG_SRC" "$LIB_DEST"

rm -rf "$PKG_DIR"
echo "Done: $PKG_NAME"
