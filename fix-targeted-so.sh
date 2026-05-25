#!/data/service/hnp/bin/bash
# Targeted .so rebuild for specific failing packages - v2
DIR="/storage/Users/currentUser/R-harmonyos/build"
CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
CXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
R_INC="$DIR/include"
R_LIB="$DIR/lib"
FC="/storage/Users/currentUser/gfortran-harmonyos/build/gcc/gfortran"
FC_DIR="/storage/Users/currentUser/gfortran-harmonyos/build/gcc"
JAVA_HOME="/data/service/hnp/bishengjdk17.0.13_06.org/bishengjdk17.0.13_06_0.13_06"
JAVA_CPPFLAGS="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux"
EXT_LIB="/storage/Users/currentUser/.local/R-deps"
BREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
BREW_INC="$BREW_PREFIX/include"
BREW_LD="$BREW_PREFIX/lib"
HOMEBREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"
LIBRARY="$DIR/library"
LOG_DIR="/storage/Users/currentUser/R-harmonyos/compile-logs"
mkdir -p "$LOG_DIR"
BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
# Path to the log1p fix include (undefines log1p macro after Rmath.h)
FIX_INC="$DIR/tmp/fix_includes"

compiled=0
failed=0

compile_and_link() {
  local pkgname="$1" src_dir="$2" libs_dir="$3"
  local extra_cflags="$4" extra_cxxflags="$5" extra_ldflags="$6"
  local extra_cppflags="$7"

  # Use configurable depth for C/C++ sources (default 5 for subdirs)
  local maxdepth="${9:-2}"
  local exclude_grep="${8:-}"  # optional grep -v pattern to exclude files
  local c_srcs=$(find "$src_dir" -maxdepth $maxdepth \( -name "*.c" \) 2>/dev/null | sort)
  local cc_srcs=$(find "$src_dir" -maxdepth $maxdepth \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort)
  local f_srcs=$(find "$src_dir" -maxdepth $maxdepth \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort)
  if [ -n "$exclude_grep" ]; then
    c_srcs=$(echo "$c_srcs" | grep -v -E "$exclude_grep" || true)
    cc_srcs=$(echo "$cc_srcs" | grep -v -E "$exclude_grep" || true)
    f_srcs=$(echo "$f_srcs" | grep -v -E "$exclude_grep" || true)
  fi

  local compile_log="$LOG_DIR/$pkgname.targeted-rebuild.log"
  > "$compile_log"
  local BUILD_TMP=$(mktemp -p "$DIR/tmp" 2>/dev/null || mktemp -p "/tmp" 2>/dev/null)
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"

  # LinkingTo resolution
  local LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  local LINKING_INCLUDES=""
  if [ -n "$LINKING_TO" ]; then
    for lpkg in $LINKING_TO; do
      lpkg=$(echo "$lpkg" | xargs)
      [ -z "$lpkg" ] && continue
      for try_path in "$LIBRARY/$lpkg/inst/include" "$LIBRARY/$lpkg/include"; do
        if [ -d "$try_path" ]; then
          LINKING_INCLUDES="$LINKING_INCLUDES -I$try_path"
          break
        fi
      done
    done
  fi

  local all_objs=""
  local compile_ok=true

  # Compile C sources (extra_cppflags first so fix_includes overrides R_INC)
  for src in $c_srcs; do
    base=$(basename "$src")
    base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC $extra_cppflags -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS --sysroot="$SYSROOT" -fPIC -O2 -g0 $extra_cflags -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      echo "  C FAILED: $base"
      tail -3 "$compile_log"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # Compile C++ sources (extra_cppflags first so fix_includes overrides R_INC)
  if $compile_ok && [ -n "$cc_srcs" ]; then
    for src in $cc_srcs; do
      base=$(basename "$src")
      base_noext="${base%.*}"
      echo "  CXX $base"
      if ! $CXX $extra_cppflags -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS --sysroot="$SYSROOT" -fPIC -O2 -g0 -std=c++17 $extra_cxxflags -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  CXX FAILED: $base"
        tail -3 "$compile_log"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Compile Fortran sources
  if $compile_ok && [ -n "$f_srcs" ] && [ -x "$FC" ]; then
    for src in $f_srcs; do
      base=$(basename "$src")
      base_noext="${base%.*}"
      echo "  FC $base"
      if ! $FC -B"$FC_DIR" -I"$src_dir" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  FC FAILED: $base"
        tail -3 "$compile_log"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Link
  if $compile_ok; then
    local soname="$pkgname.so"
    mkdir -p "$libs_dir"
    rm -f "$libs_dir/$soname"
    echo "  LD $soname"
    if ! $CC -shared -fPIC -o "$libs_dir/$soname" $all_objs \
        -L"$R_LIB" -lR $extra_ldflags --sysroot="$SYSROOT" -Wl,--allow-multiple-definition \
        -L"$R_LIB" -lmuslstubs >> "$compile_log" 2>&1; then
      echo "  LINK FAILED"
      tail -10 "$compile_log"
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    local so_size=$(ls -lh "$libs_dir/$soname" | awk '{print $5}')
    echo "  OK ($so_size)"
    return 0
  else
    echo "  FAILED (see $compile_log)"
    return 1
  fi
}

