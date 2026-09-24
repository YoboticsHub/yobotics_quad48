#include <chrono>
#include <cstdlib>
#include <functional>
#include <memory>
#include <mutex>
#include <string>

#include <geometry_msgs/msg/twist.hpp>
#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/joint_state.hpp>
#include <std_srvs/srv/trigger.hpp>

#include "robot/channel/channel_subscriber.hpp"
#include "robot/sport/sport_client.hpp"
#include "sdk_ros2/msg/control_command.hpp"
#include "sdk_ros2/srv/set_mode.hpp"

using yobotics::robot::ChannelSubscriber;
using yobotics::robot::SportClient;

class YoboticsSdkNode final : public rclcpp::Node {
public:
  YoboticsSdkNode()
  : Node("yobotics_sdk_node"), lcm_(resolve_lcm_url()), subscriber_(&lcm_) {
    sport_ = std::make_unique<SportClient>();
    control_sub_ = create_subscription<sdk_ros2::msg::ControlCommand>(
      "control_command", 10,
      std::bind(&YoboticsSdkNode::on_control_command, this, std::placeholders::_1));
    cmd_sub_ = create_subscription<geometry_msgs::msg::Twist>(
      "cmd_vel", 10, std::bind(&YoboticsSdkNode::on_cmd_vel, this, std::placeholders::_1));
    mode_srv_ = create_service<sdk_ros2::srv::SetMode>(
      "set_mode", std::bind(&YoboticsSdkNode::on_set_mode, this,
                             std::placeholders::_1, std::placeholders::_2));
    stop_srv_ = create_service<std_srvs::srv::Trigger>(
      "stop", std::bind(&YoboticsSdkNode::on_stop, this,
                         std::placeholders::_1, std::placeholders::_2));
    joint_pub_ = create_publisher<sensor_msgs::msg::JointState>("joint_states", 10);
    control_timer_ = create_wall_timer(
      std::chrono::milliseconds(50), std::bind(&YoboticsSdkNode::run_control, this));
    state_timer_ = create_wall_timer(
      std::chrono::milliseconds(50), std::bind(&YoboticsSdkNode::publish_state, this));
    RCLCPP_INFO(
      get_logger(), "Yobotics SDK ROS2 node started at 20 Hz, LCM URL: %s",
      resolve_lcm_url().c_str());
  }

  ~YoboticsSdkNode() override { sport_->Damp(); }

private:
  enum class ControlMode {
    PASSIVE,
    DAMP,
    RECOVERY_STAND,
    STAND_DOWN,
    RL_WALK,
    DEVELOPMENT
  };

  static std::string resolve_lcm_url() {
    const char *value = std::getenv("YOBOTICS_LCM_URL");
    return value && *value ? value : "udpm://239.255.76.67:7667?ttl=255";
  }

  static bool parse_mode(const std::string &value, ControlMode &mode) {
    if (value == "passive") mode = ControlMode::PASSIVE;
    else if (value == "damp") mode = ControlMode::DAMP;
    else if (value == "recovery_stand") mode = ControlMode::RECOVERY_STAND;
    else if (value == "stand_down") mode = ControlMode::STAND_DOWN;
    else if (value == "rl_walk") mode = ControlMode::RL_WALK;
    else if (value == "development") mode = ControlMode::DEVELOPMENT;
    else return false;
    return true;
  }

  static bool is_motion_mode(ControlMode mode) {
    return mode == ControlMode::RL_WALK || mode == ControlMode::DEVELOPMENT;
  }

  void clear_velocity() {
    cmd_vx_ = 0.0f;
    cmd_vy_ = 0.0f;
    cmd_wz_ = 0.0f;
    has_velocity_command_ = false;
  }

  void update_velocity(const geometry_msgs::msg::Twist &cmd_vel) {
    cmd_vx_ = static_cast<float>(cmd_vel.linear.x);
    cmd_vy_ = static_cast<float>(cmd_vel.linear.y);
    cmd_wz_ = static_cast<float>(cmd_vel.angular.z);
    last_cmd_time_ = std::chrono::steady_clock::now();
    has_velocity_command_ = true;
  }

  void on_control_command(
      const sdk_ros2::msg::ControlCommand::SharedPtr msg) {
    ControlMode requested_mode;
    if (!parse_mode(msg->mode, requested_mode)) {
      RCLCPP_WARN_THROTTLE(
        get_logger(), *get_clock(), 2000,
        "Ignoring control_command with unsupported mode '%s'", msg->mode.c_str());
      return;
    }

    std::lock_guard<std::mutex> lock(mutex_);
    current_mode_ = requested_mode;
    if (is_motion_mode(current_mode_)) {
      update_velocity(msg->cmd_vel);
    } else {
      clear_velocity();
    }
  }

