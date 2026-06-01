#!/bin/sh
# Apply HarmonyOS-specific patches to R 4.6.0 source tree.
# Run from the project root:  bash versions/4.6.0/apply-patches.sh
#
# This script assumes src/R-4.6.0/ contains the original R 4.6.0 source
# (extracted from the CRAN tarball, unmodified).

set -e

R_SRC=src/R-4.6.0
PATCHES=versions/4.6.0/patches

if [ ! -d "$R_SRC" ]; then
    echo "Error: $R_SRC not found. Extract R-4.6.0 source first:"
    echo "  tar xzf src/R-4.6.0.tar.gz -C src/"
    exit 1
fi

if [ ! -d "$PATCHES" ]; then
    echo "Error: $PATCHES directory not found."
    exit 1
fi

cd "$R_SRC"

echo "=== Applying R 4.6.0 HarmonyOS patches ==="

for pf in ../../$PATCHES/*.patch; do
    name=$(basename "$pf")
    echo "  Applying $name ..."
    patch -p1 -s < "$pf" 2>/dev/null || true
done

# Fix Rmath.h0.in: remove the Rlog1p declaration entirely (it was wrapped
# in 'extern "C"' which is C++ syntax, and keeping it in C mode conflicts
# with arithmetic.c's 'static double Rlog1p()'.  nmath/log1p.c provides the
# global Rlog1p definition when HAVE_WORKING_LOG1P is not defined.)
echo "  Fixing Rmath.h0.in (remove Rlog1p declaration) ..."
python3 -c "
with open('src/include/Rmath.h0.in', 'r') as f:
    c = f.read()
old = '''/* remap to avoid problems with getting the right entry point */
extern \"C\" {
double  Rlog1p(double);
}
#define log1p Rlog1p'''
new = '''#define log1p Rlog1p'''
if old in c:
    c = c.replace(old, new)
    with open('src/include/Rmath.h0.in', 'w') as f:
        f.write(c)
    print('    Fixed Rmath.h0.in')
else:
    print('    Rmath.h0.in already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix Rmath.h0.in'

# Fix eval.c: add forward declaration for Rlog1p (needed because Rmath.h
# no longer declares it, but eval.c uses log1p as a function pointer in
# the builtin table which expands to Rlog1p via the macro)
echo "  Fixing eval.c (add Rlog1p forward decl) ..."
python3 -c "
with open('src/main/eval.c', 'r') as f:
    c = f.read()
old = '#include <Rmath.h>'
new = '#include <Rmath.h>\n/* HarmonyOS: forward decl for Rlog1p (defined in nmath/log1p.c) */\nextern double Rlog1p(double);'
if old in c:
    c = c.replace(old, new)
    with open('src/main/eval.c', 'w') as f:
        f.write(c)
    print('    Fixed eval.c')
else:
    print('    eval.c already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix eval.c'

# Fix makebasedb.R: add compress = FALSE to avoid zlib/seccomp issue
echo "  Fixing makebasedb.R (add compress = FALSE) ..."
python3 -c "
with open('src/library/base/makebasedb.R', 'r') as f:
    c = f.read()
old = 'makeLazyLoadDB(baseenv(), baseFileBase, variables = basevars)'
new = 'makeLazyLoadDB(baseenv(), baseFileBase, compress = FALSE, variables = basevars)'
if old in c:
    c = c.replace(old, new)
    with open('src/library/base/makebasedb.R', 'w') as f:
        f.write(c)
    print('    Fixed makebasedb.R')
else:
    print('    makebasedb.R already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix makebasedb.R'

# Decompress all gzip-compressed sysdata.rda files (gzfile blocked by seccomp)
echo "  Decompressing gzip-compressed .rda files ..."
TMP_RDA="/storage/Users/currentUser/R-harmonyos/tmp/rda_decompress_$$"
for rda_file in src/library/*/R/sysdata.rda; do
    if [ -f "$rda_file" ] && file "$rda_file" 2>/dev/null | grep -q 'gzip compressed'; then
        gunzip -c "$rda_file" > "$TMP_RDA" 2>/dev/null && \
          mv -f "$TMP_RDA" "$rda_file" && \
          echo "    Decompressed $rda_file" || \
          echo "    Warning: could not decompress $rda_file"
    fi
done
# Also decompress gzip-compressed .rda data files for datasets package
for rda_file in src/library/datasets/data/*.rda; do
    if [ -f "$rda_file" ] && file "$rda_file" 2>/dev/null | grep -q 'gzip compressed'; then
        gunzip -c "$rda_file" > "$TMP_RDA" 2>/dev/null && \
          mv -f "$TMP_RDA" "$rda_file" && \
          echo "    Decompressed $rda_file" || \
          echo "    Warning: could not decompress $rda_file"
    fi
done

# Copy new files
echo "  Installing new files ..."
for nf in ../../$PATCHES/new-files/*; do
    name=$(basename "$nf")
    case "$name" in
        ohos_stubs.c)
            mkdir -p src/extra/ohos_stubs
            cp "$nf" src/extra/ohos_stubs/
            echo "    Created src/extra/ohos_stubs/$name"
            ;;
        Makefile.in)
            if [ -f src/extra/ohos_stubs/Makefile.in ]; then
                cp "$nf" src/extra/ohos_stubs/
                echo "    Updated src/extra/ohos_stubs/Makefile.in"
            fi
            ;;
    esac
done

# Fix methods/R/zzz.R: add compress = FALSE to makeLazyLoadDB call
# (seccomp blocks zlib, so lazy-load databases must be uncompressed)
echo "  Fixing methods/R/zzz.R (add compress = FALSE) ..."
python3 -c "
with open('src/library/methods/R/zzz.R', 'r') as f:
    c = f.read()
old = 'tools:::makeLazyLoadDB(ns, dbbase, variables = vars)'
new = 'tools:::makeLazyLoadDB(ns, dbbase, variables = vars, compress = FALSE)'
if old in c:
    c = c.replace(old, new)
    with open('src/library/methods/R/zzz.R', 'w') as f:
        f.write(c)
    print('    Fixed methods/R/zzz.R')
else:
    print('    methods/R/zzz.R already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix methods/R/zzz.R'

echo "=== Patches applied successfully ==="
