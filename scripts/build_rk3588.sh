#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_ROOT}/build-rk3588"
TOOLCHAIN_FILE="${PROJECT_ROOT}/cmake/rk3588-aarch64-toolchain.cmake"
SYSROOT="${HOME}/sysroots/rk3588"

echo "[RK3588 Build] Project root: ${PROJECT_ROOT}"
echo "[RK3588 Build] Build directory: ${BUILD_DIR}"
echo "[RK3588 Build] Sysroot: ${SYSROOT}"

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "[RK3588 Build] Error: aarch64-linux-gnu-gcc not found."
    echo "Install the cross toolchain first, for example:"
    echo "  sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
    exit 1
fi

if ! command -v aarch64-linux-gnu-g++ >/dev/null 2>&1; then
    echo "[RK3588 Build] Error: aarch64-linux-gnu-g++ not found."
    echo "Install the cross toolchain first, for example:"
    echo "  sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
    exit 1
fi

if [ ! -d "${SYSROOT}" ]; then
    echo "[RK3588 Build] Error: sysroot directory not found: ${SYSROOT}"
    echo "Create it and sync files from the RK3588 board, for example:"
    echo "  mkdir -p ${SYSROOT}"
    echo "  rsync -avz user@<rk3588_ip>:/lib ${SYSROOT}/"
    echo "  rsync -avz user@<rk3588_ip>:/usr/include ${SYSROOT}/usr/"
    echo "  rsync -avz user@<rk3588_ip>:/usr/lib ${SYSROOT}/usr/"
    exit 1
fi

LCM_PC_FILE=""
for candidate in \
    "${SYSROOT}/usr/local/lib/pkgconfig/lcm.pc" \
    "${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig/lcm.pc" \
    "${SYSROOT}/usr/lib/pkgconfig/lcm.pc" \
    "${SYSROOT}/usr/share/pkgconfig/lcm.pc"; do
    if [ -f "${candidate}" ]; then
        LCM_PC_FILE="${candidate}"
        break
    fi
done

if [ -z "${LCM_PC_FILE}" ]; then
    echo "[RK3588 Build] Error: lcm.pc not found in sysroot."
    echo "Expected one of:"
    echo "  ${SYSROOT}/usr/local/lib/pkgconfig/lcm.pc"
    echo "  ${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig/lcm.pc"
    echo "  ${SYSROOT}/usr/lib/pkgconfig/lcm.pc"
    echo "  ${SYSROOT}/usr/share/pkgconfig/lcm.pc"
    echo "Please sync the board's pkg-config metadata."
    exit 1
fi

if [ ! -d "${SYSROOT}/usr/include/eigen3" ] && [ ! -d "${SYSROOT}/usr/local/include/eigen3" ]; then
    echo "[RK3588 Build] Warning: Eigen3 headers not found in sysroot."
    echo "Expected one of:"
    echo "  ${SYSROOT}/usr/include/eigen3"
    echo "  ${SYSROOT}/usr/local/include/eigen3"
    echo "CMake may fail at find_package(Eigen3 REQUIRED)."
fi

ZLIB_LIBRARY_FILE=""
for candidate in \
    "${SYSROOT}/usr/lib/aarch64-linux-gnu/libz.so.1.2.11" \
    "${SYSROOT}/lib/aarch64-linux-gnu/libz.so.1.2.11" \
    "${SYSROOT}/usr/lib/aarch64-linux-gnu/libz.so" \
    "${SYSROOT}/lib/aarch64-linux-gnu/libz.so" \
    "${SYSROOT}/usr/lib/libz.so" \
    "${SYSROOT}/usr/local/lib/libz.so"; do
    if [ -e "${candidate}" ]; then
        ZLIB_LIBRARY_FILE="${candidate}"
        break
    fi
done

if [ -z "${ZLIB_LIBRARY_FILE}" ]; then
    echo "[RK3588 Build] Warning: zlib library not found in common sysroot locations."
    echo "CMake may fail at find_package(ZLIB REQUIRED)."
else
    echo "[RK3588 Build] Found zlib library: ${ZLIB_LIBRARY_FILE}"
fi

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "[RK3588 Build] Found lcm.pc: ${LCM_PC_FILE}"
echo "[RK3588 Build] Configuring CMake..."

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DNO_SIM=ON \
    -DZLIB_INCLUDE_DIR="${SYSROOT}/usr/include" \
    -DZLIB_LIBRARY="${ZLIB_LIBRARY_FILE}" \
    -DZLIB_LIBRARY_RELEASE="${ZLIB_LIBRARY_FILE}"

echo "[RK3588 Build] Building..."
make -j"$(nproc)"

echo "[RK3588 Build] Build finished."
if [ -f "${BUILD_DIR}/user/YBT_Controller/ybt_ctrl" ]; then
    echo "[RK3588 Build] Output: ${BUILD_DIR}/user/YBT_Controller/ybt_ctrl"
    echo "[RK3588 Build] Verify with:"
    echo "  file ${BUILD_DIR}/user/YBT_Controller/ybt_ctrl"
    echo "  readelf -h ${BUILD_DIR}/user/YBT_Controller/ybt_ctrl"
fi
