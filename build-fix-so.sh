#!/data/service/hnp/bin/bash
# Batch compile missing .so files for all R packages (v2)
# Features:
# - Handles Rcpp/RcppArmadillo/RcppEigen LinkingTo header paths
# - Uses -B flag for gfortran f951 subprocess
# - Handles duplicate symbols with --allow-multiple-definition
# - Resumable: skips already-processed packages
# - Substitutes Makevars variables (BLAS_LIBS, LAPACK_LIBS, etc.)
# - C++14 auto-detection for RcppArmadillo packages
# - Generates missing config.h headers
# Usage: ./build-fix-so.sh [--recompile]

DIR="/storage/Users/currentUser/R-harmonyos/build"
CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
CXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
R_INC="$DIR/include"
R_LIB="$DIR/lib"
FC="/storage/Users/currentUser/gfortran-harmonyos/build/gcc/gfortran"
FC_DIR="/storage/Users/currentUser/gfortran-harmonyos/build/gcc"

# R Makeconf-style variable definitions for substitution
BLAS_LIBS="-L$R_LIB -lRblas"
LAPACK_LIBS="-L$R_LIB -lRlapack"
FLIBS="-L$FC_DIR -lgfortran -lgcc_s"
C_VISIBILITY="-fvisibility=hidden"
SHLIB_OPENMP_CFLAGS="-fopenmp"
SHLIB_OPENMP_CXXFLAGS="-fopenmp"
SHLIB_OPENMP_FFLAGS="-fopenmp"
R_DEBUG_FLAGS=""
R_DEBUG_CXXFLAGS=""
DEFS=""

# System library search paths (built external libs)
EXT_LIB="/storage/Users/currentUser/.local/R-deps"
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"
PKG_CONFIG_PATH="$EXT_LD/pkgconfig"

LOG_DIR="$DIR/../compile-logs"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/success.log" "$LOG_DIR/fail_summary.log"

# Determine where to resume
resume_after=""
if [ -f "$LOG_DIR/last_pkg.txt" ]; then
  resume_after=$(cat "$LOG_DIR/last_pkg.txt")
  echo "Resuming after package: $resume_after"
fi

resume_skip=true

