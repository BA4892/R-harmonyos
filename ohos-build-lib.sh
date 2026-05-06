#!/data/service/hnp/bin/bash
# OHOS Cross-compilation helper for system libraries (v2)
# Usage: ./ohos-build-lib.sh <source_dir> [configure_options...]
# Features:
# - Sets up OHOS cross-compilation environment
# - Patches config.sub/config.guess to recognize ohos
# - Works around mktemp/umask/libtool issues on HarmonyOS
# - Out-of-source builds

set -e

OHOS_CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
OHOS_CXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"
OHOS_AR="/data/service/hnp/bin/ar"
OHOS_RANLIB="/data/service/hnp/bin/ranlib"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
EXT="/storage/Users/currentUser/.local/R-deps"
WORK="/storage/Users/currentUser/R-harmonyos/tmp"

export TMPDIR="$WORK"
export CONFIG_SHELL="/data/service/hnp/bin/bash"
export SHELL="/data/service/hnp/bin/bash"
export CC="$OHOS_CC"
export CXX="$OHOS_CXX"
export AR="$OHOS_AR"
export RANLIB="$OHOS_RANLIB"
export CFLAGS="--sysroot=$SYSROOT -O2 -fPIC"
export CXXFLAGS="--sysroot=$SYSROOT -O2 -fPIC"
export LDFLAGS="--sysroot=$SYSROOT"
export CPPFLAGS="-I$EXT/include"
export PKG_CONFIG_PATH="$EXT/lib/pkgconfig"
# Ensure zlib.pc exists (zlib is in sysroot but no .pc file provided)
if [ ! -f "$EXT/lib/pkgconfig/zlib.pc" ]; then
  cat > "$EXT/lib/pkgconfig/zlib.pc" << 'ZEOF'
prefix=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib/aarch64-linux-ohos
includedir=${prefix}/include
Name: zlib
Description: zlib compression library
Version: 1.2.11
Libs: -L${libdir} -lz
Cflags: -I${includedir}
ZEOF
fi

SRC_DIR="$1"
shift

if [ ! -d "$SRC_DIR" ]; then
  echo "Usage: $0 <source_dir> [configure_options...]"
  exit 1
fi

# Patch config.sub to recognize ohos
if [ -f "$SRC_DIR/config.sub" ]; then
  if ! grep -q "ohos" "$SRC_DIR/config.sub" 2>/dev/null; then
    echo "Patching config.sub for OHOS..."
    sed -i 's/-qnx\*)/-qnx*|-ohos*)/' "$SRC_DIR/config.sub" 2>/dev/null || true
  fi
fi

# Create build dir
BUILD_DIR="${WORK}/$(basename "$SRC_DIR")-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Building $(basename "$SRC_DIR") ==="
echo "  CC: $CC"
echo "  Host: aarch64-linux-gnu"
echo "  Prefix: $EXT"
echo "  Options: $@"

# Run configure out-of-source
if [ -f "$SRC_DIR/configure" ]; then
  cd "$BUILD_DIR"
  "$SRC_DIR/configure" \
    --prefix=$EXT \
    --host=aarch64-linux-gnu \
    --build=aarch64-linux-gnu \
    --enable-shared=no \
    --enable-static=yes \
    "$@" 2>&1 | tee "$BUILD_DIR/configure.log" | tail -5

  # Fix config.status: HarmonyOS mktemp + umask 077 creates unwritable dirs
  if [ -f "$BUILD_DIR/config.status" ]; then
    cs="$BUILD_DIR/config.status"
    python3 -c "
import re
with open('$cs', 'r') as f:
    c = f.read()
# Remove all umask 077 occurrences in temp dir creation blocks
c = re.sub(r'tmp=`\(\s*umask\s+077\s*&&\s*(mktemp\s+-d\s+\S*|mkdir\s+-p\s+\S*)\)\s*2>/dev/null`\s*&&\s*test\s+-d\s+\"\\\$tmp\"\s*\}\s*\|\|\s*\{[^}]*\}', '{ tmp=./conftmp\n  mkdir -p \"./conftmp\"\n}', c, flags=re.DOTALL)
# Fix any standalone umask 077 + mkdir patterns
c = re.sub(r'\(umask\s+077\s*&&\s*mkdir\s+\"\\\$tmp\"\)', 'mkdir -p \"\$tmp\" 2>/dev/null', c)
# Fix mktemp patterns
c = c.replace('mktemp -d \"./confXXXXXX\"', 'mkdir -p ./conftmp')
# Fix ECHO (ksh-ism doesn't work in bash)
c = c.replace(\"ECHO='print -r --'\", \"ECHO='echo'\")
with open('$cs', 'w') as f:
    f.write(c)
" 2>/dev/null || true
    CONFIG_SHELL=/bin/sh /bin/sh ./config.status 2>&1 | tail -3
  fi

  # Build (use -j1 to avoid mkfifo jobserver issue on HarmonyOS)
  make -j1 2>&1 | tail -10

  # Fix libtool for next time (in srcdir for future use)
  if [ -f "$BUILD_DIR/libtool" ]; then
    sed -i '1s|#! /bin/sh|#!/data/service/hnp/bin/bash|' "$BUILD_DIR/libtool"
    sed -i 's/print -r --/echo/g' "$BUILD_DIR/libtool"
    sed -i 's/umask 077//g' "$BUILD_DIR/libtool"
  fi

  # Fix SHELL in Makefiles
  for f in $(find "$BUILD_DIR" -name "Makefile"); do
    sed -i 's|SHELL = /bin/sh|SHELL = /data/service/hnp/bin/bash|g' "$f" 2>/dev/null || true
  done

elif [ -f "$SRC_DIR/CMakeLists.txt" ]; then
  cd "$BUILD_DIR"
  cmake "$SRC_DIR" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=$OHOS_CC \
    -DCMAKE_CXX_COMPILER=$OHOS_CXX \
    -DCMAKE_AR=$OHOS_AR \
    -DCMAKE_RANLIB=$OHOS_RANLIB \
    -DCMAKE_SYSROOT=$SYSROOT \
    -DCMAKE_INSTALL_PREFIX=$EXT \
    -DCMAKE_C_FLAGS="--sysroot=$SYSROOT -fPIC" \
    -DBUILD_SHARED_LIBS=OFF \
    "$@" 2>&1 | tail -10
  cmake --build . -j$(nproc) 2>&1 | tail -10
  cmake --install . 2>&1 | tail -5
else
  echo "No configure or CMakeLists.txt found in $SRC_DIR"
  exit 1
fi

# Install
if [ -f "$BUILD_DIR/Makefile" ] || [ -f "$BUILD_DIR/GNUmakefile" ]; then
  make install 2>&1 | tail -5
fi

echo "=== Build complete: $(basename "$SRC_DIR") ==="
