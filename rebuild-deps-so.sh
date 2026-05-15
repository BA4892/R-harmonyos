#!/data/service/hnp/bin/bash
# Rebuild missing/broken .so files for dependency packages
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
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"

# R Makeconf-style variable definitions
BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
C_VISIBILITY="-fvisibility=hidden"
SHLIB_OPENMP_CFLAGS="-fopenmp"
SHLIB_OPENMP_CXXFLAGS="-fopenmp"
SHLIB_OPENMP_FFLAGS="-fopenmp"

LIBRARY="/storage/Users/currentUser/R-harmonyos/build/library"
LOG_DIR="/storage/Users/currentUser/R-harmonyos/compile-logs"
mkdir -p "$LOG_DIR"

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
  s="${s//'$(R_DEBUG_FLAGS)'/ }"
  s="${s//'$(R_HOME)'/$DIR}"
  s="${s//'$(DEBUGING_FLAGS)'/ }"
  s="${s//'$(STANC_FLAGS)'/ }"
  s="${s//'$(JPEG_CFLAGS)'/ }"
  s="${s//'$(PNG_CFLAGS)'/ }"
  s="${s//'$(JPEG_LIBS)'/ }"
  s="${s//'$(PNG_LIBS)'/ }"
  s="${s//'$(TCLTK_CFLAGS)'/ }"
  s="${s//'$(TCLTK_LIBS)'/ }"
  s="${s//'${BLAS_LIBS}'/$BLAS_LIBS}"
  s="${s//'${LAPACK_LIBS}'/$LAPACK_LIBS}"
  s="${s//'${FLIBS}'/$FLIBS}"
  s="${s//'${C_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${CXX_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${SHLIB_OPENMP_CFLAGS}'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'${SHLIB_OPENMP_CXXFLAGS}'/$SHLIB_OPENMP_CXXFLAGS}"
  s="${s//'${SHLIB_OPENMP_FFLAGS}'/$SHLIB_OPENMP_FFLAGS}"
  s="${s//'${SHLIB_OPENMP_LIBS}'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'$(R_XTRA_CPPFLAGS)'/ }"
  s="${s//'$(R_XTRA_CFLAGS)'/ }"
  s="${s//'$(R_XTRA_CXXFLAGS)'/ }"
  s="${s//'$(R_XTRA_FFLAGS)'/ }"
  s="${s//'$(R_XTRA_FCFLAGS)'/ }"
  s="${s//'$(R_XTRA_LIBS)'/ }"
  echo "$s"
}

