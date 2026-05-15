#!/data/service/hnp/bin/bash
# Fix corrupt .rdb packages - all packages with load failures due to .rdb corruption
# Includes: unknown input format, read failed, undefined exports

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DIR}/build"
LIBRARY="${BUILD_DIR}/library"
export R_HOME_DIR="$BUILD_DIR"
export R_HOME="$BUILD_DIR"
export TMPDIR="${DIR}/build/tmp"
export LD_LIBRARY_PATH="${BUILD_DIR}/lib:/storage/Users/currentUser/.local/gfortran/lib64:/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0:/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib/aarch64-linux-ohos/c++"
export LD_PRELOAD="${BUILD_DIR}/lib/libc++_shared.so"

# All packages known to have corrupt/defective .rdb files
# Group 1: unknown input format (14) - already fixed, included for completeness
# Group 2: read failed on .rdb (9)
# Group 3: undefined exports (4)
ALL_PKGS="deldir ff foreign fs furrr future future.apply httr2 lattice maps mda pscl rbibutils tweenr gam geometry ggeffects intervals lavaan marquee nnet projpred randomForest parsedate pbapply rJava sfsmisc"

mkdir -p "$TMPDIR"
fixed=0
failed=0

for pkg in $ALL_PKGS; do
    echo "=== Fixing $pkg ==="
    pkg_path="$LIBRARY/$pkg"

    if [ ! -d "$pkg_path" ]; then
        echo "  Not found, skipping"
        continue
    fi

    # Remove corrupted files
    echo "  Removing .rdb/.rdx and bootstrap..."
    rm -f "$pkg_path/R/$pkg"
    shopt -s nullglob
    for f in "$pkg_path/R/"*.rdb "$pkg_path/R/"*.rdx; do
        rm -f "$f"
    done
    shopt -u nullglob

    # Re-concatenate source files
    echo "  Re-concatenating source files..."
    > "$pkg_path/R/$pkg"
    shopt -s nullglob
    for f in $(LC_COLLATE=C ls "$pkg_path/R/"*.{R,r,q} 2>/dev/null); do
        cat "$f" >> "$pkg_path/R/$pkg"
        echo "" >> "$pkg_path/R/$pkg"
    done
    shopt -u nullglob

    # Verify concatenated file has content
    concat_size=$(stat -c%s "$pkg_path/R/$pkg" 2>/dev/null)
    if [ "$concat_size" -le 10 ]; then
        echo "  WARNING: concatenated file is tiny ($concat_size bytes), may still fail"
    fi

    # Run makeLazyLoading
    echo "  Running makeLazyLoading..."
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
echo "Total attempted: $(echo $ALL_PKGS | wc -w)"
echo "Fixed: $fixed"
echo "Failed: $failed"
