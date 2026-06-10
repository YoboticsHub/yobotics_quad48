#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_ROOT="${SDK_ROOT}/build_sdk_static_only_aarch64_ubuntu22"
RUNNER_DIR="${BUILD_ROOT}/cmake_runner"
PKG_NAME="yobotics_sdk_e15_260408_aarch64_ubuntu22"
OUT_DIR="${SDK_ROOT}/dist/${PKG_NAME}"
TOOLCHAIN_FILE_DEFAULT="${SCRIPT_DIR}/toolchain/aarch64-ubuntu22.04.cmake"

TOOLCHAIN_FILE="${TOOLCHAIN_FILE:-${TOOLCHAIN_FILE_DEFAULT}}"
SYSROOT="${SYSROOT:-}"

if [[ -z "${SYSROOT}" ]]; then
  echo "[ERROR] SYSROOT is required. Example: SYSROOT=/opt/sysroots/ubuntu22.04-aarch64"
  exit 1
fi

if [[ ! -f "${TOOLCHAIN_FILE}" ]]; then
  echo "[ERROR] toolchain file not found: ${TOOLCHAIN_FILE}"
  exit 1
fi

echo "[1/6] build static library (aarch64 Ubuntu 22.04)"
rm -rf "${BUILD_ROOT}"
mkdir -p "${RUNNER_DIR}"
cp "${SCRIPT_DIR}/CMakeLists.sdk_lib_only.txt" "${RUNNER_DIR}/CMakeLists.txt"

cmake -S "${RUNNER_DIR}" -B "${BUILD_ROOT}" \
  -DSDK_SRC_ROOT="${SDK_ROOT}" \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DSYSROOT="${SYSROOT}"

cmake --build "${BUILD_ROOT}" --target yobotics_sdk -j"$(nproc)"

LIB_PATH="${BUILD_ROOT}/lib/libyobotics_sdk.a"
if [[ ! -f "${LIB_PATH}" ]]; then
  echo "[ERROR] static library not found: ${LIB_PATH}"
  exit 1
fi

echo "[2/6] skip link check for cross build"

echo "[3/6] create clean sdk package"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/include/common" "${OUT_DIR}/include/robot/E15/sport" "${OUT_DIR}/include/robot/channel" "${OUT_DIR}/lib" "${OUT_DIR}/cmake" "${OUT_DIR}/example/E15" "${OUT_DIR}/toolchain"

