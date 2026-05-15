#!/data/service/hnp/bin/bash
# Fix .rdb files for the 82 patchelf-corrupted packages after .so rebuild
DIR="/storage/Users/currentUser/R-harmonyos"
BUILD_DIR="${DIR}/build"
LIBRARY="${BUILD_DIR}/library"
export R_HOME_DIR="$BUILD_DIR"
export R_HOME="$BUILD_DIR"
export TMPDIR="${BUILD_DIR}/tmp"
JAVA_HOME="/data/service/hnp/bishengjdk17.0.13_06.org/bishengjdk17.0.13_06_0.13_06"
export LD_LIBRARY_PATH="${BUILD_DIR}/lib:/storage/Users/currentUser/.local/gfortran/lib64:/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0:/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib/aarch64-linux-ohos/c++:${JAVA_HOME}/lib/server"
export LD_PRELOAD="${BUILD_DIR}/lib/libc++_shared.so:${BUILD_DIR}/lib/libcrypto.so:${BUILD_DIR}/lib/libssl.so:${BUILD_DIR}/lib/libpng16.so:${BUILD_DIR}/lib/libgmp.so:${BUILD_DIR}/lib/libbcrypt_stub.so:${BUILD_DIR}/lib/librcpp_stubs.so"

mkdir -p "$TMPDIR"
LOG="$DIR/compile-logs/rdb-broken-fix.log"
> "$LOG"

# Read package list
PKGS=$(cat "$DIR/build/tmp/broken_pkgs.txt" | tr '\n' ' ')

MAX_PASSES=5
fixed=0
failed=0

for ((pass=1; pass<=MAX_PASSES; pass++)); do
    [ -z "$PKGS" ] && break
    echo "=== Pass $pass ($(echo $PKGS | wc -w) packages) ==="
    next_pkgs=""
    pass_fixed=0

    for pkgname in $PKGS; do
        pkg_path="$LIBRARY/$pkgname"
        [ ! -d "$pkg_path" ] && continue

        # Check if R code directory exists
        [ ! -d "$pkg_path/R" ] && continue
        rdb_count=$(ls "$pkg_path/R/"*.rdb 2>/dev/null | wc -l)

        # Only process if no .rdb exists (or force regenerate)
        if [ "$rdb_count" -gt 0 ]; then
            continue
        fi

        # Ensure concatenated R file exists
        r_concat="$pkg_path/R/$pkgname"
        if [ ! -f "$r_concat" ]; then
            > "$r_concat"
            for f in $(LC_COLLATE=C ls "$pkg_path/R/"*.{R,r,q} 2>/dev/null); do
                cat "$f" >> "$r_concat"
                echo "" >> "$r_concat"
            done
        fi

        echo "  [$pkgname] makeLazyLoading..."
        log="$TMPDIR/rdb-$pkgname.log"
        if "$BUILD_DIR/bin/exec/R" --vanilla --no-save --no-restore -e \
            "library(tools); tools:::makeLazyLoading('$pkgname', lib.loc='$LIBRARY', compress=FALSE)" \
            > "$log" 2>&1; then
            echo "    OK"
            fixed=$((fixed + 1))
            pass_fixed=$((pass_fixed + 1))
        else
            err=$(grep -E "Error:|error:|no package" "$log" | head -2 | tr '\n' '; ')
            echo "    FAILED: ${err:-see log}"
            if grep -q "there is no package called" "$log" 2>/dev/null && [ "$pass" -lt "$MAX_PASSES" ]; then
                next_pkgs="$next_pkgs $pkgname"
            elif [ "$pass" -lt "$MAX_PASSES" ]; then
                next_pkgs="$next_pkgs $pkgname"
            else
                failed=$((failed + 1))
            fi
        fi
        cat "$log" >> "$LOG"
    done

    echo "  Pass $pass: $pass_fixed fixed"
    echo ""
    PKGS="$next_pkgs"
done

echo "=== Summary ==="
echo "Fixed: $fixed"
echo "Failed: $failed"
echo "=== Done ==="
