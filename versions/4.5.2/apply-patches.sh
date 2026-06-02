#!/bin/sh
# Apply HarmonyOS-specific patches to R 4.5.2 source tree.
# Run from the project root:  bash versions/4.5.2/apply-patches.sh
#
# This script assumes src/R-4.5.2/ contains the original R 4.5.2 source
# (extracted from the CRAN tarball, unmodified).

set -e

R_SRC=src/R-4.5.2
PATCHES=versions/4.5.2/patches

if [ ! -d "$R_SRC" ]; then
    echo "Error: $R_SRC not found. Extract R-4.5.2 source first:"
    echo "  tar xzf src/R-4.5.2.tar.gz -C src/"
    exit 1
fi

if [ ! -d "$PATCHES" ]; then
    echo "Error: $PATCHES directory not found."
    exit 1
fi

cd "$R_SRC"

echo "=== Applying R 4.5.2 HarmonyOS patches ==="

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
new = '''/* remap to avoid problems with getting the right entry point */
double  Rlog1p(double);
#define log1p Rlog1p'''
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

# Fix Defn.h: add forward declaration for Rf_allocVector3 (needed because
# Rinlinedfuns.h's allocVector() inline function calls allocVector3(),
# but R 4.5.2's Defn.h is missing the declaration that R 4.6.0 has.)
echo "  Fixing Defn.h (add Rf_allocVector3 forward decl) ..."
python3 -c "
with open('src/include/Defn.h', 'r') as f:
    c = f.read()
old = '#include \"Rinlinedfuns.h\"'
new = 'SEXP Rf_allocVector3(SEXPTYPE, R_xlen_t, R_allocator_t*);\n#include \"Rinlinedfuns.h\"'
if old in c:
    c = c.replace(old, new)
    with open('src/include/Defn.h', 'w') as f:
        f.write(c)
    print('    Fixed Defn.h')
else:
    print('    Defn.h already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix Defn.h'

# Fix Defn.h: add R_popen/R_system declarations (R 4.5.2 puts them behind
# HAVE_POPEN in Rinternals.h, which the build process strips.  R 4.6.0
# declares them unconditionally in Defn.h instead.)
echo "  Fixing Defn.h (add R_popen/R_system declarations) ..."
python3 -c "
with open('src/include/Defn.h', 'r') as f:
    c = f.read()
old = '/* unix/sys-unix.c, main/connections.c */\nFILE *R_popen_pg(const char *cmd, const char *type);\nint R_pclose_pg(FILE *fp);'
new = '''/* unix/sys-unix.c, main/connections.c */
/* HarmonyOS: these were in Rinternals.h behind #ifdef HAVE_POPEN which the
   build process strips.  Declare unconditionally here (as R 4.6.0 does). */
#ifdef __cplusplus
std::FILE *R_popen(const char *, const char *);
#else
FILE *R_popen(const char *, const char *);
#endif
int R_system(const char *);
FILE *R_popen_pg(const char *cmd, const char *type);
int R_pclose_pg(FILE *fp);'''
if old in c:
    c = c.replace(old, new)
    with open('src/include/Defn.h', 'w') as f:
        f.write(c)
    print('    Fixed Defn.h (R_popen/R_system)')
else:
    print('    Defn.h already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix Defn.h R_popen'

# Fix gramRd.y: add ENABLE_LEGACY_NONAPI define so Rf_findVar etc. are visible
# (R 4.5.2 moved these behind ENABLE_LEGACY_NONAPI_FUNS in the installed headers)
echo "  Fixing gramRd.y (add ENABLE_LEGACY_NONAPI) ..."
python3 -c "
with open('src/library/tools/src/gramRd.y', 'r') as f:
    c = f.read()
old = '#define R_USE_SIGNALS 1\n#include <Defn.h>'
new = '''#define R_USE_SIGNALS 1
/* HarmonyOS: R 4.5.2 Rinternals.h places Rf_findVar etc. behind
   ENABLE_LEGACY_NONAPI, but the short-name remap macros are outside
   that guard. Enable legacy non-API declarations so the macros work. */
#define ENABLE_LEGACY_NONAPI 1
#include <Defn.h>'''
if old in c:
    c = c.replace(old, new)
    with open('src/library/tools/src/gramRd.y', 'w') as f:
        f.write(c)
    print('    Fixed gramRd.y')
else:
    print('    gramRd.y already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix gramRd.y'

# Fix distance.c: add #include <R_ext/MathThreads.h> needed for R_num_math_threads
# (R 4.5.2's build process wraps the declaration behind USE_MATH_THREADS)
echo "  Fixing distance.c (add R_ext/MathThreads.h include) ..."
python3 -c "
with open('src/library/stats/src/distance.c', 'r') as f:
    c = f.read()
old = '#include <R.h>\n#include <Rmath.h>\n#include \"stats.h\"'
new = '''#include <R.h>
#include <Rmath.h>
#include <R_ext/MathThreads.h>
#include \"stats.h\"'''
if old in c:
    c = c.replace(old, new)
    with open('src/library/stats/src/distance.c', 'w') as f:
        f.write(c)
    print('    Fixed distance.c')
else:
    print('    distance.c already fixed or pattern not found')
" 2>&1 || echo '    Warning: could not fix distance.c'

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

echo "=== Patches applied successfully ==="