cp -r "${SDK_ROOT}/include/common"/* "${OUT_DIR}/include/common/"
cp "${SDK_ROOT}/include/robot/E15/sport/sport_api.hpp" "${OUT_DIR}/include/robot/E15/sport/"
cp "${SDK_ROOT}/include/robot/E15/sport/sport_client.hpp" "${OUT_DIR}/include/robot/E15/sport/"
cp "${SDK_ROOT}/include/robot/E15/sport/sport_error.hpp" "${OUT_DIR}/include/robot/E15/sport/"
cp "${SDK_ROOT}/include/robot/channel/channel_name.hpp" "${OUT_DIR}/include/robot/channel/"
cp "${SDK_ROOT}/include/robot/channel/channel_publisher.hpp" "${OUT_DIR}/include/robot/channel/"
cp "${SDK_ROOT}/include/robot/channel/channel_subscriber.hpp" "${OUT_DIR}/include/robot/channel/"
cp "${LIB_PATH}" "${OUT_DIR}/lib/libyobotics_sdk.a"
cp "${SDK_ROOT}/cmake/yobotics_sdkConfig.cmake.in" "${OUT_DIR}/cmake/"
cp "${SDK_ROOT}/cmake/yobotics_sdkConfigVersion.cmake.in" "${OUT_DIR}/cmake/"
cp "${SDK_ROOT}/example/E15/E15_sport_client.cpp" "${OUT_DIR}/example/E15/"
cp "${SDK_ROOT}/example/E15/E15_robot_state_client.cpp" "${OUT_DIR}/example/E15/"
cp "${SCRIPT_DIR}/toolchain/aarch64-ubuntu22.04.cmake" "${OUT_DIR}/toolchain/"

echo "[4/6] remove source files from package"
find "${OUT_DIR}/include" -type f -name '*.cpp' -delete
find "${OUT_DIR}/include" -type f -name '*.pyc' -delete
find "${OUT_DIR}/include" -type f -name '*.py' -delete
find "${OUT_DIR}/include" -type f \( -name '*.tar' -o -name '*.zip' \) -delete
find "${OUT_DIR}/include" -type d -name '__pycache__' -exec rm -rf {} +
rm -rf "${OUT_DIR}/include/common/lcm_types/control_messages"
rm -rf "${OUT_DIR}/include/common/lcm_types/control_messages_backup"
rm -f "${OUT_DIR}/include/common/lcm_types/control_messages.lcm"
rm -f "${OUT_DIR}/include/common/lcm_types/nav_client_data_t.lcm"
rm -f "${OUT_DIR}/include/common/lcm_types/cpp/nav_client_cmd_t.hpp"
rm -f "${OUT_DIR}/include/common/lcm_types/cpp/nav_client_data_t.hpp"
rm -f "${OUT_DIR}/include/common/lcm_types/cpp/nav_enable_t.hpp"
rm -f "${OUT_DIR}/include/common/lcm_types/cpp/navigationtmp.hpp"
rm -f "${OUT_DIR}/include/robot/channel/httplib.hpp" "${OUT_DIR}/include/robot/channel/json.hpp"

echo "[5/6] write package CMake files"
cat > "${OUT_DIR}/CMakeLists.txt" << 'CMAKE_EOF'
cmake_minimum_required(VERSION 3.5)

project(yobotics_sdk_e15_260408_aarch64_ubuntu22 C CXX)

include(GNUInstallDirs)

set(YOBOTICS_SDK_VERSION "260408")
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(YOBOTICS_BUILD_EXAMPLES "Build E15 examples in package" ON)

find_library(LCM_LIBRARY lcm PATHS /usr/local/lib /usr/lib /usr/lib/aarch64-linux-gnu)
if(NOT LCM_LIBRARY)
  message(FATAL_ERROR "LCM library not found. Please install LCM.")
endif()

add_library(yobotics_sdk STATIC IMPORTED GLOBAL)
set_target_properties(yobotics_sdk PROPERTIES
  IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libyobotics_sdk.a"
  INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/include;${CMAKE_CURRENT_SOURCE_DIR}/include/common;${CMAKE_CURRENT_SOURCE_DIR}/include/robot;${CMAKE_CURRENT_SOURCE_DIR}/include/robot/channel"
)

if(YOBOTICS_BUILD_EXAMPLES)
  add_executable(E15_sport_client example/E15/E15_sport_client.cpp)
  add_executable(E15_robot_state_client example/E15/E15_robot_state_client.cpp)

  target_link_libraries(E15_sport_client PRIVATE yobotics_sdk ${LCM_LIBRARY} pthread -Wl,--start-group yobotics_sdk ${LCM_LIBRARY} -Wl,--end-group)
  target_link_libraries(E15_robot_state_client PRIVATE yobotics_sdk ${LCM_LIBRARY} pthread -Wl,--start-group yobotics_sdk ${LCM_LIBRARY} -Wl,--end-group)
endif()

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/lib/libyobotics_sdk.a" DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/example/" DESTINATION share/yobotics_sdk/examples)

configure_file(cmake/yobotics_sdkConfig.cmake.in yobotics_sdkConfig.cmake @ONLY)
configure_file(cmake/yobotics_sdkConfigVersion.cmake.in yobotics_sdkConfigVersion.cmake @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/yobotics_sdkConfig.cmake" "${CMAKE_CURRENT_BINARY_DIR}/yobotics_sdkConfigVersion.cmake" DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/yobotics_sdk)
CMAKE_EOF

echo "[6/6] write README/SDK usage"
cat > "${OUT_DIR}/README.md" << 'README_EOF'
# yobotics_sdk_e15_260408_aarch64_ubuntu22

本包为 E15/quad48 SDK 的 Ubuntu 22.04 aarch64 交叉编译版本。

## 使用说明
- 运行环境：Ubuntu 22.04 aarch64
- 若需重新交叉编译，请参考 `toolchain/aarch64-ubuntu22.04.cmake`

## 编译示例
```bash
mkdir -p build && cd build
cmake ..
make -j4
```
README_EOF

echo "[DONE] aarch64 Ubuntu 22.04 sdk generated: ${OUT_DIR}"
