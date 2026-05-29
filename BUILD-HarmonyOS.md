# R 4.4.3 for HarmonyOS — 交叉编译指南

## 概述

将 R 4.4.3 交叉编译到 HarmonyOS (aarch64-linux-ohos) 平台。使用 OHOS SDK Clang + gfortran 交叉编译器，依赖库由 harmonybrew 提供。

- **目标**: aarch64, HarmonyOS HongMeng Kernel 1.12.0
- **工具链**: OHOS SDK 26.0.0.18 (Clang 15.0.4) + gfortran 14.2.0
- **链接器**: lld（hmdfs 要求 `.codesign` 段，仅 lld 生成）
- **BLAS/LAPACK**: OpenBLAS 0.3.29（harmonybrew，1000x1000 MM ~0.48s / ~4.2 GFLOPs）
- **Cairo**: 支持（brew cairo 1.18.4 + fontconfig 2.17.1，PNG/SVG/PDF 后端可用）
- **readline**: 启用（brew libreadline + ncurses，Tab 补全和方向键可用）
- **Java**: BiSheng JDK 17

## 构建环境

| 组件 | 路径 |
|---|---|
| OHOS SDK | `/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/` |
| C/C++ 编译器 | `/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++` |
| Fortran | `~/.local/gfortran/bin/gfortran` |
| Java | `/data/service/hnp/bishengjdk17.0.13_06.org/` |
| lld 包装器 | `~/.local/bin/ohos-lld-wrapper` |
| 系统 library | `~/.local/R/lib/R/` |
| harmonybrew | `~/.harmonybrew/` |

### 依赖库

由 harmonybrew 提供：pcre2, curl, bzip2, xz, openssl@3, libffi, openblas, readline, ncurses, libpng, freetype, cairo, libxml2, expat, pixman, fontconfig, harfbuzz, fribidi, gmp

手动编译（`~/.local/R-deps`）：fftw3, zeromq, ANN, mpfr

## 构建步骤

```bash
# 1. 配置
./configure-R.sh

# 2. 编译 R 核心 + base 包
cd build && make && make R

# 3. 安装
make install                          # 安装到 --prefix 指定目录

# 4. 手动生成 methods 包懒加载数据库（问题 2）
echo 'tools:::makeLazyLoading("methods", compress = FALSE)' | \
  R_DEFAULT_PACKAGES=NULL LC_ALL=C ./bin/R --vanilla --no-echo

# 5. 生成 NEWS.rds（问题 4）
# 见下方问题 4
```

### 关键配置选项

```
--host=aarch64-linux-ohos            # 交叉编译目标
--enable-R-shlib                     # 构建 libR.so（必需，hmdfs 不支持静态链接）
--with-readline                      # readline 交互支持
--with-blas=-lopenblas               # OpenBLAS（SIMD 优化）
--with-lapack                        # OpenBLAS LAPACK（与 BLAS 同库）
--enable-java                        # BiSheng JDK 17
--without-x --without-tcltk          # X11 不可用（brew 无 libXt），无 Tcl/Tk
--disable-nls                        # 可选，减少依赖
```

### RPATH 策略

HarmonyOS 通常禁用 `LD_LIBRARY_PATH`，所有库路径直接编码在 DT_RPATH 中：

```
RPATH: /build/lib
       :/ohos-sdk/.../sysroot/usr/lib/aarch64-linux-ohos
       :~/.harmonybrew/lib
       :~/.local/gfortran/lib64
       :~/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0
       :/ohos-sdk/.../llvm/lib
```

## 已知问题与修复

### 1. R 启动崩溃 — "could not find function 'file'"

**现象**: R 启动时立即崩溃，报 base 函数 `file()` 未定义。

**文件**: `src/library/base/baseloader.R`

**根因**: `readRDS` 的参数名为 `file`，函数体内又调用 `file(file, "rb")`。参数 `file` 遮蔽了 base 包中的 `file()` 函数。更关键的是，在 base 包懒加载阶段，`file()` 这个非原语函数尚未定义——base 包自己还没加载完成。

**修复**: 参数重命名为 `filepath`，并将 `file(filepath, "rb")` 替换为 `.Internal(file(filepath, "rb", TRUE, "", "default", FALSE))`，直接调用 C 层实现，不依赖 R 包装函数：

```r
readRDS <- function (filepath) {
    halt <- function (message) .Internal(stop(TRUE, message))
    close <- function (con) .Internal(close(con, "rw"))
    if (! is.character(filepath)) halt("bad file name")
    con <- .Internal(file(filepath, "rb", TRUE, "", "default", FALSE))
    on.exit(close(con))
    .Internal(unserializeFromConn(con, baseenv()))
}
```

