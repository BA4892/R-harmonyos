# R for HarmonyOS

R 4.4.3 移植到 HarmonyOS (OpenHarmony) 原生平台。

## 项目结构

```
├── build/                # 构建输出目录（已编译的 R）
│   ├── bin/R             # R 主程序
│   ├── bin/exec/R        # R 独立可执行文件
│   ├── bin/install-package # 包安装脚本（内部）
│   ├── bin/rharmonyos    # HarmonyOS 启动包装器（内部）
│   ├── lib/              # 共享库 (libR.so, libRblas.so, libRlapack.so)
│   └── library/          # 已安装的 R 包（15 个基础包）
├── src/R-4.4.3/          # R 4.4.3 原始源代码（已打补丁）
├── build-deps.sh         # 构建依赖脚本
├── configure-R.sh        # R 配置脚本
├── install-package       # 包安装脚本（便捷包装器）
├── rharmonyos            # R 启动包装器（便捷包装器）
├── batch-fix-v5.sh       # 批量编译缺失的 .so 文件（针对已有依赖的包）
├── build-fix-so.sh       # 通用批量编译脚本（含 Makevars 变量展开）
├── doc/                  # 文档
```

## 构建方法

### 前置条件

- OHOS SDK 26.0.0.18 (Clang 15.0.4)
- HarmonyOS 原生 gfortran 交叉编译器
- 必要的依赖库 (pcre2, lzma, bz2, zlib)

### 配置

```bash
./configure-R.sh
```

### 构建

```bash
cd build && make
```

## HarmonyOS 兼容性

### 解决的问题


| 问题                            | 解决方案                                                   |
| ------------------------------- | ---------------------------------------------------------- |
| 无`/tmp` 目录                   | 设置`TMPDIR=/var/tmp` 或项目 `tmp/`                        |
| Seccomp 过滤器阻止`R_compress1` | 所有懒加载 DB 使用`compress=FALSE`                         |
| musl libc vs glibc 不兼容       | 静态链接 libgcc.a，不使用 libgcc_s.so.1                    |
| 无`which`/`rm`/`cmp` 命令       | 通过`PATH` 暴露标准工具路径                                |
| Seccomp 阻止 R 创建子进程       | `R CMD INSTALL` 不可用；使用专用脚本 `bin/install-package` |

### 关键补丁

- `src/R-4.4.3/src/main/connections.c` — `gzfile()` 改用 `file()`
- `src/R-4.4.3/src/library/methods/R/zzz.R` — 移除运行时 `makeLazyLoadDB` 调用（防止 .rdb 文件被截断导致"unknown input format"错误）
- `src/R-4.4.3/share/make/lazycomp.mk` — 所有包使用 `compress=FALSE`
- `src/R-4.4.3/share/make/basepkg.mk` — sysdata 使用 `compress=FALSE`
- `build/backtrace_stub.c` — libbacktrace 存根，满足 gfortran 静态库的链接需求
- `build/etc/Makeconf` — 静态链接 libgfortran.a + libgcc.a + libgcc_eh.a，避免加载 libgcc_s.so.1

## 使用

```bash
# 使用便捷包装器启动（推荐）
./rharmonyos

# 或手动设置环境变量
export TMPDIR=/path/to/build/tmp
export R_HOME_DIR=/path/to/build
export LD_LIBRARY_PATH=/path/to/build/lib
./build/bin/R

# 运行 R 脚本
./rharmonyos -e 'print(1+1)'

# 安装额外 R 包（见下方"安装包"章节）
./install-package /path/to/package_source
```

### 安装包

HarmonyOS 的 seccomp 安全策略阻止 R 创建子进程，因此 `R CMD INSTALL` 和 `install.packages()` 不可用。使用以下脚本安装源码包：

```bash
./install-package /path/to/package_source
```

此脚本会在当前 R 进程内完成全部安装步骤：