# Function: substitute Makevars variables with actual values
# Usage: expand_vars "string_with_$(VAR)" -> outputs expanded string
expand_vars() {
  local s="$1"
  # Standard $(VAR) patterns
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
  # Also handle ${VAR} curly brace variants
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
  # Handle $(VAR=default) syntax used by R Makeconf (e.g. $(DEFS=-DUSE_FC_LEN_T))
  # Extract the default value after = and use it
  s=$(echo "$s" | sed 's/\$(\([A-Z_]*\)=\([^)]*\))/\2/g')
  # Handle ${VAR=default} syntax
  s=$(echo "$s" | sed 's/\${\([A-Z_]*\)=\([^}]*\)}/\2/g')
  # Handle pkg-config backtick expressions: `libpng-config --cflags`
  local bt='`'
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*libpng-config[^${bt}]*${bt}/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*freetype-config[^${bt}]*${bt}/-I${EXT_INC//\//\\/}/g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*pkg-config[^${bt}]*${bt}//g")
  s=$(echo "$s" | sed "s/${bt}[^${bt}]*${bt}//g")  # Remove remaining backtick expressions
  # Clean up any leading '/' or '}' before '-L' that might result from concatenation issues
  s=$(echo "$s" | sed 's|[/}]\(-L\)|\1|g')
  echo "$s"
}

# Function: resolve relative -I, -L paths and .o files relative to source dir
resolve_relpaths() {
  local flags="$1"
  local srcdir="$2"
  local result=""
  for flag in $flags; do
    case "$flag" in
      -I/*|-I~*)  # Already absolute
        result="$result $flag" ;;
      -I../*|-I./*|-I[a-zA-Z]*)  # Relative path
        result="$result -I$srcdir/${flag#-I}" ;;
      -L/*|-L~*)
        result="$result $flag" ;;
      -L../*|-L./*|-L[a-zA-Z]*)
        result="$result -L$srcdir/${flag#-L}" ;;
      *.o|*.a|*.so)  # Relative object/library path
        if [ "${flag:0:1}" != "/" ]; then
          result="$result $srcdir/$flag"
        else
          result="$result $flag"
        fi ;;
      *)
        result="$result $flag" ;;
    esac
  done
  echo "$result"
}

# Function: check if a package needs C++14 based on RcppArmadillo dependency
needs_cxx14() {
  local pkgdir="$1"
  grep -q "RcppArmadillo" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  grep -q "RcppEigen" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  # Check source files for C++14 features
  grep -q "C++14\|c++14\|CXX14\|cxx14" "$pkgdir/src/Makevars" 2>/dev/null && return 0
  grep -q "C++14\|c++14" "$pkgdir/src/"*.cpp "$pkgdir/src/"*.hpp 2>/dev/null && return 0
  # ranger specific
  grep -q "ranger" "$pkgdir/DESCRIPTION" 2>/dev/null && return 0
  return 1
}

# Function: generate missing config.h for packages that need it
generate_config_h() {
  local pkgname="$1"
  local src_dir="$2"
  local pkg_path="$3"
  case "$pkgname" in
    RNetCDF|RODBC|RhpcBLASctl|ps|igraph|fftw)
      if [ ! -f "$src_dir/config.h" ]; then
        cat > "$src_dir/config.h" << 'CONFIGEOF'
/* Auto-generated config.h for HarmonyOS */
#define HAVE_STDINT_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_FCNTL_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_MEMORY_H 1
#define HAVE_DLFCN_H 1
#define HAVE_ALLOCA_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_NETDB_H 1
#define HAVE_ARPA_INET_H 1
#define STDC_HEADERS 1
CONFIGEOF
        echo "    (generated config.h)"
      fi
      ;;
    ps)
      if [ ! -f "$src_dir/config.h" ]; then
        cat > "$src_dir/config.h" << 'CONFIGEOF'
/* Auto-generated config.h for ps on HarmonyOS */
#define HAVE_CONFIG_H 1
#define HAVE_ERRNO_H 1
#define HAVE_DIRENT_H 1
#define HAVE_FCNTL_H 1
#define HAVE_DLFCN_H 1
#define HAVE_PWD_H 1
#define HAVE_SIGNAL_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_UCRED_H 1
#define HAVE_UNISTD_H 1
#define HAVE_UTMP_H 1
#define HAVE_UTMPX_H 1
#define HAVE_PROCESS_H 1
#define HAVE_GETPWUID 1
#define HAVE_GETTID 1
#define HAVE_TTYNAME 1
#define HAVE_READLINK 1
#define HAVE_STRERROR 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_DIRFD 1
#define HAVE_SNPRINTF 1
#define HAVE_VSNPRINTF 1
CONFIGEOF
        echo "    (generated config.h for ps)"
      fi
      ;;
    Cairo)
      # Always regenerate cconfig.h for Cairo (the installed one may include <cairo.h>)
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
      echo "    (generated cconfig.h for Cairo)"

      ;;
    commonmark)
      if [ ! -f "$src_dir/syntax_extension.h" ]; then
        cat > "$src_dir/syntax_extension.h" << 'CMARKEOF'
/* Auto-generated stub: include cmark-gfm extensions */
#include "extensions/cmark-gfm-core-extensions.h"
CMARKEOF
        echo "    (generated syntax_extension.h for commonmark)"
      fi
      ;;
  esac
}

echo "Batch .so compilation v2 started at $(date)"
echo "========================================"

compiled=0
failed=0
skipped=0
processed=0

