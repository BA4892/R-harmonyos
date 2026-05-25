#!/data/service/hnp/bin/bash
# Batch fix v3: Targeted fixes for remaining 115 packages
# Handles: Makevars generation, config.h generation, C++ standard workarounds

DIR="/storage/Users/currentUser/R-harmonyos/build"
CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
CXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
R_INC="$DIR/include"
R_LIB="$DIR/lib"
EXT_LIB="/storage/Users/currentUser/.local/R-deps"
BREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
BREW_INC="$BREW_PREFIX/include"
BREW_LD="$BREW_PREFIX/lib"
HOMEBREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
EXT_INC="$EXT_LIB/include"
EXT_LD="$EXT_LIB/lib"

LOG_DIR="$DIR/../compile-logs"
mkdir -p "$LOG_DIR"

# External lib subdirectories for include paths
EXT_INC_DIRS=""
for d in "$EXT_INC"/*/; do
  EXT_INC_DIRS="$EXT_INC_DIRS -I$d"
done
# Also add specific well-known subdirs that have headers at the root
for d in "$EXT_INC"/freetype2; do
  [ -d "$d" ] && EXT_INC_DIRS="$EXT_INC_DIRS -I$d"
done

# Common compilation flags
BASE_CFLAGS="-I$R_INC --sysroot=$SYSROOT -fPIC -O2 -g0 -L$R_LIB -L$EXT_LD -L$BREW_LD"
BASE_CXXFLAGS="$BASE_CFLAGS"

# Per-package compilation settings
# Format: "PKGNAME:EXTRA_CFLAGS:EXTRA_CXXFLAGS:EXTRA_LIBS:CXX_STD:DEFINES"
# DEFINES are -D flags added to both C and CXX

declare -A PKG_EXTRA_CFLAGS
declare -A PKG_EXTRA_CXXFLAGS
declare -A PKG_EXTRA_LIBS
declare -A PKG_CXX_STD
declare -A PKG_DEFINES
declare -A PKG_GENERATE_MAKEVARS
declare -A PKG_SPECIAL_ACTION

# ============================================================
# Package configurations
# ============================================================

# --- Quick Wins: packages needing ext libs we already have ---

# XML: needs libxml2
PKG_EXTRA_LIBS["XML"]="-lxml2 -llzma -lbz2 -lz"
PKG_GENERATE_MAKEVARS["XML"]="PKG_CPPFLAGS=-I$EXT_INC/libxml2"
PKG_EXTRA_CFLAGS["XML"]="-I$EXT_INC/libxml2"

# xml2: needs libxml2 + has const xmlError* workaround
PKG_EXTRA_LIBS["xml2"]="-lxml2 -llzma -lbz2 -lz"
PKG_EXTRA_CFLAGS["xml2"]="-I$EXT_INC/libxml2"
PKG_EXTRA_CXXFLAGS["xml2"]="-I$EXT_INC/libxml2"
# Hack: undefine error macro if it conflicts, and use correct API
PKG_DEFINES["xml2"]="-DR_NO_REMAP"

# Rmpfr: needs gmp
PKG_EXTRA_LIBS["Rmpfr"]="-lgmp"
PKG_GENERATE_MAKEVARS["Rmpfr"]="PKG_LIBS=-L$EXT_LD -lgmp"

# askpass: needs openssl
PKG_GENERATE_MAKEVARS["askpass"]="PKG_LIBS=-L$EXT_LD -lssl -lcrypto"

# ps: needs config.h + libprocps (not available, but can work with stubs)
PKG_GENERATE_MAKEVARS["ps"]="PKG_CPPFLAGS=-DHAVE_CONFIG_H PKG_LIBS="
# Generate config.h for ps

# jsonlite: self-contained, needs -Iyajl/api
PKG_GENERATE_MAKEVARS["jsonlite"]="PKG_CPPFLAGS=-Iyajl/api PKG_CFLAGS= PKG_LIBS=-Lyajl -lstatyajl"

# commonmark: self-contained with bundled cmark-gfm
PKG_GENERATE_MAKEVARS["commonmark"]="PKG_LIBS="
# The syntax_extension.h is in extensions/ subdir
PKG_EXTRA_CFLAGS["commonmark"]="-I$DIR/library/commonmark/src"

# RJSONIO: self-contained with bundled libjson
PKG_GENERATE_MAKEVARS["RJSONIO"]="PKG_CPPFLAGS=-I. PKG_CXXFLAGS= PKG_LIBS="
# Need to set include path to find JSONAllocator.h and libjson headers
PKG_EXTRA_CFLAGS["RJSONIO"]="-I$DIR/library/RJSONIO/src -I$DIR/library/RJSONIO/src/libjson"
PKG_EXTRA_CXXFLAGS["RJSONIO"]="-I$DIR/library/RJSONIO/src -I$DIR/library/RJSONIO/src/libjson"
PKG_SPECIAL_ACTION["RJSONIO"]="fix_rjsonio"

# Cairo: needs cairo libs + cconfig.h
PKG_EXTRA_LIBS["Cairo"]="-lcairo -lpixman-1 -lpng -lfreetype -lz"
PKG_EXTRA_CFLAGS["Cairo"]="-I$EXT_INC/cairo -I$EXT_INC/pixman-1"
PKG_SPECIAL_ACTION["Cairo"]="fix_cairo"

# --- Rcpp/RcppArmadillo only ---

# Rfast: RcppArmadillo + RcppEigen, needs C++14
PKG_CXX_STD["Rfast"]="c++14"
PKG_DEFINES["Rfast"]="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"

# Rsolnp: Rcpp
PKG_CXX_STD["Rsolnp"]="c++11"

# BayesFM: RcppArmadillo
PKG_CXX_STD["BayesFM"]="c++14"
PKG_DEFINES["BayesFM"]="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"

# MCMCpack: RcppArmadillo
PKG_CXX_STD["MCMCpack"]="c++14"
PKG_DEFINES["MCMCpack"]="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"

# fastglm: RcppArmadillo + RcppEigen
PKG_CXX_STD["fastglm"]="c++14"
PKG_DEFINES["fastglm"]="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"

# frailtypack: Rcpp
PKG_CXX_STD["frailtypack"]="c++11"

# lqmm: Rcpp
PKG_CXX_STD["lqmm"]="c++11"

# colourvalues: Rcpp
PKG_CXX_STD["colourvalues"]="c++11"

# haven: Rcpp
PKG_CXX_STD["haven"]="c++11"

# ggforce: Rcpp, needs C++14 for std::make_unique
PKG_CXX_STD["ggforce"]="c++14"

# parsermd: Rcpp + BH (Boost), needs C++14 for Spirit X3
PKG_CXX_STD["parsermd"]="c++14"

# geosphere: Rcpp, needs C++17 for hypot(x,y,z)
PKG_CXX_STD["geosphere"]="c++17"

# microbenchmark: Rcpp, OS timer issue
PKG_CXX_STD["microbenchmark"]="c++11"
PKG_DEFINES["microbenchmark"]="-DMB_HAVE_CLOCK_GETTIME -DMB_CLOCKID_T=CLOCK_MONOTONIC -D_POSIX_C_SOURCE=200112L"

# polyclip: needs POLYCLIP_LONG64 defined
PKG_CXX_STD["polyclip"]="c++11"
PKG_DEFINES["polyclip"]="-DPOLYCLIP_LONG64=int64_t -DPOLYCLIP_ULONG64=uint64_t"

# ============================================================
# Per-package special action functions
# ============================================================

fix_cairo() {
  local pkg_path="$1"
  local src_dir="$pkg_path/src"
  # Cairo needs cconfig.h generated by configure
  if [ ! -f "$src_dir/cconfig.h" ]; then
    cat > "$src_dir/cconfig.h" << 'EOF'
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
#define CAIRO_HAS_OBSERVER_SURFACE 1
#define CAIRO_HAS_XML_SURFACE 1
#define PANGO_HAS_CAIRO 1
#define PANGO_HAS_FT2 1
#endif
EOF
    echo "  (generated cconfig.h for Cairo)"
  fi
}

fix_rjsonio() {
  local pkg_path="$1"
  local src_dir="$pkg_path/src"
  # RJSONIO has a complex include structure with bundled libjson
  # Create a Makevars file if it doesn't exist
  if [ ! -f "$src_dir/Makevars" ]; then
    cat > "$src_dir/Makevars" << 'EOF'
PKG_CPPFLAGS=-I. -Ilibjson
PKG_CXXFLAGS=
PKG_LIBS=
EOF
    echo "  (generated Makevars for RJSONIO)"
  fi
}

generate_config_h() {
  local pkgname="$1"
  local src_dir="$2"
  case "$pkgname" in
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
        echo "  (generated config.h for $pkgname)"
      fi
      ;;
    commonmark)
      # Generate syntax_extension.h stub if needed
      if [ ! -f "$src_dir/syntax_extension.h" ]; then
        cat > "$src_dir/syntax_extension.h" << 'CMARKEOF'
/* Auto-generated stub: cmark-gfm syntax extension support */
#ifndef SYNTAX_EXTENSION_H
#define SYNTAX_EXTENSION_H
#include "extensions/cmark-gfm-core-extensions.h"
#endif
CMARKEOF
        echo "  (generated syntax_extension.h for commonmark)"
      fi
      ;;
  esac
}

