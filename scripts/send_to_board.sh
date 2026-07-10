#!/bin/bash
set -e

# Get script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="${DIR}/.."
BUILD_DIR="${PROJECT_ROOT}/build"

# Change to build directory
cd "${BUILD_DIR}"

# Clean and create deployment directory
echo "[Deploy] Cleaning old deployment..."
rm -rf robot-software
mkdir -p robot-software/build

# Copy executable
echo "[Deploy] Copying executable..."
if [ ! -f "./user/YBT_Controller/ybt_ctrl" ]; then
    echo "Error: ybt_ctrl executable not found! Please build the project first."
    exit 1
fi
cp ./user/YBT_Controller/ybt_ctrl robot-software/build/

# Detect target architecture from the built controller binary and select matching ONNX Runtime libs
echo "[Deploy] Detecting ybt_ctrl architecture..."
FILE_INFO="$(file ./user/YBT_Controller/ybt_ctrl)"
echo "  Binary: ${FILE_INFO}"

if [[ "${FILE_INFO}" == *"ARM aarch64"* ]]; then
    ONNX_ARCH_NAME="ARM aarch64"
    ONNX_LIB_DIR="${PROJECT_ROOT}/third-party/onnx_arm/lib"
elif [[ "${FILE_INFO}" == *"x86-64"* ]] || [[ "${FILE_INFO}" == *"x86_64"* ]]; then
    ONNX_ARCH_NAME="x86_64"
    ONNX_LIB_DIR="${PROJECT_ROOT}/third-party/onnx_x64/lib"
else
    echo "Error: unsupported ybt_ctrl architecture."
    echo "  ${FILE_INFO}"
    exit 1
fi

echo "[Deploy] Selected ONNX Runtime libs: ${ONNX_ARCH_NAME} (${ONNX_LIB_DIR})"
if [ ! -d "${ONNX_LIB_DIR}" ]; then
    echo "Error: ONNX Runtime lib directory not found: ${ONNX_LIB_DIR}"
    exit 1
fi

if ! find "${ONNX_LIB_DIR}" -maxdepth 1 -name "libonnxruntime.so*" \( -type f -o -type l \) | grep -q .; then
    echo "Error: no libonnxruntime.so* files found in: ${ONNX_LIB_DIR}"
    exit 1
fi

# Copy all shared libraries
echo "[Deploy] Copying shared libraries..."
find . -name "*.so" -type f -exec cp {} ./robot-software/build/ \;

# Explicitly copy ParamHandler libraries (ensure they are included)
echo "[Deploy] Copying ParamHandler libraries..."
if [ -f "./third-party/ParamHandler/libdynacore_param_handler.so" ]; then
    cp ./third-party/ParamHandler/libdynacore_param_handler.so ./robot-software/build/
    echo "  Copied: libdynacore_param_handler.so"
fi
# Copy yaml-cpp library and all its versioned links
if [ -d "./third-party/ParamHandler" ]; then
    find ./third-party/ParamHandler -name "libdynacore_yaml-cpp.so*" -type f -exec cp {} ./robot-software/build/ \;
    find ./third-party/ParamHandler -name "libdynacore_yaml-cpp.so*" -type l -exec cp -L {} ./robot-software/build/ \;
    echo "  Copied: libdynacore_yaml-cpp.so* (including versioned libraries)"
fi

# Copy configuration file
echo "[Deploy] Copying configuration file..."
if [ ! -f "${PROJECT_ROOT}/config.yaml" ]; then
    echo "Warning: config.yaml not found!"
else
    cp "${PROJECT_ROOT}/config.yaml" ./robot-software/build/
fi

if [ -f "${PROJECT_ROOT}/config_sim.yaml" ]; then
    cp "${PROJECT_ROOT}/config_sim.yaml" ./robot-software/build/
else
    echo "Warning: config_sim.yaml not found!"
fi

# Copy Version Information file
echo "[Deploy] Copying Version Information..."
if [ ! -f "${PROJECT_ROOT}/Version_Infor.md" ]; then
    echo "Warning: Version_Infor.md not found!"
else
    cp "${PROJECT_ROOT}/Version_Infor.md" ./robot-software/build/
fi

# Copy URDF file (required for safety checker)
echo "[Deploy] Copying URDF file..."
if [ ! -d "${PROJECT_ROOT}/resources/robots/e3" ]; then
    echo "Warning: URDF directory not found!"
else
    mkdir -p ./robot-software/build/resources/robots/e3
    cp -r "${PROJECT_ROOT}/resources/robots/e3"/* ./robot-software/build/resources/robots/e3/
fi

# Copy actor model files (ONNX models)
echo "[Deploy] Copying actor models..."
if [ ! -d "${PROJECT_ROOT}/actor_model" ]; then
    echo "Warning: actor_model directory not found!"
else
    cp -r "${PROJECT_ROOT}/actor_model" ./robot-software/build/
fi

# Copy run script
echo "[Deploy] Copying run script..."
if [ ! -f "${PROJECT_ROOT}/scripts/run_human_debug.sh" ]; then
    echo "Warning: run_human_debug.sh not found!"
else
    cp "${PROJECT_ROOT}/scripts/run_human_debug.sh" ./robot-software/build/
    chmod +x ./robot-software/build/run_human_debug.sh
fi

echo "[Deploy] Copying ONNX Runtime libraries..."
find "${ONNX_LIB_DIR}" -maxdepth 1 -name "libonnxruntime.so*" -type f -exec cp {} ./robot-software/build/ \;
find "${ONNX_LIB_DIR}" -maxdepth 1 -name "libonnxruntime.so*" -type l -exec cp -L {} ./robot-software/build/ \;
cp -r "${PROJECT_ROOT}/resources" ./robot-software/build/
# Create timestamp
DATE=$(date +"%Y%m%d%H%M")
echo "[Deploy] Deployment package created at: ${DATE}"

# Deploy to robot
echo "[Deploy] Deploying to robot..."
if [ -z "$1" ]; then
    echo "No robot IP specified, using default address: ybt@192.168.100.198"
    scp -r robot-software ybt@192.168.1.134:~/
else
    ROBOT_IP="$1"
    echo "Deploying to: user@${ROBOT_IP}"
    scp -r robot-software user@${ROBOT_IP}:~/
fi

echo "[Deploy] Deployment completed successfully!"
