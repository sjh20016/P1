# RAVAGE · Towerfall / Prototype 0.01

Godot **4.7.2 Stable** / GDScript / Windows x64。有限固定 Blender 塔林中的双触手摆荡与速度破坏实验。

## 开始游戏

解压独立构建包后，直接运行其中的 **RAVAGE.exe**。
在本机项目目录中，也可以运行 `build/RAVAGE-0.01-Windows/RAVAGE.exe`，或双击根目录的 **开始游戏.cmd**。
源工程为 `project/project.godot`。在 Godot 4.7.2 中打开后按 F6/F5 可运行场景/工程。

开始菜单点击 **ENTER THE CANYON** 或按 Enter。画面里的橙色部件可破坏，青色圆环是醒目的抓点；普通静态建筑表面也可以抓。

| 操作 | 按键 |
|---|---|
| 相机 | 鼠标移动 |
| 移动 / 空中微调 | WASD |
| 左 / 右触手 | 按住鼠标左 / 右键；松开保持惯性 |
| 收绳 / 放绳 | Q / E |
| 从平台跳下 | Space |
| 回到出生平台 | R（保留当前破坏与分数） |
| 恢复全部目标，重新开始 | F5 |
| 触手扫击练习 | F2（重置一局，带初速和右钩进入演示位置，可立即接管） |
| 调试 HUD / 线条 | F3 |
| 暂停 | Esc |
| 全屏 | F11 |

先从平台前沿跳下，瞄准上方建筑按住一只鼠标键，利用下坠和 WASD 形成摆荡，松开后改抓另一边。达到约 19 m/s 的迎面撞击可以击碎橙色段，42 m/s 以上触发较强反馈。绷紧触手在玩家速度至少 22 m/s 时扫过橙色段，同样会使其破碎。

## 本版范围

- CharacterBody3D 玩家；弹簧与阻尼直接影响速度，双钩独立运行。
- 固定 Blender 塔林，358 个静态网格碰撞；无运行时地图生成。
- 14 个可破坏部件：原地图 D01–D12、4 块碎片的横梁 D13、6 块碎片的空心段 D14。
- 每次破坏 4 或 6 个预制大碎片，全场最多 48 个活跃碎片，约 4.5–4.8 秒回收。
- GPU 小碎屑与尘、短震屏、35/52 毫秒 Hit Stop、占位冲击声音、速度线、计分。
- 没有真实绳索、实时网格切割、整塔刚体、无限地图、敌人或传送门。
- **当前并非整张地图都可破坏。** 用户补充的“后续全部可破坏”目标见 `docs/NEXT_ITERATION.zh-CN.md`。

## 调参

在 Inspector 中编辑以下资源：

- `assets/placeholders/movement.tres`：重力、空气阻力、空中微调、速度上限。
- `assets/placeholders/grapple.tres`：弹簧、阻尼、最短/最长绳、单钩/合力上限、收绳速度。
- `assets/placeholders/impact_small.tres`、`impact_medium.tres`、`impact_heavy.tres`：冲击分级、粒子、声音、震屏与停顿。
- Player/TentacleSweep：扫击速度、绷紧阈值、半径、冷却。
- DestructionManager：活跃刚体预算和寿命。
- 每个 DestructibleSegment：破坏阈值、预制碎片场景和判定包围盒。

F3 显示 FPS、完整速度向量、当前/峰值速度、左右钩状态、绳长、Rest Length、Tension、刚体数量、破坏事件和扫击次数；场景中显示抓取射线、抓点、速度向量、扫掠边界和命中点。

## 阶段与验证

Git 标签 `checkpoint-0-movement` 至 `checkpoint-7-tower-map` 保存独立阶段。灰盒 `scenes/maps/graybox.tscn`、破坏实验场 `destruction_lab.tscn`、反馈实验场 `feel_lab.tscn` 继续保留。

在 PowerShell 中执行 `./tools/run_checks.ps1`；添加 `-Stress` 包含三分钟模拟物理压力测试。具体结果见 `docs/VALIDATION.md`。打包执行 `./tools/build_windows.ps1`。

本机 `.tools` 中已准备官方 4.7.2 引擎及 Windows 模板，该目录不提交 Git。在其他电脑上直接用已安装的 Godot 4.7.2 打开源工程；重新导出时安装同版本官方模板，并在导出预设中调整自定义模板路径。

## 资产管线

原始资产位于 `资产模型`，未覆盖修改。`tools/export_tower_map.py` 在 Blender 离线导出静态塔林和已有完整/破碎配对；`project/tools/bake_assets.gd` 在 Godot 中离线烘焙碰撞和刚体场景；`tools/make_main_scene.py` 离线写入固定布局。运行游戏不需要 Blender。

所有破坏经 `DestructibleSegment.break_segment(hit_position, hit_direction, strength)` 进入。Player 仅发出移动事件，独立碰撞探测器和触手扫击器负责判定。碎片与粒子的回收由各自节点管理。
