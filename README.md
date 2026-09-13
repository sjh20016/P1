# RAVAGE · CONSEQUENCE · 0.04

Godot **4.7.2 Stable** / Windows x64 / Compatibility。黑色双触手生物在白色塔林中高速抓取、撞入建筑，并留下洞口、切痕与倒塌的残骸。

## 直接游玩

本机双击 **开始游戏.cmd**，或 `build/RAVAGE-0.04-Windows/RAVAGE.exe`。分发包解压后双击 **RAVAGE.exe**，不需要另装 Godot 或 Blender。菜单、操作说明与 HUD 均为中文。

按 **Enter** 进入后果实验场。A 场景先 **空格起跳，按住鼠标左键抓正面塔身**，同时可用 W 向前微调；**撞进洞口后松开抓钩**，保持惯性穿出，再抬头抓住出口梁。R 回出发点会保留这一局的破坏，F5 才会恢复塔体。

F9 切换 B / C，瞄准前方高梁按住鼠标左键，向侧下方摆荡，让绷紧触手扫过塔身。B 观察切断后的延迟起动，C 观察落块与后塔接触。D 用同一座塔反复比较撞洞、切口与黑痕。每次实验是约 10–30 秒的短尝试，没有强制完成倒计时。

| 操作 | 按键 |
|---|---|
| 视角 / 移动和空中微调 | 鼠标 / WASD |
| 左右触手 | 按住鼠标左 / 右键，松开保持惯性 |
| 收绳蓄力 / 放绳 | Q / E，蓄力后松钩弹出 |
| 起跳 / 回出发点 | 空格 / R |
| 重置当前实验 | F5 |
| 后果实验 / 下一实验 | F6 / F9 |
| 原自由塔林 / 0.03 八站路线 | F4 / F10 |
| 原扫切起跑练习 | F2，带辅助初速和抓钩，可立即接管 |
| 调试计数 / 保存遥测 | F3 / F8 |
| 移动模型对照 | 1 / 2 / 3，默认 M03 混合抓钩 |
| 贴墙实验 | F7；开启后 Shift 短停、空格蹬出 |
| 暂停 / 全屏 | Esc / F11 |

身体撞击仍需要面向墙体的速度至少 **26 m/s**；扫切需要速度至少 **20 m/s**、足够张力和真实触手扫动。只把钩挂在墙上不会自动切断它。F3 打开且处于 0.03 路线时，F10 保留“跳到下一站”的辅助验证用途。

## 0.04 做到了什么

- 三座重点塔：首次受损才展开局部墙板，留下真实洞口、残壁、内部梁柱。
- RAM 为洞口、削角和放射黑痕；SLASH 为细长断口、错位切唇及较少碎片。
- 两座结构塔有作者定义的支撑连接；切断弱面后，大块先抖动、倾斜，再下坠。
- 移动大块的真实接触会对另一建筑产生 COLLAPSE 伤害，最后留下有碰撞和抓取面的静态废墟。
- 新伤痕附于墙板局部坐标，随着结构移动。默认最多 **6 个活跃宏块 / 48 个碎片刚体 / 384 个新伤痕**，旧墨迹继续使用原 768 预算。
- 旧 358 栋 Blender 塔林、4,944 个离线破坏段和 M03 移动基线保留；F4 可进入。

高级后果只覆盖独立实验区域的三座塔。它没有把全城升级成实时结构模拟，没有自由 Boolean 切割、无限连锁或双钩 Pull 操作。废墟在本局保留，不保存到下次启动。实际限制见 [KNOWN_PROBLEMS](docs/rnd004/KNOWN_PROBLEMS.md)。

## 实验报告与重现

[重要变化](docs/rnd004/CHANGELOG_RND_004.md) · [方案赛马](docs/rnd004/EXPERIMENTS_004.md) · [测试与真人试玩指南](docs/rnd004/PLAYTEST_004.md) · [技术候选](docs/rnd004/TECH_RADAR_004.md)。测试区分脚本验证、AI 可见画面及真人体验判断，不把自动运行等同于“爽”的证明。

F8 的后果遥测写到 `%APPDATA%/Godot/app_userdata/RAVAGE — CONSEQUENCE 0.04/consequence004/`，包括帧耗时、物理时间、墙板、伤痕、大块、残骸、二次伤害与连锁深度。旧移动遥测仍写到同一用户目录下的 `telemetry003/`。

```powershell
python tools/make_consequence_assets.py
./tools/run_checks.ps1 -Rnd -Consequence -Stress
./tools/build_windows.ps1
./build/RAVAGE-0.04-Windows/RAVAGE.exe -- --smoke-test
python tools/package_windows.py
```

用 Godot 4.7.2 打开 `project/project.godot` 即可运行。结构样本由离线 Python 作者工具编译 JSON 与预制场景；原 Blender 文件在 `资产模型/`，没有被整城重构。引擎和模板在本机 `.tools/`，不提交 Git；其他电脑需要相同版本模板并调整导出路径。

0.03 中文构建在本机 `build/RAVAGE-0.03-Windows/` 保留；其说明和实验记录见 `docs/rnd003/`。资产与引擎许可见 [THIRD_PARTY](docs/THIRD_PARTY.md)。
