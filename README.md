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
└── doc/                  # 文档
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
- **无 Cairo/PNG/JPEG/TIFF**：配置时使用 `--without-cairo --without-libpng --without-jpeglib --without-libtiff`
- **无 Java**：配置时使用 `--disable-java`
- **无 readline**：配置时使用 `--without-readline`
- **无 X11**：配置时使用 `--without-x`
