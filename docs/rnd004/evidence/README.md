# 0.04 证据索引

- `regression.txt`：19 个脚本全部通过及长期回归摘要；`test-*.txt`：新破坏系统完整断言。
- `01-menu.png` / `02-breach-start.png`：最终中文菜单与玩家视角；`04-ram.png` / `05-slash.png`：相同塔、相同机位、无 HUD 和场景文字。
- `07-delay.png` / `08-falling.png` / `10-ruin.png`：一次固定 SLASH 注入后的实际结构演算；`11-contact-scar.png`：接触侧伤口；`12-export-smoke.png`：独立发布程序视口。
- `performance.json`：最终图形逐帧间隔与每 0.5 秒计数；`performance_summary.json`：nearest-rank p95 统计。`performance-before-font-pass.json` 保留较早一次 122 ms 尖峰，不作字重优化前后对照实验。
- `collider_race.json` / `candidate_races.json` / `budget_stress.json`：独立比例、伤痕 / 宏运动候选、预算试验；`macro_metrics.json` / `render_metrics.json`：功能夹具数据。截图期间的帧间隔不用于最终性能结论。
- `build-verification.json` 与 `export-smoke.txt`：EXE 散列、退出码、错误日志字节数及导出资源测试。

图片没有后期修图。自然输入脚本和固定损伤注入夹具的区别见 PLAYTEST_004.md。自动测试不能判断爽感。
