#!/data/service/hnp/bin/bash
# batch-fix-v4.sh: Targeted compilation for fixable R packages
# Only targets packages that can succeed with available external libraries.

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

# Base compilation flags
BASE_INC=(
  -I"$R_INC"
  --sysroot="$SYSROOT"
  -fPIC -O2 -g0
)

# Add EXT_INC subdirs
EXT_INC_DIRS=(-I"$EXT_INC")
for d in "$EXT_INC"/*/; do
  [ -d "$d" ] && EXT_INC_DIRS+=(-I"$d")
done

BASE_LINK=(
  -shared -fPIC
  -L"$R_LIB" -lR
  -L"$EXT_LD"
  --sysroot="$SYSROOT"
  -Wl,--allow-multiple-definition
  -lmuslstubs
)

# Resolve LinkingTo includes
linking_includes() {
  local pkg_path="$1"
  local pkgname=$(basename "$pkg_path")
  local result=()
  # Extract LinkingTo from DESCRIPTION
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
  # Self-include
  for self_path in "$pkg_path/inst/include" "$pkg_path/include"; do
    if [ -d "$self_path" ]; then
      result+=(-I"$self_path")
      break
    fi
  done
  echo "${result[@]}"
}

# Generate config.h for packages that need it
generate_config() {
  local pkgname="$1"
  local src_dir="$2"
  case "$pkgname" in
    RNetCDF|RODBC|RhpcBLASctl|ps|igraph|fftw)
      [ -f "$src_dir/config.h" ] && return
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
      ;;
    Cairo)
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
      echo "    (generated cconfig.h)"
      ;;
  esac
}

# ============================================================
# Package-specific build configurations
# ============================================================

compile_package() {
  local pkgname="$1"
  local pkg_path="$DIR/library/$pkgname"
  local src_dir="$pkg_path/src"
  local libs_dir="$pkg_path/libs"
  local compile_log="$LOG_DIR/${pkgname}-v4.log"

  # Skip if .so already exists
  [ -f "$libs_dir/$pkgname.so" ] && echo "  SKIP (exists)" && return 2

  echo "=== $pkgname ==="

  generate_config "$pkgname" "$src_dir"

  # Assemble include paths
  local LINK_INC=($(linking_includes "$pkg_path"))
  local CFLAGS=("${BASE_INC[@]}" -I"$src_dir" "${LINK_INC[@]}" "${EXT_INC_DIRS[@]}")
  local LIBS=("${BASE_LINK[@]}")

  # Compile sources
  local BUILD_TMP=$(mktemp -p "$DIR/../tmp")
  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  local all_objs=""
  local compile_ok=true
  local CXX_STD="c++11"
  local C_DEFINES=""
  local CXX_DEFINES=""
  local EXTRA_CXXFLAGS=""
  local EXTRA_CFLAGS=""
  local EXTRA_LIBS=""
  local LINK_INC_ONLY=false

  # ========== Package-specific configuration ==========
  case "$pkgname" in
    Cairo)
      CXX_STD="c++11"
      EXTRA_LIBS="-lcairo -lpixman-1 -lpng -lfreetype -lz"
      ;;
    XML)
      EXTRA_CFLAGS="-I$EXT_INC/libxml2"
      EXTRA_LIBS="-lxml2 -llzma -lbz2 -lz"
      ;;
    Rmpfr)
      EXTRA_LIBS="-lgmp"
      ;;
    askpass)
      EXTRA_LIBS="-lssl -lcrypto"
      ;;
    ps|igraph)
      # Just need config.h which is generated above
      ;;
    jsonlite)
      EXTRA_CFLAGS="-Iyajl/api"
      EXTRA_LIBS="-Lyajl -lstatyajl"
      ;;
    commonmark)
      # bundled cmark-gfm
      EXTRA_CFLAGS="-I$src_dir"
      ;;
    RJSONIO)
      EXTRA_CFLAGS="-I$src_dir -I$src_dir/libjson"
      EXTRA_CXXFLAGS="-I$src_dir -I$src_dir/libjson"
      ;;
    brotli)
      # Has static library in enc/ subdir
      EXTRA_LIBS="-L$src_dir/enc -lstatbrotli"
      C_DEFINES="-DBROTLI_BUILD_PORTABLE"
      EXTRA_CFLAGS="-I$src_dir/include -include config.h"
      ;;
    Rfast)
      CXX_STD="c++17"
      CXX_DEFINES="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"
      EXTRA_LIBS="-llapack -lblas -lgfortran -lgcc_s -fopenmp"
      EXTRA_CXXFLAGS="-fopenmp -DARMA_USE_CURRENT"
      ;;
    geosphere)
      CXX_STD="c++17"
      ;;
    fastglm)
      CXX_STD="c++14"
      CXX_DEFINES="-DHAVE_WORKING_LOG1P -DR_NO_REMAP"
      ;;
    ggforce)
      CXX_STD="c++14"
      ;;
    parsermd)
      CXX_STD="c++14"
      ;;
    frailtypack|lqmm|colourvalues|haven)
      CXX_STD="c++11"
      ;;
    nanonext)
      EXTRA_LIBS="-lssl -lcrypto -lcurl"
      ;;
    fs)
      CXX_STD="c++17"
      ;;
  esac

  # Parse Makevars for PKG_CPPFLAGS, PKG_CFLAGS, etc.
  local PKG_CPPFLAGS="" PKG_CFLAGS="" PKG_CXXFLAGS="" PKG_LIBS=""
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
      esac
    done <<< "$joined_vars"
    # Strip backtick expressions
    PKG_CPPFLAGS=$(echo "$PKG_CPPFLAGS" | sed 's/`[^`]*`//g')
    PKG_CFLAGS=$(echo "$PKG_CFLAGS" | sed 's/`[^`]*`//g')
    PKG_CXXFLAGS=$(echo "$PKG_CXXFLAGS" | sed 's/`[^`]*`//g')
    PKG_LIBS=$(echo "$PKG_LIBS" | sed 's/`[^`]*`//g')
  fi

  # Find source files
  local c_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.c" \) 2>/dev/null | sort))
  local cc_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) 2>/dev/null | sort))
  local f_srcs=($(find "$src_dir" -maxdepth 1 \( -name "*.f" -o -name "*.f90" -o -name "*.F" -o -name "*.F90" \) 2>/dev/null | sort))

  # Compile C sources
  for src in "${c_srcs[@]}"; do
    local base=$(basename "$src")
    local base_noext="${base%.*}"
    echo "  CC $base"
    if ! $CC "${CFLAGS[@]}" $PKG_CPPFLAGS $PKG_CFLAGS $EXTRA_CFLAGS $C_DEFINES -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
      tail -2 "$compile_log"
      compile_ok=false; break
    fi
    all_objs="$all_objs $BUILD_TMP/$base_noext.o"
  done

  # Compile C++ sources
  if $compile_ok && [ ${#cc_srcs[@]} -gt 0 ]; then
    for src in "${cc_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "  CXX $base (-std=$CXX_STD)"
      if ! $CXX -std=$CXX_STD "${CFLAGS[@]}" $PKG_CPPFLAGS $PKG_CXXFLAGS $EXTRA_CXXFLAGS $CXX_DEFINES -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        tail -2 "$compile_log"
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Compile Fortran sources
  if $compile_ok && [ ${#f_srcs[@]} -gt 0 ] && [ -x "$FC" ]; then
    # Compile twice: first pass for module files, second pass for final objects
    local f_log="$compile_log.fortran"
    # First pass: generate .mod files (ignore errors from module deps)
    for src in "${f_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "  FC (pass1) $base"
      $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$f_log" 2>&1 || true
    done
    # Second pass: compile with module files available
    for src in "${f_srcs[@]}"; do
      local base=$(basename "$src")
      local base_noext="${base%.*}"
      echo "  FC (pass2) $base"
      if ! $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$base_noext.o" >> "$compile_log" 2>&1; then
        echo "    FAILED: $base"
        grep "Fatal Error" "$compile_log" | tail -1
        compile_ok=false; break
      fi
      all_objs="$all_objs $BUILD_TMP/$base_noext.o"
    done
  fi

  # Link
  if $compile_ok; then
    echo "  LD $pkgname.so"
    mkdir -p "$libs_dir"
    if ! $CC "${LIBS[@]}" -o "$libs_dir/$pkgname.so" $all_objs $PKG_LIBS $EXTRA_LIBS >> "$compile_log" 2>&1; then
      echo "    LINK FAILED"
      tail -3 "$compile_log"
      compile_ok=false
    fi
  fi

  rm -rf "$BUILD_TMP"

  if $compile_ok; then
    local so_size=$(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}')
    echo "  OK ($so_size)"
    echo "$pkgname: OK ($so_size)" >> "$LOG_DIR/success-v4.log"
    return 0
  else
    echo "  FAILED"
    echo "$pkgname: FAILED" >> "$LOG_DIR/fail-v4.log"
    return 1
  fi
}

# ============================================================
# Main
# ============================================================

TARGETS=(
  # Self-contained / bundled libs
  jsonlite commonmark RJSONIO brotli
  # Have all ext libs
  Cairo XML Rmpfr askpass
  # config.h fix
  RNetCDF RODBC ps igraph
  # Rcpp packages
  Rfast fastglm ggforce parsermd
  frailtypack lqmm colourvalues haven geosphere
)

compiled=0 failed=0 skipped=0

echo "============================================"
echo "  batch-fix-v4: Focused .so compilation"
echo "  Targets: ${#TARGETS[@]} packages"
echo "============================================"

for pkgname in "${TARGETS[@]}"; do
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
echo "  Results: $compiled OK, $failed FAILED, $skipped SKIPPED"
echo "============================================"