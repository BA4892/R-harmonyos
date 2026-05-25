#!/data/service/hnp/bin/bash
# Rebuild .so files for the 82 patchelf-corrupted packages
# Uses the same compilation logic as build-fix-so.sh but only targets
# specific packages for much faster execution.

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

# R Makeconf-style variable definitions
BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
C_VISIBILITY="-fvisibility=hidden"
SHLIB_OPENMP_CFLAGS="-fopenmp"
SHLIB_OPENMP_CXXFLAGS="-fopenmp"
SHLIB_OPENMP_FFLAGS="-fopenmp"
DEFS=""

# External system libs
EXT_LIB="/storage/Users/currentUser/.local/R-deps"
BREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
BREW_INC="$BREW_PREFIX/include"
BREW_LD="$BREW_PREFIX/lib"
HOMEBREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"

LOG_DIR="$DIR/../compile-logs"
mkdir -p "$LOG_DIR"

# Export LD_PRELOAD for any R processes run during makeLazyLoading
export LD_PRELOAD="$DIR/lib/libc++_shared.so"

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
  s="${s//'$(R_DEBUG_FLAGS)'/$DEFS}"
  s="${s//'$(R_HOME)'/$DIR}"
  s="${s//'$(DEBUGING_FLAGS)'/ }"
  s="${s//'$(STANC_FLAGS)'/ }"
  s="${s//'$(JPEG_CFLAGS)'/ }"
  s="${s//'$(PNG_CFLAGS)'/ }"
  s="${s//'$(JPEG_LIBS)'/ }"
  s="${s//'$(PNG_LIBS)'/ }"
  s="${s//'$(TCLTK_CFLAGS)'/ }"
  s="${s//'$(TCLTK_LIBS)'/ }"
  # ${VAR} variants
  s="${s//'${BLAS_LIBS}'/$BLAS_LIBS}"
  s="${s//'${LAPACK_LIBS}'/$LAPACK_LIBS}"
  s="${s//'${FLIBS}'/$FLIBS}"
  s="${s//'${C_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${CXX_VISIBILITY}'/$C_VISIBILITY}"
  s="${s//'${SHLIB_OPENMP_CFLAGS}'/$SHLIB_OPENMP_CFLAGS}"
  s="${s//'${SHLIB_OPENMP_CXXFLAGS}'/$SHLIB_OPENMP_CXXFLAGS}"
  s="${s//'${SHLIB_OPENMP_FFLAGS}'/$SHLIB_OPENMP_FFLAGS}"
  s="${s//'${R_DEBUG_FLAGS}'/$DEFS}"
  # $(VAR=default) syntax
  s=$(echo "$s" | sed 's/\$(\([A-Z_]*\)=\([^)]*\))/\2/g')
  s=$(echo "$s" | sed 's/\${\([A-Z_]*\)=\([^}]*\)}/\2/g')
  # pkg-config backtick expressions
  s=$(echo "$s" | sed "s/\`[^\`]*libpng-config[^\`]*\`/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed "s/\`[^\`]*freetype-config[^\`]*\`/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed 's/`[^`]*pkg-config[^`]*`//g')
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
      -I/*|-I~*)  result="$result $flag" ;;
      -I../*|-I./*|-I[a-zA-Z]*)  result="$result -I$srcdir/${flag#-I}" ;;
      -L/*|-L~*)  result="$result $flag" ;;
      -L../*|-L./*|-L[a-zA-Z]*)  result="$result -L$srcdir/${flag#-L}" ;;
      *.o|*.a|*.so)
        if [ "${flag:0:1}" != "/" ]; then result="$result $srcdir/$flag"; else result="$result $flag"; fi ;;
      *)  result="$result $flag" ;;
    esac
  done
  echo "$result"
}

needs_cxx14() {
  local pkgdir="$1"
  grep -q "RcppArmadillo\|RcppEigen" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "C++14\|c++14\|CXX14\|cxx14" "$pkgdir/src/Makevars" 2>/dev/null && return 0
  grep -q "C++14\|c++14" "$pkgdir/src/"*.cpp "$pkgdir/src/"*.hpp 2>/dev/null && return 0
  grep -q "ranger" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "parsermd" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  return 1
}

# List of 82 packages to rebuild
PKGS="Rcpp httpuv reticulate raster readr paws.common fst isoband svglite roxygen2 nanotime farver pcaPP tidygraph reshape2 geepack glmmTMB clock phangorn satellite RcppCCTZ mice RcppParallel parsermd ggraph joineRML ff gdtools lme4 conquer fixest ggiraph transformr tweenr brmsmargins robustlmm alpaca sem energy ranger rugarch umap REndo bindrcpp tramME projpred multgee forecast GA frailtyEM mdmb gridtext miceadds rvg marquee mvgam openxlsx mlr3oml Amelia bife flexsurv optmatch ModelMetrics TAM mirt pbdZMQ MCMCglmm rstpm2 BayesFactor lime partitions mmrm CDM rtdists phyr sdmTMB icenReg netrankr robmixglm lavaSearch2 wrswoR rlme"

LIBRARY="/storage/Users/currentUser/R-harmonyos/build/library"
compiled=0
failed=0
skipped=0

echo "=== Targeted .so rebuild for 82 patchelf-corrupted packages ==="
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
    # Strip backtick expressions
    PKG_CPPFLAGS=$(echo "$PKG_CPPFLAGS" | sed 's/`[^`]*`//g')
    PKG_CFLAGS=$(echo "$PKG_CFLAGS" | sed 's/`[^`]*`//g')
    PKG_FFLAGS=$(echo "$PKG_FFLAGS" | sed 's/`[^`]*`//g')
    PKG_FCFLAGS=$(echo "$PKG_FCFLAGS" | sed 's/`[^`]*`//g')
    PKG_CXXFLAGS=$(echo "$PKG_CXXFLAGS" | sed 's/`[^`]*`//g')
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/`[^`]*`//g')
    # Expand variables
    PKG_CPPFLAGS=$(expand_vars "$PKG_CPPFLAGS")
    PKG_CFLAGS=$(expand_vars "$PKG_CFLAGS")
    PKG_FFLAGS=$(expand_vars "$PKG_FFLAGS")
    PKG_FCFLAGS=$(expand_vars "$PKG_FCFLAGS")
    PKG_CXXFLAGS=$(expand_vars "$PKG_CXXFLAGS")
    PKG_LIBS=$(expand_vars "$PKG_LIBS")
    OBJECTS=$(expand_vars "$OBJECTS")
    # Resolve relative paths
    PKG_CPPFLAGS=$(resolve_relpaths "$PKG_CPPFLAGS" "$src_dir")
    PKG_CFLAGS=$(resolve_relpaths "$PKG_CFLAGS" "$src_dir")
    PKG_CXXFLAGS=$(resolve_relpaths "$PKG_CXXFLAGS" "$src_dir")
    PKG_LIBS=$(resolve_relpaths "$PKG_LIBS" "$src_dir")
  fi

  # Determine C++ standard
  CXX_STD="-std=c++11"
  if needs_cxx14 "$pkg_path"; then
    if [ "$pkgname" = "parsermd" ] || grep -q "C++17\|c++17\|CXX17\|cxx17\|filesystem" "$pkg_path/src/"*.cpp "$pkg_path/src/"*.hpp 2>/dev/null; then
      CXX_STD="-std=c++17"
      echo "  (C++17)"
    else
      CXX_STD="-std=c++14"
      echo "  (C++14)"
    fi
  fi

  # RcppArmadillo/Eigen specific flags
  if grep -q "RcppArmadillo\|RcppEigen" "$pkg_path/DESCRIPTION" 2>/dev/null; then
    PKG_CXXFLAGS="-DR_NO_REMAP -DHAVE_WORKING_LOG1P $PKG_CXXFLAGS"
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
      for try_path in \
        "/storage/Users/currentUser/R-harmonyos/build/library/$lpkg/inst/include" \
        "/storage/Users/currentUser/R-harmonyos/build/library/$lpkg/include"; do
        if [ -d "$try_path" ]; then
          LINKING_INCLUDES="$LINKING_INCLUDES -I$try_path"
          break
        fi
      done
    done
  fi
  # Self include
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    [ -d "$self_path" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$self_path" && break
  done
  # System includes
  if [ -d "$EXT_INC" ] && [ -d "$BREW_INC" ]; then
    LINKING_INCLUDES="$LINKING_INCLUDES -I$EXT_INC -I$BREW_INC"
    for d in "$EXT_INC"/*/; do
      [ -d "$d" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$d"
    done
  fi
  # System lib paths
  if [ -d "$EXT_LD" ]; then
    PKG_LIBS="$PKG_LIBS -L$EXT_LD -L$BREW_LD"
  fi

  # RcppArmadillo generated config header
  if [ -f "/storage/Users/currentUser/R-harmonyos/build/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h.in" ]; then
    gen_h="/storage/Users/currentUser/R-harmonyos/build/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h"
    if [ ! -f "$gen_h" ]; then
      echo "// Auto-generated" > "$gen_h"
      echo "#ifndef RcppArmadilloConfigGenerated_H" >> "$gen_h"
      echo "#define RcppArmadilloConfigGenerated_H" >> "$gen_h"
      echo "#define ARMA_USE_OPENMP 0" >> "$gen_h"
      echo "#endif" >> "$gen_h"
    fi
  fi

  compile_log="$LOG_DIR/$pkgname.rebuild.log"
  BUILD_TMP=$(mktemp -p "$DIR/../tmp")
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

    echo "  LD $pkgname.so"
    # Only add Java libs if the package has Java sources
    JAVA_LIBS=""
    if [ -d "$src_dir/../java" ] && [ "$(find "$src_dir/../java" -name '*.java' 2>/dev/null | head -1)" ]; then
      JAVA_LIBS="-L${JAVA_HOME}/lib/server -ljvm"
    fi
    if ! $CC -shared -fPIC -o "$libs_dir/$pkgname.so" $all_objs \
        -L"$R_LIB" -lR $PKG_LIBS --sysroot="$SYSROOT" -Wl,--allow-multiple-definition \
        -L"$R_LIB" -lmuslstubs $JAVA_LIBS >> "$compile_log" 2>&1; then
      echo "  LINK FAILED"
      grep -E "error:|undefined reference" "$compile_log" | head -3
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "  OK ($so_size)"

    # Run makeLazyLoading if needed
    rdb_file="$pkg_path/R/$pkgname.rdb"
    if [ ! -f "$rdb_file" ]; then
      r_concat="$pkg_path/R/$pkgname"
      if [ -f "$r_concat" ]; then
        echo "  Running makeLazyLoading..."
        export R_HOME_DIR="$DIR"
        export R_HOME="$DIR"
        export LD_LIBRARY_PATH="$DIR/lib"
        export LD_PRELOAD="$DIR/lib/libc++_shared.so"
        "$DIR/bin/exec/R" --vanilla --no-save --no-restore -e \
          "library(tools); tools:::makeLazyLoading(\"$pkgname\", lib.loc = \"$LIBRARY\", compress = FALSE)" \
          >> "$compile_log" 2>&1 || true
      fi
    fi

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
