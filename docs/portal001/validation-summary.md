# 2026-09-19 验证记录

实际引擎：4.7.1.stable.official.a13da4feb。上游源码注释为 4.7.2，未验证该版本。

| 验证 | 结果 | 文件 |
| --- | --- | --- |
| Godot editor import | 通过，无脚本错误 | `import.txt` |
| Portal 数学 / 物理 / 异常处理 | 48 项通过，无失败或退出泄漏 | `portal-tests.txt`, `test-results.json` |
| 正常渲染、WASAPI、真实输入巡检 | 最终零错误；A–H 与重置重试 | `portal-tour.txt`, `rendered-playtest.json` |
| 原移动回归 | failures=0 | `regression-movement.txt` |
| 原抓钩回归 | failures=0 | `regression-grapple.txt` |
| 原破坏回归 | failures=0 | `regression-destruction.txt` |
| 原生命周期回归 | 三轮加载/释放完成 | `regression-lifecycle.txt` |
| 原开放塔回归 | failures=0 | `regression-open006.txt` |
| 原双拉回归 | failures=0 | `regression-dual_pull007.txt` |

帧时间：4491 样本 / 25.45 秒，P95 6.356 ms，P99 8.006 ms，最大 175.943 ms，超过 33.33 ms 共 9 帧。包含截图与重载，不是纯渲染耗时，不是五分钟压力验收。原始样本保存于 `rendered-frames-ms.json`。

巡检经历过失败并修改后重跑：刚体默认阻尼；切割目标被前一步弹丸提前毁坏；出门镜头进入实体墙；头less循环音频释放；一次自动按键未切区。最后一项在巡检禁用输入合并并记录实际区域/控制状态后通过，尚未独立复现原触发条件。保留这些限制，不把“最终通过”解释为没有发生过失败。

这是一轮程序化输入与截图检查，没有真人受试者。七项趣味性问题的逐项判断见根目录 `PORTAL-0.01.md`。
