#!/bin/bash
#
# 创建 Quad48_Controller 风格的一键分发包
# 默认输出到 build/Quad48_Controller
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${1:-${PROJECT_ROOT}/build/Quad48_Controller}"
BUILD_OUTPUT_DIR="${PROJECT_ROOT}/build/robot-software/build"
REFERENCE_DIR="${PROJECT_ROOT%/quad48-rl-control-framework-rk3588_0602}/Quad48_Controller"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Create Quad48_Controller Bundle${NC}"
echo -e "${CYAN}========================================${NC}"
echo "Project root : ${PROJECT_ROOT}"
echo "Output dir   : ${OUTPUT_DIR}"
echo "Reference dir: ${REFERENCE_DIR}"
echo ""

if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    echo -e "${RED}错误: 找不到构建产物目录: ${BUILD_OUTPUT_DIR}${NC}"
    exit 1
fi

if [ ! -f "${BUILD_OUTPUT_DIR}/ybt_ctrl" ]; then
    echo -e "${RED}错误: 找不到控制器二进制: ${BUILD_OUTPUT_DIR}/ybt_ctrl${NC}"
    exit 1
fi

copy_dir() {
    local src="$1"
    local dst="$2"

    if [ ! -e "${src}" ]; then
        echo -e "${YELLOW}警告: 缺少目录 ${src}${NC}"
        return 0
    fi

    mkdir -p "$(dirname "${dst}")"
    rm -rf "${dst}"
    cp -a "${src}" "${dst}"
    echo "  copied dir  : ${src}"
}

copy_file_if_exists() {
    local src="$1"
    local dst="$2"

    if [ -f "${src}" ]; then
        mkdir -p "$(dirname "${dst}")"
        cp -f "${src}" "${dst}"
        echo "  copied file : ${src}"
    else
        echo -e "${YELLOW}警告: 缺少文件 ${src}${NC}"
    fi
}

copy_onnxruntime_libs() {
    local arch
    local onnx_lib_dir=""

    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64)
            onnx_lib_dir="${PROJECT_ROOT}/third-party/onnx_x64/lib"
            ;;
        aarch64|arm64|arm*)
            onnx_lib_dir="${PROJECT_ROOT}/third-party/onnx_arm/lib"
            ;;
        *)
            echo -e "${YELLOW}警告: 未识别架构 ${arch}，跳过 ONNX Runtime 库自动复制${NC}"
            return 0
            ;;
    esac

    if [ ! -d "${onnx_lib_dir}" ]; then
        echo -e "${YELLOW}警告: 缺少 ONNX Runtime 库目录 ${onnx_lib_dir}${NC}"
        return 0
    fi

    find "${onnx_lib_dir}" -maxdepth 1 \( -type f -o -type l \) -name 'libonnxruntime*.so*' \
        -exec cp -a {} "${OUTPUT_DIR}/lib/" \;

    if [ ! -e "${OUTPUT_DIR}/lib/libonnxruntime.so.1" ]; then
        local main_lib
        main_lib="$(find "${OUTPUT_DIR}/lib" -maxdepth 1 -type f -name 'libonnxruntime.so.1.*' \
            -printf '%f\n' | sort -V | tail -n 1)"
        if [ -n "${main_lib}" ]; then
            ln -sfn "${main_lib}" "${OUTPUT_DIR}/lib/libonnxruntime.so.1"
        fi
    fi

    if [ ! -e "${OUTPUT_DIR}/lib/libonnxruntime.so" ] && [ -e "${OUTPUT_DIR}/lib/libonnxruntime.so.1" ]; then
        ln -sfn libonnxruntime.so.1 "${OUTPUT_DIR}/lib/libonnxruntime.so"
    fi

    if [ -e "${OUTPUT_DIR}/lib/libonnxruntime.so.1" ]; then
        echo "  copied ONNX Runtime libs from: ${onnx_lib_dir}"
    else
        echo -e "${YELLOW}警告: 未能复制 libonnxruntime.so.1，运行 RL 控制器会失败${NC}"
    fi
}

echo -e "${CYAN}准备输出目录...${NC}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/bin" "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/log" "${OUTPUT_DIR}/scripts"

echo -e "${CYAN}复制二进制和库...${NC}"
cp -f "${BUILD_OUTPUT_DIR}/ybt_ctrl" "${OUTPUT_DIR}/bin/ybt_ctrl.bin"
chmod +x "${OUTPUT_DIR}/bin/ybt_ctrl.bin"

find "${BUILD_OUTPUT_DIR}" -maxdepth 1 -type f -name 'lib*.so*' -exec cp -f {} "${OUTPUT_DIR}/lib/" \;

copy_onnxruntime_libs