# ============================================================
# Compilation function for a single package
# ============================================================

compile_package() {
  local pkgname="$1"
  local pkg_path="$DIR/library/$pkgname"
  local src_dir="$pkg_path/src"
  local libs_dir="$pkg_path/libs"

  # Skip if .so already exists
  if [ -f "$libs_dir/$pkgname.so" ]; then
    echo "  SKIP (already has .so)"
    return 2
  fi

  # Check source files
  local c_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.c" \) 2>/dev/null | sort)
  local cc_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort)
  local f_srcs=$(find "$src_dir" -maxdepth 1 \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort)

  if [ -z "$c_srcs" ] && [ -z "$cc_srcs" ] && [ -z "$f_srcs" ]; then
    echo "  SKIP (no source files at src/ level)"
    return 2
  fi

  # Generate config.h if needed
  generate_config_h "$pkgname" "$src_dir"

  # Run special action if defined
  local action="${PKG_SPECIAL_ACTION[$pkgname]}"
  if [ -n "$action" ]; then
    $action "$pkg_path"
  fi

  # Generate Makevars if configured
  local mv_content="${PKG_GENERATE_MAKEVARS[$pkgname]}"
  if [ -n "$mv_content" ] && [ ! -f "$src_dir/Makevars" ]; then
    echo "$mv_content" > "$src_dir/Makevars"
    echo "  (generated Makevars)"
  fi

  # Parse Makevars if it exists
  local PKG_CPPFLAGS=""; local PKG_CFLAGS=""; local PKG_CXXFLAGS=""
  local PKG_FFLAGS=""; local PKG_FCFLAGS=""; local PKG_LIBS=""; local OBJECTS=""
  if [ -f "$src_dir/Makevars" ]; then
    local joined_vars=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$src_dir/Makevars" 2>/dev/null || cat "$src_dir/Makevars")
    while IFS= read -r line; do
      case "$line" in
        .PHONY:*|all:*|\$*|include*) continue ;;
      esac
      line=$(echo "$line" | sed 's/^\([A-Z_0-9]*\)[[:space:]]*=[[:space:]]*/\1=/')
      case "$line" in
        PKG_CPPFLAGS=*) PKG_CPPFLAGS="${line#*=}" ;;
        PKG_CFLAGS=*)   PKG_CFLAGS="${line#*=}" ;;
        PKG_CXXFLAGS=*) PKG_CXXFLAGS="${line#*=}" ;;
        PKG_FFLAGS=*)   PKG_FFLAGS="${line#*=}" ;;
        PKG_FCFLAGS=*)  PKG_FCFLAGS="${line#*=}" ;;
        PKG_LIBS=*)     PKG_LIBS="${line#*=}" ;;
        OBJECTS=*)      OBJECTS="${line#*=}" ;;
        OBJS=*)         OBJECTS="${line#*=}" ;;
      esac
    done <<< "$joined_vars"
    # Strip backtick expressions
    PKG_CPPFLAGS=$(echo "$PKG_CPPFLAGS" | sed 's/`[^`]*`//g')
    PKG_CFLAGS=$(echo "$PKG_CFLAGS" | sed 's/`[^`]*`//g')
    PKG_CXXFLAGS=$(echo "$PKG_CXXFLAGS" | sed 's/`[^`]*`//g')
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/`[^`]*`//g')
  fi

  # Resolve relative -I and -L paths
  local result_pkg_cflags=""
  for flag in $PKG_CFLAGS; do
    case "$flag" in -I../*|-I./*|-I[a-zA-Z]*) flag="-I$src_dir/${flag#-I}" ;; esac
    result_pkg_cflags="$result_pkg_cflags $flag"
  done
  PKG_CFLAGS="$result_pkg_cflags"

  local result_pkg_cxxflags=""
  for flag in $PKG_CXXFLAGS; do
    case "$flag" in -I../*|-I./*|-I[a-zA-Z]*) flag="-I$src_dir/${flag#-I}" ;; esac
    result_pkg_cxxflags="$result_pkg_cxxflags $flag"
  done
  PKG_CXXFLAGS="$result_pkg_cxxflags"

  local result_pkg_ppflags=""
  for flag in $PKG_CPPFLAGS; do
    case "$flag" in -I../*|-I./*|-I[a-zA-Z]*) flag="-I$src_dir/${flag#-I}" ;; esac
    result_pkg_ppflags="$result_pkg_ppflags $flag"
  done
  PKG_CPPFLAGS="$result_pkg_ppflags"

  # LinkingTo handling
  local LINKING_TO=$(awk 'BEGIN{found=0}
    /^LinkingTo:/{found=1; sub(/^LinkingTo:[[:space:]]*/,""); line=$0; next}
    found{if(/^[^[:space:]]/) exit; line=line" "$0}
    END{print line}' "$pkg_path/DESCRIPTION" 2>/dev/null | \
    sed 's/([^)]*)//g' | tr ',' ' ' | tr -s ' ')
  local LINKING_INCLUDES=""
  if [ -n "$LINKING_TO" ]; then
    for lpkg in $LINKING_TO; do
      lpkg=$(echo "$lpkg" | xargs)
      [ -z "$lpkg" ] && continue
      for try_path in "$DIR/library/$lpkg/inst/include" "$DIR/library/$lpkg/include"; do
        if [ -d "$try_path" ]; then
          LINKING_INCLUDES="$LINKING_INCLUDES -I$try_path"
          break
        fi
      done
    done
  fi

  # Self-include path
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    if [ -d "$self_path" ]; then
      LINKING_INCLUDES="$LINKING_INCLUDES -I$self_path"
      break
    fi
  done

  # RcppArmadillo config generation
  if [ -f "$DIR/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h.in" ]; then
    local gen_h="$DIR/library/RcppArmadillo/inst/include/RcppArmadillo/config/RcppArmadilloConfigGenerated.h"
    if [ ! -f "$gen_h" ]; then
      cat > "$gen_h" << 'ARMADEOF'
// Auto-generated by batch-fix-v3.sh
#ifndef RcppArmadilloConfigGenerated_H
#define RcppArmadilloConfigGenerated_H
#define ARMA_USE_OPENMP 0
#endif
ARMADEOF
    fi
  fi

  # Compose flags
  local cxx_std="${PKG_CXX_STD[$pkgname]:-c++11}"
  local defines="${PKG_DEFINES[$pkgname]:-}"
  local ext_cflags="${PKG_EXTRA_CFLAGS[$pkgname]:-} $defines"
  local ext_cxxflags="${PKG_EXTRA_CXXFLAGS[$pkgname]:-} $defines"
  local ext_libs="${PKG_EXTRA_LIBS[$pkgname]:-}"

  local compile_flags="-I$R_INC -I$src_dir $LINKING_INCLUDES $EXT_INC_DIRS --sysroot=$SYSROOT -fPIC -O2 -g0"
  local link_flags="-shared -fPIC -L$R_LIB -lR -L$EXT_LD $ext_libs --sysroot=$SYSROOT -Wl,--allow-multiple-definition -lmuslstubs"

  local compile_log="$LOG_DIR/${pkgname}-v3.log"
  local BUILD_TMP=$(mktemp -p "$DIR/../tmp" 2>/dev/null || mktemp -p /data/local/tmp 2>/dev/null || mktemp -p /tmp)
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  local all_objs=""
  local compile_ok=true

  # Compile C sources
  for src in $c_srcs; do
    local base=$(basename "$src")
    local base_noext="${base%.*}"
    echo "    CC $base"
    if ! $CC $compile_flags $PKG_CPPFLAGS $PKG_CFLAGS $ext_cflags -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      echo "    FAILED: $base"
      tail -3 "$compile_log"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # Compile C++ sources
  if $compile_ok && [ -n "$cc_srcs" ]; then
    for src in $cc_srcs; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "    CXX $base (-std=$cxx_std)"
      if ! $CXX -std=$cxx_std $compile_flags $PKG_CPPFLAGS $PKG_CXXFLAGS $ext_cxxflags -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "    FAILED: $base"
        tail -3 "$compile_log"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Link
  if $compile_ok; then
    echo "    LD $pkgname.so"
    mkdir -p "$libs_dir"
    if ! $CC $link_flags -o "$libs_dir/$pkgname.so" $all_objs $PKG_LIBS >> "$compile_log" 2>&1; then
      echo "    LINK FAILED"
      tail -5 "$compile_log"
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    local so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "    OK ($so_size)"
  fi

  $compile_ok && return 0 || return 1
}

# ============================================================
# Main: compile target packages
# ============================================================

TARGETS=(
  # Quick wins - already have ext libs
  XML xml2 Rmpfr askpass ps jsonlite commonmark RJSONIO Cairo
  # Rcpp/RcppArmadillo dependent
  Rfast Rsolnp BayesFM MCMCpack fastglm frailtypack lqmm colourvalues haven
  ggforce parsermd geosphere microbenchmark polyclip
)

compiled=0
failed=0
skipped=0

echo "============================================"
echo "  batch-fix-v3: Targeted .so compilation"
echo "  Targets: ${#TARGETS[@]} packages"
echo "============================================"
echo ""

for pkgname in "${TARGETS[@]}"; do
  echo "=== $pkgname ==="
  compile_package "$pkgname"
  rc=$?
  case $rc in
    0) compiled=$((compiled+1)) ;;
    1) failed=$((failed+1)) ;;
    2) skipped=$((skipped+1)) ;;
  esac
done

echo ""
echo "============================================"
echo "  Results:"
echo "  Compiled: $compiled"
echo "  Failed: $failed"
echo "  Skipped: $skipped"
echo "============================================"
