# 0.03 技术候选

继续扩展前，先收集本版真人对抓取、速度控制、撞击重量和救援窗口的反馈。以下候选没有作为当前可玩功能承诺。

| 候选 | 状态 | 下一次最小实验 / 启动条件 |
|---|---|---|
| Hybrid Grab / Motor | KEEP | 用 F8 的真实失败位置调整近距离拉力和辅助范围；优先解决“抓住后撞锚失速” |
| 纯弹簧 / 径向摆锤 | 对照保留 | 同一段路线按 1/2/3 比较，避免一次换多个参数 |
| 双钩拉扯塔体 | REVISIT | 基础移动获得正面反馈后，只用一个预制塔段测试双锚张力差触发破坏 |
| 单点穿刺 | REVISIT | 验证瞄点、入口和出口反馈是否提供独立于身体冲撞的价值 |
| 螺旋切割 | 暂缓 | 先确认现有扫切易理解；不增加大范围连锁与碎片预算 |
| 裂变移动 | 暂缓 | 先纸面研究切换视点与速度继承；当前没有分身、分身 AI 或多角色物理 |
| Fake Structure | MERGE 小样 | 课程只有一块檐板倾斜、延迟下降、2.5 秒清理；若重量感有效，再扩展极少数作者指定组合 |
| Support Graph | 暂缓 | 只有悬空结构严重破坏体验时再做固定小场的连通性实验，不建立全图真实应力系统 |
| 全分段状态性能 | REVISIT | 实测长帧已降低，但全部 358 栋激活仍约 30–38 FPS；研究远距静态段批次 / 休眠 |
| 60 / 90 Hz 物理 | REVISIT | 固定夹具已通过；保持 120，待高速掠边与真人对比足够再决定 |
| 自动贴墙 | KILL 当前默认 | 高速流动优先；保留 Shift 主动短停 + Space 蹬出实验 |
| 真实绳索、运行时网格切割、流体 | 范围外 | 当前预算与动作目标不需要引入这些系统 |

当前技术护栏：CharacterBody3D 玩家、StaticBody3D 环境、预制破坏状态、最多 48 活跃大碎片、768 墨迹、GPU 小碎屑、有限地图。未来动作必须复用这些预算或通过独立证据证明改变预算的必要性。

实现依据为 Godot 官方 API 与现有项目；未引入第三方破坏插件。空间查询与投影接口参考：[PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)、[Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)、[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)。
