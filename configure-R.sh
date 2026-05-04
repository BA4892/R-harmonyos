#!/bin/sh
# Configure R 4.4.3 for HarmonyOS (OpenHarmony) with OHOS Clang + gfortran
# Run this from the project root to (re)configure the build.
# After configuring, run: cd build && make
set -e

export TMPDIR=/storage/Users/currentUser/R-harmonyos/tmp
export CONFIG_SHELL=/data/service/hnp/bin/bash
export SHELL=/data/service/hnp/bin/bash
umask 022
mkdir -p "$TMPDIR"

R_SRC=/storage/Users/currentUser/R-harmonyos/src/R-4.4.3
BUILD_DIR=/storage/Users/currentUser/R-harmonyos/build
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
OHOS_CLANGXX=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++
GFORTRAN=/storage/Users/currentUser/.local/gfortran/bin/gfortran
SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
GFORTRAN_LIB=/storage/Users/currentUser/.local/gfortran/lib64
GCC_LIB=/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0
RDEPS=/storage/Users/currentUser/.local/R-deps

# Library path for running test binaries
export LD_LIBRARY_PATH="${GFORTRAN_LIB}:${GCC_LIB}:$LD_LIBRARY_PATH"

# Timezone data (musl looks for /usr/share/zoneinfo which doesn't exist on HarmonyOS)
# Use TZ env var for now; we cache the configure check
export TZ=CST-8

# Clean build directory to avoid stale cache
rm -f config.cache config.status

export PKG_CONFIG_PATH="${RDEPS}/lib/pkgconfig"

# Pre-seed configure cache variables to skip runtime tests (blocked by hmmac)
# and link tests that fail due to missing libraries (BLAS/LAPACK/iconv on OHOS)
for cv in \
    r_cv_mixed_c_fortran=yes \
    r_cv_double_complex_agree=yes \
    r_cv_working_mktime=yes \
    r_cv_working_mktime1=yes \
    r_cv_working_mktime2=yes \
    r_cv_working_calloc=yes \
    r_cv_working_isfinite=yes \
    r_cv_working_log1p=yes \
    r_cv_ftell_append=yes \
    r_cv_working_sigaction=yes \
    ac_cv_prog_cc_cross=yes \
    cross_compiling=yes \
    r_cv_header_zlib_h=yes \
    r_cv_have_bzlib=yes \
    r_cv_have_lzma=yes \
    r_cv_have_pcre2utf=yes \
    r_cv_have_curl728=yes \
    r_cv_have_curl_https=yes \
    ac_cv_func_iconv=yes \
    ac_cv_have_decl_mbrtowc=yes \
    ac_cv_have_decl_wcrtomb=yes \
    ac_cv_have_decl_wcscoll=yes \
    ac_cv_have_decl_wcsftime=yes \
    ac_cv_have_decl_wcstod=yes \
    ac_cv_have_decl_mbstowcs=yes \
    ac_cv_have_decl_wcstombs=yes \
    ac_cv_have_decl_wctrans=yes \
    ac_cv_have_decl_wctype=yes \
    ac_cv_have_decl_iswctype=yes \
    ac_cv_have_decl_wcwidth=yes \
    ac_cv_have_decl_wcswidth=yes \
    ac_cv_type_wctrans_t=yes \
    ac_cv_type_mbstate_t=yes \
    lt_cv_truncate_bin="/usr/bin/dd bs=4096 count=1" \
    ac_cv_have_decl_size_max=yes; do
    export "$cv"
done

# Run configure (may fail at config.status due to umask issue on OHOS)
"$R_SRC/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=aarch64-pc-linux-musl \
    --prefix=/storage/Users/currentUser/.local/R \
    --enable-R-shlib \
    --without-readline \
    --without-x \
    --without-tcltk \
    --without-cairo \
    --without-libpng \
    --without-jpeglib \
    --without-libtiff \
    --without-aqua \
    --disable-java \
    --without-blas \
    --without-lapack \
    --with-pcre2 \
    CC="$OHOS_CLANG" \
    CXX="$OHOS_CLANGXX" \
    FC="$GFORTRAN" \
    F77="$GFORTRAN" \
    CFLAGS="-O2 -g0 --sysroot=$SYSROOT -I${RDEPS}/include" \
    CXXFLAGS="-O2 -g0 --sysroot=$SYSROOT -I${RDEPS}/include" \
    FCFLAGS="-O2 -g0" \
    FFLAGS="-O2 -g0" \
    LDFLAGS="--sysroot=$SYSROOT -L${GFORTRAN_LIB} -L${SYSROOT}/usr/lib/aarch64-linux-ohos -L${RDEPS}/lib" \
    LIBS="-lm" \
    CPPFLAGS="-I${RDEPS}/include" \
    CURL_LIBS="-lcurl -lssl -lcrypto -lz -lpthread -ldl" \
    CURL_CPPFLAGS="" \
    CPP="${OHOS_CLANG} -E --sysroot=$SYSROOT -I${RDEPS}/include" \
    CXXCPP="${OHOS_CLANGXX} -E --sysroot=$SYSROOT -I${RDEPS}/include" 2>&1 | tee /storage/Users/currentUser/R-harmonyos/build/configure.log || true

# Patch config.status to fix umask 077 issue (OHOS filesystem incompatibility)
if [ -f config.status ]; then
    echo "Patching config.status to fix umask 077 -> 022 ..."
    sed -i 's/umask 077 \&\& mktemp -d/umask 022 \&\& mktemp -d/g' config.status
    sed -i 's/umask 077 \&\& mkdir/umask 022 \&\& mkdir/g' config.status
    echo "Re-running config.status ..."
    /bin/sh config.status 2>&1 | tee -a /storage/Users/currentUser/R-harmonyos/build/configure.log
fi
