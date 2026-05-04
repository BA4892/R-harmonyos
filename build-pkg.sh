#!/data/service/hnp/bin/bash
# Build and install an R package with native code for HarmonyOS
# Usage: ./build-pkg.sh <tarball> [install_dir]
#
# Extracts a CRAN source tarball, compiles C/C++/Fortran code,
# and installs using install-package.

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DIR}/build"
TMPDIR="${TMPDIR:-${DIR}/tmp}"
R_LIB="${BUILD_DIR}/lib"
R_INC="${BUILD_DIR}/include"
SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
CC=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
CXX=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++
CFLAGS="-I${R_INC} --sysroot=${SYSROOT} -fPIC -O2 -g0"
CXXFLAGS="-I${R_INC} --sysroot=${SYSROOT} -fPIC -O2 -g0 -std=gnu++17"
LDFLAGS="-L${R_LIB} -lR --sysroot=${SYSROOT}"

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

# Check for native code
if [ -d "$PKG_SRC/src" ]; then
    echo "  Native code found in src/"

    # Check for Makevars and extract flags
    MAKEFLAGS=""
    if [ -f "$PKG_SRC/src/Makevars" ]; then
        echo "  Using Makevars"
        # Parse important flags from Makevars
        while IFS= read -r line; do
            case "$line" in
                PKG_CFLAGS=*) eval "$line"; CFLAGS="$CFLAGS $PKG_CFLAGS" ;;
                PKG_CXXFLAGS=*) eval "$line"; CXXFLAGS="$CXXFLAGS $PKG_CXXFLAGS" ;;
                PKG_LIBS=*) eval "$line"; LDFLAGS="$LDFLAGS $PKG_LIBS" ;;
                PKG_CPPFLAGS=*) eval "$line"; CFLAGS="$CFLAGS $PKG_CPPFLAGS"; CXXFLAGS="$CXXFLAGS $PKG_CPPFLAGS" ;;
            esac
        done < "$PKG_SRC/src/Makevars"
    fi

    echo "  CFLAGS: $CFLAGS"

    # Compile C files
    cd "$PKG_SRC/src"
    for src in *.c; do
        [ -f "$src" ] || continue
        echo "    CC $src"
        $CC $CFLAGS -c "$src" -o "${src%.c}.o"
    done

    # Compile C++ files
    for src in *.cpp; do
        [ -f "$src" ] || continue
        echo "    CXX $src"
        $CXX $CXXFLAGS -c "$src" -o "${src%.cpp}.o"
    done

    # Compile Fortran files
    for src in *.f *.f90; do
        [ -f "$src" ] || continue
        echo "    FC $src"
        # Use gfortran for Fortran
        /storage/Users/currentUser/.local/gfortran/bin/gfortran -fPIC -O2 -g0 -c "$src" -o "${src%.*}.o"
    done

    # Link shared library
    echo "    LD ${PKG_NAME}.so"
    $CC -shared -fPIC -o "${PKG_NAME}.so" *.o $LDFLAGS 2>&1

    # Create libs directory in source
    mkdir -p "$PKG_SRC/libs"
    cp "${PKG_NAME}.so" "$PKG_SRC/libs/"
    echo "    ${PKG_NAME}.so: $(ls -lh "${PKG_NAME}.so" | awk '{print $5}')"
fi

# Install the package
echo "  Installing $PKG_NAME..."
TMPDIR="$TMPDIR" R_HOME_DIR="$BUILD_DIR" R_HOME="$BUILD_DIR" \
  LD_LIBRARY_PATH="${R_LIB}:${LD_LIBRARY_PATH}" \
  PATH="/usr/bin:/bin:/data/service/hnp/bin:$PATH" \
  "${BUILD_DIR}/bin/install-package" "$PKG_SRC" "$LIB_DEST" 2>&1 | grep -v "^$" | grep -v "initializing" | grep -v "^R version" | grep -v "^Copyright" | grep -v "^Platform" | grep -v "^You are" | grep -v "^Type" | grep -v "^Natural" | grep -v "citation" | grep -v "contributors" | grep -v "help.start" | grep -v "^During" | grep -v "^>"

echo "Done: $PKG_NAME"
rm -rf "$PKG_DIR"
