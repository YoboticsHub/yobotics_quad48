#!/bin/bash
#
# 创建客户分发包脚本
# 基于编译后的文件打包生成用户可直接使用的分发包
#
# 作者: Han Jiang (jh18954242606@163.com)
# 日期: 2026-01
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="${SCRIPT_DIR}/.."

# 检查构建目录（优先使用 build_lib，如果没有则使用 build）
BUILD_DIR="${PROJECT_ROOT}/build_lib"
if [ ! -d "$BUILD_DIR" ] || [ ! -f "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" ]; then
    BUILD_DIR="${PROJECT_ROOT}/build"
    if [ ! -d "$BUILD_DIR" ] || [ ! -f "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" ]; then
        echo -e "${RED}错误: 找不到编译后的可执行文件${NC}"
        echo "请先编译项目:"
        echo "  cd build && cmake .. && make -j4"
        echo "或者编译为库:"
        echo "  cd build_lib && cmake -DBUILD_AS_LIBRARY=ON .. && make -j4"
        exit 1
    fi
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  创建客户分发包${NC}"
echo -e "${CYAN}========================================${NC}"
echo "构建目录: $BUILD_DIR"
echo ""

# 分发包目录名称
DIST_NAME="Yobotics_Quad_Controller"
DIST_DIR="${PROJECT_ROOT}/${DIST_NAME}"

# 清理旧的分发包
if [ -d "$DIST_DIR" ]; then
    echo -e "${YELLOW}清理旧的分发包...${NC}"
    rm -rf "$DIST_DIR"
fi

# 创建目录结构
echo -e "${CYAN}创建目录结构...${NC}"
mkdir -p "$DIST_DIR/bin"
mkdir -p "$DIST_DIR/lib"
mkdir -p "$DIST_DIR/config"
mkdir -p "$DIST_DIR/resources/robots/e3"
mkdir -p "$DIST_DIR/scripts"
mkdir -p "$DIST_DIR/log"

# 1. 复制可执行文件
echo -e "${CYAN}📦 复制可执行文件...${NC}"
if [ -f "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" ]; then
    cp "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" "$DIST_DIR/bin/ybt_ctrl.bin"
    chmod +x "$DIST_DIR/bin/ybt_ctrl.bin"
    echo -e "${GREEN}✓ 可执行文件已复制${NC}"
else
    echo -e "${RED}错误: 找不到可执行文件 ybt_ctrl${NC}"
    exit 1
fi

# 2. 复制所有共享库
echo -e "${CYAN}📦 复制依赖库...${NC}"

# 2.1 复制构建目录中的所有 .so 文件
echo "  复制构建目录中的库文件..."
find "$BUILD_DIR" -name "*.so" -type f -exec cp -L {} "$DIST_DIR/lib/" \; 2>/dev/null || true
find "$BUILD_DIR" -name "*.so" -type l -exec cp -L {} "$DIST_DIR/lib/" \; 2>/dev/null || true

# 2.2 特别处理 ParamHandler 库（确保所有版本符号链接都被复制）
PARAMHANDLER_LIB_DIR="$BUILD_DIR/third-party/ParamHandler"
if [ -d "$PARAMHANDLER_LIB_DIR" ]; then
    echo "  复制 ParamHandler 库（包括所有版本）..."
    for lib_file in "$PARAMHANDLER_LIB_DIR"/libdynacore*.so*; do
        if [ -e "$lib_file" ]; then
            cp -L "$lib_file" "$DIST_DIR/lib/" 2>/dev/null || true
        fi
    done
    echo -e "    ${GREEN}✓${NC} ParamHandler 库已复制"
fi

# 2.3 复制 ONNX Runtime 库
echo "  复制 ONNX Runtime 库..."
ONNX_COPIED=false

# 搜索路径列表（按优先级）
ONNX_SEARCH_PATHS=(
    "${PROJECT_ROOT}/third-party/onnx/lib"
    "/usr/lib/onnxruntime-linux-x64-1.20.1/lib"
    "/usr/lib/onnxruntime-linux-x64-1.19.2/lib"
    "/usr/lib/onnxruntime-linux-x64-1.18.1/lib"
    "/usr/local/lib"
    "/usr/lib/x86_64-linux-gnu"
    "/opt/onnxruntime/lib"
)

