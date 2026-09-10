# RAVAGE · Living Ink / Prototype 0.02

Godot **4.7.2 Stable** / GDScript / Windows x64。固定 Blender 塔林中的双触手摆荡、分段破坏与黑白墨迹实验。

## 开始游戏

解压 Windows 构建包，双击 **RAVAGE.exe**。本机可双击根目录的 **开始游戏.cmd**，或运行 `build/RAVAGE-0.02-Windows/RAVAGE.exe`。
源工程为 `project/project.godot`，使用 Godot 4.7.2 打开后按 F5。

开始菜单点击 **ENTER THE CANYON** 或按 Enter。建筑表面与黑色圆环都能抓取。塔身、桥梁、平台和抓取环均可破坏。

| 操作 | 按键 |
|---|---|
| 相机 | 鼠标移动 |
| 移动 / 空中微调 | WASD |
| 左 / 右触手 | 按住鼠标左 / 右键；松开保持惯性 |
| 收绳 / 放绳 | Q / E |
| 跳跃 | Space |
| 回到出生平台 | R，保留破坏、墨迹和分数；必要时恢复出生平台 |
| 恢复地图与墨迹，重新开始 | F5 |
| 扫击练习 | F2，重置一局，带初速和右钩进入演示位置，可立即接管 |
| 调试 HUD / 线条 | F3 |
| 暂停 | Esc |
| 全屏 | F11 |

跳下平台，瞄准上方建筑按住鼠标键，借下坠和 WASD 形成摆荡。松开后改抓另一侧。约 **19 m/s 的迎面撞击**可以破坏建筑段，42 m/s 以上触发较强反馈。绷紧触手在玩家速度至少 22 m/s 时扫过建筑段，也会造成破坏。

## 0.02 内容

- 358 个 Blender 建筑物件，离线预制 **4,944 个可破坏段**。首次破坏时加载该建筑的分段表示；击中段消失，邻段继续支持碰撞与抓取。
- 原有 14 个独立部件，加上出生平台和 9 个抓取环，总计还有 24 个独立破坏目标。
- 暖白纸面建筑、浅灰明暗、白雾背景；黑色脉动核心、8 条不规则细触须、两条渐细的抓取触手。
- 抓取、松钩、快速擦墙和破坏飞溅在真实表面留下墨迹。新墨有微弱湿润反光，约 7 秒后变哑光。
- 墨迹最多保留 768 处，超额替换最旧记录。每 32 处为一个绘制批次，只上传变化批次。被破坏表面的墨迹随之清除，保留表面的墨迹继续存在。
- 黑色暴露断面；复用用户提供的 R01–R04 碎石资产。每次 4 或 6 块大碎片，全场最多 48 个活跃刚体，约 4.5–4.8 秒回收。
- 保留弹簧双钩、扫击、GPU 碎屑、短震屏、35/52 毫秒 Hit Stop、冲击声、速度线及计分。

大建筑采用约 24 米高的离线分段，破坏位置受这些段边界约束。新增建筑破坏使用代表性碎石，**没有逐体积还原所有碎块，也没有失去支撑后的整塔倒塌**。本版没有实时切网格、真实绳索、无限地图、敌人或流体模拟。

## 调参

在 Inspector 中编辑 `assets/placeholders/movement.tres`、`grapple.tres` 和 `impact_*.tres` 调整移动、抓钩与冲击。Player/TentacleSweep 控制扫击阈值；DestructionManager 控制碎片预算和寿命；InkMarks 控制墨迹预算、干燥时间及擦痕采样间隔；Player/InkBody 控制视觉触须数量和长度。

纸面材质与核心视觉位于 `assets/placeholders/paper.tres`、`living_ink.tres` 和 `shaders/`。美术方向与技术范围见 `docs/ART_DIRECTION.zh-CN.md`。

F3 显示 FPS、速度、左右钩状态、绳长、张力、刚体与墨迹数量、破坏及扫击次数；调试线条使用辅助色以区分左右钩。

## 验证与打包

```powershell
./tools/run_checks.ps1
./tools/run_checks.ps1 -Stress
./tools/build_windows.ps1
./build/RAVAGE-0.02-Windows/RAVAGE.exe -- --smoke-test
```

验证记录见 `docs/VALIDATION.md`。开发测试与 GLB 导入中间资产不进入 Windows 发布包。正常双击程序进入菜单；`--smoke-test` 专供导出验证。

本机 `.tools` 已准备官方 4.7.2 引擎及 Windows 模板，不提交 Git。在其他电脑重新导出时，安装同版本官方模板并调整导出预设中的自定义模板路径。

## 资产管线与阶段

原始文件位于 `资产模型`，未覆盖修改。以下工具均离线运行：

1. `tools/export_tower_map.py`、`project/tools/bake_assets.gd`：原有地图与 14 组完整 / 破碎配对。
2. `tools/export_destructible_world.py`：Blender 塔林分段、封口、稳定 ID 与清单。
3. `project/tools/bake_ink_rubble.gd`：四块预制碎石及凸碰撞。
4. `project/tools/bake_destructible_world.gd`：建筑完整表示、分段表示、碰撞与纸面 / 断面材质。
5. `tools/make_main_scene.py`：固定主场景布局。

游戏运行不需要 Blender。所有破坏经 `DestructibleSegment.break_segment()` 进入；玩家只提供移动信号，撞击探测器和扫击器独立判定。

`checkpoint-0-movement` 至 `checkpoint-7-tower-map` 保留 0.01 开发阶段；`checkpoint-8-full-destruction` 保存全建筑破坏；后续水墨与发布阶段继续独立记录。灰盒和实验场保留，便于调试基础玩法。
