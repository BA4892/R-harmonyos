#!/data/service/hnp/bin/bash
# batch-fix-v5.sh: Compile .so for packages with available dependencies
# Uses bash arrays throughout for safe word splitting.

DIR="/storage/Users/currentUser/R-harmonyos/build"
CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
CXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"
FC="/storage/Users/currentUser/gfortran-harmonyos/build/gcc/gfortran"
FC_DIR="/storage/Users/currentUser/gfortran-harmonyos/build/gcc"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
R_INC="$DIR/include"
R_LIB="$DIR/lib"
EXT_INC="/storage/Users/currentUser/.local/R-deps/include"
EXT_LD="/storage/Users/currentUser/.local/R-deps/lib"
LOG_DIR="$DIR/../compile-logs"
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR/success-v5.log" "$LOG_DIR/fail-v5.log"

BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
C_VISIBILITY="-fvisibility=hidden"
SHLIB_OPENMP_CFLAGS="-fopenmp"
SHLIB_OPENMP_CXXFLAGS="-fopenmp"
SHLIB_OPENMP_FFLAGS="-fopenmp"

EXT_INC_DIRS=(-I"$EXT_INC")
for d in "$EXT_INC"/*/; do
  [ -d "$d" ] && EXT_INC_DIRS+=(-I"$d")
done

BASE_CFLAGS=(-I"$R_INC" --sysroot="$SYSROOT" -fPIC -O2 -g0)
BASE_LINK=(-shared -fPIC -L"$R_LIB" -lR -L"$EXT_LD" --sysroot="$SYSROOT" -Wl,--allow-multiple-definition -lmuslstubs)

expand_vars() {
  local s="$1"
  s="${s//'$(BLAS_LIBS)'/$BLAS_LIBS}"
  s="${s//'$(LAPACK_LIBS)'/$LAPACK_LIBS}"
  s="${s//'$(FLIBS)'/$FLIBS}"
  s="${s//'$(C_VISIBILITY)'/$C_VISIBILITY}"
  s="${s//'$(CXX_VISIBILITY)'/$C_VISIBILITY}"
  s="${s//'$(SHLIB_OPENMP_CFLAGS)'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'$(SHLIB_OPENMP_CXXFLAGS)'/$SHLIB_OPENMP_CXXFLAGS}"
  s="${s//'$(SHLIB_OPENMP_FFLAGS)'/$SHLIB_OPENMP_FFLAGS}"
  s="${s//'$(SHLIB_OPENMP_LIBS)'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'$(R_HOME)'/$DIR}"
  s="${s//'$(DEFS)'/}"
  s=$(echo "$s" | sed 's/\$(\([A-Z_]*\)=\([^)]*\))/\2/g')
  s=$(echo "$s" | sed 's/`[^`]*`//g')
  s=$(echo "$s" | sed 's|[/}]\(-L\)|\1|g')
  echo "$s"
}

resolve_relpaths() {
  local flags="$1"
  local srcdir="$2"
  local result=""
  for flag in $flags; do
    case "$flag" in
      -I/*|-I~*) result="$result $flag" ;;
      -I*) result="$result -I$srcdir/${flag#-I}" ;;
      -L/*|-L~*) result="$result $flag" ;;
      -L*) result="$result -L$srcdir/${flag#-L}" ;;
      *.o|*.a|*.so) result="$result $srcdir/$flag" ;;
      *) result="$result $flag" ;;
    esac
  done
  echo "$result"
}

linking_includes() {
  local pkg_path="$1"
  local result=()
  local LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | \
    sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  for lpkg in $LINKING_TO; do
    for try_path in "$DIR/library/$lpkg/inst/include" "$DIR/library/$lpkg/include"; do
      if [ -d "$try_path" ]; then
        result+=(-I"$try_path")
        break
      fi
    done
  done
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    if [ -d "$self_path" ]; then
      result+=(-I"$self_path")
      break
    fi
  done
  echo "${result[@]}"
}

compile_one() {
  local pkgname="$1"
  local pkg_path="$DIR/library/$pkgname"
  local src_dir="$pkg_path/src"
  local libs_dir="$pkg_path/libs"
  local compile_log="$LOG_DIR/${pkgname}-v5.log"
  rm -f "$compile_log"

  [ -f "$libs_dir/$pkgname.so" ] && echo "  SKIP (exists)" && return 2
  echo "=== $pkgname ==="
  mkdir -p "$libs_dir"

  local PKG_CPPFLAGS="" PKG_CFLAGS="" PKG_CXXFLAGS="" PKG_LIBS="" OBJECTS=""
  if [ -f "$src_dir/Makevars" ]; then
    local joined_vars=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$src_dir/Makevars" 2>/dev/null)
    while IFS= read -r line; do
      case "$line" in .PHONY:*|all:*|\$*|include*) continue ;; esac
      line=$(echo "$line" | sed 's/^\([A-Z_0-9]*\)[[:space:]]*=[[:space:]]*/\1=/')
      case "$line" in
        PKG_CPPFLAGS=*) PKG_CPPFLAGS="${line#*=}" ;;
        PKG_CFLAGS=*)   PKG_CFLAGS="${line#*=}" ;;
        PKG_CXXFLAGS=*) PKG_CXXFLAGS="${line#*=}" ;;
        PKG_LIBS=*)     PKG_LIBS="${line#*=}" ;;
        OBJECTS=*)      OBJECTS="${line#*=}" ;;
        OBJS=*)         OBJECTS="${line#*=}" ;;
      esac
    done <<< "$joined_vars"
    # Clean PKG_LIBS - if it looks like "PKG_LIBS=" was concatenated into another var, filter
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/PKG_LIBS=//g')
    PKG_CPPFLAGS=$(expand_vars "$PKG_CPPFLAGS")
    PKG_CFLAGS=$(expand_vars "$PKG_CFLAGS")
    PKG_CXXFLAGS=$(expand_vars "$PKG_CXXFLAGS")
    PKG_LIBS=$(expand_vars "$PKG_LIBS")
    PKG_CPPFLAGS=$(resolve_relpaths "$PKG_CPPFLAGS" "$src_dir")
    PKG_CFLAGS=$(resolve_relpaths "$PKG_CFLAGS" "$src_dir")
    PKG_CXXFLAGS=$(resolve_relpaths "$PKG_CXXFLAGS" "$src_dir")
    PKG_LIBS=$(resolve_relpaths "$PKG_LIBS" "$src_dir")
  fi

  local CXX_STD="c++11"
  local EXTRA_CFLAGS="" EXTRA_CXXFLAGS="" EXTRA_DEFS="" EXTRA_LIBS=""

  case "$pkgname" in
    Cairo)
      # Force regenerate cconfig.h without #include <cairo.h>
      cat > "$src_dir/cconfig.h" << 'CONFIGEOF'
