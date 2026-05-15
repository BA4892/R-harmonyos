#!/usr/bin/env bash
# Regenerate all concatenated R package files with proper newlines between files
# This fixes the "unable to load R code" errors caused by files concatenated
# without newline separators in previous runs.

LIBRARY="/storage/Users/currentUser/R-harmonyos/build/library"

count=0
for pkg_path in "$LIBRARY"/*/; do
    pkgname=$(basename "$pkg_path")
    [ ! -d "$pkg_path/R" ] && continue

    # Check for R source files
    r_files=$(find "$pkg_path/R" -maxdepth 1 \( -name "*.R" -o -name "*.r" -o -name "*.q" \) 2>/dev/null)
    [ -z "$r_files" ] && continue

    # Check if has .rdb already (no fix needed)
    rdb_count=$(find "$pkg_path/R" -maxdepth 1 -name "*.rdb" 2>/dev/null | wc -l)
    [ "$rdb_count" -gt 0 ] && continue

    concat="$pkg_path/R/$pkgname"

    # Remove stale concatenated file
    rm -f "$concat"

    # Regenerate with newlines, alphabetical order regardless of extension
    for f in $(LC_COLLATE=C ls "$pkg_path/R/"*.{R,r,q} 2>/dev/null); do
        [ -f "$f" ] || continue
        cat "$f" >> "$concat"
        echo "" >> "$concat"
    done

    if [ -f "$concat" ]; then
        echo "Regenerated $pkgname ($(wc -c < "$concat") bytes)"
        count=$((count + 1))
    fi
done

echo "=== Total regenerated: $count ==="