1. 复制包源文件到库目录
2. 调用 `tools:::.install_package_description()` 创建 `Meta/package.rds` 和 `Meta/features.rds`
3. 调用 `tools:::makeLazyLoading(compress=FALSE)` 创建懒加载数据库
   以上步骤均在同一 R 进程中执行，无需创建子进程。

## 测试状态

以下功能已通过验证（R 4.4.3 on HarmonyOS 1.12.0, aarch64）：


| 功能                         | 状态                             |
| ---------------------------- | -------------------------------- |
| R REPL 交互式使用            | ✓ 通过                          |
| 基础运算（算术、矩阵）       | ✓ 通过                          |
| 线性模型 lm()                | ✓ 通过                          |
| 方差分析 aov()               | ✓ 通过                          |
| 特征值分解 eigen()           | ✓ 通过                          |
| S4 类系统                    | ✓ 通过                          |
| 所有 13 个可加载基础包加载   | ✓ 通过                          |
| Fortran 数值例程（det 等）   | ✓ 通过                          |
| OpenMP 并行（detectCores）   | ✓ 通过                          |
| `methods` 包启动             | ✓ 通过（partial=TRUE 引导修复） |
| `install-package` 脚本安装包 | ✓ 通过                          |
| `rharmonyos` 包装器          | ✓ 通过                          |

## 已知限制

- **gzfile() 不可用**：Seccomp 过滤了 zlib 压缩操作。包安装需要设置 `compress=FALSE`
- **`system()` 不可用**：R 无法通过 `system()` / `system2()` 创建子进程（seccomp 限制）
- **`install.packages()` 不可用**：安装包需使用 `install-package` 脚本
- **`R CMD INSTALL` 不可用**：原因同上，所有子进程创建均被拦截
- **`library()` pager 报错**：`pager` 命令无法通过子进程执行（seccomp 限制），但不影响 R 的正常使用
- **`Sys.which("uname")` 警告**：startup 时提示 `which` 未找到，不影响 R 运行
- **无 Tcl/Tk**：配置时使用 `--without-tcltk`
- **Cairo 不支持**：fontconfig 仅在受限的存根中可用，缺少完整的字体匹配功能
- **无 Java**：配置时使用 `--disable-java`
- **无 readline**：配置时使用 `--without-readline`
- **无 X11**：配置时使用 `--without-x`

## 批量编译 R 包 .so 文件

HarmonyOS 使用 seccomp 安全策略，`R CMD INSTALL` 和 `install.packages()` 不可用。安装 R 包后，通常缺少编译后的 `.so` 共享库。使用批量脚本可以编译这些 `.so` 文件。

### 使用方法

```bash
# 批量编译已知可编译的包
./batch-fix-v5.sh

# 或针对所有包运行完整编译脚本
./build-fix-so.sh
```

### 已编译的包

以下包的 `.so` 文件已通过 `batch-fix-v5.sh` 成功编译：

| 包 | 大小 | 说明 |
|---|---|---|
| jsonlite | 78K | JSON 解析（含 bundled yajl） |
| commonmark | 350K | CommonMark Markdown 渲染（含 bundled cmark-gfm） |
| brotli | 582K | Brotli 压缩算法（含 bundled enc 静态库） |
| colourvalues | 1.2M | 颜色值转换（Rcpp） |
| haven | 463K | 读取 SPSS/Stata/SAS 文件（含 bundled readstat） |
| parsermd | 1.2M | R Markdown 解析器（Rcpp, Boost Spirit X3, C++17） |
| lqmm | 18K | 线性分位数混合模型（含 Fortran 代码） |
| frailtypack | 2.7M | 共享脆弱模型和联合模型（大量 Fortran 代码） |
| ggforce | 631K | ggplot2 扩展（预编译） |
| fs | 219K | 文件系统操作（预编译） |
| Rmpfr | 674K | 多精度浮点数运算（需 GMP + MPFR） |
| jpeg | 530K | JPEG 图像读取（需 libjpeg-turbo） |
| Rglpk | 814K | 线性规划求解（需 GLPK） |
| RODBC | 454K | ODBC 数据库连接（需 unixODBC） |

