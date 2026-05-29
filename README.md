# R for HarmonyOS

R 4.4.3 移植到 HarmonyOS (aarch64-linux-ohos) 原生平台。

## 快速开始

```bash
# 第 1 步：克隆本项目
git clone https://github.com/sxgou/R-harmonyos.git
cd R-harmonyos

# 第 2 步：安装依赖库（brew 安装所有 R 需要的库）
bash build-deps.sh

# 第 3 步：下载 R 4.4.3 源码
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/

# 第 4 步：配置（自动对 R 源码打 HarmonyOS 补丁 + 交叉编译配置）
bash configure-R.sh

# 第 5 步：编译
cd build && make && make R

# 第 6 步：安装到 ~/.local/R/
make install

# 第 7 步：生成 methods 包懒加载数据库（必需，否则 stats4 等包无法加载）
echo 'tools:::makeLazyLoading("methods", compress = FALSE)' | \
  R_DEFAULT_PACKAGES=NULL LC_ALL=C ./bin/R --vanilla --no-echo
```

> **注意**：以上步骤假设你已准备好 HarmonyOS 交叉编译工具链（OHOS SDK Clang + gfortran + lld 包装器）。如果尚未准备，请先阅读完整构建指南。

**完整构建指南**（含工具链准备、环境要求、已知问题、排错方法）：[doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md)

---

## 使用

安装后通过 R 包装脚本启动：

```bash
~/.local/R/lib/R/bin/R                          # 进入 R REPL
~/.local/R/lib/R/bin/R -e 'print(1+1)'          # 直接运行表达式
~/.local/R/lib/R/bin/R --vanilla -e \
  'install.packages("jsonlite", repos="https://cloud.r-project.org")'
```

---

## 项目结构

```
├── build/                    # 构建输出（编译结果）
├── src/R-4.4.3/              # R 4.4.3 源码（需从 CRAN 下载，运行脚本后被打补丁）
├── patches/                  # HarmonyOS 适配补丁
│   ├── *.patch               #   14 个源码修改补丁
│   └── new-files/            #   新增文件（ohos_stubs.c + Makefile.in）
├── doc/
│   └── BUILD-HarmonyOS.md    # 完整构建指南（从这里开始看）
├── apply-patches.sh          # 打补丁脚本（configure-R.sh 自动调用）
├── build-deps.sh             # 依赖库安装脚本（第 2 步运行）
├── configure-R.sh            # 配置脚本（第 4 步运行，自动打补丁 + 交叉编译配置）
└── README.md                 # 本文件
```

---

## 各脚本说明

| 脚本 | 何时运行 | 作用 |
|------|----------|------|
| `build-deps.sh` | 克隆项目后，第 1 步 | 通过 harmonybrew 安装 bzip2, curl, pcre2, cairo, openblas 等依赖库 |
| `apply-patches.sh` | 解压 R 源码后，可由 configure-R.sh 自动调用 | 对 src/R-4.4.3/ 应用 14 个 HarmonyOS 补丁 + 安装新增文件 |
| `configure-R.sh` | 打补丁后（自动调用 apply-patches.sh） | 配置交叉编译参数并运行 R 的 configure |

---

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

---

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

---

## 已知限制

- **gzfile() 不可用**：seccomp 过滤 zlib。包安装需 `compress=FALSE`；预压缩 vignette.rds 通过 `memDecompress()` + `unserialize()` 变通读取
- **Rscript 不可用**：seccomp 阻止 `execv()`，`Rscript -e` 返回 Permission denied
- **无 X11 / Tcl/Tk**：HarmonyOS 无相关支持
- **ELF 不可 strip**：hmdfs 安全隔离上下文被破坏

---

*详细构建说明见 [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md)*
