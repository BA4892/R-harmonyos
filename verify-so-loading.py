#!/data/service/hnp/bin/python3
"""Verify that all .so files in R packages can be loaded with LD_PRELOAD."""
import ctypes
import os
import sys

# Numeric constants for systems where ctypes lacks RTLD_* attributes
RTLD_LAZY = 1
RTLD_LOCAL = 0
RTLD_NOLOAD = 0  # 0 means don't use noload on this system

BUILD_DIR = "/storage/Users/currentUser/R-harmonyos/build"
LIBRARY = os.path.join(BUILD_DIR, "library")
LD_PRELOAD_LIB = os.path.join(BUILD_DIR, "lib", "libc++_shared.so")

# Pre-load our LD_PRELOAD library so its symbols are available
os.environ["LD_PRELOAD"] = LD_PRELOAD_LIB

ok = 0
fail = 0
failures = []

for pkg in sorted(os.listdir(LIBRARY)):
    libs_dir = os.path.join(LIBRARY, pkg, "libs")
    if not os.path.isdir(libs_dir):
        continue
    so_files = [f for f in os.listdir(libs_dir) if f.endswith(".so")]
    if not so_files:
        continue
    for so in so_files:
        so_path = os.path.join(libs_dir, so)
        try:
            lib = ctypes.CDLL(so_path, mode=RTLD_LAZY | RTLD_LOCAL)
            print(f"  OK  {pkg}/{so}")
            ok += 1
        except Exception as e:
            msg = str(e).split("\n")[0]
            print(f"FAIL  {pkg}/{so}: {msg}")
            fail += 1
            failures.append((pkg, so, msg))

print(f"\n=== Summary ===")
print(f"OK: {ok}")
print(f"FAIL: {fail}")

if failures:
    print(f"\n=== Failures ===")
    for pkg, so, msg in failures:
        print(f"  {pkg}/{so}: {msg}")
    sys.exit(1)
else:
    print("All .so files load successfully!")
    sys.exit(0)
