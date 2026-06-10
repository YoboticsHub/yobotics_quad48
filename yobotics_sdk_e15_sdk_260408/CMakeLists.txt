cmake_minimum_required(VERSION 3.5)

project(yobotics_sdk_e15 C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -fpermissive")

include_directories(
    ${PROJECT_SOURCE_DIR}/include
    ${PROJECT_SOURCE_DIR}/include/common
    ${PROJECT_SOURCE_DIR}/include/robot
    ${PROJECT_SOURCE_DIR}/include/robot/channel
)

add_library(yobotics_sdk STATIC
    include/robot/E15/sport/sport_client.cpp
    include/robot/E15/nav/nav_client.cpp
    include/robot/channel/channel_all.cpp
)

set_target_properties(yobotics_sdk PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/lib
)

add_executable(E15_sport_client example/E15/E15_sport_client.cpp)
add_executable(E15_robot_state_client example/E15/E15_robot_state_client.cpp)
add_executable(E15_http_server example/E15/E15_http_server.cpp)

find_library(LCM_LIBRARY lcm PATHS /usr/local/lib /usr/lib /usr/lib/x86_64-linux-gnu)
if(NOT LCM_LIBRARY)
    message(FATAL_ERROR "LCM library not found. Please install LCM.")
endif()

target_link_libraries(E15_sport_client
    PRIVATE
    ${LCM_LIBRARY}
    yobotics_sdk
    pthread
    -Wl,--start-group
    yobotics_sdk ${LCM_LIBRARY}
    -Wl,--end-group
)

target_link_libraries(E15_robot_state_client
    PRIVATE
    ${LCM_LIBRARY}
    yobotics_sdk
    pthread
    -Wl,--start-group
    yobotics_sdk ${LCM_LIBRARY}
    -Wl,--end-group
)

target_link_libraries(E15_http_server
    PRIVATE
    ${LCM_LIBRARY}
    yobotics_sdk
    pthread
    -Wl,--start-group
    yobotics_sdk ${LCM_LIBRARY}
    -Wl,--end-group
)
