# aarch64 Ubuntu 22.04 toolchain template
# Usage:
#   cmake -S <src> -B <build> \
#     -DCMAKE_TOOLCHAIN_FILE=/abs/path/aarch64-ubuntu22.04.cmake \
#     -DSYSROOT=/abs/path/to/sysroot

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(NOT DEFINED SYSROOT)
  message(FATAL_ERROR "SYSROOT is required. Example: -DSYSROOT=/opt/sysroots/ubuntu22.04-aarch64")
endif()

set(CMAKE_SYSROOT "${SYSROOT}")

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_AR aarch64-linux-gnu-ar)
set(CMAKE_RANLIB aarch64-linux-gnu-ranlib)

# Search headers and libs inside sysroot
set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