### 2. methods 包懒加载数据库缺失

**现象**: 加载 stats4 包时崩溃，找不到 `methods.rdx`。stats4 依赖 methods，methods 加载时 `nspackloader.R` 调用 `lazyLoad()` 找不到 `.rdx` 文件。

**文件**: `src/library/methods/R/zzz.R`

**根因**: HarmonyOS 适配中移除了 `...onLoad` 函数末尾的 `makeLazyLoadDB` 调用。标准 R 中此调用在 `loadNamespace("methods")` 时生成 `methods.rdb`/`methods.rdx`。移除后 Makefile 规则虽然执行了但目标文件没有生成。

**修复**: 构建后手动生成懒加载数据库：
```bash
echo 'tools:::makeLazyLoading("methods", compress = FALSE)' | \
  R_DEFAULT_PACKAGES=NULL LC_ALL=C ./bin/R --vanilla --no-echo
```

生成文件：`library/methods/R/methods` (nspackloader), `methods.rdb` (963 KB), `methods.rdx` (23 KB)

### 3. LD_LIBRARY_PATH 导致启动失败 — "promise already under evaluation"

**现象**: R 通过包装脚本启动时报错 "promise already under evaluation"，直接执行 `bin/exec/R` 正常。

**文件**: `etc/ldpaths.in`

**根因**: configure 从 `LDFLAGS` 的 `-L` 参数收集路径写入 `ldpaths`，这些路径包括 OHOS SDK sysroot、gfortran、harmonybrew 等。包装脚本 `bin/R` 在启动 R 前 source `ldpaths`，将 sysroot 路径加入 `LD_LIBRARY_PATH`。动态链接器优先搜索这些路径时加载了 OHOS SDK 的 libc，与构建宿主机的 musl 环境不兼容，导致 R 懒加载期间内部状态不一致。

**修复**: `ldpaths.in` 中忽略 `@R_LD_LIBRARY_PATH@`，只保留 `${R_HOME}/lib`。所有依赖路径已通过 RPATH 编码在二进制中，运行时无需通过环境变量指定：
```sh
: ${R_LD_LIBRARY_PATH=${R_HOME}/lib}
```

同时 `ldpaths.in` 新增 `libohos_stubs.so` 的 LD_PRELOAD 注入代码（见问题 8）。

### 4. `make install` 缺少 NEWS.rds

**现象**: `make install` 因缺少 `NEWS.rds` 失败。

**根因**: `NEWS.rds`、`NEWS.2.rds`、`NEWS.3.rds` 需要在安装前从 `NEWS.Rd` 生成。正常构建流程中这一步在安装阶段自动完成，但交叉编译环境下需要手动执行。

**修复**: 在 `build/doc/` 目录下用 R 生成：
```bash
echo 'options(warn=1);saveRDS(tools:::prepare_Rd(tools::parse_Rd(
  "../../src/R-4.4.3/doc/NEWS.Rd",
  macros = "../share/Rd/macros/system.Rd"), stages = "install",
  warningCalls = FALSE), "NEWS.rds")' | ../bin/R --vanilla --no-echo
# 同样生成 NEWS.2.rds, NEWS.3.rds
```

### 5. `make install` 缺少 Rscript.1 man page

**根因**: `help2man` 需要执行目标平台二进制来提取帮助信息，但交叉编译的 Rscript 无法在构建宿主机上运行（需要 HarmonyOS musl 动态链接器）。

**修复**: 创建最小 man page 存根。

### 6. ohos-lld-wrapper — musl $ORIGIN 不兼容

**现象**: configure 的链接测试全部失败——包括 readline、ncurses 等明明已安装的库。gfortran 和 OpenBLAS 测试也崩溃。

**根因**: 这是 configure 阶段最隐蔽的问题。HarmonyOS musl ld.so **不支持 `$ORIGIN` 标记**在 RUNPATH 中。lld 的 RUNPATH 设置为 `$ORIGIN/../lib`（指向 OHOS SDK 的 llvm/lib），但 musl 完全忽略该标记。结果 lld 运行时找不到自己的 libxml2.so.16，直接崩溃——不是库没装，是 lld 本身无法运行。所有需要链接器的测试因此全部失败。

**修复**: 创建 `ohos-lld-wrapper`，先设置 `LD_LIBRARY_PATH` 指向 OHOS LLVM lib，再 exec lld：

