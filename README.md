# R for HarmonyOS

R 4.4.3 移植到 HarmonyOS (aarch64-linux-ohos) 原生平台。

## 项目结构

```
├── build/                    # 构建输出
├── src/R-4.4.3/              # R 4.4.3 源代码（从 CRAN 下载，运行 apply-patches.sh 打补丁）
├── patches/                  # HarmonyOS 适配补丁
│   ├── *.patch               # 14 个源码修改补丁
│   └── new-files/            # 新增文件（ohos_stubs.c + Makefile.in）
├── apply-patches.sh          # 打补丁脚本（被 configure-R.sh 自动调用）
├── build-deps.sh             # 依赖库安装脚本（可选）
├── configure-R.sh            # 配置脚本（自动打补丁 + 交叉编译配置）
├── BUILD-HarmonyOS.md        # 完整构建指南（必读）
└── doc/
```

## 快速开始

```bash
# 1. 安装依赖库（详见 BUILD-HarmonyOS.md 第 2 步）
bash build-deps.sh

# 2. 下载 R 源码
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/

# 3. 配置（自动调用 apply-patches.sh 打补丁）
bash configure-R.sh

# 4. 编译
cd build && make && make R

# 5. 安装
make install

# 6. 安装后处理（生成 methods 懒加载库等）
echo 'tools:::makeLazyLoading("methods", compress = FALSE)' | \
  R_DEFAULT_PACKAGES=NULL LC_ALL=C ./bin/R --vanilla --no-echo
```

**完整构建指南**（含工具链准备、已知问题、排错）请阅读 [BUILD-HarmonyOS.md](BUILD-HarmonyOS.md)。

## 使用

安装后通过 R 包装脚本启动：

```bash
~/.local/R/lib/R/bin/R -e 'print(1+1)'
~/.local/R/lib/R/bin/R --vanilla -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'
```

## 当前配置

| 选项 | 值 |
|------|-----|
| 目标平台 | aarch64-linux-ohos, HarmonyOS HongMeng Kernel 1.12.0 |
| 工具链 | OHOS SDK 26.0.0.18 (Clang 15.0.4) + gfortran 14.2.0 |
| 链接器 | lld（hmdfs 要求 `.codesign` 段） |
| BLAS/LAPACK | OpenBLAS 0.3.29（1000x1000 MM ~0.48s） |
| Cairo | 支持（PNG/SVG/PDF 后端） |
| readline | 启用（Tab 补全和方向键） |
| Java | BiSheng JDK 17 |

## HarmonyOS 兼容性

| 问题 | 原因 | 解决 |
|------|------|------|
| 无 `/tmp` | seccomp 限制 | 设置 `TMPDIR` 到用户目录 |
| `gzfile()` 不可用 | seccomp 过滤 zlib 操作 | patch 为 `file()`，预压缩文件通过 `memDecompress()` fallback |
| `Rscript` 不可用 | seccomp 阻止 `execv()` | 改用 `R --vanilla -e` |
| hmdfs 拒绝无 `.codesign` 的 ELF | 分布式文件系统安全要求 | 使用 lld 链接（自动生成 `.codesign`） |
| musl libc 裁剪 | OHOS 裁剪版缺少部分符号 | 编译 `libohos_stubs.so`，LD_PRELOAD 注入 |
| readline 配置时链接测试失败 | lld 因 musl 不支持 `$ORIGIN` 无法运行 | 创建 `ohos-lld-wrapper`，设置 `LD_LIBRARY_PATH` 后 exec lld |
| 无 X11 / Tcl/Tk | HarmonyOS 无相关支持 | `--without-x --without-tcltk` |
| 交叉编译 man page | `help2man` 无法执行目标二进制 | 创建 man page 存根 |

## 测试状态

| 功能 | 状态 |
|------|------|
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
- **Cairo PNG/SVG/PDF**：可用（brew cairo + fontconfig 完整支持）。X11 后端不可用（无 X server）
- **无 X11 / Tcl/Tk**
- **ELF 不可 strip**：hmdfs 安全隔离上下文被破坏
