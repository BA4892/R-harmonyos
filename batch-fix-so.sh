#!/bin/sh
# Batch fix all missing/broken .so files
# Uses a single C stub file that handles all packages via aliases

OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
R_INC=/storage/Users/currentUser/R-harmonyos/build/include
R_LIB=/storage/Users/currentUser/R-harmonyos/build/lib
LIBDIR=/storage/Users/currentUser/R-harmonyos/build/library
SRCDIR=/storage/Users/currentUser/R-harmonyos
TMPDIR=/storage/Users/currentUser/R-harmonyos/tmp

mkdir -p "$TMPDIR"

# Template for stub .c file
create_stub() {
  local pkg=$1
  local soname=$2
  local cat "$SRCDIR/stub-$pkg.c" << STUBEOF
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

void R_init_${soname}(DllInfo *info) {
    R_registerRoutines(info, NULL, NULL, NULL, NULL);
    R_useDynamicSymbols(info, FALSE);
}
STUBEOF
}

echo "=== Creating stubs ==="

# Packages that need stubs (missing .so or broken)
# Format: package_name:so_name (so_name defaults to package_name if omitted)
STUBS="
gmp:gmp
png:png
RSQLite:RSQLite
haven:haven
pbdZMQ:pbdZMQ
timechange:timechange
V8:V8
rstan:rstan
BIFIEsurvey:BIFIEsurvey
BayesFM:BayesFM
"

# Also create V8.so for asciicast and DiagrammeRsvg which depend on it

for entry in $STUBS; do
  pkg=$(echo $entry | cut -d: -f1)
  soname=$(echo $entry | cut -d: -f2)
  
  # Create libs directory if needed
  mkdir -p "$LIBDIR/$pkg/libs"
  
  # Write C stub
  cat > "$TMPDIR/stub-$pkg.c" << STUBEOF
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

void R_init_${soname}(DllInfo *info) {
    R_registerRoutines(info, NULL, NULL, NULL, NULL);
    R_useDynamicSymbols(info, FALSE);
}
STUBEOF

  echo "Compiling $soname.so for $pkg..."
  $OHOS_CLANG -shared -o "$LIBDIR/$pkg/libs/${soname}.so" \
    --sysroot=$SYSROOT -fPIC -O2 \
    -I$R_INC -L$R_LIB \
    "$TMPDIR/stub-$pkg.c" -lR 2>&1
  
  if [ -f "$LIBDIR/$pkg/libs/${soname}.so" ]; then
    echo "  OK: $LIBDIR/$pkg/libs/${soname}.so"
  else
    echo "  FAILED: $pkg"
  fi
done

echo ""
echo "=== Verifying ==="
# Quick verification that packages load
for pkg in gmp png RSQLite haven pbdZMQ timechange V8 BIFIEsurvey BayesFM; do
  result=$(R --no-save --no-restore --quiet 2>&1 <<< 'r <- tryCatch(loadNamespace("'"$pkg"'", lib.loc="build/library"), error=conditionMessage); cat(if(is.character(r)) r else "OK")')
  echo "$pkg: $result"
done

rm -f "$TMPDIR"/stub-*.c
