#!/bin/bash

# 实物控制器启动脚本：按系统架构选择控制器和动态库目录。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config.yaml"
EXTRA_ARGS=()

usage() {
    echo "用法: $0 [选项] [控制器参数...]"
    echo ""
    echo "选项:"
    echo "  --config FILE    指定配置文件路径（默认: config.yaml）"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo "架构选择:"
    echo "  x86_64           使用 bin/ybt_ctrl 和 lib/"
    echo "  aarch64/arm64    使用 bin_rk3588/ybt_ctrl 和 lib_rk3588/"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            if [ $# -lt 2 ]; then
                echo "错误: --config 需要指定文件路径"
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ "$CONFIG_FILE" != /* ]]; then
    CONFIG_FILE="${PROJECT_ROOT}/${CONFIG_FILE}"
fi

HOST_ARCH="$(uname -m)"
ARCH_LABEL=""
CONTROLLER_EXE=""
LIB_DIR=""

case "$HOST_ARCH" in
    x86_64)
        ARCH_LABEL="x86_64"
        CONTROLLER_EXE="${PROJECT_ROOT}/bin/ybt_ctrl"
        LIB_DIR="${PROJECT_ROOT}/lib"
        ;;
    aarch64|arm64)
        ARCH_LABEL="RK3588/aarch64"
        CONTROLLER_EXE="${PROJECT_ROOT}/bin_rk3588/ybt_ctrl"
        LIB_DIR="${PROJECT_ROOT}/lib_rk3588"
        ;;
    *)
        echo "错误: 不支持的系统架构: $HOST_ARCH"
        echo "当前分发包仅支持 x86_64 和 aarch64/arm64 (RK3588)"
        exit 1
        ;;
esac

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

if [ ! -f "$CONTROLLER_EXE" ]; then
    echo "错误: 找不到当前架构对应的控制器: $CONTROLLER_EXE"
    exit 1
fi

if [ ! -d "$LIB_DIR" ]; then
    echo "错误: 找不到当前架构对应的动态库目录: $LIB_DIR"
    exit 1
fi

cd "$PROJECT_ROOT"

# enable multicast and add route for lcm out the top
# sudo ifconfig enxa0cec80e3ced multicast
# sudo route add -net 224.0.0.0 netmask 240.0.0.0 dev enxa0cec80e3ced
sudo ifconfig eth1 multicast
sudo route add -net 224.0.0.0 netmask 240.0.0.0 dev eth1 2>/dev/null || true

EXISTING_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
EXISTING_LD_LIBRARY_PATH="${EXISTING_LD_LIBRARY_PATH#:}"
if [ -n "$EXISTING_LD_LIBRARY_PATH" ]; then
    RUNTIME_LD_LIBRARY_PATH="${LIB_DIR}:${EXISTING_LD_LIBRARY_PATH}"
else
    RUNTIME_LD_LIBRARY_PATH="${LIB_DIR}"
fi

echo "=========================================="
echo "启动实物控制器"
echo "=========================================="
echo "系统架构: $HOST_ARCH ($ARCH_LABEL)"
echo "项目根目录: $PROJECT_ROOT"
echo "可执行文件: $CONTROLLER_EXE"
echo "配置文件: $CONFIG_FILE"
echo "库路径: $LIB_DIR"
echo "LCM 网卡: eth1"
echo "=========================================="
echo ""

sudo env LD_LIBRARY_PATH="$RUNTIME_LD_LIBRARY_PATH" "$CONTROLLER_EXE" --config "$CONFIG_FILE" "${EXTRA_ARGS[@]}"
