#!/bin/sh
# Build R dependencies for HarmonyOS (bzip2, xz/liblzma, pcre2)
# These are installed into $HOME/.local/R-deps/ for use by configure-R.sh
#
# 2026-05: harmonybrew 已提供这些依赖的预编译 bottle。
# 推荐直接使用 brew 安装，不再需要本脚本：
#   brew install bzip2 xz pcre2 openssl curl libpng freetype cairo \
#              geos gmp libxml2 pixman
# 本脚本保留供参考和离线环境使用。
set -e

export TMPDIR=/storage/Users/currentUser/R-harmonyos/tmp
mkdir -p "$TMPDIR" /storage/Users/currentUser/.local/R-deps/lib /storage/Users/currentUser/.local/R-deps/include

OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
PREFIX=/storage/Users/currentUser/.local/R-deps

export CC="$OHOS_CLANG"
export CFLAGS="-O2 --sysroot=$SYSROOT"
export LDFLAGS="--sysroot=$SYSROOT"

JOBS=$(nproc 2>/dev/null || echo 4)

echo "=== Building R deps ==="

# --- bzip2 ---
echo "--- bzip2 ---"
cd "$TMPDIR"
[ -f bzip2-1.0.8.tar.gz ] || curl -sLo bzip2-1.0.8.tar.gz https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
rm -rf bzip2-1.0.8; tar xzf bzip2-1.0.8.tar.gz; cd bzip2-1.0.8
make -j$JOBS CC="$CC" LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS -fPIC" libbz2.a libbz2.so 2>&1 | tail -5
cp libbz2.a libbz2.so "$PREFIX/lib/" && cp bzlib.h "$PREFIX/include/"
echo "bzip2: done"

# --- xz (liblzma) ---
echo "--- xz ---"
cd "$TMPDIR"
[ -f xz-5.6.3.tar.gz ] || curl -sLo xz-5.6.3.tar.gz https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-5.6.3.tar.gz
rm -rf xz-5.6.3; tar xzf xz-5.6.3.tar.gz; cd xz-5.6.3
./configure --host=aarch64-linux-ohos --build=x86_64-pc-linux-gnu \
  --prefix="$PREFIX" --disable-shared --enable-static \
  CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tail -5
make -j$JOBS 2>&1 | tail -5 && make install 2>&1 | tail -3
echo "xz: done"

# --- pcre2 ---
echo "--- pcre2 ---"
cd "$TMPDIR"
[ -f pcre2-10.44.tar.bz2 ] || curl -sLo pcre2-10.44.tar.bz2 https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2
rm -rf pcre2-10.44; tar xf pcre2-10.44.tar.bz2; cd pcre2-10.44
./configure --host=aarch64-linux-ohos --build=x86_64-pc-linux-gnu \
  --prefix="$PREFIX" --disable-shared --enable-static \
  --enable-pcre2-16 --enable-pcre2-32 \
  CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tail -5
make -j$JOBS 2>&1 | tail -5 && make install 2>&1 | tail -3
echo "pcre2: done"

echo "=== Done ==="
ls "$PREFIX/lib/"*.a 2>/dev/null
