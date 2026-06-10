#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_ROOT="${SDK_ROOT}/build_sdk_static_only"
RUNNER_DIR="${BUILD_ROOT}/cmake_runner"
PKG_NAME="yobotics_sdk_e15_260408"
OUT_DIR="${SDK_ROOT}/dist/${PKG_NAME}"

echo "[1/6] build static library"
rm -rf "${BUILD_ROOT}"
mkdir -p "${RUNNER_DIR}"
cp "${SCRIPT_DIR}/CMakeLists.sdk_lib_only.txt" "${RUNNER_DIR}/CMakeLists.txt"

cmake -S "${RUNNER_DIR}" -B "${BUILD_ROOT}" -DSDK_SRC_ROOT="${SDK_ROOT}"
cmake --build "${BUILD_ROOT}" --target yobotics_sdk -j"$(nproc)"

LIB_PATH="${BUILD_ROOT}/lib/libyobotics_sdk.a"
if [[ ! -f "${LIB_PATH}" ]]; then
  echo "[ERROR] static library not found: ${LIB_PATH}"
  exit 1
fi

echo "[2/6] verify keyboard example link (internal check)"
find_library_cmd="find /usr/local/lib /usr/lib /usr/lib/x86_64-linux-gnu -name 'liblcm.so*' 2>/dev/null | head -n 1"
LCM_SO="$(bash -lc "${find_library_cmd}")"
if [[ -n "${LCM_SO}" ]]; then
  g++ -std=c++11 -fpermissive \
    -I"${SDK_ROOT}/include" \
    -I"${SDK_ROOT}/include/common" \
    -I"${SDK_ROOT}/include/robot" \
    -I"${SDK_ROOT}/include/robot/channel" \
    "${SDK_ROOT}/example/E15/E15_sport_client.cpp" \
    "${LIB_PATH}" -L"$(dirname "${LCM_SO}")" -llcm -lpthread \
    -o "${BUILD_ROOT}/E15_sport_client_link_check" || {
      echo "[ERROR] keyboard example link check failed"
      exit 1
    }
else
  echo "[WARN] liblcm.so not found, skip keyboard example link check"
fi

echo "[3/6] create clean sdk package"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/include/common" "${OUT_DIR}/include/robot/E15/sport" "${OUT_DIR}/include/robot/channel" "${OUT_DIR}/lib" "${OUT_DIR}/cmake" "${OUT_DIR}/example/E15"
mkdir -p "${OUT_DIR}/toolchain" "${OUT_DIR}/tools"

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
cp -f "${SCRIPT_DIR}/toolchain/aarch64-ubuntu22.04.cmake" "${OUT_DIR}/toolchain/" 2>/dev/null || true
cp -f "${SCRIPT_DIR}/generate_clean_sdk_aarch64_ubuntu22.sh" "${OUT_DIR}/tools/" 2>/dev/null || true

echo "[4/6] remove source files from package"
find "${OUT_DIR}/include" -type f -name '*.cpp' -delete
find "${OUT_DIR}/include" -type f -name '*.pyc' -delete
find "${OUT_DIR}/include" -type f -name '*.py' -delete
find "${OUT_DIR}/include" -type f \( -name '*.tar' -o -name '*.zip' \) -delete
find "${OUT_DIR}/include" -type d -name '__pycache__' -exec rm -rf {} +
# Navigation HTTP/control_messages are not used in the 8-API clean SDK.
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

project(yobotics_sdk_e15_260408 C CXX)

include(GNUInstallDirs)

set(YOBOTICS_SDK_VERSION "260408")
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(YOBOTICS_BUILD_EXAMPLES "Build E15 examples in package" ON)

find_library(LCM_LIBRARY lcm PATHS /usr/local/lib /usr/lib /usr/lib/x86_64-linux-gnu)
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
# yobotics_sdk_e15_260408

本包基于 `quad48-rl-control-framework-rk3588` 当前 LCM 控制协议生成，
用于 E15/quad48 客户侧二次开发集成。

## 包内容
- `include/`：SDK 头文件
- `lib/libyobotics_sdk.a`：静态库
- `example/E15/`：客户示例（仅 `sport_client`、`robot_state_client`）
- `cmake/`：CMake 配置模板
- `CMakeLists.txt`：可独立编译/安装

## 编译示例
```bash
mkdir -p build && cd build
cmake ..
make -j4
```

## 安装 SDK
```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/yobotics_sdk_e15_260408
make -j4
sudo make install
```

## 业务程序直接链接静态库
```bash
g++ -std=c++11 your_app.cpp \
  -I./include -I./include/common -I./include/robot -I./include/robot/channel \
  ./lib/libyobotics_sdk.a -llcm -lpthread -o your_app
```

