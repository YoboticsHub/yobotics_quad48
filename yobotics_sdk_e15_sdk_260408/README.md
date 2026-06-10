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
