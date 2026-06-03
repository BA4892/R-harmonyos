#!/bin/sh
# Patch Rcpp's undoRmath.h to add #undef log1p
#
# Rmath.h defines "#define log1p Rlog1p", which conflicts with C++
# std::log1p used by Armadillo headers. Rcpp's undoRmath.h (included
# right after Rmath.h) undefines all the other Rmath macros but
# omits log1p. This script adds the missing #undef.
#
# Run this AFTER Rcpp is installed or reinstalled:
#   bash versions/4.6.0/patch-rcpp.sh
#
# R_HOME and R_LIB can be overridden to match your setup:
#   R_LIB=/path/to/library bash versions/4.6.0/patch-rcpp.sh

set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
R_SRC="$HERE/../../src/R-4.6.0"
R_LIB="${R_LIB:-$HERE/../../build/library}"
TARGET="$R_LIB/Rcpp/include/Rcpp/sugar/undoRmath.h"

if [ ! -f "$TARGET" ]; then
    echo "Error: $TARGET not found."
    echo "Rcpp may not be installed yet, or R_LIB is wrong."
    echo "Current R_LIB=$R_LIB"
    exit 1
fi

if grep -q '^#undef log1p$' "$TARGET" 2>/dev/null; then
    echo "undoRmath.h already patched (log1p undef found)"
    exit 0
fi

# Add #undef log1p before #undef log1pmx
sed -i '/^#undef log1pmx$/i #undef log1p' "$TARGET"
echo "Patched $TARGET: added #undef log1p"