for pkg_path in /storage/Users/currentUser/R-harmonyos/build/library/*/; do
  pkgname=$(basename "$pkg_path")
  src_dir="$pkg_path/src"
  libs_dir="$pkg_path/libs"

  # Check if this package has compilable sources
  c_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.c" \) 2>/dev/null | sort)
  cc_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort)
  f_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort)

  if [ -z "$c_srcs" ] && [ -z "$cc_srcs" ] && [ -z "$f_srcs" ]; then
    continue
  fi

  processed=$((processed + 1))

  # Resume logic
  if [ -n "$resume_after" ]; then
    if [ "$resume_skip" = true ]; then
      if [ "$pkgname" = "$resume_after" ]; then
        resume_skip=false
      fi
      continue
    fi
  fi

  # Check if .so already exists
  existing_so=$(find "$libs_dir" -name "*.so" 2>/dev/null | head -1)
  recompile=${1:-}
  if [ -n "$existing_so" ] && [ "$recompile" != "--recompile" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo ""
  echo "=== $pkgname ($processed) ==="

  # Parse Makevars (handles both VAR=val and VAR = val)
  PKG_CPPFLAGS=""; PKG_CFLAGS=""; PKG_FFLAGS=""; PKG_FCFLAGS=""; PKG_CXXFLAGS=""; PKG_LIBS=""; OBJECTS=""
  MAKEVARS="$src_dir/Makevars"
  if [ -f "$MAKEVARS" ]; then
    # Join continuation lines ending with backslash before parsing
    joined_vars=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$MAKEVARS")
    while IFS= read -r line; do
      # Skip Makefile rules/phony/targets
      case "$line" in
        .PHONY:*|all:*|\$*|include*) continue ;;
      esac
      # Normalize: strip spaces/tabs around =
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
    # Strip backtick expressions (command substitutions) before variable expansion
    # These contain $(R_HOME)/bin/Rscript which would cause issues
    PKG_CPPFLAGS=$(echo "$PKG_CPPFLAGS" | sed 's/`[^`]*`//g')
    PKG_CFLAGS=$(echo "$PKG_CFLAGS" | sed 's/`[^`]*`//g')
    PKG_FFLAGS=$(echo "$PKG_FFLAGS" | sed 's/`[^`]*`//g')
    PKG_FCFLAGS=$(echo "$PKG_FCFLAGS" | sed 's/`[^`]*`//g')
    PKG_CXXFLAGS=$(echo "$PKG_CXXFLAGS" | sed 's/`[^`]*`//g')
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/`[^`]*`//g')
    # Expand Makevars variables
    PKG_CPPFLAGS=$(expand_vars "$PKG_CPPFLAGS")
    PKG_CFLAGS=$(expand_vars "$PKG_CFLAGS")
    PKG_FFLAGS=$(expand_vars "$PKG_FFLAGS")
    PKG_FCFLAGS=$(expand_vars "$PKG_FCFLAGS")
    PKG_CXXFLAGS=$(expand_vars "$PKG_CXXFLAGS")
    PKG_LIBS=$(expand_vars "$PKG_LIBS")
    OBJECTS=$(expand_vars "$OBJECTS")

    # Resolve relative -I and -L paths to absolute (relative to src_dir)
    PKG_CPPFLAGS=$(resolve_relpaths "$PKG_CPPFLAGS" "$src_dir")
    PKG_CFLAGS=$(resolve_relpaths "$PKG_CFLAGS" "$src_dir")
    PKG_CXXFLAGS=$(resolve_relpaths "$PKG_CXXFLAGS" "$src_dir")
    PKG_LIBS=$(resolve_relpaths "$PKG_LIBS" "$src_dir")
  fi

  # Generate missing config.h
  generate_config_h "$pkgname" "$src_dir" "$pkg_path"

  # Determine C++ standard
  CXX_STD="-std=c++11"
  if needs_cxx14 "$pkg_path"; then
    CXX_STD="-std=c++14"
    echo "    (C++14 detected)"
  fi

  # R_NO_REMAP to avoid Rmath.h log1p macro conflict with std::log1p in C++11/14
  # Also define HAVE_WORKING_LOG1P to prevent Rmath.h from #define log1p Rlog1p
  if grep -q "RcppArmadillo\|RcppEigen" "$pkg_path/DESCRIPTION" 2>/dev/null; then
    PKG_CXXFLAGS="-DR_NO_REMAP -DHAVE_WORKING_LOG1P $PKG_CXXFLAGS"
  fi

  # Handle LinkingTo - extract package names, handle multi-line DESCRIPTION fields
  LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | \
    sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  LINKING_INCLUDES=""
  if [ -n "$LINKING_TO" ]; then
    for lpkg in $LINKING_TO; do
      lpkg=$(echo "$lpkg" | xargs)
      [ -z "$lpkg" ] && continue
      # Try standard paths for LinkingTo packages
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

  # Self-referencing include: packages like Rcpp,RcppArmadillo include their own headers
  for self_path in \
    "$pkg_path/inst/include" \
    "$pkg_path/include"; do
    if [ -d "$self_path" ]; then
      LINKING_INCLUDES="$LINKING_INCLUDES -I$self_path"
      break
    fi
  done

  # System library include paths - add ALL available ext lib dirs
  if [ -d "$EXT_INC" ]; then
    LINKING_INCLUDES="$LINKING_INCLUDES -I$EXT_INC"
    for d in "$EXT_INC"/*/; do
      [ -d "$d" ] && LINKING_INCLUDES="$LINKING_INCLUDES -I$d"
    done
  fi

  # Add system library lib paths to PKG_LIBS
  if [ -d "$EXT_LD" ]; then
    PKG_LIBS="$PKG_LIBS -L$EXT_LD"
  fi

  # Workaround for RcppArmadillo missing generated config header
  if [ -f "/storage/Users/currentUser/R-harmonyos/build/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h.in" ]; then
    gen_h="/storage/Users/currentUser/R-harmonyos/build/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h"
    if [ ! -f "$gen_h" ]; then
      # Create a default config (no ARMA_* defines)
      echo "// Auto-generated by build-fix-so.sh" > "$gen_h"
      echo "#ifndef RcppArmadilloConfigGenerated_H" >> "$gen_h"
      echo "#define RcppArmadilloConfigGenerated_H" >> "$gen_h"
      echo "" >> "$gen_h"
      echo "#define ARMA_USE_OPENMP 0" >> "$gen_h"
      echo "" >> "$gen_h"
      echo "#endif" >> "$gen_h"
    fi
  fi

  compile_log="$LOG_DIR/$pkgname.log"
  BUILD_TMP=$(mktemp -p "$DIR/../tmp")
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  all_objs=""
  compile_ok=true

  # Compile C sources
  for src in $c_srcs; do
    base=$(basename "$src")
    base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES --sysroot="$SYSROOT" -fPIC -O2 -g0 $PKG_CPPFLAGS $PKG_CFLAGS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      err=$(grep "fatal error" "$compile_log" | head -1)
      echo "  FAILED: $base -> $err"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # Compile C++ sources
  if $compile_ok && [ -n "$cc_srcs" ]; then
    # Check for C++11/14/17 flags from Makevars
    for src in $cc_srcs; do
      base=$(basename "$src")
      base_noext="${base%.*}"
      echo "  CXX $base"
      if ! $CXX -I"$R_INC" -I"$src_dir" $LINKING_INCLUDES --sysroot="$SYSROOT" -fPIC -O2 -g0 $CXX_STD $PKG_CPPFLAGS $PKG_CXXFLAGS -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        err=$(grep "fatal error" "$compile_log" | head -1)
        echo "  FAILED: $base -> $err"
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
        err=$(grep "fatal error\|cannot execute" "$compile_log" | head -1)
        echo "  FAILED: $base -> $err"
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
          # Try finding it elsewhere
          obj_path=$(find "$src_dir" -name "$obj" 2>/dev/null | head -1)
        fi
        all_objs="$all_objs $obj_path"
      done
    fi

    echo "  LD $pkgname.so"
    mkdir -p "$libs_dir"
    if ! $CC -shared -fPIC -o "$libs_dir/$pkgname.so" $all_objs \
        -L"$R_LIB" -lR $PKG_LIBS --sysroot="$SYSROOT" -Wl,--allow-multiple-definition \
        -L"$R_LIB" -lmuslstubs >> "$compile_log" 2>&1; then
      echo "  LINK FAILED"
      err=$(grep -E "error:|undefined reference" "$compile_log" | head -3)
      echo "  $err"
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "  OK ($so_size)"
    echo "$pkgname: OK ($so_size)" >> "$LOG_DIR/success.log"

    # Run makeLazyLoading if rdb doesn't exist
    rdb_file="$pkg_path/R/$pkgname.rdb"
    if [ ! -f "$rdb_file" ]; then
      r_concat="$pkg_path/R/$pkgname"
      if [ ! -f "$r_concat" ]; then
        r_files=$(ls "$pkg_path/R/"*.R 2>/dev/null)
        if [ -n "$r_files" ]; then
          for f in $r_files; do cat "$f"; done > "$r_concat"
        fi
      fi
      if [ -f "$r_concat" ]; then
        echo "  Running makeLazyLoading..."
        export TMPDIR="${TMPDIR:-$DIR/tmp}"
        export R_HOME_DIR="$DIR"
        export R_HOME="$DIR"
        export LD_LIBRARY_PATH="$DIR/lib"
        "$DIR/bin/exec/R" --vanilla --no-save --no-restore -e \
          "library(tools); tools:::makeLazyLoading(\"$pkgname\", lib.loc = \"/storage/Users/currentUser/R-harmonyos/build/library\", compress = FALSE)" \
          >> "$compile_log" 2>&1 || true
      fi
    fi

    compiled=$((compiled + 1))
  else
    echo "  FAILED"
    err_short=$(grep -E "fatal error:|error:|required|not found" "$compile_log" | head -3 | tr '\n' '; ')
    echo "  Error: $err_short"
    echo "$pkgname: $err_short" >> "$LOG_DIR/fail_summary.log"
    failed=$((failed + 1))
  fi

  echo "$pkgname" > "$LOG_DIR/last_pkg.txt"
done

echo ""
echo "========================================"
echo "Batch compilation finished at $(date)"
echo "Compiled: $compiled"
echo "Failed: $failed"
echo "Skipped (already had .so): $skipped"
echo "Total processed: $processed"
echo "Success log: $LOG_DIR/success.log"
echo "Failure summary: $LOG_DIR/fail_summary.log"
