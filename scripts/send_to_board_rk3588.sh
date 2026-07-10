#!/bin/bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="${DIR}/.."
SYSROOT="${HOME}/sysroots/rk3588"

ROBOT_TARGET="${1:-ybt@192.168.1.134}"
BUILD_DIR_ARG="${2:-build-rk3588}"

if [[ "${BUILD_DIR_ARG}" = /* ]]; then
    BUILD_DIR="${BUILD_DIR_ARG}"
else
    BUILD_DIR="${PROJECT_ROOT}/${BUILD_DIR_ARG}"
fi

CONTROLLER_EXE="${BUILD_DIR}/user/YBT_Controller/ybt_ctrl"
PACKAGE_DIR="${BUILD_DIR}/robot-software"
PACKAGE_BUILD_DIR="${PACKAGE_DIR}/build"

echo "[RK3588 Deploy] Project root: ${PROJECT_ROOT}"
echo "[RK3588 Deploy] Build directory: ${BUILD_DIR}"
echo "[RK3588 Deploy] Target: ${ROBOT_TARGET}"

if [ ! -d "${BUILD_DIR}" ]; then
    echo "[RK3588 Deploy] Error: build directory not found: ${BUILD_DIR}"
    echo "Build first with:"
    echo "  bash ${PROJECT_ROOT}/scripts/build_rk3588.sh"
    exit 1
fi

if [ ! -f "${CONTROLLER_EXE}" ]; then
    echo "[RK3588 Deploy] Error: ybt_ctrl not found: ${CONTROLLER_EXE}"
    echo "Build first with:"
    echo "  bash ${PROJECT_ROOT}/scripts/build_rk3588.sh"
    exit 1
fi

FILE_INFO="$(file "${CONTROLLER_EXE}")"
echo "[RK3588 Deploy] Binary: ${FILE_INFO}"

if [[ "${FILE_INFO}" != *"ARM aarch64"* ]]; then
    echo "[RK3588 Deploy] Error: ybt_ctrl is not an ARM aarch64 binary."
    echo "This script only deploys RK3588 builds. Rebuild with:"
    echo "  bash ${PROJECT_ROOT}/scripts/build_rk3588.sh"
    exit 1
fi

cd "${BUILD_DIR}"

echo "[RK3588 Deploy] Cleaning old package..."
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_BUILD_DIR}"

echo "[RK3588 Deploy] Copying executable..."
cp "${CONTROLLER_EXE}" "${PACKAGE_BUILD_DIR}/"

echo "[RK3588 Deploy] Copying build shared libraries..."
find "${BUILD_DIR}" -name "*.so" -type f -exec cp {} "${PACKAGE_BUILD_DIR}/" \;
find "${BUILD_DIR}" -name "*.so.*" -type f -exec cp {} "${PACKAGE_BUILD_DIR}/" \;

echo "[RK3588 Deploy] Copying ONNX Runtime ARM libraries..."
if [ -d "${PROJECT_ROOT}/third-party/onnx_arm/lib" ]; then
    find "${PROJECT_ROOT}/third-party/onnx_arm/lib" -maxdepth 1 -name "libonnxruntime.so*" -type f -exec cp {} "${PACKAGE_BUILD_DIR}/" \;
    find "${PROJECT_ROOT}/third-party/onnx_arm/lib" -maxdepth 1 -name "libonnxruntime.so*" -type l -exec cp -L {} "${PACKAGE_BUILD_DIR}/" \;
else
    echo "[RK3588 Deploy] Warning: ONNX Runtime ARM lib directory not found."
fi

echo "[RK3588 Deploy] Copying LCM ARM libraries from sysroot..."
if [ -d "${SYSROOT}/usr/local/lib" ]; then
    find "${SYSROOT}/usr/local/lib" -maxdepth 1 -name "liblcm.so*" -type f -exec cp {} "${PACKAGE_BUILD_DIR}/" \;
    find "${SYSROOT}/usr/local/lib" -maxdepth 1 -name "liblcm.so*" -type l -exec cp -L {} "${PACKAGE_BUILD_DIR}/" \;
else
    echo "[RK3588 Deploy] Warning: sysroot LCM lib directory not found: ${SYSROOT}/usr/local/lib"
fi

echo "[RK3588 Deploy] Copying configuration..."
if [ -f "${PROJECT_ROOT}/config.yaml" ]; then
    cp "${PROJECT_ROOT}/config.yaml" "${PACKAGE_BUILD_DIR}/"
else
    echo "[RK3588 Deploy] Warning: config.yaml not found."
fi

if [ -f "${PROJECT_ROOT}/config_sim.yaml" ]; then
    cp "${PROJECT_ROOT}/config_sim.yaml" "${PACKAGE_BUILD_DIR}/"
fi

if [ -f "${PROJECT_ROOT}/Version_Infor.md" ]; then
    cp "${PROJECT_ROOT}/Version_Infor.md" "${PACKAGE_BUILD_DIR}/"
fi

echo "[RK3588 Deploy] Copying runtime assets..."
if [ -d "${PROJECT_ROOT}/actor_model" ]; then
    cp -r "${PROJECT_ROOT}/actor_model" "${PACKAGE_BUILD_DIR}/"
else
    echo "[RK3588 Deploy] Warning: actor_model directory not found."
fi

if [ -d "${PROJECT_ROOT}/resources" ]; then
    cp -r "${PROJECT_ROOT}/resources" "${PACKAGE_BUILD_DIR}/"
else
    echo "[RK3588 Deploy] Warning: resources directory not found."
fi

if [ -f "${PROJECT_ROOT}/scripts/run_human_debug.sh" ]; then
    cp "${PROJECT_ROOT}/scripts/run_human_debug.sh" "${PACKAGE_BUILD_DIR}/"
    chmod +x "${PACKAGE_BUILD_DIR}/run_human_debug.sh"
fi

echo "[RK3588 Deploy] Package contents summary:"
find "${PACKAGE_BUILD_DIR}" -maxdepth 1 \( -name "ybt_ctrl" -o -name "*.so*" -o -name "config.yaml" \) -printf "  %f\n" | sort

echo "[RK3588 Deploy] Deploying..."
scp -r "${PACKAGE_DIR}" "${ROBOT_TARGET}:~/"

echo "[RK3588 Deploy] Deployment completed successfully."
