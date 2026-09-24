cmake_minimum_required(VERSION 3.10)
project(sdk_ros2 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_compile_options(-Wall -Wextra -Wpedantic)

find_package(ament_cmake REQUIRED)
find_package(builtin_interfaces REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(std_srvs REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(Threads REQUIRED)

find_library(LCM_LIBRARY NAMES lcm REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/ControlCommand.msg"
  "srv/SetMode.srv"
  DEPENDENCIES builtin_interfaces geometry_msgs
)

set(YOBOTICS_VENDOR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/yobotics_sdk")
set(YOBOTICS_VENDOR_INCLUDE_DIR "${YOBOTICS_VENDOR_DIR}/include")

add_library(yobotics_sdk_embedded STATIC
  "${YOBOTICS_VENDOR_INCLUDE_DIR}/robot/sport/sport_client.cpp"
  "${YOBOTICS_VENDOR_INCLUDE_DIR}/robot/channel/channel_all.cpp"
)
target_include_directories(yobotics_sdk_embedded SYSTEM PUBLIC
  "${YOBOTICS_VENDOR_INCLUDE_DIR}"
  "${YOBOTICS_VENDOR_INCLUDE_DIR}/common"
  "${YOBOTICS_VENDOR_INCLUDE_DIR}/robot"
  "${YOBOTICS_VENDOR_INCLUDE_DIR}/robot/channel"
)
target_link_libraries(yobotics_sdk_embedded PUBLIC
  "${LCM_LIBRARY}"
  Threads::Threads
)

add_executable(yobotics_sdk_node src/yobotics_sdk_node.cpp)
target_link_libraries(yobotics_sdk_node yobotics_sdk_embedded)
ament_target_dependencies(yobotics_sdk_node
  geometry_msgs rclcpp sensor_msgs std_srvs
)
add_dependencies(yobotics_sdk_node ${PROJECT_NAME}__rosidl_generator_cpp)
rosidl_get_typesupport_target(cpp_typesupport_target
  ${PROJECT_NAME} "rosidl_typesupport_cpp"
)
target_link_libraries(yobotics_sdk_node "${cpp_typesupport_target}")

install(TARGETS yobotics_sdk_node DESTINATION lib/${PROJECT_NAME})
install(DIRECTORY launch DESTINATION share/${PROJECT_NAME})

ament_export_dependencies(rosidl_default_runtime)
ament_package()