  void on_cmd_vel(const geometry_msgs::msg::Twist::SharedPtr msg) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (is_motion_mode(current_mode_)) {
      update_velocity(*msg);
    } else {
      clear_velocity();
    }
  }

  void on_set_mode(const std::shared_ptr<sdk_ros2::srv::SetMode::Request> req,
                   std::shared_ptr<sdk_ros2::srv::SetMode::Response> res) {
    ControlMode requested_mode;
    if (!parse_mode(req->mode, requested_mode)) {
      res->code = -1;
      res->success = false;
      res->message = "unsupported mode";
      return;
    }

    std::lock_guard<std::mutex> lock(mutex_);
    current_mode_ = requested_mode;
    clear_velocity();
    res->code = 0;
    res->success = true;
    res->message = "mode command accepted";
  }

  void on_stop(const std::shared_ptr<std_srvs::srv::Trigger::Request>,
               std::shared_ptr<std_srvs::srv::Trigger::Response> res) {
    std::lock_guard<std::mutex> lock(mutex_);
    current_mode_ = ControlMode::DAMP;
    clear_velocity();
    res->success = sport_->Damp() == 0;
    res->message = res->success ? "damp command published" : "failed";
  }

  int32_t send_current_mode() {
    switch (current_mode_) {
      case ControlMode::PASSIVE: return sport_->Passive();
      case ControlMode::DAMP: return sport_->Damp();
      case ControlMode::RECOVERY_STAND: return sport_->RecoveryStand();
      case ControlMode::STAND_DOWN: return sport_->StandDown();
      case ControlMode::RL_WALK: return sport_->RLWalk();
      case ControlMode::DEVELOPMENT: return sport_->Development();
    }
    return -1;
  }

  void run_control() {
    std::lock_guard<std::mutex> lock(mutex_);
    sport_->EnableLCMControl();
    send_current_mode();

    if (!is_motion_mode(current_mode_)) {
      clear_velocity();
      return;
    }

    const auto now = std::chrono::steady_clock::now();
    if (has_velocity_command_ &&
        now - last_cmd_time_ > std::chrono::milliseconds(500)) {
      clear_velocity();
      RCLCPP_WARN(get_logger(), "cmd_vel timed out after 0.5 s; sending zero velocity");
    }
    sport_->Move(cmd_vx_, cmd_vy_, cmd_wz_);
  }

  void publish_state() {
    quad_joint_state_t state{};
    subscriber_.read(&state);
    sensor_msgs::msg::JointState msg;
    msg.header.stamp = now();
    static const char *names[12] = {
      "fl_abad", "fl_hip", "fl_knee", "fr_abad", "fr_hip", "fr_knee",
      "rl_abad", "rl_hip", "rl_knee", "rr_abad", "rr_hip", "rr_knee"};
    msg.name.assign(names, names + 12);
    msg.position.assign(state.joint_q, state.joint_q + 12);
    msg.velocity.assign(state.joint_qd, state.joint_qd + 12);
    msg.effort.assign(state.joint_tau, state.joint_tau + 12);
    joint_pub_->publish(msg);
  }

  lcm::LCM lcm_;
  ChannelSubscriber subscriber_;
  std::unique_ptr<SportClient> sport_;
  std::mutex mutex_;
  ControlMode current_mode_{ControlMode::DAMP};
  float cmd_vx_{0.0f};
  float cmd_vy_{0.0f};
  float cmd_wz_{0.0f};
  bool has_velocity_command_{false};
  std::chrono::steady_clock::time_point last_cmd_time_{};
  rclcpp::Subscription<sdk_ros2::msg::ControlCommand>::SharedPtr control_sub_;
  rclcpp::Subscription<geometry_msgs::msg::Twist>::SharedPtr cmd_sub_;
  rclcpp::Service<sdk_ros2::srv::SetMode>::SharedPtr mode_srv_;
  rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr stop_srv_;
  rclcpp::Publisher<sensor_msgs::msg::JointState>::SharedPtr joint_pub_;
  rclcpp::TimerBase::SharedPtr control_timer_;
  rclcpp::TimerBase::SharedPtr state_timer_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<YoboticsSdkNode>());
  rclcpp::shutdown();
  return 0;
}
