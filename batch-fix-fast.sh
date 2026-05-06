#!/data/service/hnp/bin/bash
DIR="/storage/Users/currentUser/R-harmonyos/build"
CC="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
FC="/storage/Users/currentUser/gfortran-harmonyos/build/gcc/gfortran"
FC_DIR="/storage/Users/currentUser/gfortran-harmonyos/build/gcc"
SYSROOT="/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot"
R_INC="$DIR/include"
R_LIB="$DIR/lib"

compile_lqmm() {
  pkgname="lqmm"
  pkg_path="$DIR/library/$pkgname"
  src_dir="$pkg_path/src"
  libs_dir="$pkg_path/libs"
  mkdir -p "$libs_dir"
  rm -f "$libs_dir/$pkgname.so"
  echo "=== lqmm ==="
  BUILD_TMP=$(mktemp -d "$DIR/../tmp/lqmm-XXXXXX")
  $CC -I"$R_INC" -I"$src_dir" --sysroot="$SYSROOT" -fPIC -O2 -g0 -DFC_LEN_T=int -c "$src_dir/init.c" -o "$BUILD_TMP/init.o" 2>&1
  if [ $? -eq 0 ]; then
    for f in "$src_dir"/*.f "$src_dir"/*.f90; do
      [ -f "$f" ] && $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$f" -o "$BUILD_TMP/$(basename ${f%.*}).o" 2>&1 || true
    done
    all_objs=""
    for f in "$BUILD_TMP"/*.o; do
      [ -f "$f" ] && all_objs="$all_objs $f"
    done
    all_objs="${all_objs# }"
    echo "  LD $pkgname.so"
    $CC -shared -fPIC -o "$libs_dir/$pkgname.so" $all_objs -L"$R_LIB" -lR --sysroot="$SYSROOT" -Wl,--allow-multiple-definition -lmuslstubs 2>&1 && echo "  OK ($(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}'))" || echo "  LINK FAILED"
  else
    echo "  COMPILE FAILED"
  fi
  rm -rf "$BUILD_TMP"
}

compile_frailtypack() {
  pkgname="frailtypack"
  pkg_path="$DIR/library/$pkgname"
  src_dir="$pkg_path/src"
  libs_dir="$pkg_path/libs"
  if [ -f "$libs_dir/$pkgname.so" ]; then echo "  SKIP (exists)"; return; fi
  mkdir -p "$libs_dir"
  echo "=== frailtypack ==="
  BUILD_TMP=$(mktemp -d "$DIR/../tmp/frail-XXXXXX")
  c_ok=true
  for src in "$src_dir"/*.c; do
    [ -f "$src" ] || continue
    base=$(basename "$src")
    echo "  CC $base"
    $CC -I"$R_INC" -I"$src_dir" --sysroot="$SYSROOT" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/${base%.*}.o" 2>&1 || { c_ok=false; break; }
  done
  if $c_ok; then
    for src in "$src_dir"/*.f90 "$src_dir"/*.f; do
      [ -f "$src" ] || continue
      $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/$(basename ${src%.*}).o" 2>&1 || true
    done
    for src in "$src_dir"/*.f90 "$src_dir"/*.f; do
      [ -f "$src" ] || continue
      base=$(basename "$src")
      echo "  FC $base"
      $FC -B"$FC_DIR" -I"$src_dir" -I"$BUILD_TMP" -fPIC -O2 -g0 -c "$src" -o "$BUILD_TMP/${base%.*}.o" 2>&1 || { echo "  FAILED: $base"; c_ok=false; break; }
    done
  fi
  all_objs=""
  for f in "$BUILD_TMP"/*.o; do
    [ -f "$f" ] && all_objs="$all_objs $f"
  done
  all_objs="${all_objs# }"
  echo "  LD $pkgname.so"
  $CC -shared -fPIC -o "$libs_dir/$pkgname.so" $all_objs -L"$R_LIB" -lR --sysroot="$SYSROOT" -Wl,--allow-multiple-definition -lmuslstubs -lgfortran -lgcc_s 2>&1 && echo "  OK ($(ls -lh "$libs_dir/$pkgname.so" | awk '{print $5}'))" || echo "  LINK FAILED"
  rm -rf "$BUILD_TMP"
}

compile_lqmm
compile_frailtypack
