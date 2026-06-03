#!/bin/sh
# Install remaining R 4.6.0 packages
set -e

TOP_SRC=/storage/Users/currentUser/R-harmonyos/src/R-4.6.0
TOP_BUILD=/storage/Users/currentUser/R-harmonyos/build
ICU_DATA=/storage/Users/currentUser/R-harmonyos/tmp/icu-install/share/icu/78.3
LD_LIBRARY_PATH="${TOP_BUILD}/lib:${TOP_BUILD}/../tmp/icu-install/lib"
R_EXE="${TOP_BUILD}/bin/R --vanilla --no-echo"

install_pkg() {
    pkg=$1
    echo "=== Installing $pkg ==="
    pkgdir="${TOP_BUILD}/library/$pkg"
    srcpkg="${TOP_SRC}/src/library/$pkg"

    mkdir -p "$pkgdir/R" "$pkgdir/help" "$pkgdir/html" "$pkgdir/Meta"

    # Copy DESCRIPTION
    if [ -f "${TOP_BUILD}/src/library/$pkg/DESCRIPTION" ]; then
        cp "${TOP_BUILD}/src/library/$pkg/DESCRIPTION" "$pkgdir/"
    fi

    # Copy NAMESPACE
    if [ -f "$srcpkg/NAMESPACE" ]; then
        cp "$srcpkg/NAMESPACE" "$pkgdir/"
    fi

    # Copy and concatenate R files
    if [ -d "$srcpkg/R" ]; then
        # Copy individual common files
        for f in "$srcpkg/R"/*.R "$srcpkg/R"/*.r; do
            [ -f "$f" ] && cp "$f" "$pkgdir/R/"
        done 2>/dev/null || true

        # Also copy platform-specific files (R/unix/, R/windows/)
        # HarmonyOS uses R_OSTYPE=unix
        if [ -d "$srcpkg/R/unix" ]; then
            for f in "$srcpkg/R/unix"/*.R "$srcpkg/R/unix"/*.r; do
                [ -f "$f" ] && cp "$f" "$pkgdir/R/"
            done 2>/dev/null || true
        fi

        # Create concatenated all.R and R/<pkg> file (needed for makeLazyLoading)
        # Include both common and platform-specific files (but NOT the other platform)
        cat "$srcpkg/R"/*.R "$srcpkg/R"/*.r "$srcpkg/R/unix"/*.R "$srcpkg/R/unix"/*.r 2>/dev/null > "$pkgdir/R/all.R" || true
        cp "$pkgdir/R/all.R" "$pkgdir/R/$pkg"
    fi

    # Copy data
    if [ -d "$srcpkg/data" ]; then
        mkdir -p "$pkgdir/data"
        for f in "$srcpkg/data"/*; do
            [ -f "$f" ] && cp "$f" "$pkgdir/data/"
        done 2>/dev/null || true
    fi

    # Copy .so if exists
    for so in "${TOP_BUILD}/src/library/$pkg/src/$pkg.so" "${TOP_BUILD}/library/$pkg/libs/$pkg.so"; do
        if [ -f "$so" ]; then
            mkdir -p "$pkgdir/libs"
            cp "$so" "$pkgdir/libs/$pkg.so" 2>/dev/null || true
        fi
    done

    # Run makeLazyLoading
    echo "tools:::makeLazyLoading(\"$pkg\")" | \
        R_DEFAULT_PACKAGES=tools LC_ALL=C $R_EXE > /dev/null 2>&1 && \
        echo "$pkg: lazy load OK" || \
        echo "$pkg: lazy load FAILED"

    echo "=== Done $pkg ==="
}

for pkg in datasets methods splines parallel grid stats stats4; do
    install_pkg $pkg
done

echo "=== All done ==="
ls "${TOP_BUILD}/library/" | sort