/* Auto-generated cconfig.h for Cairo on HarmonyOS */
#ifndef _CCONFIG_H_
#define _CCONFIG_H_
#define HAVE_CAIRO 1
#define CAIRO_HAS_PDF_SURFACE 1
#define CAIRO_HAS_PNG_FUNCTIONS 1
#define CAIRO_HAS_PS_SURFACE 1
#define CAIRO_HAS_SVG_SURFACE 1
#define CAIRO_HAS_IMAGE_SURFACE 1
#define CAIRO_HAS_RECORDING_SURFACE 1
#define CAIRO_HAS_TEE_SURFACE 1
#define CAIRO_HAS_USER_FONT 1
#define CAIRO_HAS_MIME_SURFACE 1
#define CAIRO_HAS_XML_SURFACE 1
#endif
CONFIGEOF
      EXTRA_CFLAGS="-I$EXT_INC/cairo -I$EXT_INC/pixman-1 -I$EXT_INC/freetype2 -I$EXT_INC/libpng16"
      EXTRA_LIBS="-lcairo -lpixman-1 -lpng -lfreetype -lz"
      ;;
    XML)
      EXTRA_LIBS="-lxml2 -llzma -lbz2 -lz"
      ;;
    RJSONIO)
      EXTRA_DEFS="-DJSON_LIBRARY=1 -DNDEBUG=1 -DJSON_VALIDATE -DJSON_STREAM=1 -DJSON_READ_PRIORITY=1 -DJSON_ISO_STRICT"
      ;;
    brotli)
      local enc_dir="$src_dir/enc"
      if [ ! -f "$enc_dir/libstatbrotli.a" ]; then
        echo "    Building brotli static lib..."
        (cd "$enc_dir" && for f in *.c; do
          $CC -I"$src_dir/include" -DBROTLI_BUILD_PORTABLE --sysroot="$SYSROOT" -fPIC -O2 -g0 -c "$f" -o "${f%.c}.o"
        done && ar rcs libstatbrotli.a *.o)
      fi
      EXTRA_CFLAGS="-I$src_dir/include -DBROTLI_BUILD_PORTABLE"
      EXTRA_LIBS="-L$enc_dir -lstatbrotli"
      ;;
    parsermd)
      CXX_STD="c++17"
      EXTRA_DEFS="-DBOOST_SPIRIT_X3_HIDE_CXX17_WARNING"
      ;;
    colourvalues)
      CXX_STD="c++14"
      EXTRA_DEFS="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"
      ;;
    haven)
      CXX_STD="c++14"
      EXTRA_DEFS="-DHAVE_WORKING_LOG1P"
      EXTRA_CFLAGS="-I$src_dir/readstat"
      EXTRA_CXXFLAGS="-I$src_dir/readstat"
      ;;
    geosphere)
      CXX_STD="c++17"
      EXTRA_CFLAGS="-x c++"
      ;;
    frailtypack|lqmm)
      CXX_STD="c++11"
      ;;
  esac

  local LINK_INCS=($(linking_includes "$pkg_path"))
  local CFLAGS=("${BASE_CFLAGS[@]}" -I"$src_dir" "${LINK_INCS[@]}" "${EXT_INC_DIRS[@]}" $PKG_CPPFLAGS)
  local CXXFLAGS=("${BASE_CFLAGS[@]}" -I"$src_dir" "${LINK_INCS[@]}" "${EXT_INC_DIRS[@]}" $PKG_CPPFLAGS)
  local LINK_FLAGS=("${BASE_LINK[@]}")

  BUILD_TMP=$(mktemp -p "$DIR/../tmp" 2>/dev/null || mktemp -p /data)
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  local all_objs=()
  local ok=true

  local c_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.c" \) 2>/dev/null | sort))
  local cc_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort))
  local f_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.f" -o -name "*.f90" \) 2>/dev/null | sort))

  # C sources
  for src in "${c_srcs[@]}"; do
    local base=$(basename "$src")
    local base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC "${CFLAGS[@]}" $PKG_CFLAGS $EXTRA_CFLAGS $EXTRA_DEFS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      tail -2 "$compile_log"; ok=false; break
    fi
    all_objs+=("$BUILD_TMP/$base_noext.o")
  done

  # C++ sources
  if $ok && [ ${#cc_srcs[@]} -gt 0 ]; then
    for src in "${cc_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "  CXX $base (-std=$CXX_STD)"
      if ! $CXX -std=$CXX_STD "${CXXFLAGS[@]}" $PKG_CXXFLAGS $EXTRA_CXXFLAGS $EXTRA_DEFS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        tail -2 "$compile_log"; ok=false; break
      fi
      all_objs+=("$BUILD_TMP/$base_noext.o")
    done
  fi

  # Fortran sources
  if $ok && [ ${#f_srcs[@]} -gt 0 ] && [ -x "$FC" ]; then
    for src in "${f_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1 || true
    done
    for src in "${f_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "  FC $base"
      if ! $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        grep "Fatal Error" "$compile_log" | tail -1; ok=false; break
      fi
      all_objs+=("$BUILD_TMP/$base_noext.o")
    done
  fi

  # Link (only use PKG_LIBS if non-empty and not just whitespace)
  if $ok; then
    local PKG_LIBS_TRIMMED=$(echo "$PKG_LIBS" | xargs)
    echo "  LD $pkgname.so"
    if [ -n "$PKG_LIBS_TRIMMED" ]; then
      if ! $CC "${LINK_FLAGS[@]}" $PKG_LIBS -o "$libs_dir/$pkgname.so" "${all_objs[@]}" $EXTRA_LIBS >> "$compile_log" 2>&1; then
        tail -3 "$compile_log"; ok=false
      fi
    else
      if ! $CC "${LINK_FLAGS[@]}" -o "$libs_dir/$pkgname.so" "${all_objs[@]}" $EXTRA_LIBS >> "$compile_log" 2>&1; then
        tail -3 "$compile_log"; ok=false
      fi
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $ok; then
    local so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "  OK ($so_size)"
    echo "$pkgname: OK ($so_size)" >> "$LOG_DIR/success-v5.log"
    return 0
  else
    echo "  FAILED (see $compile_log)"
    echo "$pkgname: FAILED" >> "$LOG_DIR/fail-v5.log"
    return 1
  fi
}

# ============ MAIN ============
TARGETS=(
  jsonlite commonmark RJSONIO brotli
  colourvalues haven geosphere
  parsermd frailtypack lqmm
)

echo "============================================"
echo "  batch-fix-v5: Focused .so compilation"
echo "  Targets: ${#TARGETS[@]} packages"
echo "============================================"

compiled=0 failed=0 skipped=0
for pkgname in "${TARGETS[@]}"; do
  compile_one "$pkgname"
  rc=$?
  case $rc in 0) compiled=$((compiled+1)) ;; 1) failed=$((failed+1)) ;; 2) skipped=$((skipped+1)) ;; esac
done

echo ""
echo "============================================"
echo "  Done: $compiled OK, $failed FAILED, $skipped SKIPPED"
echo "============================================"
