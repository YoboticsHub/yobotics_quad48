from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='sdk_ros2',
            executable='yobotics_sdk_node',
            name='yobotics_sdk_node',
            output='screen',
        )
    ])
