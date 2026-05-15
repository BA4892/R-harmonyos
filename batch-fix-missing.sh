#!/data/service/hnp/bin/bash
# Targeted batch compilation for packages with native code but no .so
# Usage: ./batch-fix-missing.sh [--recompile]
#
# Only processes packages that have source files but no compiled .so,
# skipping packages with known-unfixable external dependencies.

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

# External libs
EXT_LIB="/storage/Users/currentUser/.local/R-deps"
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"

# R Makeconf-style vars
BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
C_VISIBILITY="-fvisibility=hidden"
SHLIB_OPENMP_CFLAGS="-fopenmp"
SHLIB_OPENMP_CXXFLAGS="-fopenmp"
SHLIB_OPENMP_FFLAGS="-fopenmp"
DEFS=""

# Known unfixable packages (missing external system libs not available on HarmonyOS)
SKIP_PKGS="RMariaDB RMySQL RPostgreSQL RPostgres RNetCDF Rmpi V8 RSQLite duckdb arrow
  gert git2r RSQLite fstcore av libsodium sodium
  arrow adbcdrivermanager archive clustermq"

LIBRARY="$DIR/library"
LOG_DIR="$DIR/../compile-logs"
mkdir -p "$LOG_DIR"

# Helper functions (from build-fix-so.sh)
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
  s="${s//'$(R_DEBUG_FLAGS)'/$R_DEBUG_FLAGS}"
  s="${s//'$(R_DEBUG_CXXFLAGS)'/$R_DEBUG_CXXFLAGS}"
  s="${s//'$(DEFS)'/$DEFS}"
  s="${s//'$(R_HOME)'/$DIR}"
  s="${s//'$(STANC_FLAGS)'/ }"
  s="${s//'$(JPEG_CFLAGS)'/ }"
  s="${s//'$(PNG_CFLAGS)'/ }"
  s="${s//'$(JPEG_LIBS)'/ }"
  s="${s//'$(PNG_LIBS)'/ }"
  s="${s//'$(TCLTK_CFLAGS)'/ }"
  s="${s//'$(TCLTK_LIBS)'/ }"
  # Handle ${VAR} curly brace variants
  s="${s//'${BLAS_LIBS}'/$BLAS_LIBS}"
  s="${s//'${LAPACK_LIBS}'/$LAPACK_LIBS}"
  s="${s//'${FLIBS}'/$FLIBS}"
  s="${s//'${C_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${CXX_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${SHLIB_OPENMP_CFLAGS}'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'${SHLIB_OPENMP_CXXFLAGS}'/$SHLIB_OPENMP_CXXFLAGS}"
  s="${s//'${SHLIB_OPENMP_FFLAGS}'/$SHLIB_OPENMP_FFLAGS}"
  s="${s//'${R_DEBUG_FLAGS}'/$R_DEBUG_FLAGS}"
  s="${s//'${R_DEBUG_CXXFLAGS}'/$R_DEBUG_CXXFLAGS}"
  s="${s//'${DEFS}'/$DEFS}"
  s=$(echo "$s" | sed 's/\$(\([A-Z_]*\)=\([^)]*\))/\2/g')
  s=$(echo "$s" | sed 's/\${\([A-Z_]*\)=\([^}]*\)}/\2/g')
  local bt='`'
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*libpng-config[^${bt}]*${bt}/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*freetype-config[^${bt}]*${bt}/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*pkg-config[^${bt}]*${bt}//g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*${bt}//g")
  s=$(echo "$s" | sed 's|[/}]\(-L\)|\1|g')
  # Strip remaining $(...) patterns (GNU Make functions, undefined vars)
  while [[ "$s" == *'$('* ]]; do
    s=$(echo "$s" | sed 's/\$([^)]*)//g')
  done
  # Clean up orphaned parens from nested GNU Make function stripping
  s=$(echo "$s" | sed 's/)[)]*//g')
  echo "$s"
}

