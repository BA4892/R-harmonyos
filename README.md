# R for HarmonyOS

支持多个 R 版本在 HarmonyOS (aarch64-linux-ohos) 平台的原生移植。

当前支持的 R 版本：

| 版本 | 状态 | 补丁 |
|------|------|------|
| 4.4.3 | ✓ 已测试验证 | `versions/4.4.3/patches/` (2 个) |
| 4.5.2 | ✓ 已测试验证 | `versions/4.5.2/patches/` (4 个) |
| 4.6.0 | ✓ 已测试验证 | `versions/4.6.0/patches/` (2 个) |

## 快速开始

```bash
# 第 1 步：克隆本项目
git clone https://github.com/sxgou/R-harmonyos.git
cd R-harmonyos

# 第 2 步：安装依赖库（brew 安装所有 R 需要的库）
bash build-deps.sh

# 第 3 步：下载 R 4.4.3 源码（也可下载 4.6.0）
curl -L https://cran.r-project.org/src/base/R-4/R-4.4.3.tar.gz | tar xz -C src/

# 第 4 步：配置（自动打补丁 + 交叉编译配置）。默认 4.4.3，可指定版本:
#   bash configure-R.sh          # 使用 R 4.4.3
#   bash configure-R.sh 4.6.0    # 使用 R 4.6.0
bash configure-R.sh

# 第 5 步：编译
cd build && make && make R

# 第 6 步：安装到 ~/.local/R/
make install

# 第 7 步：一键安装后处理（生成 methods 懒加载库 + NEWS.rds + 验证）
bash post-install-R.sh
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
├── src/                      # R 源码目录（从 CRAN 下载，不在 git 中）
│   ├── R-4.4.3/              #   R 4.4.3 源码
│   └── R-4.6.0/              #   R 4.6.0 源码
├── versions/                 # 各 R 版本的补丁和配置
│   ├── 4.4.3/
│   │   ├── patches/          #   2 个 HarmonyOS 补丁
│   │   │   ├── *.patch
│   │   │   └── new-files/    #   新增文件（ohos_stubs.c + Makefile.in）
│   │   └── apply-patches.sh  #   4.4.3 打补丁脚本
│   ├── 4.5.2/
│   │   ├── patches/          #   4 个 HarmonyOS 补丁
│   │   │   ├── *.patch
│   │   │   └── new-files/
│   │   └── apply-patches.sh  #   4.5.2 打补丁脚本（含 6 个内联 python 修复）
│   └── 4.6.0/
│       ├── patches/          #   2 个 HarmonyOS 补丁
│       │   ├── *.patch
│       │   └── new-files/
│       └── apply-patches.sh  #   4.6.0 打补丁脚本
├── doc/
│   └── BUILD-HarmonyOS.md    # 完整构建指南
├── apply-patches.sh          # 打补丁入口：bash apply-patches.sh [版本]
├── build-deps.sh             # 依赖库安装脚本
├── configure-R.sh            # 配置入口：bash configure-R.sh [版本]
├── post-install-R.sh         # 安装后处理：bash post-install-R.sh [版本]
└── README.md                 # 本文件
```

---

## 各脚本说明

| 脚本 | 何时运行 | 作用 |
|------|----------|------|
| `build-deps.sh` | 克隆项目后，第 1 步 | 通过 harmonybrew 安装 bzip2, curl, pcre2, cairo, pango, cmake, ninja 等依赖库和构建工具 |
| `apply-patches.sh [版本]` | 解压 R 源码后，可由 configure-R.sh 自动调用 | 对 `src/R-版本/` 应用对应版本的 HarmonyOS 补丁。`bash apply-patches.sh 4.6.0` |
| `configure-R.sh [版本]` | 打补丁后（自动调用 apply-patches.sh） | 配置交叉编译参数并运行 R 的 configure。默认 4.4.3，`bash configure-R.sh 4.6.0` |
| `post-install-R.sh [版本]` | `make install` 之后 | 生成 methods 懒加载库、NEWS.rds、验证安装完整性 |

所有脚本接受可选的版本参数。不指定则默认使用 R 4.4.3。

---

## 当前配置

| 选项 | 值 |
|------|-----|
| 目标平台 | aarch64-linux-ohos, HarmonyOS HongMeng Kernel 1.12.0 |
| 工具链 | OHOS SDK 26.0.0.18 (Clang 15.0.4) + [gfortran 14.2.0](https://github.com/sxgou/gfortran-harmonyos) |
| 链接器 | lld（hmdfs 要求 `.codesign` 段） |
| BLAS/LAPACK | [OpenBLAS 0.3.29](https://github.com/sxgou/openblas-harmonyos)（1000x1000 MM ~0.48s） |
| 包管理器 | [harmonybrew](https://gitcode.com/Harmonybrew/homebrew-harmony)（84 个 formula） |
| Cairo + Pango | 支持（brew cairo + pango，PNG/SVG/PDF 后端，Pango 文本布局增强） |
| readline | 启用（Tab 补全和方向键） |
| Java | BiSheng JDK 17 |

---

## 测试状态

| 功能 | 状态 |
|------|------|
| gzfile() / gzopen 压缩文件读写（zlib-ng-compat） | ✓ |
| saveRDS/readRDS 压缩序列化（gzip/bzip2/xz） | ✓ |
| memCompress/memDecompress 内存压缩/解压 | ✓ |
| PDF 设备 afm 字体指标加载 | ✓ |
| R REPL 交互式使用（readline Tab 补全） | ✓ |
| 全部 15 个 base 包构建通过 | ✓ |
| 12 个可加载包加载正常 | ✓ |
| 矩阵运算（OpenBLAS 优化） | ✓ 0.48s / 1000x1000 MM |
| 线性模型 / 方差分析 / MLE | ✓ |
| Fortran 数值例程 | ✓ |
| libcurl 网络 | ✓ |
| OpenMP 并行（20 核） | ✓ |
| `install.packages()` / `R CMD INSTALL` | ✓ |
| `Rscript` 脚本执行 | ✓ |
| ggplot2 + CairoPNG 渲染 | ✓ |
| Jupyter IRkernel | ✓ |

---

## 已知限制

- ~~**gzfile() / gzopen / R_compress1 / R_decompress1 不可用**~~ **已修复**（2026-06-02）：OHOS SDK 自带的 libz.so 使用被 seccomp 封锁的自定义 syscall。通过 `etc/ldpaths` 将 brew 的 `zlib-ng-compat` 路径加入 `LD_LIBRARY_PATH`，R 启动时自动加载 zlib-ng-compat 替代 SDK libz，所有压缩/解压接口恢复正常。详见 [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md) 第 12 节。
- **无 X11 / Tcl/Tk**：HarmonyOS 无相关支持
- **ELF 不可 strip**：hmdfs 安全隔离上下文被破坏

---

*详细构建说明见 [doc/BUILD-HarmonyOS.md](doc/BUILD-HarmonyOS.md)*