echo -e "${CYAN}创建可移植启动入口...${NC}"
cat > "${OUTPUT_DIR}/bin/ybt_ctrl" << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REAL_BIN="${SCRIPT_DIR}/ybt_ctrl.bin"

if [ ! -x "${REAL_BIN}" ]; then
    echo "错误: 找不到控制器二进制: ${REAL_BIN}"
    exit 1
fi

export LD_LIBRARY_PATH="${PROJECT_ROOT}/lib:${LD_LIBRARY_PATH:-}"
export PYTHONPATH="${PROJECT_ROOT}:${PROJECT_ROOT}/lcm-types/python:${PYTHONPATH:-}"

exec "${REAL_BIN}" "$@"
EOF
chmod +x "${OUTPUT_DIR}/bin/ybt_ctrl"

echo -e "${CYAN}复制顶层目录...${NC}"
copy_dir "${PROJECT_ROOT}/actor_model" "${OUTPUT_DIR}/actor_model"
copy_dir "${PROJECT_ROOT}/lcm-types" "${OUTPUT_DIR}/lcm-types"
copy_dir "${PROJECT_ROOT}/WebRTC_server" "${OUTPUT_DIR}/WebRTC_server"
copy_dir "${PROJECT_ROOT}/resources" "${OUTPUT_DIR}/resources"
copy_dir "${PROJECT_ROOT}/mujoco_sim" "${OUTPUT_DIR}/mujoco_sim"
copy_dir "${PROJECT_ROOT}/yobotics_sdk_e15_sdk_260408" "${OUTPUT_DIR}/yobotics_sdk_e15_sdk_260408"

echo -e "${CYAN}复制顶层文件...${NC}"
copy_file_if_exists "${PROJECT_ROOT}/config.yaml" "${OUTPUT_DIR}/config.yaml"

if [ ! -f "${OUTPUT_DIR}/README.md" ]; then
    if [ -f "${REFERENCE_DIR}/README.md" ]; then
        cp -f "${REFERENCE_DIR}/README.md" "${OUTPUT_DIR}/README.md"
        echo "  copied file : ${REFERENCE_DIR}/README.md"
    else
        cat > "${OUTPUT_DIR}/README.md" << 'EOF'
# Quad48_Controller

Generated from `quad48-rl-control-framework-rk3588_0602`.
EOF
    fi
fi

echo -e "${CYAN}复制脚本...${NC}"
copy_dir "${PROJECT_ROOT}/scripts" "${OUTPUT_DIR}/scripts"

if [ -f "${PROJECT_ROOT}/yobotics_sdk_e15_sdk_260408/build/E15_sport_client" ]; then
    cp -f "${PROJECT_ROOT}/yobotics_sdk_e15_sdk_260408/build/E15_sport_client" "${OUTPUT_DIR}/scripts/E15_sport_client"
    chmod +x "${OUTPUT_DIR}/scripts/E15_sport_client"
fi

if [ -f "${PROJECT_ROOT}/build/Quad48_Controller/scripts/run_controller.sh" ] && \
   [ "${PROJECT_ROOT}/build/Quad48_Controller/scripts/run_controller.sh" != "${OUTPUT_DIR}/scripts/run_controller.sh" ]; then
    cp -f "${PROJECT_ROOT}/build/Quad48_Controller/scripts/run_controller.sh" "${OUTPUT_DIR}/scripts/run_controller.sh"
fi

if [ -f "${PROJECT_ROOT}/build/Quad48_Controller/scripts/start_mujoco.sh" ] && \
   [ "${PROJECT_ROOT}/build/Quad48_Controller/scripts/start_mujoco.sh" != "${OUTPUT_DIR}/scripts/start_mujoco.sh" ]; then
    cp -f "${PROJECT_ROOT}/build/Quad48_Controller/scripts/start_mujoco.sh" "${OUTPUT_DIR}/scripts/start_mujoco.sh"
fi

chmod +x "${OUTPUT_DIR}/scripts/"*.sh 2>/dev/null || true

echo -e "${CYAN}复制日志模板...${NC}"
if [ -f "${PROJECT_ROOT}/build/Quad48_Controller/log/log_RL_walk_data.csv" ]; then
    cp -f "${PROJECT_ROOT}/build/Quad48_Controller/log/log_RL_walk_data.csv" "${OUTPUT_DIR}/log/"
fi

if [ -f "${PROJECT_ROOT}/build/Quad48_Controller/log/robot_log.txt" ]; then
    cp -f "${PROJECT_ROOT}/build/Quad48_Controller/log/robot_log.txt" "${OUTPUT_DIR}/log/"
fi

echo -e "${GREEN}打包完成${NC}"
echo "输出目录: ${OUTPUT_DIR}"
echo ""
find "${OUTPUT_DIR}" -maxdepth 2 | sort