# 尝试从各个路径查找并复制 ONNX Runtime 库
for ONNX_LIB_DIR in "${ONNX_SEARCH_PATHS[@]}"; do
    if [ -d "$ONNX_LIB_DIR" ]; then
        # 检查是否存在 libonnxruntime 相关的库文件
        if ls "$ONNX_LIB_DIR"/libonnxruntime*.so* 1> /dev/null 2>&1; then
            echo "    在 $ONNX_LIB_DIR 找到 ONNX Runtime 库"
            
            # 第一步：找到并复制所有实际文件（非符号链接）
            # 这避免了符号链接解析的问题
            ACTUAL_FILES=()
            for lib_file in "$ONNX_LIB_DIR"/libonnxruntime*.so*; do
                if [ -e "$lib_file" ] && [ ! -L "$lib_file" ]; then
                    # 这是实际文件，直接复制
                    lib_name=$(basename "$lib_file")
                    if [ ! -f "$DIST_DIR/lib/$lib_name" ]; then
                        cp "$lib_file" "$DIST_DIR/lib/$lib_name" 2>/dev/null && {
                            ACTUAL_FILES+=("$lib_name")
                            echo "      已复制实际文件: $lib_name"
                        } || true
                    fi
                fi
            done
            
            # 如果没有找到实际文件，尝试通过符号链接找到实际文件
            if [ ${#ACTUAL_FILES[@]} -eq 0 ]; then
                # 查找 libonnxruntime.so.1 或 libonnxruntime.so
                ONNX_SO1=""
                if [ -L "$ONNX_LIB_DIR/libonnxruntime.so.1" ] || [ -f "$ONNX_LIB_DIR/libonnxruntime.so.1" ]; then
                    ONNX_SO1="$ONNX_LIB_DIR/libonnxruntime.so.1"
                elif [ -L "$ONNX_LIB_DIR/libonnxruntime.so" ] || [ -f "$ONNX_LIB_DIR/libonnxruntime.so" ]; then
                    ONNX_SO1="$ONNX_LIB_DIR/libonnxruntime.so"
                fi
                
                if [ -n "$ONNX_SO1" ]; then
                    # 跟随符号链接找到实际文件
                    REAL_LIB=$(readlink -f "$ONNX_SO1" 2>/dev/null || realpath "$ONNX_SO1" 2>/dev/null)
                    if [ -z "$REAL_LIB" ] || [ ! -f "$REAL_LIB" ]; then
                        # 手动解析符号链接
                        REAL_LIB="$ONNX_SO1"
                        while [ -L "$REAL_LIB" ] && [ -e "$REAL_LIB" ]; do
                            link_target=$(readlink "$REAL_LIB")
                            if [[ "$link_target" = /* ]]; then
                                REAL_LIB="$link_target"
                            else
                                REAL_LIB="$(dirname "$REAL_LIB")/$link_target"
                            fi
                        done
                    fi
                    
                    if [ -f "$REAL_LIB" ] && [ ! -L "$REAL_LIB" ]; then
                        REAL_LIB_NAME=$(basename "$REAL_LIB")
                        if [ ! -f "$DIST_DIR/lib/$REAL_LIB_NAME" ]; then
                            cp "$REAL_LIB" "$DIST_DIR/lib/$REAL_LIB_NAME" 2>/dev/null && {
                                ACTUAL_FILES+=("$REAL_LIB_NAME")
                                echo "      已复制实际文件: $REAL_LIB_NAME"
                            } || true
                        fi
                    fi
                fi
            fi
            
            # 复制 providers 共享库（实际文件）
            if [ -f "$ONNX_LIB_DIR/libonnxruntime_providers_shared.so" ]; then
                if [ ! -f "$DIST_DIR/lib/libonnxruntime_providers_shared.so" ]; then
                    cp "$ONNX_LIB_DIR/libonnxruntime_providers_shared.so" "$DIST_DIR/lib/" 2>/dev/null && \
                        echo "      已复制: libonnxruntime_providers_shared.so" || true
                fi
            fi
            
            # 第二步：基于实际文件重新创建符号链接结构
            # 找到主要的 ONNX Runtime 库文件（通常是 libonnxruntime.so.1.x.x 格式）
            MAIN_LIB=""
            for lib_name in "${ACTUAL_FILES[@]}"; do
                if [[ "$lib_name" =~ ^libonnxruntime\.so\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
                   [[ "$lib_name" =~ ^libonnxruntime\.so\.[0-9]+\.[0-9]+$ ]]; then
                    MAIN_LIB="$lib_name"
                    break
                fi
            done
            
            # 如果没有找到版本号格式，使用第一个实际文件
            if [ -z "$MAIN_LIB" ] && [ ${#ACTUAL_FILES[@]} -gt 0 ]; then
                MAIN_LIB="${ACTUAL_FILES[0]}"
            fi
            
            # 创建符号链接
            if [ -n "$MAIN_LIB" ] && [ -f "$DIST_DIR/lib/$MAIN_LIB" ]; then
                cd "$DIST_DIR/lib"
                
                # 创建 libonnxruntime.so.1 -> 主库文件
                if [ "$MAIN_LIB" != "libonnxruntime.so.1" ]; then
                    rm -f libonnxruntime.so.1 2>/dev/null || true
                    ln -sf "$MAIN_LIB" libonnxruntime.so.1 2>/dev/null && \
                        echo "      已创建符号链接: libonnxruntime.so.1 -> $MAIN_LIB" || true
                fi
                
                # 创建 libonnxruntime.so -> libonnxruntime.so.1
                rm -f libonnxruntime.so 2>/dev/null || true
                ln -sf libonnxruntime.so.1 libonnxruntime.so 2>/dev/null && \
                    echo "      已创建符号链接: libonnxruntime.so -> libonnxruntime.so.1" || true
                
                cd - >/dev/null
            fi
            
            if [ ${#ACTUAL_FILES[@]} -gt 0 ]; then
                ONNX_COPIED=true
                echo -e "    ${GREEN}✓${NC} ONNX Runtime 库已从 $ONNX_LIB_DIR 复制"
                break
            fi
        fi
    fi
done

# 如果没有复制成功，尝试使用 ldd 查找
if [ "$ONNX_COPIED" = false ] && [ -f "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" ] && command -v ldd >/dev/null 2>&1; then
    echo "    尝试使用 ldd 查找 ONNX Runtime 库..."
    ORIG_LD_PATH="$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="$BUILD_DIR/common:$BUILD_DIR/robot:$BUILD_DIR/third-party/ParamHandler:$BUILD_DIR/third-party/cnpy:$BUILD_DIR/third-party/lord_imu:$BUILD_DIR/third-party/vectornav:${PROJECT_ROOT}/third-party/onnx/lib:$LD_LIBRARY_PATH"
    
    LDD_MAIN_LIB=""
    while IFS= read -r line; do
        if [[ "$line" =~ libonnxruntime\.so ]] && [[ "$line" =~ "=>" ]]; then
            lib_path=$(echo "$line" | awk -F'=> ' '{print $2}' | awk '{print $1}' | tr -d '()')
            if [[ -n "$lib_path" ]] && [[ -f "$lib_path" ]]; then
                # 跟随符号链接找到实际文件
                real_path=$(readlink -f "$lib_path" 2>/dev/null || echo "$lib_path")
                if [ -f "$real_path" ]; then
                    lib_name=$(basename "$real_path")
                    if [ ! -f "$DIST_DIR/lib/$lib_name" ]; then
                        cp "$real_path" "$DIST_DIR/lib/$lib_name" 2>/dev/null && {
                            echo "      已复制实际文件: $lib_name (来自 ldd: $lib_path)"
                            if [ -z "$LDD_MAIN_LIB" ]; then
                                LDD_MAIN_LIB="$lib_name"
                            fi
                            ONNX_COPIED=true
                        } || true
                    fi
                fi
            fi
        fi
    done < <(ldd "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" 2>/dev/null || true)
    
    # 如果通过 ldd 找到了库，创建符号链接
    if [ "$ONNX_COPIED" = true ] && [ -n "$LDD_MAIN_LIB" ] && [ -f "$DIST_DIR/lib/$LDD_MAIN_LIB" ]; then
        cd "$DIST_DIR/lib"
        if [ "$LDD_MAIN_LIB" != "libonnxruntime.so.1" ]; then
            rm -f libonnxruntime.so.1 2>/dev/null || true
            ln -sf "$LDD_MAIN_LIB" libonnxruntime.so.1 2>/dev/null && \
                echo "      已创建符号链接: libonnxruntime.so.1 -> $LDD_MAIN_LIB" || true
        fi
        rm -f libonnxruntime.so 2>/dev/null || true
        ln -sf libonnxruntime.so.1 libonnxruntime.so 2>/dev/null && \
            echo "      已创建符号链接: libonnxruntime.so -> libonnxruntime.so.1" || true
        cd - >/dev/null
    fi
    
    export LD_LIBRARY_PATH="$ORIG_LD_PATH"
fi

# 最终检查
ONNX_SO1_EXISTS=false
if [ -f "$DIST_DIR/lib/libonnxruntime.so.1" ] || [ -L "$DIST_DIR/lib/libonnxruntime.so.1" ]; then
    ONNX_SO1_EXISTS=true
    # 验证符号链接是否有效
    if [ -L "$DIST_DIR/lib/libonnxruntime.so.1" ]; then
        link_target=$(readlink "$DIST_DIR/lib/libonnxruntime.so.1")
        if [[ "$link_target" != /* ]]; then
            # 相对链接，检查目标是否存在
            if [ ! -f "$DIST_DIR/lib/$link_target" ]; then
                ONNX_SO1_EXISTS=false
            fi
        elif [ ! -f "$link_target" ]; then
            ONNX_SO1_EXISTS=false
        fi
    fi
fi

if [ "$ONNX_COPIED" = false ] || [ "$ONNX_SO1_EXISTS" = false ]; then
    echo -e "    ${RED}✗${NC} 错误: 无法找到或复制 libonnxruntime.so.1"
    echo "    请确保已安装 ONNX Runtime，或者手动将库文件复制到 $DIST_DIR/lib/"
    echo "    常见的安装位置："
    echo "      - ${PROJECT_ROOT}/third-party/onnx/lib/"
    echo "      - /usr/lib/onnxruntime-linux-x64-1.20.1/lib/"
    echo "      - /usr/local/lib/"
    echo ""
    echo "    当前已复制的 ONNX Runtime 文件："
    ls -lh "$DIST_DIR/lib"/libonnxruntime* 2>/dev/null || echo "      无"
else
    echo -e "    ${GREEN}✓${NC} 已验证 libonnxruntime.so.1 存在且有效"
fi

# 2.4 使用 ldd 检查可执行文件的依赖并复制缺失的库
echo "  检查可执行文件的依赖..."
if [ -f "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" ] && command -v ldd >/dev/null 2>&1; then
    ORIG_LD_PATH="$LD_LIBRARY_PATH"
    # 扩展 LD_LIBRARY_PATH 以包含所有可能的库路径
    export LD_LIBRARY_PATH="$BUILD_DIR/common:$BUILD_DIR/robot:$BUILD_DIR/third-party/ParamHandler:$BUILD_DIR/third-party/cnpy:$BUILD_DIR/third-party/lord_imu:$BUILD_DIR/third-party/vectornav:${PROJECT_ROOT}/third-party/onnx/lib:/usr/lib/onnxruntime-linux-x64-1.20.1/lib:/usr/lib/onnxruntime-linux-x64-1.19.2/lib:/usr/lib/onnxruntime-linux-x64-1.18.1/lib:/usr/local/lib:/usr/lib/x86_64-linux-gnu:/opt/onnxruntime/lib:$LD_LIBRARY_PATH"
    
    MISSING_PROJECT_DEPS=()
    while IFS= read -r line; do
        if [[ "$line" =~ "=>" ]]; then
            lib_path=$(echo "$line" | awk -F'=> ' '{print $2}' | awk '{print $1}' | tr -d '()')
            if [[ -n "$lib_path" ]] && [[ -f "$lib_path" ]]; then
                lib_name=$(basename "$lib_path")
                # 跳过 ONNX Runtime 库（已经在前面步骤中处理过了）
                if [[ "$lib_name" =~ libonnxruntime ]]; then
                    :  # 跳过，不处理
                # 如果是项目内部库，复制（使用 cp 而不是 cp -L，避免符号链接问题）
                elif [[ "$lib_path" == "$BUILD_DIR"* ]] || [[ "$lib_path" == "$PROJECT_ROOT"* ]]; then
                    # 如果是符号链接，先找到实际文件
                    if [ -L "$lib_path" ]; then
                        real_path=$(readlink -f "$lib_path" 2>/dev/null || echo "$lib_path")
                        if [ -f "$real_path" ] && [ ! -L "$real_path" ]; then
                            real_name=$(basename "$real_path")
                            if [ ! -f "$DIST_DIR/lib/$real_name" ]; then
                                cp "$real_path" "$DIST_DIR/lib/$real_name" 2>/dev/null || true
                            fi
                        fi
                    else
                        # 是实际文件，直接复制
                        if [ ! -f "$DIST_DIR/lib/$lib_name" ]; then
                            cp "$lib_path" "$DIST_DIR/lib/" 2>/dev/null || true
                        fi
                    fi
                fi
            elif [[ "$line" =~ "not found" ]]; then
                lib_name=$(echo "$line" | awk '{print $1}')
                if [[ "$lib_name" =~ libmit_controller ]] || [[ "$lib_name" =~ librobot ]] || \
                   [[ "$lib_name" =~ libbiomimetics ]] || [[ "$lib_name" =~ libdynacore ]] || \
                   [[ "$lib_name" =~ libonnxruntime ]] || [[ "$lib_name" =~ libcnpy ]] || \
                   [[ "$lib_name" =~ liblord_imu ]] || [[ "$lib_name" =~ liblibvnc ]]; then
                    MISSING_PROJECT_DEPS+=("$lib_name")
                fi
            fi
        fi
    done < <(ldd "$BUILD_DIR/user/YBT_Controller/ybt_ctrl" 2>/dev/null || true)
    
    export LD_LIBRARY_PATH="$ORIG_LD_PATH"
    
    if [ ${#MISSING_PROJECT_DEPS[@]} -gt 0 ]; then
        echo -e "    ${YELLOW}⚠️${NC}  以下项目库可能需要手动检查:"
        for lib in "${MISSING_PROJECT_DEPS[@]}"; do
            echo "      - $lib"
        done
    fi
fi

# 2.5 验证关键库文件
echo "  验证关键库文件..."
REQUIRED_LIBS=(
    "libmit_controller.so"
    "librobot.so"
    "libbiomimetics.so"
    "libdynacore_param_handler.so"
    "libdynacore_yaml-cpp.so"
    "libonnxruntime.so.1"
)

MISSING_LIBS=()
for lib in "${REQUIRED_LIBS[@]}"; do
    if ! ls "$DIST_DIR/lib/$lib"* 1>/dev/null 2>&1; then
        MISSING_LIBS+=("$lib")
    fi
done

if [ ${#MISSING_LIBS[@]} -gt 0 ]; then
    echo -e "    ${YELLOW}⚠️${NC}  警告: 以下关键库文件未找到:"
    for lib in "${MISSING_LIBS[@]}"; do
        echo "      - $lib"
    done
else
    echo -e "    ${GREEN}✓${NC} 所有关键库文件都已复制"
    lib_count=$(find "$DIST_DIR/lib" -name "*.so*" -type f 2>/dev/null | wc -l)
    echo -e "    ${GREEN}✓${NC} 共复制 $lib_count 个库文件"
fi

# 3. 复制配置文件
echo -e "${CYAN}⚙️  复制配置文件...${NC}"
if [ -f "${PROJECT_ROOT}/config.yaml" ]; then
    cp "${PROJECT_ROOT}/config.yaml" "$DIST_DIR/"
    echo -e "${GREEN}✓ 配置文件 config.yaml 已复制到根目录${NC}"
else
    echo -e "${YELLOW}⚠️  警告: 找不到配置文件 config.yaml${NC}"
fi

if [ -f "${PROJECT_ROOT}/config_sim.yaml" ]; then
    cp "${PROJECT_ROOT}/config_sim.yaml" "$DIST_DIR/"
    echo -e "${GREEN}✓ 配置文件 config_sim.yaml 已复制到根目录${NC}"
else
    echo -e "${YELLOW}⚠️  警告: 找不到配置文件 config_sim.yaml${NC}"
fi

# 4. 复制资源文件
echo -e "${CYAN}📁 复制资源文件...${NC}"
if [ -d "${PROJECT_ROOT}/resources/robots/e3" ]; then
    cp -r "${PROJECT_ROOT}/resources/robots/e3"/* "$DIST_DIR/resources/robots/e3/" 2>/dev/null || true
    echo -e "${GREEN}✓ 资源文件已复制${NC}"
else
    echo -e "${YELLOW}⚠️  警告: 找不到资源文件目录${NC}"
fi

# 4.1 复制 LCM 类型定义（Python，用于 MuJoCo 仿真器）
echo -e "${CYAN}📦 复制 LCM Python 类型定义...${NC}"
if [ -d "${PROJECT_ROOT}/lcm-types/python" ]; then
    mkdir -p "$DIST_DIR/lcm-types/python"
    # 只复制 .py 文件，不复制 __pycache__
    find "${PROJECT_ROOT}/lcm-types/python" -name "*.py" -type f -exec cp {} "$DIST_DIR/lcm-types/python/" \; 2>/dev/null || true
    echo -e "${GREEN}✓ LCM Python 类型定义已复制${NC}"
else
    echo -e "${YELLOW}⚠️  警告: 找不到 LCM Python 类型定义目录${NC}"
fi

# 4.2 复制 MuJoCo 仿真器
echo -e "${CYAN}🤖 复制 MuJoCo 仿真器...${NC}"
if [ -d "${PROJECT_ROOT}/mujoco_sim" ]; then
    mkdir -p "$DIST_DIR/mujoco_sim"
    cp -r "${PROJECT_ROOT}/mujoco_sim"/* "$DIST_DIR/mujoco_sim/" 2>/dev/null || true
    echo -e "${GREEN}✓ MuJoCo 仿真器已复制${NC}"
else
    echo -e "${YELLOW}⚠️  警告: 找不到 MuJoCo 仿真器目录${NC}"
fi

# 5. 复制 ONNX 模型文件（如果存在且未嵌入）
echo -e "${CYAN}🤖 检查 ONNX 模型...${NC}"
if [ -d "${PROJECT_ROOT}/actor_model" ]; then
    # 检查是否启用了嵌入模型
    EMBEDDED_MODEL_H=""
    if [ -f "$BUILD_DIR/user/YBT_Controller/generated/embedded_onnx_models.h" ]; then
        EMBEDDED_MODEL_H="$BUILD_DIR/user/YBT_Controller/generated/embedded_onnx_models.h"
    elif [ -f "${PROJECT_ROOT}/build/user/YBT_Controller/generated/embedded_onnx_models.h" ]; then
        EMBEDDED_MODEL_H="${PROJECT_ROOT}/build/user/YBT_Controller/generated/embedded_onnx_models.h"
    fi
    
    if [ -n "$EMBEDDED_MODEL_H" ]; then
        echo -e "${GREEN}✓ ONNX 模型已嵌入到库中，无需复制模型文件${NC}"
    else
        echo -e "${YELLOW}⚠️  警告: ONNX 模型未嵌入，将复制模型文件${NC}"
        mkdir -p "$DIST_DIR/models"
        cp -r "${PROJECT_ROOT}/actor_model/"* "$DIST_DIR/models/" 2>/dev/null || true
        echo -e "${GREEN}✓ ONNX 模型文件已复制${NC}"
    fi
fi

# 6. 复制必要的脚本
echo -e "${CYAN}📜 复制脚本文件...${NC}"
SCRIPTS_TO_COPY=(
    "run_controller.sh"
    "start_mujoco.sh"
    "setup_lcm_network.sh"
    "show_network_bandwidth.sh"
    "install_python_lcm.sh"
    "setup_conda_env.sh"
    "remove_conda_env.sh"
)

for script in "${SCRIPTS_TO_COPY[@]}"; do
    if [ -f "${PROJECT_ROOT}/scripts/$script" ]; then
        cp "${PROJECT_ROOT}/scripts/$script" "$DIST_DIR/scripts/"
        chmod +x "$DIST_DIR/scripts/$script"
        echo "  ✓ $script"
    fi
done

# 修改脚本中的路径（适配分发包结构）
if [ -f "$DIST_DIR/scripts/run_controller.sh" ]; then
    sed -i "s|PROJECT_ROOT=\"\${SCRIPT_DIR}/..\"|PROJECT_ROOT=\"\${SCRIPT_DIR}/..\"|g" "$DIST_DIR/scripts/run_controller.sh" || true
fi

if [ -f "$DIST_DIR/scripts/start_mujoco.sh" ]; then
    sed -i "s|PROJECT_ROOT=\"\${SCRIPT_DIR}/..\"|PROJECT_ROOT=\"\${SCRIPT_DIR}/..\"|g" "$DIST_DIR/scripts/start_mujoco.sh" || true
fi

# 7. 创建可移植启动包装器
echo -e "${CYAN}🔧 创建可移植启动包装器...${NC}"
cat > "$DIST_DIR/bin/ybt_ctrl" << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REAL_BIN="${SCRIPT_DIR}/ybt_ctrl.bin"

if [ ! -x "${REAL_BIN}" ]; then
    echo "错误: 找不到控制器二进制: ${REAL_BIN}"
    exit 1
fi

export LD_LIBRARY_PATH="${PROJECT_ROOT}/lib:${LD_LIBRARY_PATH}"
export PYTHONPATH="${PROJECT_ROOT}:${PROJECT_ROOT}/lcm-types/python:${PYTHONPATH}"

exec "${REAL_BIN}" "$@"
EOF
chmod +x "$DIST_DIR/bin/ybt_ctrl"
echo -e "${GREEN}✓ 启动包装器已创建${NC}"

# 8. 修复 RPATH（如果 patchelf 可用）
if command -v patchelf >/dev/null 2>&1; then
    echo -e "${CYAN}🔧 修复可执行文件的 RPATH...${NC}"
    # 设置 RPATH 为相对路径，指向 lib 目录
    patchelf --set-rpath '$ORIGIN/../lib' "$DIST_DIR/bin/ybt_ctrl.bin" 2>/dev/null && \
        echo -e "${GREEN}✓ RPATH 已修复为相对路径 (\$ORIGIN/../lib)${NC}" || \
        echo -e "${YELLOW}⚠️  警告: 无法修复 RPATH，运行时可能需要设置 LD_LIBRARY_PATH${NC}"
    
    # 验证 RPATH 设置
    if patchelf --print-rpath "$DIST_DIR/bin/ybt_ctrl.bin" 2>/dev/null | grep -q '\$ORIGIN/../lib'; then
        echo -e "${GREEN}✓ RPATH 验证成功${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  警告: patchelf 不可用，已改用包装器注入 LD_LIBRARY_PATH${NC}"
fi

# 9. 生成 README
echo -e "${CYAN}📄 生成 README 文档...${NC}"
cat > "$DIST_DIR/README.md" << 'EOF'
# Yobotics Quad Controller

四足机器人强化学习控制框架 - 客户分发包

## 快速开始

### 1. 环境配置

#### 系统依赖
```bash
sudo apt-get update
sudo apt-get install -y liblcm-dev libeigen3-dev
```

#### LCM 网络配置（如需要）
```bash
sudo ./scripts/setup_lcm_network.sh
```

#### Python LCM（如需要使用外部算法）
```bash
./scripts/install_python_lcm.sh
```

### 2. 运行控制器

#### 仿真模式
```bash
./scripts/start_mujoco.sh
```

#### 硬件模式
```bash
./scripts/run_controller.sh
```

## 目录结构

```
Yobotics_Quad_Controller/
├── bin/                    # 可执行文件
│   └── ybt_ctrl         # 主控制器程序
├── lib/                    # 依赖库文件
├── config.yaml            # 配置文件
├── models/                # ONNX 模型文件（如果未嵌入）
├── resources/             # 资源文件（URDF等）
├── lcm-types/             # LCM 类型定义
│   └── python/            # Python 类型定义（用于仿真器）
├── mujoco_sim/            # MuJoCo 仿真器模块
├── scripts/               # 工具脚本
└── log/                   # 日志文件目录
```

## 配置文件

主要配置文件为根目录下的 `config.yaml`，包含：
- 机器人参数配置
- 控制模式设置
- 通信接口配置
- 安全保护参数

## 控制模式

使用游戏手柄/遥控器切换控制模式：
- `START` 按钮：下一个模式
- `BACK` 按钮：上一个模式

可用模式：
- `RECOVERY_STAND`: 恢复站立
- `RL_WALK`: 强化学习行走
- `DEVELOPMENT`: 外部算法控制

## 故障排除

### 库文件找不到
如果运行时提示找不到库文件（如 `libonnxruntime.so.1: cannot open shared object file`），请设置 LD_LIBRARY_PATH：

```bash
export LD_LIBRARY_PATH=$PWD/lib:$LD_LIBRARY_PATH
```

或者创建一个包装脚本：

```bash
#!/bin/bash
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
./bin/ybt_ctrl "$@"
```

**注意**：如果分发包是通过 `create_customer_package.sh` 创建的，可执行文件应已设置 RPATH，通常不需要手动设置 LD_LIBRARY_PATH。如果仍有问题，请检查：
1. `lib/libonnxruntime.so.1` 文件是否存在
2. 符号链接是否有效（`ls -l lib/libonnxruntime.so*`）

### LCM 通信问题
检查网络配置：
```bash
./scripts/setup_lcm_network.sh
./scripts/show_network_bandwidth.sh
```

## 技术支持

如有问题，请联系技术支持团队。

EOF
echo -e "${GREEN}✓ README 已生成${NC}"

# 9. 生成版本信息
echo -e "${CYAN}📋 生成版本信息...${NC}"
VERSION="1.0.0"
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
cat > "$DIST_DIR/VERSION.txt" << EOF
Yobotics Quad Controller
Version: $VERSION
Build Date: $BUILD_DATE
Build Directory: $BUILD_DIR
EOF
echo -e "${GREEN}✓ 版本信息已生成${NC}"

# 10. 生成文件清单
echo -e "${CYAN}📋 生成文件清单...${NC}"
cat > "$DIST_DIR/FILES.txt" << EOF
分发包文件清单
生成时间: $(date)

目录结构:
EOF
tree -L 3 "$DIST_DIR" >> "$DIST_DIR/FILES.txt" 2>/dev/null || find "$DIST_DIR" -type f | sort >> "$DIST_DIR/FILES.txt"
echo -e "${GREEN}✓ 文件清单已生成${NC}"

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ 分发包创建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo "分发包位置: $DIST_DIR"
echo "可执行文件: $DIST_DIR/bin/ybt_ctrl"
echo ""
echo "下一步："
echo "  1. 进入分发包目录: cd $DIST_NAME"
echo "  2. 查看 README.md 了解使用方法"
echo "  3. 运行控制器: ./scripts/start_mujoco.sh (仿真) 或 ./scripts/run_controller.sh (硬件)"
echo ""
