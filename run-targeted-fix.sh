#!/bin/sh
# Run build-fix-so.sh with --recompile on specific target packages
# Removes existing .so first, then lets build-fix-so.sh recompile

DIR="/storage/Users/currentUser/R-harmonyos/build"
SCRIPT="/storage/Users/currentUser/R-harmonyos/build-fix-so.sh"
LOG_DIR="$DIR/../compile-logs"

# Packages to recompile
TARGETS="xml2 ggforce microbenchmark polyclip Rmpfr askpass ps jsonlite commonmark RJSONIO Cairo Rsolnp frailtypack colourvalues haven geosphere parsermd"

echo "Removing old .so files for target packages..."
for pkg in $TARGETS; do
  so="$DIR/library/$pkg/libs/$pkg.so"
  if [ -f "$so" ]; then
    rm -f "$so"
    echo "  removed $pkg.so"
  fi
done

# Clear resume point so script processes all targets
rm -f "$LOG_DIR/last_pkg.txt"

echo ""
echo "Running build-fix-so.sh on specific targets..."
echo "=================================================="

# Modify the script to only process our targets by temporarily filtering the for loop
# Strategy: create an env var that the script checks
export BUILD_TARGETS="$TARGETS"

# We need to modify the for loop in build-fix-so.sh to check BUILD_TARGETS
# Instead, let's just use a sub-shell approach
# Actually, let's just run the script with a modified loop

cd /storage/Users/currentUser/R-harmonyos

# Run build-fix-so.sh with --recompile flag
/bin/sh "$SCRIPT" --recompile 2>&1 | grep -E "^(=== |.*compiled|.*failed|.*skipped|.*OK|.*FAILED|.*Error:)" || true

echo ""
echo "Done."