echo "=== Targeted .so rebuild v2 ==="
echo "Started at $(date)"
echo ""

# ======== 1. fstcore ========
# Needs -I for internal fstlib headers (ZSTD/common/xxhash.h, etc.)
echo "--- fstcore ---"
pkgname="fstcore"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
FSTCORE_INCLUDES="-I$src_dir/fstlib -I$src_dir/fstlib/ZSTD -I$src_dir/fstlib/ZSTD/common -I$src_dir/fstlib/LZ4 -I$EXT_INC"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "$FSTCORE_INCLUDES" \
    "$FSTCORE_INCLUDES" \
    "" "" "" 5
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

# ======== 2. RcppArmadillo ========
# log1p macro fix: use fix_includes Rmath.h override
echo ""
echo "--- RcppArmadillo ---"
pkgname="RcppArmadillo"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "" \
    "-DARMA_USE_CURRENT" \
    "$BLAS_LIBS $LAPACK_LIBS $FLIBS" \
    "-I$FIX_INC -I$pkg_path/inst/include -DARMA_USE_CURRENT"
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

# ======== 3. glmnet ========
# Same log1p macro fix
echo ""
echo "--- glmnet ---"
pkgname="glmnet"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "" \
    "-DEIGEN_PERMANENTLY_DISABLE_STUPID_WARNINGS" \
    "-L$FC_DIR -lgfortran -lgcc_s" \
    "-I$FIX_INC -I$src_dir/glmnetpp/include -I$src_dir/glmnetpp/src"
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

# ======== 4. xml2 ========
# Needs libxml2 headers + package's own inst/include for xml2_types.h
echo ""
echo "--- xml2 ---"
pkgname="xml2"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
XML2_INCLUDES="-I$EXT_INC/libxml2 -I$pkg_path/inst/include -DSTRICT_R_HEADERS -DR_NO_REMAP -DUCHAR_TYPE=wchar_t"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "$XML2_INCLUDES" \
    "$XML2_INCLUDES" \
    "$EXT_LD/libxml2.a -lz" \
    ""
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

# ======== 5. curl ========
# Link directly against libcurl.a (full path) to avoid sysroot issues
echo ""
echo "--- curl ---"
pkgname="curl"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
CURL_INCLUDES="-I$EXT_INC"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "$CURL_INCLUDES" \
    "$CURL_INCLUDES" \
    "-Wl,--whole-archive $EXT_LD/libcurl.a -Wl,--no-whole-archive -lz -lssl -lcrypto" \
    ""
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

# ======== 6. systemfonts ========
# Needs FreeType for font handling + proper C++17
echo ""
echo "--- systemfonts ---"
pkgname="systemfonts"
pkg_path="$LIBRARY/$pkgname"
src_dir="$pkg_path/src"
libs_dir="$pkg_path/libs"
SYSFONT_INCLUDES="-I$EXT_INC/freetype2 -I$EXT_INC"
if [ -d "$src_dir" ]; then
  compile_and_link "$pkgname" "$src_dir" "$libs_dir" \
    "$SYSFONT_INCLUDES" \
    "-I$FIX_INC $SYSFONT_INCLUDES" \
    "$EXT_LD/libfontconfig.a $EXT_LD/libfreetype.a $EXT_LD/libpng16.a $EXT_LD/libexpat.a -lz -lpthread" \
    "-I$EXT_INC" \
    "Windows|mac/"
  if [ $? -eq 0 ]; then compiled=$((compiled + 1)); else failed=$((failed + 1)); fi
else
  echo "  NO src dir"
fi

echo ""
echo "=== Summary ==="
echo "Compiled: $compiled"
echo "Failed: $failed"
echo "Finished at $(date)"
