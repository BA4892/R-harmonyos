#!/data/service/hnp/bin/bash
# Fix remaining corrupt .rdb packages found during batch run

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DIR}/build"
LIBRARY="${BUILD_DIR}/library"
export R_HOME_DIR="$BUILD_DIR"
export R_HOME="$BUILD_DIR"
export TMPDIR="${DIR}/build/tmp"
export LD_LIBRARY_PATH="${BUILD_DIR}/lib:/storage/Users/currentUser/.local/gfortran/lib64:/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0:/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib/aarch64-linux-ohos/c++"
export LD_PRELOAD="${BUILD_DIR}/lib/libc++_shared.so"

PKGS="connectcreds ellmer"

mkdir -p "$TMPDIR"
fixed=0
failed=0

for pkg in $PKGS; do
    echo "=== Fixing $pkg ==="
    pkg_path="$LIBRARY/$pkg"
    [ ! -d "$pkg_path" ] && echo "  Not found" && continue

    # Remove corrupted files
    rm -f "$pkg_path/R/$pkg"
    shopt -s nullglob
    for f in "$pkg_path/R/"*.rdb "$pkg_path/R/"*.rdx; do rm -f "$f"; done
    shopt -u nullglob

    # Re-concatenate with newlines between files
    > "$pkg_path/R/$pkg"
    for f in $(LC_COLLATE=C ls "$pkg_path/R/"*.{R,r,q} 2>/dev/null); do
        cat "$f" >> "$pkg_path/R/$pkg"
        echo "" >> "$pkg_path/R/$pkg"
    done

    # Run makeLazyLoading
    log="$TMPDIR/fix-rdb-$pkg.log"
    if "$BUILD_DIR/bin/exec/R" --vanilla --no-save -e \
        "library(tools); tools:::makeLazyLoading('$pkg', lib.loc='$LIBRARY', compress=FALSE)" \
        > "$log" 2>&1; then
        echo "    OK"
        fixed=$((fixed + 1))
    else
        echo "    FAILED"
        grep -E "^Error:|Error in" "$log" | head -3
        failed=$((failed + 1))
    fi
    echo ""
done

echo "=== Summary ==="
echo "Fixed: $fixed"
echo "Failed: $failed"
