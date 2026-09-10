# RAVAGE · MOMENTUM / IMPACT · 0.03

Godot **4.7.2 Stable** / GDScript / Windows x64。黑色双触手生物在暖白 Blender 塔林中抓取、摆荡、撞穿与切断建筑。

## 直接开始

本机双击根目录 **开始游戏.cmd**，或运行 `build/RAVAGE-0.03-Windows/RAVAGE.exe`。分发包解压后双击 **RAVAGE.exe**，不需要安装 Godot 或 Blender。

按 **Enter** 进入八站实验路线。第一次先瞄准上方圆环抓取，再抓向写有 RAM 的墙面。松开保留速度，继续抓下一处。路线按约三分钟体验设计，实际用时由操作和重试决定，没有强制倒计时。F4 可进入自由塔林。

| 操作 | 按键 |
|---|---|
| 视角 / 移动与空中微调 | 鼠标 / WASD |
| 左右触手 | 按住鼠标左 / 右键；快速点按突进，松开飞行 |
| 收绳蓄力 / 放绳 | Q / E；有效张力下 Q 蓄力，释放触手弹出 |
| 跳跃 | Space |
| 回检查点 | R；保留破坏、墨迹与分数 |
| 当前模式重新开始 | F5；恢复地图与墨迹 |
| 自由塔林 / 八站路线 | F4 / F6 |
| 扫切练习 | F2；带初速和已抓取的右钩，可立即接管 |
| 移动算法比较 | 1 纯弹簧 / 2 径向摆锤 / 3 Hybrid（默认） |
| 贴墙实验开关 | F7；低速近墙按 Shift 短停，Space 蹬出；最多停 0.45 秒 |
| 保存遥测 / 调试 HUD | F8 / F3 |
| 暂停 / 全屏 | Esc / F11 |

身体撞击要求朝向墙面的速度至少 **26 m/s**。普通结构撞穿后保留大部分速度；斜撞主要损失法向速度。触手切割要求速度至少 **20 m/s**、足够张力和实际扫动；直接抓住目标不会凭空切掉它。

切梁站：抓右上方远环，保持抓钩，向梁侧下方掠过，让绷紧触手扫过横梁。救援站：下坠后转头朝上方建筑或环抓取，不必在旧版高度线立即重来。普通建筑表面与黑色圆环都可抓，建筑、平台、桥梁和抓取环都可破坏。

## 0.03 内容与范围

- 新默认 Hybrid 抓钩：瞬间速度脉冲 + 持续拉力 + 绳长约束。中心未命中时辅助选择附近可见表面，危险坠落时有限提高宽容度。
- 抓取发射 / 命中 / 张力 / 松钩声音、方向反冲、身体挤压、FOV 脉冲；身体重击与触手切割使用不同反馈强度。
- 坠落宽限保留抓钩与空中控制。离开可救援区域、无法继续上升后回到检查点，另保留 -800 m 硬下限。
- 固定八站路线测试撞墙捷径、切梁后新摆荡角度、暴露内部锚点、紧急救援与重型终点。一个作者指定檐板会在支撑被切断后倾斜下落。
- 继承 **358 个 Blender 建筑、4,944 个离线破坏段**，另有 24 个基础独立目标；课程增加 12 个结构与 10 个可破坏抓取环。
- 暖白纸面、黑色核心、8 条视觉触须、双渐细抓钩与方向性墨迹。最多 **768 处墨迹 / 24 绘制批次**，大碎片最多 **48 个活跃刚体**，约 4.5–4.8 秒回收。

建筑按预制段产生缺口，新增大楼用代表性碎石反馈。整塔不会普遍失去支撑后倒塌；没有实时切网格、无限地图、敌人或流体。全部建筑进入分段状态时，本机 UHD 730 集显仍可能降到约 30–38 FPS，见验证记录。

## 实验记录与数据

`docs/rnd003/` 提供 `CHANGELOG_RND_003.md`、`EXPERIMENTS_003.md`、`PLAYTEST_003.md`、`TECH_RADAR_003.md`。客观测试不替代真人对手感和重量的判断。

F8 和正常路线完成会保存 JSON 到：

`%APPDATA%/Godot/app_userdata/RAVAGE — Momentum Impact 0.03/telemetry003/`

记录抓取成功 / Miss、达速时间、平均 / 峰值速度、释放速度、救援、重置、撞击与切割。F3 打开后可用 F10 调试跳到下一站；这种运行标记为 assisted，并显示 STATION CHECK COMPLETE，不能与正常连续通关时间混用。

## 源工程、调参与重现

用 Godot 4.7.2 打开 `project/project.godot` 后按 F5。主要参数在 `assets/placeholders/grapple_m01.tres` 至 `grapple_m03.tres`、`movement.tres`、`impact_*.tres`；切割阈值位于 Player/TentacleSweep，碎片与墨迹预算在对应管理节点。课程由 `tools/make_course003.py` 离线生成，主场景由 `tools/make_main_scene.py` 生成。

```powershell
./tools/run_checks.ps1 -Rnd
./tools/run_checks.ps1 -Rnd -Stress
./tools/build_windows.ps1
./build/RAVAGE-0.03-Windows/RAVAGE.exe -- --smoke-test
```

`-Stress` 包含 21,600 次物理帧的长期循环。渲染与大量分段压力脚本保留在 `project/scripts/debug/capture_*.gd`。开发测试、截图脚本与原始 GLB 导入中间资产不进入 Windows 游戏包。

本机 `.tools` 提供官方引擎与模板，不提交 Git；其他电脑需安装同版模板并调整导出预设路径。原 Blender 文件保留在 `资产模型`，离线资产工具在 `tools/` 和 `project/tools/`，运行游戏不依赖 Blender。

详细验证见 `docs/VALIDATION.md`；0.01 / 0.02 验证与本地构建继续保留。美术继承与限制见 `docs/ART_DIRECTION.zh-CN.md`，资产来源及引擎许可见 `docs/THIRD_PARTY.md`。
