#!/data/service/hnp/bin/bash
# Generate missing .rdb lazy-load databases for all installed R packages
# Usage: ./batch-fix-rdb.sh
#
# Iterates all packages in build/library/ and runs makeLazyLoading
# on those that have R code but no .rdb file.
#
# Uses multiple passes to handle inter-package dependencies:
# if package A depends on B and both lack .rdb, pass 1 may fix B
# so pass 2 can fix A.

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DIR}/build"
LIBRARY="${BUILD_DIR}/library"
export R_HOME_DIR="$BUILD_DIR"
export R_HOME="$BUILD_DIR"
export TMPDIR="${TMPDIR:-${BUILD_DIR}/tmp}"
export LD_LIBRARY_PATH="${BUILD_DIR}/lib:/storage/Users/currentUser/.local/gfortran/lib64:/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0:/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib/aarch64-linux-ohos/c++:${LD_LIBRARY_PATH}"
export LD_PRELOAD="${BUILD_DIR}/lib/libc++_shared.so"
export PATH="/usr/bin:/bin:/data/service/hnp/bin:$PATH"

mkdir -p "$TMPDIR"
LOG="$DIR/compile-logs/rdb-fix.log"

MAX_PASSES=5

echo "=== Missing .rdb fix started at $(date) ==="
echo "Library: $LIBRARY"
echo "Log: $LOG"
echo "Max passes: $MAX_PASSES"
echo ""

# Step 1: Scan all packages, collect those with R code
pkg_list=""
already_had=0
for pkg_path in "$LIBRARY"/*/; do
    pkgname=$(basename "$pkg_path")
    # Check if R code directory exists with files
    [ ! -d "$pkg_path/R" ] && continue
    r_files=$(ls "$pkg_path/R/"*.R "$pkg_path/R/"*.r "$pkg_path/R/"*.q 2>/dev/null)
    [ -z "$r_files" ] && continue

    # Check if .rdb already exists
    rdb_count=$(ls "$pkg_path/R/"*.rdb 2>/dev/null | wc -l)
    if [ "$rdb_count" -gt 0 ]; then
        already_had=$((already_had + 1))
        continue
    fi

    pkg_list="$pkg_list $pkgname"
done

total=$((already_had + $(echo "$pkg_list" | wc -w)))
echo "Total packages with R code: $total"
echo "Already have .rdb: $already_had"
echo "Need .rdb: $((total - already_had))"
echo ""

# Step 2: Process missing .rdb packages in multiple passes
current_list="$pkg_list"
fixed_total=0
failed_total=0
> "$LOG"

for ((pass=1; pass<=MAX_PASSES; pass++)); do
    [ -z "$current_list" ] && break
    echo "--- Pass $pass ($(echo "$current_list" | wc -w) packages remaining) ---"

    next_list=""
    pass_fixed=0

    for pkgname in $current_list; do
        pkg_path="$LIBRARY/$pkgname"

        # Ensure concatenated R file exists
        r_concat="$pkg_path/R/$pkgname"
        if [ ! -f "$r_concat" ]; then
            for f in $(LC_COLLATE=C ls "$pkg_path/R/"*.{R,r,q} 2>/dev/null); do
                cat "$f" >> "$r_concat"
                echo "" >> "$r_concat"
            done
        fi

        # Double-check .rdb doesn't exist (might have been created in a prev pass)
        rdb_count=$(ls "$pkg_path/R/"*.rdb 2>/dev/null | wc -l)
        [ "$rdb_count" -gt 0 ] && continue

        echo "  [$pkgname] running makeLazyLoading..."

        tmp_log="$LOG.tmp.$pkgname"
        if "$BUILD_DIR/bin/exec/R" --vanilla --no-save --no-restore -e \
            "library(tools); wd <- getwd(); setwd(\"$pkg_path\"); tools:::makeLazyLoading(\"$pkgname\", lib.loc = \"$LIBRARY\", compress = FALSE); setwd(wd)" \
            >> "$tmp_log" 2>&1; then
            echo "    OK"
            fixed_total=$((fixed_total + 1))
            pass_fixed=$((pass_fixed + 1))
            cat "$tmp_log" >> "$LOG"
            rm -f "$tmp_log"
        else
            err=$(grep -E "Error:|error:|no package" "$tmp_log" | head -2 | tr '\n' '; ')
            echo "    FAILED: ${err:-see log}"

            # Check if it's a missing dependency
            if grep -q "there is no package called" "$tmp_log" 2>/dev/null; then
                if [ "$pass" -lt "$MAX_PASSES" ]; then
                    # May succeed in later pass
                    next_list="$next_list $pkgname"
                else
                    echo "      (gave up after $MAX_PASSES passes)"
                    failed_total=$((failed_total + 1))
                fi
            else
                # Other error - try again next pass
                if [ "$pass" -lt "$MAX_PASSES" ]; then
                    next_list="$next_list $pkgname"
                else
                    failed_total=$((failed_total + 1))
                fi
            fi
            cat "$tmp_log" >> "$LOG"
            rm -f "$tmp_log"
        fi
    done

    echo "  Pass $pass: $pass_fixed fixed"
    echo ""
    current_list="$next_list"
done

rm -f "$LOG.tmp".*

echo "=== Summary ==="
echo "Total packages with R code: $total"
echo "Already had .rdb: $already_had"
echo "Successfully fixed: $fixed_total"
echo "Failed: $failed_total"
echo "=== Done at $(date) ==="