```sh
#!/bin/sh
LLVM_LIB=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/lib
export LD_LIBRARY_PATH="${LLVM_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec -a "ld.lld" "$LLVM_LIB/../bin/lld" --code-sign "$@"
```

关键细节：
- `exec -a "ld.lld"`：lld 是多合一二进制，argv[0] 决定其行为模式，"ld.lld" 触发 Unix 链接器模式
- `--code-sign`：生成 hmdfs 要求的 `.codesign` 段
- configure-R.sh 中使用 `-fuse-ld=/path/to/ohos-lld-wrapper`
- 配置脚本中 `LD_LIBRARY_PATH` 也需直接传给 configure 命令行（bash 导出的环境变量不总是传播到链接器子进程）

### 7. hmdfs 文件系统限制

**现象**: 静态链接的 ELF 文件无法执行（EACCES），bfd 链接的 `.so` 文件 `dlopen()` 失败，strip 后的二进制无法运行。

**根因**: HarmonyOS 的 hmdfs 分布式文件系统安全机制要求：
- ELF Type 必须为 **DYN (Shared object file)**——即 PIE 可执行文件
- 必须有 **`.codesign` section**：这是 hmdfs 的安全隔离标记，仅 lld 的 `--code-sign` 自动生成。bfd 不生成此段，导致 bfd 链接的 R.bin 无法被 `exec()`，bfd 链接的 `.so` 也无法 `dlopen()`
- 不能 strip：`llvm-strip` 在 hmdfs 上原地修改 ELF 时会破坏安全隔离上下文

**影响**: 这是整个移植最基础的要求——**必须使用 lld 链接器**。bfd 链接的文件在 hmdfs 上完全不可用。此前被错误归因为"seccomp 拦截子进程"，实际上 seccomp 确实拦截 `execv()`，但 hmdfs 拒绝对所有 bfd 产物的 exec/dlopen 是更根本的限制。

**验证**:
```bash
readelf -h binary | grep 'Type:'
# Type: DYN (Shared object file)

readelf -l binary | grep 'interpreter'
# [Requesting program interpreter: /lib/ld-musl-aarch64.so.1]

readelf -S binary | grep codesign
# 应有 .codesign section
```

**恢复 bfd 构建的排查经验**：如果误用 bfd 重建了 R.bin，hmdfs 会静默返回 EACCES，表现为主进程调 `system()` 或 `system2()` 不返回。这会波及所有子进程操作：`R CMD INSTALL`、`install.packages()`、编译器调用。切换回 lld 重新 `make install` 即可恢复。

### 8. OHOS libc 裁剪 — libohos_stubs 补齐库

**现象**: Rust 编译时或 R 包运行时遇到 `undefined symbol` 错误。

**根因**: OHOS 的 musl libc 是裁剪版，缺少部分标准符号。这些符号在标准 musl 和 glibc 中都存在，但 OHOS 移除了它们以减小体积。

**补齐方案**: `src/extra/ohos_stubs/ohos_stubs.c` 编译为两种形式：

| 场景 | 方式 | 符号 |
|---|---|---|
| Rust 编译时静态链接 | `libohos_stubs.a` | `posix_spawn_file_actions_addchdir_np`（返回 ENOSYS），`__xpg_strerror_r`（转发 strerror_r） |
| R 包运行时动态注入 | `libohos_stubs.so`（LD_PRELOAD） | 同上 + `pthread_setcanceltype`（返回 0），`pthread_cancel`（返回 0） |

**R 包场景**：`pthread_setcanceltype` 和 `pthread_cancel` 由 cli 包触发——进度条线程在卸载时调用这些函数。缺少时包加载失败。

**构建集成**：
- 源文件 `src/extra/ohos_stubs/ohos_stubs.c` 通过 `src/extra/Makefile.in` 的 `make.ohos_stubs` 目标自动编译
- `make && make install` 自动安装 `libohos_stubs.so` 到 `$(Rexeclibdir)`
- `etc/ldpaths.in` 自动生成 LD_PRELOAD 注入代码
- 注意 `-fvisibility=hidden` 会默认隐藏所有符号，需要在源文件中使用 `#pragma GCC visibility push(default)` 确保符号被导出

### 9. OpenBLAS 集成

**现象**: R 默认使用内部 reference BLAS（纯 Fortran 实现，无 SIMD 优化），大型矩阵运算性能低。

**修复**: 集成 harmonybrew 的 OpenBLAS 0.3.29（TARGET=ARMV8, USE_THREAD=1, gfortran 14.2.0）：

**configure 变更**：
```
--without-blas --without-lapack   →   --with-blas="-lopenblas" --with-lapack
```

