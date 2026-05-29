# R for HarmonyOS

R 4.4.3 移植到 HarmonyOS (aarch64-linux-ohos) 原生平台。

## 项目结构

```
├── build/                  # 构建输出
├── src/R-4.4.3/            # R 4.4.3 源代码（已打补丁）
│   └── src/extra/ohos_stubs/ohos_stubs.c  # libc 补齐库
├── configure-R.sh          # 配置脚本
├── rharmonyos              # R 启动包装器
├── install-package         # 包安装脚本
├── BUILD-HarmonyOS.md      # 构建指南与已知问题
└── doc/                    # 文档
```

## 构建

```bash
./configure-R.sh
cd build && make && make R && make install
```

安装到 `~/.local/R/lib/R/`，包含全部 15 个 base 包。

### 前置条件

- OHOS SDK 26.0.0.18 (Clang 15.0.4)
- gfortran 交叉编译器（[gfortran-harmonyos](https://github.com/sxgou/gfortran-harmonyos)）
- 依赖库通过 [harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony) 安装
- 个别库（fftw, zeromq, ANN, mpfr）仍在 `~/.local/R-deps`

### 当前配置

| 选项 | 值 |
|---|---|
| 链接器 | `-fuse-ld=ohos-lld-wrapper` |
| BLAS/LAPACK | OpenBLAS 0.3.29（harmonybrew，1000x1000 MM ~0.48s） |
| readline | 启用（brew libreadline + ncurses，Tab 补全和方向键可用） |
| Java | BiSheng JDK 17 |
| 交叉编译 | x86_64 → aarch64-pc-linux-musl |

## 使用

```bash
./rharmonyos                          # R REPL
./rharmonyos -e 'print(1+1)'         # 运行表达式
./rharmonyos --vanilla -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'
./install-package /path/to/pkg       # 传统单进程安装
```

## HarmonyOS 兼容性

| 问题 | 原因 | 解决 |
|---|---|---|
| 无 `/tmp` | seccomp 限制 | 设置 `TMPDIR` 到用户目录 |
| `gzfile()` 不可用 | seccomp 过滤 zlib 操作 | patch 为 `file()`，预压缩文件通过 `memDecompress()` fallback |
| `Rscript` 不可用 | seccomp 阻止 `execv()` | 改用 `R --vanilla -e` 或包装脚本 |
| hmdfs 拒绝无 `.codesign` 的 ELF | 分布式文件系统安全要求 | 使用 lld 链接（自动生成 `.codesign`） |
| musl libc 裁剪 | OHOS 裁剪版缺少部分符号 | 编译 `libohos_stubs.so`，LD_PRELOAD 注入 |
| readline 配置时链接测试失败 | lld 因 musl 不支持 `$ORIGIN` 无法运行 | 创建 `ohos-lld-wrapper`，设置 `LD_LIBRARY_PATH` 后 exec lld |
| 无 X11 / Tcl/Tk | HarmonyOS 无相关支持 | `--without-x --without-tcltk` |
| 交叉编译 man page | `help2man` 无法执行目标二进制 | 创建 man page 存根 |

## 测试状态

| 功能 | 状态 |
|---|---|
| R REPL 交互式使用（readline Tab 补全） | ✓ |
| 全部 15 个 base 包构建通过 | ✓ |
| 12 个可加载包加载正常 | ✓ |
| 矩阵运算（OpenBLAS 优化） | ✓ 0.48s / 1000x1000 MM |
| 线性模型 / 方差分析 / MLE | ✓ |
| Fortran 数值例程 | ✓ |
| libcurl 网络 | ✓ |
| OpenMP 并行（20 核） | ✓ |
| `install.packages()` / `R CMD INSTALL` | ✓ |
| ggplot2 + CairoPNG 渲染 | ✓ |
| Jupyter IRkernel | ✓ |

## 已知限制

- **gzfile() 不可用**：seccomp 过滤 zlib。包安装需 `compress=FALSE`；预压缩 vignette.rds 通过 `memDecompress()` + `unserialize()` 变通读取
- **Rscript 不可用**：seccomp 阻止 `execv()`，`Rscript -e` 返回 Permission denied
- **Cairo 包无 fontconfig**：brew fontconfig 仅存根，需静态链接 Cairo + 禁用 FreeType
- **无 X11 / Tcl/Tk**
- **ELF 不可 strip**：hmdfs 安全隔离上下文被破坏
