# R 4.4.3 for HarmonyOS — 交叉编译指南

## 概述

将 R 4.4.3 交叉编译到 HarmonyOS (aarch64-linux-ohos) 平台。

- **目标**: aarch64, HarmonyOS HongMeng Kernel 1.12.0
- **工具链**: OHOS SDK 26.0.0.18 (Clang 15.0.4) + [gfortran 14.2.0](https://github.com/sxgou/gfortran-harmonyos)
- **链接器**: lld（hmdfs 要求 `.codesign` 段，仅 lld 生成）
- **BLAS/LAPACK**: [OpenBLAS 0.3.29](https://github.com/sxgou/openblas-harmonyos)（harmonybrew，1000x1000 MM ~0.48s / ~4.2 GFLOPs）
- **包管理器**: [harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony)
- **Cairo**: 支持（brew cairo 1.18.4 + fontconfig 2.17.1，PNG/SVG/PDF 后端可用）
- **readline**: 启用（brew libreadline + ncurses，Tab 补全和方向键可用）
- **Java**: BiSheng JDK 17

### 脚本总览

| 脚本 | 位置 | 何时运行 | 作用 |
|------|------|----------|------|
| `build-deps.sh` | 项目根目录 | **第 2 步**（可选） | 自动安装 brew 依赖库 |
| `apply-patches.sh` | 项目根目录 | **第 4 步**，或在第 6 步由 configure-R.sh 自动调用 | 对 R 源码打 HarmonyOS 补丁 |
| `configure-R.sh` | 项目根目录 | **第 6 步** | 配置 R 构建（自动调 apply-patches.sh） |

所有脚本必须**按顺序执行**，不可跳过或调换次序。

---

## 构建环境

| 组件 | 路径 | 参考 |
|------|------|------|
| OHOS SDK | `/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/` | 华为官方 |
| C/C++ 编译器 | `/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++` | OHOS SDK 自带 |
| Fortran | `~/.local/gfortran/bin/gfortran` | [gfortran-harmonyos](https://github.com/sxgou/gfortran-harmonyos) |
| Java | `/data/service/hnp/bishengjdk17.0.13_06.org/` | 华为官方 |
| lld 包装器 | `~/.local/bin/ohos-lld-wrapper` | 本指南第 1 步创建 |
| harmonybrew | `~/.harmonybrew/` | [Harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony) |
| OpenBLAS | harmonybrew 提供 | [openblas-harmonyos](https://github.com/sxgou/openblas-harmonyos) |

### 依赖库

由 harmonybrew 提供：pcre2, curl, bzip2, xz, openssl@3, libffi, openblas, readline, ncurses, libpng, freetype, cairo, libxml2, expat, pixman, fontconfig, harfbuzz, fribidi, gmp

手动编译（`~/.local/R-deps`）：fftw3, zeromq, ANN, mpfr

---

## 构建步骤

```
Prerequisites (Step 1)          — 工具链准备
       │
  Step 2: build-deps.sh         — 安装依赖库（可选，也可手动 brew install）
       │
  Step 3: tar xzf R-4.4.3...   — 解压 R 源码
       │
  Step 4: apply-patches.sh     — 打补丁（可跳过，Step 6 自动执行）
       │
  Step 5: configure-R.sh       — 配置（自动调用 apply-patches.sh）
       │
  Step 6: cd build && make...  — 编译
       │
  Step 7: make install         — 安装
       │
  Step 8: Post-install         — 生成 methods 懒加载库 + NEWS.rds
```

---

### 第 1 步：准备工具链

确保以下工具链已就绪：

```bash
# OHOS SDK — 检查 clang 可用
aarch64-unknown-linux-ohos-clang --version

# gfortran 交叉编译器（从以下项目获取）
#   https://github.com/sxgou/gfortran-harmonyos
~/.local/gfortran/bin/gfortran --version

# BiSheng JDK 17
java -version

# lld 包装器 — 见下方说明
~/.local/bin/ohos-lld-wrapper --help
```

**获取各工具链**：

| 组件 | 获取方式 |
|------|----------|
| OHOS SDK + Clang | 华为官方分发，或 DevEco Studio 自带 |
| gfortran 交叉编译器 | 从 [gfortran-harmonyos](https://github.com/sxgou/gfortran-harmonyos) 下载预编译包，解压到 `~/.local/gfortran/` |
| BiSheng JDK 17 | 华为官方分发 |
| harmonybrew | 从 [Harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony) 安装，提供 pcre2、curl、cairo、openblas 等依赖库 |
| OpenBLAS | harmonybrew 自带，或从 [openblas-harmonyos](https://github.com/sxgou/openblas-harmonyos) 自行编译 |

**lld 包装器**：必须安装 `~/.local/bin/ohos-lld-wrapper`，内容如下：

```sh
#!/bin/sh
LLVM_LIB=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib
export LD_LIBRARY_PATH="${LLVM_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec -a "ld.lld" "$LLVM_LIB/../bin/lld" --code-sign "$@"
```

此包装器解决两个关键问题：
1. **musl 不支持 `$ORIGIN`** — lld 自身 RUNPATH 设为 `$ORIGIN/../lib` 指向 OHOS LLVM lib，但 musl ld.so 忽略此标记，导致 lld 运行时找不到自己的 libxml2.so.16。包装器通过 `LD_LIBRARY_PATH` 显式指定 LLVM lib 路径。
2. **hmdfs 要求 `.codesign` 段** — 仅 lld 的 `--code-sign` 自动生成此段，bfd 链接器无法生成。

---

### 第 2 步：安装 R 依赖库

**方式 A — 自动安装（推荐）**：

```bash
bash build-deps.sh
```

此脚本自动执行：
- `brew install bzip2 xz pcre2 curl libpng freetype cairo ...`（所有 brew 可用依赖）
- 创建 `~/.local/R-deps/` 目录（用于尚未进入 brew 的库）
- 验证关键库文件是否存在

**方式 B — 手动安装**：

```bash
brew install bzip2 xz pcre2 curl openssl libpng freetype cairo \
  geos gmp libxml2 pixman libjpeg unixodbc expat fontconfig
```

非 brew 库（fftw3, zeromq, ANN, mpfr）需要手动交叉编译，安装到 `~/.local/R-deps/`。

---

### 第 3 步：下载并解压 R 4.4.3 源码

```bash
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/
```

解压后目录结构：

```
src/R-4.4.3/        ← R 原始源码（由 apply-patches.sh 修改）
```

---

### 第 4 步：对 R 源码打 HarmonyOS 补丁

```bash
bash apply-patches.sh
```

此脚本对 `src/R-4.4.3/` 中的原始源码执行以下操作：

- 应用 `patches/` 目录下的 **14 个补丁文件**（修改现有 R 源码）
- 复制 `patches/new-files/` 中的 **2 个新增文件**（ohos_stubs.c + Makefile.in）到 `src/extra/ohos_stubs/`

补丁覆盖范围：

| 补丁文件 | 修改内容 |
|----------|----------|
| `src-library-base-baseloader.R.patch` | readRDS 参数名 `file` → `filepath`，避免遮蔽 base::file() |
| `src-main-gzio.h.patch` | fopen → R_fopen，补上 Fileio.h |
| `src-library-base-R-serialize.R.patch` | gzfile() → file()（绕过 seccomp zlib 过滤） |
| `src-library-base-R-load.R.patch` | gzfile() → file() |
| `src-library-base-R-dcf.R.patch` | gzfile() → file() |
| `src-library-base-R-lazyload.R.patch` | 懒加载中 gzfile() → file() |
| `etc-ldpaths.in.patch` | LD_PRELOAD 注入 libohos_stubs.so；LD_LIBRARY_PATH 限制为仅 `${R_HOME}/lib` |
| `src-library-methods-R-zzz.R.patch` | nspackloader 懒加载支持 |
| `src-library-tools-R-admin.R.patch` | vignette 安装时 memDecompress fallback |
| `src-library-tools-R-Rd.R.patch` | partial.rdb 的 memDecompress fallback |
| `src-main-Makefile.in.patch` | install-bin 清理非 R 文件（R.bfd, test-exec, test-sh） |
| `src-extra-Makefile.in.patch` | ohos_stubs 构建集成 |
| `share-make-lazycomp.mk.patch` | 懒加载数据库 compress=FALSE |
| `share-make-basepkg.mk.patch` | base 包安装 compress=FALSE |

**注意**：此步骤也可跳过——第 5 步的 `configure-R.sh` 会自动调用 `apply-patches.sh`。单独运行适用于提前查看补丁效果或在修改补丁后单独测试。

---

### 第 5 步：配置 R 构建

```bash
bash configure-R.sh
```

此脚本完成以下工作：

1. **自动调用 `apply-patches.sh`**（如果尚未打补丁）
2. **清理** `build/` 目录中的 `config.cache` 和 `config.status`
3. **设置环境变量**（PKG_CONFIG_PATH 指向 brew 和 R-deps，LD_LIBRARY_PATH 指向 OHOS LLVM lib 和 gfortran）
4. **预配置缓存变量**（约 35 个 `r_cv_*` / `ac_cv_*` 变量，跳过因 seccomp 限制无法运行的运行时测试）
5. **运行 `src/R-4.4.3/configure`** 并传递所有 HarmonyOS 交叉编译参数
6. **修补 `config.status`**（修复 HarmonyOS toybox 的兼容性问题：umask 077 + mktemp 失败，ksh `print -r --` bash 不支持）
7. **重新运行 `config.status`** 生成最终的 Makefile

关键配置选项：

```
--host=aarch64-pc-linux-musl      # 交叉编译目标（实际对应 aarch64-linux-ohos）
--enable-R-shlib                   # 构建 libR.so（必需，hmdfs 不支持静态链接）
--with-readline                    # readline 交互支持
--with-blas=-lopenblas             # OpenBLAS（SIMD 优化）
--with-lapack                      # OpenBLAS LAPACK
--enable-java                      # BiSheng JDK 17
--without-x                        # X11 不可用（brew 无 libXt）
--without-tcltk                    # 无 Tcl/Tk
```

---

### 第 6 步：编译

```bash
cd build && make && make R
```

各阶段说明：
- `make`：编译 R 核心 C/Fortran 代码和 libR.so
- `make R`：生成 R 主二进制（PIE）和 Rscript

编译时需注意：
- **编译全部 15 个 base 包**：`make` 会自动编译
- **Makeconf 一致性**：`build/Makeconf` 和 `build/etc/Makeconf` 必须同步（由 configure 生成）。如果修改了配置，需重新运行 `configure-R.sh`
- **两个 Makeconf 文件**：如果手动修改其中一个，必须同步到另一个，否则 make 会使用过时的配置

---

### 第 7 步：安装

```bash
make install
```

安装到 `--prefix` 指定的目录（`~/.local/R/`），结果如下：

| 组件 | 路径 |
|------|------|
| R Home | `~/.local/R/lib/R/` |
| R 二进制 | `~/.local/R/lib/R/bin/exec/R` |
| libR.so | `~/.local/R/lib/R/lib/libR.so` |
| Base 包 | `~/.local/R/lib/R/library/*/` |
| 包装脚本 | `~/.local/R/lib/R/bin/R` |

**注意**：hmdfs 不允许覆盖已存在的 `.so` 文件。如需重新安装，先删除旧文件：

```bash
rm -rf ~/.local/R/lib/R/lib/*.so ~/.local/R/lib/R/bin/exec/R
make install
```

---

### 第 8 步：安装后处理

运行一键安装后处理脚本（生成 methods 懒加载库、NEWS.rds、验证完整性）：

```bash
bash post-install-R.sh
```

此脚本自动完成：

1. **生成 methods 包懒加载数据库** — 生成 `library/methods/R/methods`、`methods.rdb` (963 KB)、`methods.rdx` (23 KB)。stats4 等依赖 methods 的包需要此文件，否则加载失败。
2. **生成 NEWS.rds / NEWS.2.rds / NEWS.3.rds** — 如果 `make install` 未自动生成，从 `NEWS.Rd` 编译。
3. **验证安装完整性** — 检查 R 二进制、libR.so、libohos_stubs.so 以及 base/methods/stats 等关键包是否就位。

脚本可在项目根目录重复运行（已存在的步骤自动跳过）。

---

## 使用

R 安装后通过包装脚本启动：

```bash
~/.local/R/lib/R/bin/R                          # R REPL
~/.local/R/lib/R/bin/R -e 'print(1+1)'          # 运行表达式
~/.local/R/lib/R/bin/R --vanilla -e \
  'install.packages("jsonlite", repos="https://cloud.r-project.org")'
```

**注意**：`Rscript` 不可用——seccomp 阻止 `execv()`。改用 `R --vanilla -e` 执行脚本。

---

## 已知问题与修复

### 1. R 启动崩溃 — "could not find function 'file'"

**现象**: R 启动时立即崩溃，报 base 函数 `file()` 未定义。

**文件**: `src/library/base/baseloader.R`

**根因**: `readRDS` 的参数名为 `file`，函数体内又调用 `file(file, "rb")`。参数 `file` 遮蔽了 base 包中的 `file()` 函数。更关键的是，在 base 包懒加载阶段，`file()` 这个非原语函数尚未定义——base 包自己还没加载完成。

**修复**: 参数重命名为 `filepath`，并将 `file(filepath, "rb")` 替换为 `.Internal(file(filepath, "rb", TRUE, "", "default", FALSE))`，直接调用 C 层实现，不依赖 R 包装函数。

### 2. methods 包懒加载数据库缺失

详见第 8a 步。

### 3. LD_LIBRARY_PATH 导致启动失败 — "promise already under evaluation"

**现象**: R 通过包装脚本启动时报错 "promise already under evaluation"，直接执行 `bin/exec/R` 正常。

**文件**: `etc/ldpaths.in`

**根因**: configure 从 `LDFLAGS` 的 `-L` 参数收集路径写入 `ldpaths`，这些路径包括 OHOS SDK sysroot、gfortran、harmonybrew 等。包装脚本 `bin/R` 在启动 R 前 source `ldpaths`，将 sysroot 路径加入 `LD_LIBRARY_PATH`。动态链接器优先搜索这些路径时加载了 OHOS SDK 的 libc，与构建宿主机的 musl 环境不兼容，导致 R 懒加载期间内部状态不一致。

**修复**: `ldpaths.in` 中忽略 `@R_LD_LIBRARY_PATH@`，只保留 `${R_HOME}/lib`。所有依赖路径已通过 RPATH 编码在二进制中。

### 4. `make install` 缺少 NEWS.rds

详见第 8b 步。

### 5. `make install` 缺少 Rscript.1 man page

**根因**: `help2man` 需要执行目标平台二进制来提取帮助信息，但交叉编译的 Rscript 无法在构建宿主机上运行（需要 HarmonyOS musl 动态链接器）。

**修复**: 创建最小 man page 存根。

### 6. ohos-lld-wrapper — musl $ORIGIN 不兼容

详见第 1 步中 lld 包装器的说明。

### 7. hmdfs 文件系统限制

**现象**: 静态链接的 ELF 文件无法执行（EACCES），bfd 链接的 `.so` 文件 `dlopen()` 失败，strip 后的二进制无法运行。

**根因**: HarmonyOS 的 hmdfs 分布式文件系统安全机制要求：
- ELF Type 必须为 **DYN (Shared object file)**——即 PIE 可执行文件
- 必须有 **`.codesign` section**：仅 lld 的 `--code-sign` 自动生成
- 不能 strip：`llvm-strip` 在 hmdfs 上原地修改 ELF 时会破坏安全隔离上下文

**验证**:
```bash
readelf -h binary | grep 'Type:'
# Type: DYN (Shared object file)
readelf -S binary | grep codesign
# 应有 .codesign section
```

### 8. OHOS libc 裁剪 — libohos_stubs 补齐库

**现象**: Rust 编译时或 R 包运行时遇到 `undefined symbol` 错误。

**根因**: OHOS 的 musl libc 是裁剪版，缺少部分标准符号。

**补齐方案**: `src/extra/ohos_stubs/ohos_stubs.c` 编译为两种形式：

| 场景 | 方式 | 符号 |
|------|------|------|
| Rust 编译时静态链接 | `libohos_stubs.a` | `posix_spawn_file_actions_addchdir_np`（返回 ENOSYS），`__xpg_strerror_r`（转发 strerror_r） |
| R 包运行时动态注入 | `libohos_stubs.so`（LD_PRELOAD） | 同上 + `pthread_setcanceltype`（返回 0），`pthread_cancel`（返回 0） |

### 9. OpenBLAS 集成

R 配置时使用 `--with-blas="-lopenblas" --with-lapack`，libR.so 直接链接 libopenblas.so.0。1000x1000 矩阵乘法在 20 核 aarch64 上约 0.48s（~4.2 GFLOPs）。

### 10. `bin/exec/` 遗留文件导致多架构构建错误

`src/main/Makefile.in` 的 `install-bin` 目标已自动删除 `bin/exec/` 中的非 R 文件（R.bfd, test-exec, test-sh）。

### 11. gzfile 压缩导致 vignette 安装失败

**修复**: `src/library/tools/R/admin.R` 中 `.install_package_vignettes3` 对 `readRDS` 添加了 fallback——读取原始字节后用 `memDecompress()` 解压 gzip，再用 `unserialize()` 解析。R 内置的 zlib 实现不依赖 `gzfile` 连接，可绕过 seccomp 限制。

---

## 构建产物

| 产物 | 大小 | 说明 |
|------|------|------|
| libR.so | 3.2 MB | R 共享库 |
| R.bin | 22 KB | R 主执行体 (PIE) |
| Rscript | 24 KB | R 脚本前端 (PIE) |
| methods.rdb | 963 KB | methods 包懒加载数据 |
| methods.rdx | 23 KB | methods 包懒加载索引 |
| internet.so | 72 KB | 网络模块 |
| lapack.so | 47 KB | LAPACK C 包装 |
| libRlapack.so | 1.7 MB | LAPACK Fortran 实现 |
| libohos_stubs.so | — | libc 补齐库 |

---

## 验证

```bash
# 版本信息
LC_ALL=C ~/.local/R/lib/R/bin/R --version

# 启动并加载所有关键包
LC_ALL=C ~/.local/R/lib/R/bin/R --vanilla --no-echo \
  -e 'library(methods); library(stats4); cat("OK\n")'

# 矩阵运算测试
LC_ALL=C ~/.local/R/lib/R/bin/R --vanilla --no-echo \
  -e 'm <- matrix(rnorm(1e6), 1000); cat(system.time({m %*% m})[3], "s\n")'
```

## 已验证功能

- [x] R 核心启动 (R 4.4.3)
- [x] 全部 15 个 base 包构建和加载
- [x] stats4 最大似然估计 (MLE)
- [x] libcurl 网络功能
- [x] 基础图形设备 (grDevices)
- [x] BLAS/LAPACK 线性代数（OpenBLAS 0.3.29）
- [x] `R CMD INSTALL` 和 `install.packages()`
- [x] ggplot2 + CairoPNG 渲染
- [x] readline 交互式终端（Tab 补全和方向键）
- [x] Jupyter IRkernel
- [ ] tcltk（需 Tcl/Tk 运行时）
- [ ] 推荐包 (MASS, lattice 等)

---

*最后更新: 2026-05-29*