**效果**：
- libR.so 直接链接 libopenblas.so.0（RUNPATH 已包含 harmonybrew/lib）
- `sessionInfo()` 显示 LAPACK: libopenblas_armv8p-r0.3.29.so (LAPACK v3.12.0)
- libRblas.so 仍作为内部 reference BLAS 存在但不再使用
- 1000x1000 矩阵乘法: 0.48s (~4.2 GFLOPs)，比 reference BLAS 快 10-15x

**OpenBLAS 交叉编译项目**: https://github.com/sxgou/openblas-harmonyos

### 10. `bin/exec/` 遗留文件导致多架构构建错误

**现象**: `R CMD INSTALL` 或 `install.packages()` 安装 R 包时报错：`make: *** No rule to make target 'fastmap.o'`，随后尝试 `*** arch - R.bfd`。

**根因**: `R CMD INSTALL` 默认启用 multiarch，扫描 `bin/exec/` 中的每个文件/目录视为子架构。若遗留了测试文件 `R.bfd`（BFD 链接器测试时生成），R 会为它尝试构建，但因 `etc/R.bfd/Makeconf` 不存在而失败。install.R 的检测逻辑为 `archs <- Sys.glob("*")`——它无法区分正式 R 可执行文件和遗留文件。

**修复**: `src/main/Makefile.in` 的 `install-bin` 目标自动删除 `bin/exec/` 中的非 R 文件：
```makefile
install-bin: installdirs
    @$(SHELL) $(top_srcdir)/tools/copy-if-change $(R_binary) "$(DESTDIR)$(Rexecbindir2)/R"
    @rm -f "$(DESTDIR)$(Rexecbindir2)/R.bfd" "$(DESTDIR)$(Rexecbindir2)/test-exec" "$(DESTDIR)$(Rexecbindir2)/test-sh"
```

验证：`make install` 后 `ls $R_HOME/bin/exec/` 应仅包含 `R`。

### 11. gzfile 压缩导致 vignette 安装失败

**现象**: `install.packages("jsonlite")` 编译成功、帮助索引安装完成，但在 `** installing vignettes` 步骤失败：`Error in readRDS(indexname) : unknown input format`。

**根因**: 
1. CRAN 包的 `build/vignette.rds` 使用 gzip 压缩
2. HarmonyOS 上 `gzfile()` 被 patch 为 `file()`（seccomp 拦截 zlib 操作），读取时不解压直接返回原始压缩字节
3. `readRDS()` 收到压缩字节，解析为 R 序列化格式时失败

**修复**: `src/library/tools/R/admin.R` 中 `.install_package_vignettes3` 的 `readRDS` 包装 fallback：
```r
vignetteIndex <- tryCatch(readRDS(indexname), error = function(e) {
    rawdata <- readBin(indexname, raw(), file.info(indexname)$size)
    decompressed <- memDecompress(rawdata, "gzip")
    unserialize(decompressed)
})
```

`memDecompress()` 使用 R 内置的 zlib 实现，不依赖 `gzfile` 连接，可绕过 seccomp 限制。

## 安装位置

| 组件 | 路径 |
|---|---|
| R Home | `~/.local/R/lib/R/` |
| R 二进制 | `~/.local/R/lib/R/bin/exec/R` |
| libR.so | `~/.local/R/lib/R/lib/libR.so` |
| Base 包 | `~/.local/R/lib/R/library/*/` |
| 包装脚本 | `~/.local/R/lib/R/bin/R` |

## 构建产物

| 产物 | 大小 | 说明 |
|---|---|---|
| libR.so | 3.2 MB | R 共享库 |
| R.bin | 22 KB | R 主执行体 (PIE) |
| Rscript | 24 KB | R 脚本前端 (PIE) |
| methods.rdb | 963 KB | methods 包懒加载数据 |
| methods.rdx | 23 KB | methods 包懒加载索引 |
| internet.so | 72 KB | 网络模块 |
| lapack.so | 47 KB | LAPACK C 包装 |
| libRlapack.so | 1.7 MB | LAPACK Fortran 实现 |
| libohos_stubs.so | — | libc 补齐库 |

## 验证

```bash
# 版本信息
LC_ALL=C /path/to/R/bin/R --version

# 启动并加载所有关键包
R_HOME=/path/to/R LC_ALL=C /path/to/R/bin/exec/R --vanilla --no-echo \
  -e 'library(methods); library(stats4); cat("OK\n")'

# 通过包装脚本
LC_ALL=C /path/to/R/bin/R --vanilla --no-echo \
  -e 'cat("R version:", R.version.string, "\n")'
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
