# R for HarmonyOS — Cross-Compilation Guide

## Overview

Cross-compile multiple versions of R for the HarmonyOS (aarch64-linux-ohos) platform.

Currently supported R versions:

| Version | Patch Location | Number of Patches |
|---------|----------------|-------------------|
| 4.4.3 | `versions/4.4.3/patches/` | 2 |
| 4.5.2 | `versions/4.5.2/patches/` | 4 |
| 4.6.0 | `versions/4.6.0/patches/` | 3 |

- **Target**: aarch64, HarmonyOS HongMeng Kernel 1.12.0
- **Toolchain**: OHOS SDK 26.0.0.18 (Clang 15.0.4) + [gfortran 14.2.0](https://github.com/sxgou/gfortran-harmonyos)
- **Linker**: lld (hmdfs requires the `.codesign` section, which is generated only by lld)
- **BLAS/LAPACK**: [OpenBLAS 0.3.29](https://github.com/sxgou/openblas-harmonyos) (harmonybrew, 1000x1000 MM ~0.48s / ~4.2 GFLOPs)
- **Package Manager**: [harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony)
- **Cairo + Pango**: Supported (brew cairo 1.18.4 + pango 1.57.1 + fontconfig 2.17.1; PNG/SVG/PDF backends available; enhanced Pango text layout)
- **readline**: Enabled (brew libreadline + ncurses; Tab completion and arrow keys work)
- **Java**: BiSheng JDK 17

### Script Overview

All scripts accept an optional version parameter; if not specified, the default is R 4.4.3:

| Script | When to run | Purpose |
|--------|-------------|---------|
| `build-deps.sh` | **Step 2** | Automatically installs Brew dependencies |
| `apply-patches.sh [version]` | **Step 4**, or automatically called by `configure-R.sh` | Apply HarmonyOS patches to `src/R-version/`. Example: `bash apply-patches.sh 4.6.0` |
| `configure-R.sh [version]` | **Step 5** | Configure cross-compilation (automatically calls `apply-patches.sh`). Example: `bash configure-R.sh 4.6.0` |
| `post-install-R.sh [version]` | **Step 8** | Generate the methods lazy-loading library, `NEWS.rds`, configure the user R environment, and verify the installation. Example: `bash post-install-R.sh 4.6.0` |
| `versions/<version>/patch-rcpp.sh` | **Automatic** (see `harmony_install`) | Patches Rcpp's `undoRmath.h` to resolve the `log1p` macro conflict. Can also be run manually. |

All steps must be **performed in order**; do not skip or reorder them.

---

## Build Environment

| Component | Path | Reference |
|-----------|------|-----------|
| OHOS SDK | `/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/` | Huawei Official |
| C/C++ Compiler | `/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++` | Included in OHOS SDK |
| Fortran | `~/.local/gfortran/bin/gfortran` | [gfortran-harmonyos](https://github.com/sxgou/gfortran-harmonyos) |
| Java | `/data/service/hnp/bishengjdk17.0.13_06.org/` | Huawei Official |
| lld wrapper | `~/.local/bin/ohos-lld-wrapper` | Created in Step 1 of this guide |
| harmonybrew | `~/.harmonybrew/` | [Harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony) |
| OpenBLAS | Provided by harmonybrew | [openblas-harmonyos](https://github.com/sxgou/openblas-harmonyos) |

### Dependency Libraries

Provided by harmonybrew：pcre2, curl, bzip2, xz, openssl@3, libffi, openblas, readline, ncurses, libpng, freetype, cairo, libxml2, expat, pixman, fontconfig, harfbuzz, fribidi, gmp, pango, cmake, ninja, libtiff, pkgconf, autoconf, automake, bison, flex, sccache, libgit2, libsodium, proj, webp, giflib, mpfr

Manual compilation（`~/.local/R-deps`）：fftw3, zeromq, ANN, glpk

---

## Build Steps

```
Prerequisites (Step 1)              — Toolchain Setup
       │
  Step 2: build-deps.sh             — Install dependencies
       │
  Step 3: tar xzf R-X.Y.Z.tar.gz   — Unzip the source code for the required version of R
       │
  Step 4: apply-patches.sh [版本]   — Apply patches (optional; this step is performed automatically in Step 5)
       │
  Step 5: configure-R.sh [版本]     — Configuration (automatically runs apply-patches.sh)
       │
  Step 6: cd build && make...       — Compiled
       │
  Step 7: make install              — Installation
       │
  Step 8: post-install-R.sh [版本]  — Post-installation procedures
```

---

### Step 1: Prepare the toolchain

Ensure that the following toolchain is ready：

```bash
# OHOS SDK — Check if clang is available
aarch64-unknown-linux-ohos-clang --version

# gfortran Cross-compiler (available from the following projects)
#   https://github.com/sxgou/gfortran-harmonyos
~/.local/gfortran/bin/gfortran --version

# BiSheng JDK 17
java -version

# lld Wrapper — See the description below
~/.local/bin/ohos-lld-wrapper --help
```

**Get the toolchains**：

| Component | How to obtain |
|-----------|---------------|
| OHOS SDK + Clang | Officially distributed by Huawei, or included with DevEco Studio |
| gfortran cross-compiler | Download the precompiled package from [gfortran-harmonyos](https://github.com/sxgou/gfortran-harmonyos) and extract it to `~/.local/gfortran/` |
| BiSheng JDK 17 | Officially distributed by Huawei |
| harmonybrew | Install from [Harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony); provides dependencies such as pcre2, curl, cairo, and openblas |
| OpenBLAS | Included with harmonybrew, or compile yourself from [openblas-harmonyos](https://github.com/sxgou/openblas-harmonyos) |

**lld Packager**: Must be installed `~/.local/bin/ohos-lld-wrapper`，The content is as follows:：

```sh
#!/bin/sh
LLVM_LIB=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib
export LD_LIBRARY_PATH="${LLVM_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec -a "ld.lld" "$LLVM_LIB/../bin/lld" --code-sign "$@"
```

This wrapper addresses two key issues：
1. **musl does not support `$ORIGIN`** — lld sets its own RUNPATH to `$ORIGIN/../lib` to point to the OHOS LLVM libraries, but musl’s ld.so ignores this flag, causing lld to be unable to find its own libxml2.so.16 at runtime. The wrapper explicitly specifies the LLVM library path via `LD_LIBRARY_PATH`.
2. **hmdfs requires the `.codesign` section** — Only lld’s `--code-sign` option automatically generates this section; the bfd linker cannot generate it.

---

### Step 2: Install R dependencies

**Method A — Automatic installation (recommended)**:

```bash
bash build-deps.sh
```

This script runs automatically：
- `brew install bzip2 xz pcre2 curl libpng freetype cairo ...` (all dependencies available via Homebrew, including build tools such as pango, cmake, and ninja)
- Create the `~/.local/R-deps/` directory (for libraries not yet available via Homebrew)
- Verify that the key library files exist

**方式 B — 手动安装**：

```bash
brew install bzip2 xz pcre2 curl openssl libpng freetype cairo \
  geos gmp libxml2 pixman libjpeg unixodbc expat fontconfig \
  pango cmake ninja libtiff pkgconf autoconf automake bison flex \
  sccache libgit2 libsodium proj webp giflib mpfr
```

Non-Brew packages (fftw3, zeromq, ANN, glpk) must be cross-compiled manually and installed to `~/.local/R-deps/`.

---

### Step 3: Download and Extract the R Source Code

Select the R version you want. Currently, versions 4.4.3 and 4.6.0 are supported:

```bash
# Download R 4.4.3
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/

# Or download R 4.6.0
curl -L https://cran.r-project.org/src/base/R-4/R-4.6.0.tar.gz | tar xz -C src/
```

Directory structure after extraction:

```
src/R-X.Y.Z/        ← R source code (to be patched and compiled by subsequent scripts)
```

---

### 第 4 步：对 R 源码打 HarmonyOS 补丁

```bash
# Apply patches to R 4.4.3 by default
bash apply-patches.sh

# You can also specify a version, such as R 4.6.0
bash apply-patches.sh 4.6.0
```

This script reads patches from `versions/<version>/patches/` and performs the following operations on the original source code in `src/R-<version>/`:

- Applies **patch files** (modifies the existing R source code; the number varies by version)
  - 4.4.3 / 4.6.0: 2 common patches
  - 4.5.2: 4 patches (2 common + 2 version-specific)
- Copies **2 new files** (ohos_stubs.c + Makefile.in) to `src/extra/ohos_stubs/`
- Runs **inline Python fixes** (4.5.2 only: 6 additional fixes to resolve header file reorganization issues specific to R 4.5.2)

Patch coverage:

| Patch File | Changes | 4.4.3 | 4.5.2 | 4.6.0 |
|------------|---------|:-----:|:-----:|:-----:|
| `etc-ldpaths.in.patch` | Inject `libohos_stubs.so` via `LD_PRELOAD`; add `brew/lib` to `LD_LIBRARY_PATH` to prioritize zlib-ng-compat | ✓ | ✓ | ✓ |
| `src-unix-Rscript.c.patch` | When `execv()` fails, `dlopen("libR.so")` directly calls `Rf_initialize_R` + `Rf_mainloop` (bypassing seccomp execv blocking) | ✓ | ✓ | ✓ |
| `namespace-assignNativeRoutines.patch` | Fixes the issue in `assignNativeRoutines` where `if(exists(...))` skips existing bindings. Lazy-loaded `C_*` variables (which are serialized as NULL in EXTPTRSXP) are not overwritten by `.Call` registration, causing all `C_*` calls to fail | ✗ | ✗ | ✓ |
| `src-extra-Makefile.in-ohos_stubs.patch` | Adds `ohos_stubs` to the `SUBDIRS` in `src/extra/Makefile.in`, enabling `libohos_stubs.so` to be automatically built as part of the standard make process | ✗ | ✓ | ✗ |
| `etc-ldpaths.in-LD_PRELOAD.patch` | Embeds `LD_PRELOAD` configuration in the `ldpaths.in` template, causing `libohos_stubs.so` to be automatically preloaded on every R startup | ✗ | ✓ | ✗ |

R 4.5.2-specific inline Python fixes (included in `apply-patches.sh`):

| Fix Target | Resolution |
|----------|------|
| `src/include/Rmath.h0.in` | Remove the `extern “C”` declaration wrapping Rlog1p (causes a conflict in C mode) |
| `src/main/eval.c` | Add a forward declaration for Rlog1p (Rmath.h no longer declares it) |
| `src/include/Defn.h` | Add forward declaration for Rf_allocVector3 (missing in R 4.5.2; declaration present in R 4.6.0) |
| `src/include/Defn.h` | Add unconditional declarations for R_popen/R_system (R 4.5.2 places them after the HAVE_POPEN condition) |
| `src/library/tools/src/gramRd.y` | Add ENABLE_LEGACY_NONAPI definition (to make Rf_findVar, etc., visible)|
| `src/library/stats/src/distance.c` | Add R_ext/MathThreads.h header inclusion |

> **Note**: The original 9–13 zlib compression workarounds and 2 patches with no practical effect (baseloader.R, gzio.h) have been removed. These patches were used to bypass compression interface restrictions when R triggered seccomp blocking due to loading the OHOS SDK’s `libz.so`. Since `zlib-ng-compat` (brew) replaced the SDK’s `libz`, all compression/decompression interfaces now function normally, and no workarounds are required.
>
> For R 4.5.2, the build of `libohos_stubs.so` has been integrated into the R build system (via the `SUBDIRS` entry in `src/extra/Makefile.in` and `src/extra/ohos_stubs/Makefile.in`). `LD_PRELOAD` injection is embedded in `etc/ldpaths.in`, causing `libohos_stubs.so` to be automatically preloaded every time R starts.

**Note**: You can skip this step—the `configure-R.sh` script in Step 5 will automatically run `apply-patches.sh`. Running it separately is useful for previewing the effects of the patches or for testing them individually after making changes.

---

### Step 5: Configure the R Build

```bash
# Configure R 4.4.3 by default
bash configure-R.sh

# You can also specify a version, such as R 4.6.0
bash configure-R.sh 4.6.0
```

This script performs the following tasks:

1. **Automatically runs `apply-patches.sh <version>`** (if patches have not yet been applied)
2. **Cleans up** `config.cache` and `config.status` in the `build/` directory
3. **Sets environment variables** (PKG_CONFIG_PATH points to brew and R-deps; LD_LIBRARY_PATH points to OHOS LLVM lib and gfortran)
4. **Pre-configure cache variables** (approximately 35 `r_cv_*` / `ac_cv_*` variables; skip runtime tests that cannot run due to seccomp restrictions)
5. **Run `src/R-<version>/configure`** and pass all HarmonyOS cross-compilation parameters
6. **Patch `config.status`** (Fix HarmonyOS toybox compatibility issues: umask 077 + mktemp failure, ksh `print -r --` not supported by bash)
7. **Run `config.status` again** to generate the final Makefile

Key Configuration Options：

```
--host=aarch64-pc-linux-musl      # Cross-compilation target (actually corresponds to aarch64-linux-ohos)
--enable-R-shlib                   # Build libR.so (required; hmdfs does not support static linking)
--with-readline                    # Readline interactive support
--with-blas=-lopenblas             # OpenBLAS (SIMD optimization)
--with-lapack                      # OpenBLAS LAPACK
--enable-java                      # BiSheng JDK 17
--without-x                        # X11 unavailable (no libXt in Homebrew)
--without-tcltk                    # No Tcl/Tk
```

---

### Step 6: Compile

```bash
cd build && make && make R
```

Explanation of each stage:
- `make`: Compiles the R core C/Fortran code and libR.so
- `make R`: Generates the main R binary (PIE) and Rscript

Important notes during compilation:
- **Compile all 15 base packages**: `make` will compile them automatically
- **Makeconf consistency**: `build/Makeconf` and `build/etc/Makeconf` must be in sync (generated by `configure`). If you modify the configuration, you must rerun `configure-R.sh`
- **Two Makeconf files**: If you manually modify one of them, you must update the other accordingly; otherwise, `make` will use an outdated configuration

---

### Step 7: Installation

```bash
make install
```

Install to the directory specified by `--prefix` (`~/.local/R/`). The result is as follows:

| Component | Path |
|-----------|------|
| R Home | `~/.local/R/lib/R/` |
| R Binary | `~/.local/R/lib/R/bin/exec/R` |
| libR.so | `~/.local/R/lib/R/lib/libR.so` |
| Base Packages | `~/.local/R/lib/R/library/*/` |
| Wrapper Scripts | `~/.local/R/lib/R/bin/R` |

**Note**: hmdfs does not allow overwriting existing `.so` files. To reinstall, first delete the old files:

```bash
rm -rf ~/.local/R/lib/R/lib/*.so ~/.local/R/lib/R/bin/exec/R
make install
```

---

### Step 8: Post-Installation

Run the one-click post-installation script (to generate the methods lazy-loading library, NEWS.rds, and verify integrity):

```bash
bash post-install-R.sh
```

This script automatically performs the following:

1. **Generate the `methods` package for lazy database loading** — Generates `library/methods/R/methods`, `methods.rdb` (963 KB), and `methods.rdx` (23 KB). Packages that depend on `methods`, such as `stats4`, require these files; otherwise, loading will fail.
2. **Generate NEWS.rds / NEWS.2.rds / NEWS.3.rds** — If `make install` does not generate these automatically, compile them from `NEWS.Rd`.
3. **Configure the user’s R environment** — Automatically create `~/.Rprofile`, containing:
   - `TMPDIR` set to the hmfs path (to avoid `configure` script failure due to hmdfs limitations)
   - `harmony_install()` helper function, which automatically handles `--host` and `--no-test-load`
   - Automatically patches `undoRmath.h` after Rcpp installation (resolves `log1p` macro conflict)
   - The `TMPDIR` environment variable is automatically appended to `~/.bashrc`
4. **Verify Installation Integrity** — Check whether the R binary, `libR.so`, `libohos_stubs.so`, and key packages such as `base/methods/stats` are in place.

The script can be rerun from the project root directory (existing steps are automatically skipped).

---

## Usage

After installing R, launch it using the wrapper script:

```bash
~/.local/R/lib/R/bin/R                          # R REPL
~/.local/R/lib/R/bin/R -e ‘print(1+1)’          # Run an expression
~/.local/R/lib/R/bin/R --vanilla -e \
  ‘install.packages(“jsonlite”, repos="https://cloud.r-project.org")’
```

**Note**: In earlier versions, `Rscript` was unavailable because `execv()` was blocked by seccomp. Starting with patch #18 (`src/unix/Rscript.c`), Rscript now works correctly by using a workaround that directly calls `Rf_initialize_R` and `Rf_mainloop` via `dlopen(“libR.so”)`.

---

## Installing R Packages

### Recommended Method: `harmony_install()`

After running `post-install-R.sh`, the `harmony_install()` helper function is defined in `~/.Rprofile`, which automatically handles configuration issues specific to HarmonyOS:

```r
# Install a single package (automatically adds --host=aarch64-linux-ohos)
harmony_install(“jsonlite”)

# Batch installation
harmony_install(c(“dplyr”, ‘ggplot2’, “Seurat”))

# Specify a repository
harmony_install(“Seurat”, repos = “https://mirrors.tuna.tsinghua.edu.cn/CRAN”)

# Bioconductor packages (automatically installs BiocManager + passes HarmonyOS parameters)
harmony_install(“DESeq2”, bioc = TRUE)
harmony_install(c(“edgeR”, “limma”), bioc = TRUE)

# GitHub packages (automatically install remotes + pass HarmonyOS parameters)
harmony_install(“satijalab/seurat-wrappers”, github = TRUE)
harmony_install(“chris-mcginnis-ucsf/DoubletFinder”, github = TRUE)
```

`harmony_install()` automatically performs the following tasks:

| Issue | Automatic Resolution |
|-------|----------------------|
| `configure` cannot execute test programs (SELinux blocking) | Pass `configure.args = "--host=aarch64-linux-ohos"` |
| hmdfs temporary file limit | Use `TMPDIR=/data/storage/el4/base/R-build` (hmfs) |
| Rcpp `undoRmath.h` missing `#undef log1p` | Automatically detected and patched after Rcpp installation |
| Test loading may fail after package installation | Pass `INSTALL_opts = "--no-test-load"` |

### Manual Method (`--vanilla` Mode)

If you prefer to start R using `--vanilla` (to skip `.Rprofile`), you'll need to pass the arguments manually:

```r
install.packages("Seurat",
    repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN",
    configure.args = "--host=aarch64-linux-ohos",
    INSTALL_opts = "--no-test-load")
```

### Seurat Installation

Seurat 5.5.0 has been fully verified on HarmonyOS:

```r
harmony_install("Seurat")
```

Core Verification Process:

```r
library(Seurat)
obj <- CreateSeuratObject(counts = data)
obj <- NormalizeData(obj, verbose = FALSE)
obj <- FindVariableFeatures(obj, verbose = FALSE)
obj <- ScaleData(obj, verbose = FALSE)
obj <- RunPCA(obj, verbose = FALSE, npcs = 10)
obj <- FindNeighbors(obj, verbose = FALSE, dims = 1:10)
obj <- FindClusters(obj, verbose = FALSE)
obj <- RunUMAP(obj, dims = 1:10, verbose = FALSE)
```



---

## Known Issues and Fixes

### 1. R Crashes on Startup — “could not find function ‘file’”

**Symptom**: R crashes immediately upon startup, reporting that the base package function `file()` is undefined.

**File**: `src/library/base/baseloader.R`

**Root Cause**: The `readRDS` function takes an argument named `file`, and within the function body, `file(file, “rb”)` is called. The `file` argument masks the `file()` function in the base package. More critically, during the lazy-loading phase of the base package, the non-primitive function `file()` has not yet been defined—the base package itself has not yet finished loading.

**Fix**: Rename the parameter to `filepath` and replace `file(filepath, “rb”)` with `.Internal(file(filepath, “rb”, TRUE, ‘’, “default”, FALSE))`, directly calling the C-level implementation without relying on the R wrapper function.

### 2. Missing database during lazy loading of the `methods` package

See Step 8a for details.

### 3. LD_LIBRARY_PATH causes startup failure — “promise already under evaluation”

**Symptom**: An error “promise already under evaluation” occurs when R is started via a wrapper script; running `bin/exec/R` directly works fine.

**File**: `etc/ldpaths.in`

**Root Cause**: `configure` collects paths from the `-L` parameters in `LDFLAGS` and writes them to `ldpaths`. These paths include the OHOS SDK sysroot, gfortran, harmonybrew, and others. The wrapper script `bin/R` sources `ldpaths` before launching R, adding the sysroot path to `LD_LIBRARY_PATH`. When the dynamic linker prioritizes searching these paths, it loads the OHOS SDK’s libc, which is incompatible with the host machine’s musl environment. This causes internal state inconsistencies during R’s lazy loading.

**Fix**: Ignore `@R_LD_LIBRARY_PATH@` in `ldpaths.in` and retain only `${R_HOME}/lib`. All dependency paths are now encoded in the binaries via RPATH.

### 4. `make install` is missing NEWS.rds

See step 8b for details.

### 5. `make install` missing Rscript.1 man page

**Root Cause**: `help2man` requires executing the target platform binary to extract help information, but the cross-compiled Rscript cannot run on the host machine (requires the HarmonyOS musl linker).

**Fix**: Create a minimal man page stub.

### 6. ohos-lld-wrapper — musl $ORIGIN incompatibility

See the notes on the lld wrapper in Step 1 for details.

### 7. hmdfs File System Restrictions

**Symptoms**: Statically linked ELF files cannot be executed (EACCES); `.so` files linked with bfd fail to `dlopen()`; stripped binaries cannot run.

**Root Cause**: HarmonyOS’s hmdfs distributed file system security mechanisms require:
- The ELF Type must be **DYN (Shared object file)**—i.e., a PIE executable
- A **`.codesign` section** must be present: This is automatically generated only by lld’s `--code-sign` option
- Stripping is not allowed: `llvm-strip` modifies the ELF in-place on hmdfs, which compromises the security isolation context

**Verification**:
```bash
readelf -h binary | grep ‘Type:’
# Type: DYN (Shared object file)
readelf -S binary | grep codesign
# Should have a .codesign section
```

### 8. OHOS libc Trimming — libohos_stubs Supplement Library

**Symptom**: `undefined symbol` errors occur during Rust compilation or when running R packages.

**Root Cause**: OHOS’s musl libc is a stripped version and lacks some standard symbols.

**Workaround**: Compile `src/extra/ohos_stubs/ohos_stubs.c` into two forms:

| Scenario | Method | Symbol |
|----------|--------|--------|
| Rust compile‑time static linking | `libohos_stubs.a` | `posix_spawn_file_actions_addchdir_np` (returns `ENOSYS`), `__xpg_strerror_r` (forwards `strerror_r`) |
| R package runtime dynamic injection | `libohos_stubs.so` (`LD_PRELOAD`) | Same as above + `pthread_setcanceltype` (returns `0`), `pthread_cancel` (returns `0`) |

**LD_PRELOAD Injection Method**: The following snippet is embedded in `etc/ldpaths.in` (the R runtime configuration file template). After running `configure`, it is generated into the installed `etc/ldpaths` directory, ensuring automatic preloading every time R starts:

```sh
LD_PRELOAD="${R_HOME}/lib${R_ARCH}/libohos_stubs.so${LD_PRELOAD:+:${LD_PRELOAD}}"
export LD_PRELOAD
```

This mechanism allows R packages such as `cli` and `purrr` that use `pthread_setcanceltype` to run normally without modifying the package source code.

### 9. OpenBLAS Integration

When configuring R, use `--with-blas=“-lopenblas” --with-lapack`; libR.so links directly to libopenblas.so.0. A 1000x1000 matrix multiplication takes approximately 0.48s on a 20-core aarch64 system (~4.2 GFLOPs).

### 10. Legacy Files in `bin/exec/` Causing Multi-Architecture Build Errors

The `install-bin` target in `src/main/Makefile.in` now automatically removes non-R files (R.bfd, test-exec, test-sh) from `bin/exec/`.

### 11. gzfile Compression Causing Vignette Installation Failure

**Fix**: In `src/library/tools/R/admin.R`, the `.install_package_vignettes3` function adds a fallback for `readRDS`—it reads the raw bytes, decompresses the gzip using `memDecompress()`, and then parses the data using `unserialize()`. R’s built-in zlib implementation does not rely on the `gzfile` library, allowing it to bypass seccomp restrictions.

### 12. seccomp blocks all zlib compression interfaces

**Symptoms**: The HarmonyOS seccomp filter blocks custom syscalls used in the `libz.so` library included with the OHOS SDK, resulting in:
- All `gzopen()` / `gzfile()` calls failing
- All `saveRDS(compress=TRUE)` calls fail (returning `unknown input format`)
- All `makeLazyLoadDB(compress=TRUE)` calls fail
- sysdata compression (R_compress1) fails during system package installation
- `memDecompress(type=“gzip”)` memory decompression fails

**Root Cause**: The OHOS SDK path in R's RUNPATH (`/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot/usr/lib/aarch64-linux-ohos/`) takes precedence over the brew path, causing the runtime to load the SDK’s `libz.so` (triggering seccomp) instead of brew’s `zlib-ng-compat` (which uses standard syscalls).

**Update 2026-06-02**: By adding the brew lib path to `LD_LIBRARY_PATH` via `etc/ldpaths` (in musl, `LD_LIBRARY_PATH` takes precedence over `DT_RPATH`), R automatically loads `zlib-ng-compat` instead of the SDK’s `libz` at startup, and all compression/decompression interfaces return to normal. Specific changes:

```bash
# Add to `etc/ldpaths`:
R_BREW_LIB="/storage/Users/currentUser/.harmonybrew/lib"
: ${R_LD_LIBRARY_PATH=${R_BREW_LIB}:${R_HOME}/lib}
```

**Patch Cleanup Notes**: The original 13 (4.6.0) / 9 (4.4.3) zlib compression workarounds and 2 patches with no practical effect (baseloader.R, gzio.h) have all been removed. These patches were used to bypass compression interface restrictions when R triggered seccomp blocking due to loading the OHOS SDK’s libz.so. The methods included:
- Replacing `gzfile()` with `file()` to bypass the gzopen block
- Changing `saveRDS(compress=TRUE)` to `compress=FALSE` to bypass the R_compress1 block
- Forcing compression to be disabled in lazy-load database builds
- Replacing `gzfile()` reads with an external `gzip -dc` pipe
- Adding a try-catch fallback to `memDecompress()`

Since `zlib-ng-compat` (brew) replaced the SDK’s libz, all compression/decompression interfaces now function normally, and no workarounds are required.

> Note: R 4.5.2 includes two additional version-specific patches on top of the public patches (ohos_stubs build integration + ldpaths.in LD_PRELOAD injection), as well as six inline Python fixes. See the patch coverage table above for details.

---

## Build Artifacts

| Artifact | Size | Description |
|------|------|------|
| libR.so | 3.2 MB | R shared library |
| R.bin | 22 KB | R main executable (PIE) |
| Rscript | 24 KB | R scripting frontend (PIE) |
| methods.rdb | 963 KB | Lazy-loaded data for the methods package |
| methods.rdx | 23 KB | Lazy-loaded index for the methods package |
| internet.so | 72 KB | Network module |
| lapack.so | 47 KB | LAPACK C wrapper |
| libRlapack.so | 1.7 MB | LAPACK Fortran implementation |
| libohos_stubs.so | — | libc stub library |

---

## Verification

```bash
# Version information
LC_ALL=C ~/.local/R/lib/R/bin/R --version

# Start R and load all essential packages
LC_ALL=C ~/.local/R/lib/R/bin/R --vanilla --no-echo \
  -e ‘library(methods); library(stats4); cat(“OK\n”)’

# Matrix operation test
LC_ALL=C ~/.local/R/lib/R/bin/R --vanilla --no-echo \
  -e 'm <- matrix(rnorm(1e6), 1000); cat(system.time({m %*% m})[3], “s\n”)'
```

## Verified Features

- [x] gzfile() / gzopen compressed file read/write (zlib-ng-compat)
- [x] saveRDS/readRDS compressed serialization (gzip/bzip2/xz)
- [x] memCompress/memDecompress memory compression/decompression
- [x] PDF device afm font metrics loading
- [x] R core startup (R 4.4.3)
- [x] All 15 base packages built and loaded
- [x] stats4 maximum likelihood estimation (MLE)
- [x] libcurl network functionality
- [x] Basic graphics devices (grDevices)
- [x] BLAS/LAPACK linear algebra (OpenBLAS 0.3.29)
- [x] `R CMD INSTALL` and `install.packages()`
- [x] ggplot2 + CairoPNG rendering
- [x] readline interactive terminal (Tab completion and arrow keys)
- [x] Jupyter IRkernel
- [x] Seurat 5.5.0 (full workflow including NormalizeData, RunPCA, FindClusters, RunUMAP, etc.)
- [ ] tcltk (requires Tcl/Tk runtime)
- [ ] Recommended packages (MASS, lattice, etc.)

---

*Last updated: 2026-06-03 (Added namespace.R fix patch, Seurat support, and harmony_install automated configuration)*