### 常见编译失败原因

| 原因 | 示例包 |
|---|---|
| 缺少外部系统库（GDAL, MySQL, PostgreSQL, NetCDF, V8 等） | sf, RMySQL, RPostgreSQL, RNetCDF, V8 |
| libxml2 API 不兼容（`xmlAttr.val` 改为 `children`） | XML |
| 缺少系统调用（`getpass`, `_res` 等 musl 不支持的 API） | askpass, pingr |
| 需要 fontconfig 完整实现（仅有存根） | Cairo |
| 缺少 R 依赖包（zigg, bigmemory 等未安装） | Rfast, fastglm |
| C++ 标准库兼容性（OHOS SDK libc++ 限制） | geosphere |
| JSON 库 API 不匹配（bundled libjson 版本问题） | RJSONIO |

## R 核心系统库依赖

R 核心编译和运行时所需的系统库（非 R 包依赖）：

| 类别 | 库 | 链接方式 | 来源 |
|------|-----|---------|------|
| 压缩 | zlib | 动态 (libz.so) | OHOS SDK sysroot |
| 压缩 | bzip2 | 静态 (libbz2.a) | ~/.local/R-deps |
| 压缩 | liblzma (XZ) | 静态 (liblzma.a) | ~/.local/R-deps |
| 正则 | PCRE2 | 静态 (libpcre2-8.a) | ~/.local/R-deps |
| 网络 | libcurl + OpenSSL | 静态 (libcurl.a+libssl.a) | ~/.local/R-deps |
| 编码 | iconv | musl libc 内置 | OHOS SDK sysroot |
| 并行 | libomp (OpenMP) | 动态 (libomp.so) | OHOS SDK llvm |
| Fortran | libgfortran+libgcc | 静态 (libgfortran.a等) | gfortran 安装目录 |

## 外部系统库（R 包支持）

以下系统库已为 HarmonyOS aarch64 交叉编译并安装到 `~/.local/R-deps`，供 R 包编译时链接：

| 库 | 版本 | 大小 | 用途 |
|---|---|---|---|
| GMP | 6.3.0 | 1.0M | 多精度算术库 |
| MPFR | 4.2.1 | 1.0M | 多精度浮点运算 |
| libjpeg-turbo | 3.0.4 | 665K | JPEG 图像编解码 |
| GLPK | 5.0 | 1.8M | 线性规划求解器 |
| unixODBC | 2.3.12 | 1.0M | ODBC 数据库连接 |
| expat | 2.6.2 | 206K | XML 解析器 |
| fontconfig | 2.15.0 | 473K | 字体配置（仅静态库，工具未编译） |
| freetype | 2.13.2 | 1.2M | 字体渲染引擎 |
| libpng16 | 1.6.x | 424K | PNG 图像编解码 |
| libxml2 | 2.x | 2.9M | XML 处理库 |
| cairo | 1.16.0 | 1.7M | 2D 图形库（无 X11 时功能受限） |
| pixman | 0.42.2 | 553K | 像素操作库（cairo 依赖） |
| fftw3 | 3.x | 1.6M | FFT 库（含单精度 fftw3f） |
| GEOS | 3.12.0 | 10.6M | 几何引擎（sf 包依赖） |
| ANN | - | 136K | 近似最近邻搜索 |

构建脚本位于 `ohos-libs/scripts/build-all-simple.sh`，该脚本自动处理 HarmonyOS 特有的问题：
- `/tmp` 只读 → 设置 `WORK` 到用户目录
- `config.status` 中 `mktemp` 不可用 → 通过 `--no-create` + 手动修补或 `mktemp` 包装器解决
- `print -r --` 在 POSIX shell 中不可用 → sed 替换为 `echo`
- `rm` 命令不可用 → 忽略 `rm` 错误