## 异机部署说明（SDK 电脑与狗端电脑分离）
- 双方必须使用同一个 LCM 多播地址（例如 `udpm://239.255.76.67:7667?ttl=1`）。
- 双方需在同一网段，且网络允许 UDP 组播转发。
- SDK 仅负责 LCM 消息收发，不负责切换狗端本地配置。

详细控制方式切换说明见 `SDK使用说明.md`。

## Ubuntu 16.04/20.04 兼容建议
- 本 SDK 以 `C++11` 编译，兼容 GCC 5+（Ubuntu 16.04/20.04 常见工具链）。
- 若目标机器系统较老，建议在目标机器上重新执行构建，避免预编译静态库与本机 `libstdc++`/ABI 不一致。

## ARM 交叉编译（Ubuntu 22.04 aarch64）
- 交叉编译脚本：`tools/generate_clean_sdk_aarch64_ubuntu22.sh`
- 交叉编译工具链模板：`toolchain/aarch64-ubuntu22.04.cmake`
- 使用示例（需准备 `SYSROOT` 与 `aarch64-linux-gnu-g++`）：
```bash
SYSROOT=/opt/sysroots/ubuntu22.04-aarch64 \
./tools/generate_clean_sdk_aarch64_ubuntu22.sh
```
README_EOF

cat > "${OUT_DIR}/SDK使用说明.md" << 'USAGE_EOF'
# E15 SDK 使用说明

## 1. 运行前提
- 控制框架必须使用 **LCM 控制方式**，否则 SDK 无法建立通信链路。
- 当前对接框架：`quad48-rl-control-framework-rk3588`

## 2. 通信频道（与 quad48 当前实现对齐）
- 控制下发：`QUAD_ROBOT_CONTROL`（`sport_client_cmd_t`）
- 状态回读：`QUAD_ROBOT_STATE`（`sport_client_state_t`）
- 关节状态：`leg_control_data`（`quad_joint_state_t`）
- 关节命令镜像：`leg_control_command`（`quad_joint_command_t`）
- 开发态命令：`Y15_development_command`
- 开发态状态：`Y15_development_state`

## 3. API 编号（与 rt_lcm.cpp 对齐）
- `1000`：PASSIVE
- `1001`：DAMP
- `1002`：RL_WALK
- `1003`：RL_RUN
- `1005`：DEVELOPMENT
- `1006`：RECOVERY_STAND
- `1007`：STAND_DOWN

## 4. SDK 包内容
- `include/`：头文件
- `lib/libyobotics_sdk.a`：静态库
- `example/E15/E15_sport_client.cpp`：键盘控制示例
- `example/E15/E15_robot_state_client.cpp`：状态读取示例

## 5. 编译与运行
```bash
mkdir -p build && cd build
cmake ..
make -j4
```

可选环境变量：
- `YOBOTICS_LCM_URL`：LCM 地址（例如 `udpm://239.255.76.67:7667?ttl=255`）

示例运行：
```bash
./E15_sport_client
./E15_robot_state_client
```

## 6. 控制字段说明
- `Move(vx, vy, vyaw)`：设置速度指令
- `BodyHeight(h)`：设置机身高度，映射到 `v_des[2]`
- `Euler(roll, pitch)`：设置姿态命令，映射到 `omega_des[0/1]`
- 以上字段仅在 `RL_WALK`、`RL_RUN` 和 `DEVELOPMENT` 模式下由控制框架消费

## 7. 异机部署与控制方式切换
- 当 SDK 与狗端不在同一台电脑时，双方必须配置一致的 LCM 多播 URL，且网络允许 UDP 组播。
- 狗端是否启用 LCM 控制，仍以控制框架本地配置为准。

## 8. Ubuntu 16.04/20.04 兼容说明
- SDK 代码按 `C++11` 约束，适配 Ubuntu 16.04/20.04 的常见编译环境。
- 若你从其他系统拷贝了预编译 `libyobotics_sdk.a`，建议在 Ubuntu 16.04/20.04 本机重新编译该库再链接。

## 9. ARM（Ubuntu 22.04 aarch64）交叉编译
- 交叉编译脚本：`tools/generate_clean_sdk_aarch64_ubuntu22.sh`
- 交叉编译工具链模板：`toolchain/aarch64-ubuntu22.04.cmake`
- 需要准备：`aarch64-linux-gnu-g++` 与对应 Ubuntu 22.04 aarch64 的 `SYSROOT`
USAGE_EOF

echo "[DONE] clean sdk generated: ${OUT_DIR}"