resolve_relpaths() {
  local val="$1" basedir="$2"
  local result=""
  for tok in $val; do
    case "$tok" in
      -I./*|-I../*) tok="-I$(realpath "$basedir/${tok#-I}" 2>/dev/null || echo "$tok")" ;;
      -L./*|-L../*) tok="-L$(realpath "$basedir/${tok#-L}" 2>/dev/null || echo "$tok")" ;;
    esac
    result="$result $tok"
  done
  echo "$result"
}

needs_cxx14() {
  local pkgdir="$1"
  grep -q "RcppArmadillo\|RcppEigen" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "C++14\|c++14\|CXX14\|cxx14" "$pkgdir/src/Makevars" 2>/dev/null && return 0
  grep -q "C++14\|c++14" "$pkgdir/src/"*.cpp "$pkgdir/src/"*.hpp 2>/dev/null && return 0
  return 1
}

# Packages that need .so rebuild (missing or broken)
PKGS="terra igraph stringi xml2 nloptr fstcore units gsl cubature png curl systemfonts openssl gmp glmnet RcppArmadillo"

compiled=0
failed=0
skipped=0

echo "=== Dependency .so rebuild ==="
echo "Started at $(date)"
echo ""

for pkgname in $PKGS; do
  pkg_path="$LIBRARY/$pkgname"

  if [ ! -d "$pkg_path" ]; then
    echo "SKIP: $pkgname (not installed)"
    skipped=$((skipped + 1))
    continue
  fi

  src_dir="$pkg_path/src"
  libs_dir="$pkg_path/libs"

  # Check if package has compilable sources
  c_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.c" \) 2>/dev/null | sort)
  cc_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort)
  f_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort)

  if [ -z "$c_srcs" ] && [ -z "$cc_srcs" ] && [ -z "$f_srcs" ]; then
    echo "SKIP: $pkgname (no compilable sources)"
    skipped=$((skipped + 1))
    continue
  fi

  echo ""
  echo "=== $pkgname ==="

  # Check for subdirectories with source files
  sub_srcs=$(find "$src_dir" -mindepth 2 \( -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.f" -o -name "*.f90" \) 2>/dev/null | head -5)
  if [ -n "$sub_srcs" ]; then
    echo "  (has subdirectory sources - may need special handling)"
  fi

  # Clean any existing .so
  mkdir -p "$libs_dir"
  rm -f "$libs_dir"/*.so

  # Parse Makevars
  PKG_CPPFLAGS=""; PKG_CFLAGS=""; PKG_FFLAGS=""; PKG_FCFLAGS=""; PKG_CXXFLAGS=""; PKG_LIBS=""; OBJECTS=""
  MAKEVARS="$src_dir/Makevars"
  if [ -f "$MAKEVARS" ]; then
    joined_vars=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$MAKEVARS")
    while IFS= read -r line; do
      case "$line" in
        .PHONY:*|all:*|\$*|include*) continue ;;
      esac
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
    PKG_CPPFLAGS=$(echo "$PKG_CPPFLAGS" | sed 's/`[^`]*`//g')
    PKG_CFLAGS=$(echo "$PKG_CFLAGS" | sed 's/`[^`]*`//g')
    PKG_FFLAGS=$(echo "$PKG_FFLAGS" | sed 's/`[^`]*`//g')
    PKG_FCFLAGS=$(echo "$PKG_FCFLAGS" | sed 's/`[^`]*`//g')
    PKG_CXXFLAGS=$(echo "$PKG_CXXFLAGS" | sed 's/`[^`]*`//g')
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/`[^`]*`//g')
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

  # C++ standard
  CXX_STD="-std=c++11"
  if needs_cxx14 "$pkg_path"; then
    CXX_STD="-std=c++14"
  fi

  # LinkingTo
  LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  LINKING_INCLUDES=""
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
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    [ -d "$self_path" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$self_path" && break
  done
  if [ -d "$EXT_INC" ]; then
    LINKING_INCLUDES="$LINKING_INCLUDES -I$EXT_INC"
    for d in "$EXT_INC"/*/; do
      [ -d "$d" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$d"
    done
  fi
  if [ -d "$EXT_LD" ]; then
    PKG_LIBS="$PKG_LIBS -L$EXT_LD"
  fi

  compile_log="$LOG_DIR/$pkgname.rebuild.log"
  BUILD_TMP=$(mktemp -p "/tmp" 2>/dev/null || mktemp -p "/storage/Users/currentUser/R-harmonyos/build/tmp")
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  all_objs=""
  compile_ok=true

  # Compile C sources
  for src in $c_srcs; do
    base=$(basename "$src")
    base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS --sysroot="$SYSROOT" -fPIC -O2 -g0 $PKG_CPPFLAGS $PKG_CFLAGS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      echo "  C FAILED: $base"
      echo "  (check $compile_log)"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # Compile C++ sources
  if $compile_ok && [ -n "$cc_srcs" ]; then
    for src in $cc_srcs; do
      base=$(basename "$src")
      base_noext="${base%.*}"
      echo "  CXX $base"
      if ! $CXX -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES $JAVA_CPPFLAGS --sysroot="$SYSROOT" -fPIC -O2 -g0 $CXX_STD $PKG_CPPFLAGS $PKG_CXXFLAGS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  CXX FAILED: $base"
        echo "  (check $compile_log)"
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
      if ! $FC -B"$FC_DIR" -I"$src_dir" -fPIC -O2 -g0 $PKG_FFLAGS $PKG_FCFLAGS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "  FC FAILED: $base"
        echo "  (check $compile_log)"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Link
  if $compile_ok; then
    if [ -n "$OBJECTS" ]; then
      all_objs=""
      for obj in $OBJECTS; do
        obj_path="$BUILD_TMP/$obj"
        if [ ! -f "$obj_path" ]; then
          obj_path=$(find "$src_dir" -name "$obj" 2>/dev/null | head -1)
        fi
        all_objs="$all_objs $obj_path"
      done
    fi

    # Determine .so name from Makevars or package name
    soname="$pkgname.so"
    echo "  LD $soname"
    if ! $CC -shared -fPIC -o "$libs_dir/$soname" $all_objs \
        -L"$R_LIB" -lR $PKG_LIBS --sysroot="$SYSROOT" -Wl,--allow-multiple-definition \
        -L"$R_LIB" -lmuslstubs >> "$compile_log" 2>&1; then
      echo "  LINK FAILED"
      grep -E "error:|undefined reference" "$compile_log" | head -5
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    so_size=$(ls -lh "$libs_dir/$soname" | awk '{print $5}')
    echo "  OK ($so_size)"
    compiled=$((compiled + 1))
  else
    echo "  FAILED"
    failed=$((failed + 1))
  fi
done

echo ""
echo "=== Summary ==="
echo "Compiled: $compiled"
echo "Failed: $failed"
echo "Skipped: $skipped"
echo "Finished at $(date)"