resolve_relpaths() {
  local flags="$1"; local srcdir="$2"; local result=""
  for flag in $flags; do
    case "$flag" in
      -I/*|-I~*) result="$result $flag" ;;
      -I../*|-I./*|-I[a-zA-Z]*) result="$result -I$srcdir/${flag#-I}" ;;
      -L/*|-L~*) result="$result $flag" ;;
      -L../*|-L./*|-L[a-zA-Z]*) result="$result -L$srcdir/${flag#-L}" ;;
      *.o|*.a|*.so)
        if [ "${flag:0:1}" != "/" ]; then result="$result $srcdir/$flag"
        else result="$result $flag"; fi ;;
      *) result="$result $flag" ;;
    esac
  done
  echo "$result"
}

needs_cxx14() {
  local pkgdir="$1"
  grep -q "RcppArmadillo" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "RcppEigen" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "C++14\|c++14\|CXX14\|cxx14" "$pkgdir/src/Makevars" 2>/dev/null && return 0
  grep -q "ranger" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  return 1
}

echo "=== Targeted .so compilation started at $(date) ==="
echo "Only processing packages with source files but no .so"
echo ""

compiled=0
failed=0
skipped=0
no_source=0
recompile=${1:-}

for pkg_path in "$LIBRARY"/*/; do
  pkgname=$(basename "$pkg_path")
  src_dir="$pkg_path/src"
  libs_dir="$pkg_path/libs"

  # Check if this package has compilable sources
  c_srcs=$(find "$src_dir" \( -name "*.c" \) 2>/dev/null | sort)
  cc_srcs=$(find "$src_dir" \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort)
  f_srcs=$(find "$src_dir" \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort)

  if [ -z "$c_srcs" ] && [ -z "$cc_srcs" ] && [ -z "$f_srcs" ]; then
    no_source=$((no_source + 1))
    continue
  fi

  # Check if .so already exists
  existing_so=$(find "$libs_dir" -name "*.so" 2>/dev/null | head -1)
  if [ -n "$existing_so" ] && [ "$recompile" != "--recompile" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Skip known-unfixable packages
  skip=false
  for spkg in $SKIP_PKGS; do
    if [ "$pkgname" = "$spkg" ]; then
      skip=true
      break
    fi
  done
  if $skip; then
    echo "  SKIP $pkgname (known unfixable)"
    skipped=$((skipped + 1))
    continue
  fi

  echo "=== $pkgname ==="

  # Parse Makevars
  PKG_CPPFLAGS=""; PKG_CFLAGS=""; PKG_FFLAGS=""; PKG_FCFLAGS=""
  PKG_CXXFLAGS=""; PKG_LIBS=""; OBJECTS=""
  MAKEVARS="$src_dir/Makevars"
  if [ -f "$MAKEVARS" ]; then
    joined_vars=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$MAKEVARS" 2>/dev/null)
    while IFS= read -r line; do
      case "$line" in .PHONY:*|all:*|\$*|include*) continue ;; esac
      line=$(echo "$line" | sed 's/^\([A-Z_0-9]*\)[[:space:]]*=[[:space:]]*/\1=/')
      case "$line" in
        PKG_CPPFLAGS=*) PKG_CPPFLAGS="${line#*=}" ;;
        PKG_CFLAGS=*)   PKG_CFLAGS="${line#*=}" ;;
        PKG_FFLAGS=*)   PKG_FFLAGS="${line#*=}" ;;
        PKG_FCFLAGS=*)  PKG_FCFLAGS="${line#*=}" ;;
        PKG_CXXFLAGS=*) PKG_CXXFLAGS="${line#*=}" ;;
        PKG_LIBS=*)     PKG_LIBS="${line#*=}" ;;
        OBJECTS=*)      OBJECTS="${line#*=}" ;;
        OBJS=*)         OBJECTS="${line#*=}" ;;
      esac
    done <<< "$joined_vars"
    for var in PKG_CPPFLAGS PKG_CFLAGS PKG_FFLAGS PKG_FCFLAGS PKG_CXXFLAGS PKG_LIBS; do
      val=$(sed 's/`[^`]*`//g' <<< "${!var}")
      printf -v "$var" "%s" "$val"
    done
    PKG_CPPFLAGS=$(expand_vars "$PKG_CPPFLAGS")
    PKG_CFLAGS=$(expand_vars "$PKG_CFLAGS")
    PKG_FFLAGS=$(expand_vars "$PKG_FFLAGS")
    PKG_FCFLAGS=$(expand_vars "$PKG_FCFLAGS")
    PKG_CXXFLAGS=$(expand_vars "$PKG_CXXFLAGS")
    PKG_LIBS=$(expand_vars "$PKG_LIBS")
    OBJECTS=$(expand_vars "$OBJECTS")
    PKG_CPPFLAGS=$(resolve_relpaths "$PKG_CPPFLAGS" "$src_dir")
    PKG_CFLAGS=$(resolve_relpaths "$PKG_CFLAGS" "$src_dir")
    PKG_CXXFLAGS=$(resolve_relpaths "$PKG_CXXFLAGS" "$src_dir")
    PKG_LIBS=$(resolve_relpaths "$PKG_LIBS" "$src_dir")
  fi

  # Detect C++ standard
  CXX_STD="-std=c++11"
  if needs_cxx14 "$pkg_path"; then
    if grep -q "C++17\|c++17\|CXX17\|cxx17\|filesystem" "$src_dir/"*.cpp "$src_dir/"*.hpp "$src_dir/"*.h 2>/dev/null; then
      CXX_STD="-std=c++17"
      echo "    (C++17 detected)"
    else
      CXX_STD="-std=c++14"
      echo "    (C++14 detected)"
    fi
  fi

  # R_NO_REMAP
  if grep -q "RcppArmadillo\|RcppEigen" "$pkg_path/DESCRIPTION" 2>/dev/null; then
    PKG_CXXFLAGS="-DR_NO_REMAP -DHAVE_WORKING_LOG1P $PKG_CXXFLAGS"
  fi

  # LinkingTo resolution
  LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | \
    sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  LINKING_INCLUDES=""
  if [ -n "$LINKING_TO" ]; then
    for lpkg in $LINKING_TO; do
      lpkg=$(echo "$lpkg" | xargs); [ -z "$lpkg" ] && continue
      for try_path in "$LIBRARY/$lpkg/inst/include" "$LIBRARY/$lpkg/include"; do
        [ -d "$try_path" ] && { LINKING_INCLUDES="$LINKING_INCLUDES -I$try_path"; break; }
      done
    done
  fi
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    [ -d "$self_path" ] && { LINKING_INCLUDES="$LINKING_INCLUDES -I$self_path"; break; }
  done
  if [ -d "$EXT_INC" ]; then
    LINKING_INCLUDES="$LINKING_INCLUDES -I$EXT_INC"
    for d in "$EXT_INC"/*/; do [ -d "$d" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$d"; done
  fi
  if [ -d "$EXT_LD" ]; then
    PKG_LIBS="$PKG_LIBS -L$EXT_LD"
  fi

  compile_log="$LOG_DIR/$pkgname.log"
  BUILD_TMP=$(mktemp -p "$DIR/../tmp")
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  all_objs=""
  compile_ok=true

  # CC
  for src in $c_srcs; do
    base=$(basename "$src"); base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS \
         --sysroot="$SYSROOT" -fPIC -O2 -g0 $PKG_CPPFLAGS $PKG_CFLAGS \
         -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      echo "  FAILED: $base"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # CXX
  if $compile_ok && [ -n "$cc_srcs" ]; then
    for src in $cc_srcs; do
      base=$(basename "$src"); base_noext="${base%.*}"
      echo "  CXX $base"
      if ! $CXX -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS \
           --sysroot="$SYSROOT" -fPIC -O2 -g0 $CXX_STD $PKG_CPPFLAGS $PKG_CXXFLAGS \
           -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  FAILED: $base"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # FC
  if $compile_ok && [ -n "$f_srcs" ] && [ -x "$FC" ]; then
    for src in $f_srcs; do
      base=$(basename "$src"); base_noext="${base%.*}"
      echo "  FC $base"
      if ! $FC -B"$FC_DIR" -I"$src_dir" -fPIC -O2 -g0 $PKG_FFLAGS $PKG_FCFLAGS \
           -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  FAILED: $base"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # LD
  if $compile_ok; then
    if [ -n "$OBJECTS" ]; then
      all_objs=""
      for obj in $OBJECTS; do
        obj_path="$BUILD_TMP/$obj"
        [ ! -f "$obj_path" ] && obj_path=$(find "$src_dir" -name "$obj" 2>/dev/null | head -1)
        all_objs="$all_objs $obj_path"
      done
    fi
    echo "  LD $pkgname.so"
    mkdir -p "$libs_dir"
    if ! $CC -shared -fPIC -o "$libs_dir/$pkgname.so" $all_objs \
         -L"$R_LIB" -lR $PKG_LIBS --sysroot="$SYSROOT" \
         -Wl,--allow-multiple-definition -L"$R_LIB" -lmuslstubs >> "$compile_log" 2>&1; then
      echo "  LINK FAILED"
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "  OK ($so_size)"
    echo "$pkgname: OK ($so_size)" >> "$LOG_DIR/success.log"
    compiled=$((compiled + 1))
  else
    err_short=$(grep -E "fatal error:|error:" "$compile_log" | head -2 | tr '\n' '; ')
    echo "  FAILED: ${err_short:-see log}"
    echo "$pkgname: ${err_short}" >> "$LOG_DIR/fail_summary.log"
    failed=$((failed + 1))
  fi
done

echo ""
echo "=== Summary ==="
echo "Packages with source files: $((compiled + failed + skipped))"
echo "  Pure R (no source): $no_source"
echo "  Already had .so: $skipped"
echo "  Newly compiled: $compiled"
echo "  Failed: $failed"
echo "=== Done at $(date) ==="
