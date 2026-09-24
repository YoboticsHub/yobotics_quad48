# Quad48 四足机器人控制框架使用说明书

本文档用于指导用户安装、配置、启动、调试和二次开发 Quad48 四足机器人控制框架。

## 文档信息

<table>
  <colgroup>
    <col style="width: 7em; min-width: 7em;" />
    <col />
  </colgroup>
  <thead>
    <tr>
      <th>项目</th>
      <th>内容</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>文档版本</td>
      <td>1.0</td>
    </tr>
    <tr>
      <td>适用软件</td>
      <td>Quad48 四足机器人控制框架</td>
    </tr>
    <tr>
      <td>修订日期</td>
      <td>2026-09-04</td>
    </tr>
    <tr>
      <td>适用机型</td>
      <td>Quad48 控制框架；实物机型覆盖 <strong>E15</strong>（RK3588 / aarch64）与 <strong>Y15</strong>（x86_64）。仿真与 SDK 流程二者通用，SPI、IMU、二进制目录等机型差异详见3.1 实物部署原理-Y15 与 E15 的 SPI 差异、3.2 修改 config</td>
    </tr>
  </tbody>
</table>


## 推荐阅读路径

| 用户类型 | 推荐路径 | 目标 |
| --- | --- | --- |
| 首次使用人员 | 第一部分 -> 第二部分 | 完成环境配置并跑通 MuJoCo 仿真 |
| 现场交付人员 | 第一部分 -> 第二部分 -> 第三部分 | 从仿真验证切换到实物部署 |
| SDK 集成人员 | 第一部分 -> 第四部分 | 通过 SDK 读取状态、下发运动命令或 HTTP 控制 |
| ROS 2 集成人员 | 第一部分 -> 第四部分 -> 第六部分 | 构建 ROS 2 SDK 并通过标准话题下发运动命令 |
| 算法开发人员 | 第二部分 -> 第五部分 -> 第三部分 | 在仿真中验证自研算法，再部署到实物 |

## 使用原则

- 先仿真、再实机：新模型、新脚本、新参数必须先在 MuJoCo 或安全支架环境中验证。（详见2.1 MuJoCo 仿真的作用-仿真和实物的关系、3.1 实物部署原理-从仿真到实物的运行时序）
- 先默认配置、再小步修改：不要一次性修改多个通信、模型和安全参数。（详见1.3 软件包目录-配置文件定位、3.2 修改 config-核心配置）
- 先验证算法、再上机器人：确认关节顺序、动作幅值、PD 参数、LCM 通道和日志输出后再实物运行。（详见2.3 验证预部署模型、5.7 自研算法实物部署-仿真到实物检查清单）
- 实机运行前必须确认急停、供电、地面环境、线缆、IMU、SPI 设备配置。（详见3.2 修改 config-配置核对流程、3.4 实物运行检查与安全停止-运行前检查）

## 常用入口

本处仅列常用命令，详细操作请到对应章节阅读，不要仅凭下列命令开始正式操作。

```bash
# 准备 Python / MuJoCo / LCM 环境（详情见1.2 系统要求-初次配置、1.4 初次使用流程）
bash scripts/setup_conda_env.sh

# 启动 MuJoCo 仿真（详情见2.2 启动仿真）
bash scripts/start_mujoco.sh --config config_sim.yaml

# 启动实物控制器（详情见3.3 实物机器人部署运行-启动实物控制器）
bash scripts/run_robot_controller.sh --config config.yaml

# 监控 LCM 通道（详情见2.4 仿真调试-LCM Monitor）
bash scripts/monitor_lcm.sh --no-gui
```

真实机器人运行涉及运动安全风险。未确认原因前，不要重复运行异常模型、异常脚本或异常配置。

## 机器人操作视频
以E15型号四足机器人为例：

![type:video](videos/E15.mp4)
