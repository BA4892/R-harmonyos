# R for HarmonyOS

Supports the native porting of multiple versions of R to the HarmonyOS (aarch64-linux-ohos) platform.

Currently supported versions of R:

| Version | Status | Patches |
|---------|--------|---------|
| 4.4.3 | ✓ Tested and verified | `versions/4.4.3/patches/` (2) |
| 4.5.2 | ✓ Tested and verified | `versions/4.5.2/patches/` (4) |
| 4.6.0 | ✓ Tested and verified | `versions/4.6.0/patches/` (2) |

## Quick Start

```bash
# Step 1: Clone this project
git clone https://github.com/sxgou/R-harmonyos.git
cd R-harmonyos

# Step 2: Install dependencies (use brew to install all libraries required by R)
bash build-deps.sh

# Step 3: Download the R 4.4.3 source code (you can also download 4.6.0)
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/

# Step 4: Configuration (automatic patching + cross-compilation configuration). Default is 4.4.3; you can specify a version:
#   bash configure-R.sh          # Use R 4.4.3
#   bash configure-R.sh 4.6.0    # Use R 4.6.0
bash configure-R.sh

# Step 5: Compile
cd build && make && make R

# Step 6: Install to ~/.local/R/

Translated with DeepL.com (free version)
make install

# Step 7: One-click post-installation (generate methods lazy-loading library + NEWS.rds + verification)
bash post-install-R.sh
```

> **Note**: The steps above assume you have already set up the HarmonyOS cross-compilation toolchain (OHOS SDK Clang + gfortran + lld wrapper). If you haven’t set it up yet, please read the complete build guide first.

**Complete Build Guide** (includes toolchain setup, environment requirements, known issues, and troubleshooting): [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md)

---

## Usage

After installation, launch via the R wrapper script:

```bash
~/.local/R/lib/R/bin/R                          # Enter R REPL
~/.local/R/lib/R/bin/R -e ‘print(1+1)’          # Run an expression directly
~/.local/R/lib/R/bin/R --vanilla -e \
  ‘install.packages(“jsonlite”, repos="https://cloud.r-project.org")’
```

---

## 项目结构

```
├── build/                    # Build output (compilation results)
├── src/                      # R source code directory (downloaded from CRAN; not in Git)
│   ├── R-4.4.3/              #   R 4.4.3 Source Code
│   └── R-4.6.0/              #   R 4.6.0 Source Code
├── versions/                 # Patches and configurations for various versions of R
│   ├── 4.4.3/
│   │   ├── patches/          #   2 HarmonyOS patches
│   │   │   ├── *.patch
│   │   │   └── new-files/    #   New files (ohos_stubs.c + Makefile.in)
│   │   └── apply-patches.sh  #   4.4.3 Patch Script
│   ├── 4.5.2/
│   │   ├── patches/          #   4 HarmonyOS patches
│   │   │   ├── *.patch
│   │   │   └── new-files/
│   │   └── apply-patches.sh  #   4.5.2 Patch script (includes 6 inline Python fixes)
│   └── 4.6.0/
│       ├── patches/          #   2 HarmonyOS patches
│       │   ├── *.patch
│       │   └── new-files/
│       └── apply-patches.sh  #   4.6.0 Patch Script
├── doc/
│   └── BUILD-HarmonyOS.md    # Complete Build Guide
├── apply-patches.sh          # Patch application command: bash apply-patches.sh [version]
├── build-deps.sh             # Dependency library installation script
├── configure-R.sh            # Configuration command: bash configure-R.sh [version]
├── post-install-R.sh         # Post-installation steps: bash post-install-R.sh [version]
└── README.md                 # This document
```

---

## Description of Each Script

| Script | When to run | Purpose |
|--------|-------------|---------|
| `build-deps.sh` | After cloning the project, Step 1 | Installs dependencies and build tools such as bzip2, curl, pcre2, cairo, pango, cmake, and ninja via harmonybrew |
| `apply-patches.sh [version]` | After unpacking the R source code; can be automatically invoked by `configure-R.sh` | Applies the corresponding HarmonyOS patches to `src/R-version/`. Example: `bash apply-patches.sh 4.6.0` |
| `configure-R.sh [version]` | After applying patches (automatically invokes apply-patches.sh) | Configure cross-compilation parameters and run R's configure. Default version is 4.4.3. Example: `bash configure-R.sh 4.6.0` |
| `post-install-R.sh [version]` | After `make install` | Generates the methods lazy-loading library, NEWS.rds, and verifies installation integrity |

All scripts accept an optional version parameter. If no version is specified, R 4.4.3 is used by default.

---

## Current Configuration

| Option | Value |
|--------|-------|
| Target Platform | `aarch64-linux-ohos`, HarmonyOS HongMeng Kernel 1.12.0 |
| Toolchain | OHOS SDK 26.0.0.18 (Clang 15.0.4) + [gfortran 14.2.0](https://github.com/sxgou/gfortran-harmonyos) |
| Linker | `lld` (hmdfs requires `.codesign` section) |
| BLAS/LAPACK | [OpenBLAS 0.3.29](https://github.com/sxgou/openblas-harmonyos) (1000×1000 MM ~0.48s) |
| Package Manager | [harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony) (84 formulas) |
| Cairo + Pango | Supported (brew cairo + pango, PNG/SVG/PDF backends, enhanced Pango text layout) |
| readline | Enabled (Tab completion and arrow keys) |
| Java | BiSheng JDK 17 |

---

## Test Status

| Feature | Status |
|---------|--------|
| `gzfile()` / `gzopen` compressed file read/write (zlib-ng-compat) | ✓ |
| `saveRDS`/`readRDS` compressed serialization (gzip/bzip2/xz) | ✓ |
| `memCompress`/`memDecompress` in‑memory compression/decompression | ✓ |
| PDF device afm font metrics loading | ✓ |
| R REPL interactive use (readline Tab completion) | ✓ |
| All 15 base packages built successfully | ✓ |
| 12 loadable packages loaded successfully | ✓ |
| Matrix operations (OpenBLAS optimization) | ✓ 0.48s / 1000×1000 MM |
| Linear models / ANOVA / MLE | ✓ |
| Fortran numerical routines | ✓ |
| libcurl networking | ✓ |
| OpenMP parallelism (20 cores) | ✓ |
| `install.packages()` / `R CMD INSTALL` | ✓ |
| `Rscript` script execution | ✓ |
| ggplot2 + CairoPNG rendering | ✓ |
| Jupyter IRkernel | ✓ |

---

## Known limitations

- ~~**gzfile() / gzopen / R_compress1 / R_decompress1 are unavailable**~~ **Fixed** (June 2, 2026): The libz.so included with the OHOS SDK uses custom syscalls that are blocked by seccomp. Add the `zlib-ng-compat` path from brew to `LD_LIBRARY_PATH` via `etc/ldpaths`. R will automatically load `zlib-ng-compat` to replace the SDK’s `libz` upon startup, restoring all compression/decompression interfaces to normal. See Section 12 of [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md) for details.
- **No X11 / Tcl/Tk**: HarmonyOS does not support these
- **ELF cannot be stripped**: hmdfs security isolation context is compromised

---

*For detailed build instructions, see [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md)*
