#!/bin/sh
# R for HarmonyOS 安装后处理脚本
# 在 make install 之后运行，一键解决所有安装后问题。
#
# 用法: cd /path/to/R-harmonyos && bash post-install-R.sh
#
# 执行内容:
#   1. 生成 methods 包懒加载数据库（必需，否则 stats4 等包无法加载）
#   2. 生成 NEWS.rds / NEWS.2.rds / NEWS.3.rds（缺少时 make install 会失败）
#   3. 验证安装完整性

set -e

# ------ 配置 ------
# R_HOME 自动检测（优先已安装路径，其次 build 路径）
if [ -x "$HOME/.local/R/lib/R/bin/R" ]; then
    R_BIN="$HOME/.local/R/lib/R/bin/R"
    R_HOME="$HOME/.local/R/lib/R"
elif [ -x "build/bin/R" ]; then
    R_BIN="$(pwd)/build/bin/R"
    R_HOME="$(pwd)/build"
else
    echo "Error: 找不到 R 可执行文件。请先运行 make install 或确认编译已完成。"
    echo "  查找位置: $HOME/.local/R/lib/R/bin/R"
    echo "           build/bin/R"
    exit 1
fi

BUILD_DIR="$(pwd)/build"
R_SRC="$(pwd)/src/R-4.4.3"

echo "=== R for HarmonyOS 安装后处理 ==="
echo "R 可执行文件: $R_BIN"
echo "R_HOME:       $R_HOME"
echo "构建目录:     $BUILD_DIR"
echo ""

# ------ 1. 生成 methods 包懒加载数据库 ------
echo "--- [1/3] 生成 methods 包懒加载数据库 ---"
METHODS_DIR="$R_HOME/library/methods/R"
if [ -f "$METHODS_DIR/methods.rdb" ] && [ -f "$METHODS_DIR/methods.rdx" ]; then
    echo "  [跳过] methods 懒加载数据库已存在:"
    echo "    $METHODS_DIR/methods.rdb"
    echo "    $METHODS_DIR/methods.rdx"
else
    echo 'tools:::makeLazyLoading("methods", compress = FALSE)' | \
        R_DEFAULT_PACKAGES=NULL LC_ALL=C "$R_BIN" --vanilla --no-echo
    echo "  [完成] methods 懒加载数据库已生成"
fi
echo ""

# ------ 2. 生成 NEWS.rds ------
echo "--- [2/3] 生成 NEWS.rds ---"
if [ ! -d "$BUILD_DIR/doc" ]; then
    echo "  [跳过] $BUILD_DIR/doc 不存在，跳过 NEWS.rds 生成"
    echo "  （make install 可能需要手动处理）"
else
    cd "$BUILD_DIR/doc"

    for news_rd in NEWS.Rd NEWS.2.Rd NEWS.3.Rd; do
        news_rds="${news_rd%.Rd}.rds"
        if [ -f "$news_rds" ]; then
            echo "  [跳过] $news_rds 已存在"
            continue
        fi
        # 检查源文件是否存在
        src_rd="../../src/R-4.4.3/doc/$news_rd"
        if [ ! -f "$src_rd" ]; then
            echo "  [跳过] $src_rd 不存在"
            continue
        fi
        echo "  生成 $news_rds ..."
        LC_ALL=C "$R_BIN" --vanilla --no-echo -e \
            'options(warn=1); saveRDS(tools:::prepare_Rd(tools::parse_Rd(
              "'"$src_rd"'",
              macros = "../share/Rd/macros/system.Rd"), stages = "install",
              warningCalls = FALSE), "'"$news_rds"'")' 2>/dev/null || \
        echo "  [警告] $news_rds 生成失败（make install 可能会重试）"
    done

    cd "$(pwd)"  # 回到原始目录
    echo "  [完成] NEWS.rds 处理完毕"
fi
echo ""

# ------ 3. 验证安装完整性 ------
echo "--- [3/3] 验证安装完整性 ---"
ERRORS=0

check_file() {
    local file="$1" desc="$2"
    if [ -f "$file" ]; then
        echo "  [OK] $desc"
    else
        echo "  [ERR] $desc: 缺少 $file"
        ERRORS=$((ERRORS + 1))
    fi
}

check_file "$R_HOME/bin/exec/R" "R 主二进制"
check_file "$R_HOME/lib/libR.so" "libR.so"
check_file "$R_HOME/library/base/R/base" "base 包"
check_file "$R_HOME/library/methods/R/methods" "methods 包 (nspackloader)"
check_file "$R_HOME/library/methods/R/methods.rdb" "methods.rdb"
check_file "$R_HOME/library/methods/R/methods.rdx" "methods.rdx"
check_file "$R_HOME/library/stats/R/stats" "stats 包"
check_file "$R_HOME/library/graphics/R/graphics" "graphics 包"
check_file "$R_HOME/library/grDevices/R/grDevices" "grDevices 包"
check_file "$R_HOME/library/utils/R/utils" "utils 包"
check_file "$R_HOME/lib/libohos_stubs.so" "libohos_stubs.so"

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== 安装后处理全部完成，验证通过 ==="
else
    echo "=== 完成（$ERRORS 个文件缺失，请检查上述 [ERR] 项）==="
fi
