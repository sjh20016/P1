# Prototype 0.03 验证记录

2026-09-10。Windows x64，Godot 4.7.2.stable.official.ed1daf0bf，UHD 730 / OpenGL Compatibility / 1280×800 / 120 Hz 物理。

## 最终源工程检查

`tools/run_checks.ps1 -Rnd -Stress` 全部通过：8 组原回归、4 组 0.03 专项、21,600 物理帧长期测试。长期循环峰值速度 55.903 m/s、刚体 40 / 48、墨迹 241 / 768，破坏 243 次，异常帧 0，碎片最终回收。导入无脚本错误，主场景多次载入 / 释放无资源泄漏。

0.03 专项比较三种抓钩、三种瞄准辅助、法向动量损失、坠落宽限、物理墙面蹬出、双手共享脉冲、收绳释放和重复重开。60 / 90 / 120 Hz 的真实扫切均通过。默认保持 120 Hz。

## 真实渲染与玩法路径

从正常出生点实际抓环并改抓 Gate A，撞穿后截图约 53 m/s；实际塔林分站验证切梁后约 69 m/s、内部入口可穿过、危险下坠变为向上约 29 m/s、重型终点撞穿后约 39 m/s。截图直接来自 Godot 视口。

首段没有中途传送；其余为显式标记的站点重放，不作为无辅助完整通关证据。真人的趣味性、音效重量与完整路线用时仍需试玩判断。

## 大量建筑保留分段状态

固定种子激活 358 栋，随机尝试破坏 1–3 段，实际 501 段；保留分段状态，600 渲染帧测量。空间筛选前 p50 / p95 为 33.425 / 372.679 ms；筛选后为 32.581 / 34.571 ms，最终 FPS 采样分别 29 / 38。两次为同脚本真实运动，最终视角不完全锁定；这是本机压力观察，不承诺全场 60 FPS。

筛选后再次通过精确扫掠、冷却、低速 / 松绳拒绝与三频率路线测试。所有分段持续激活的极端场景仍约 30–38 FPS，未来优化方向已记录。

## Windows 构建

独立 EXE 实际运行通过：

```text
EXPORT SMOKE fracture=true sweeps=2
EXPORT FULL WORLD break=true ink=true
EXPORT COURSE hybrid=true route_A=true
EXPORT SMOKE RESULT PASS
```

图形错误日志为空。程序为嵌入资源的 Windows x64 EXE，155,380,104 字节；SHA-256：`4078D8A3B61B8FAA8106F930C5415AFEAC2A48DA0C7B33435C715AD45A1B03EC`。随包提供中文说明、引擎许可与四份研发报告。

首次导出写出文件但返回失败；显式重新导入后导出返回 0，构建脚本已固定先导入再导出。最终使用成功导出的 EXE 运行上述烟雾测试。ZIP 全条目 CRC 验证与内嵌 EXE 散列核对通过；ZIP 自身散列另存为同名 `.zip.sha256` 文件，避免校验值被包含在自身内容中。

## 重现与证据

```powershell
./tools/run_checks.ps1 -Rnd -Stress
./tools/build_windows.ps1
./build/RAVAGE-0.03-Windows/RAVAGE.exe -- --smoke-test
```

完整研发记录在 `rnd003/`。`rnd003/evidence` 保留 JSON 与摘要日志；本机 build/rnd003 保留全部截图、详细日志及测量。图形脚本为 capture_rnd003.gd、capture_course_stations003.gd、capture_segmented003.gd。

原始 Blender 文件不变，Windows 包不含开发测试脚本和导入中间 GLB。0.02 与 0.01 的独立验证分别保存在 VALIDATION-0.02.md、VALIDATION-0.01.md。
