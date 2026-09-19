# 0.04 技术候选

以下是候选，不属于本版可玩功能。

| 候选 | 状态 | 下一次最小验证 |
|---|---|---|
| Pierce / 单点穿刺 | REVISIT | 点状贯穿能否形成不同于 RAM 的伤口和速度决策 |
| Spin Slash / 旋转切割 | REVISIT | 先用一个固定弧面验证清晰度，不增加全屏范围攻击 |
| Dual / Advanced Pull | REVISIT | 双锚各自采样张力，先只拉断一条 Weak Bond，再验证两塔接触 |
| Hero Collapse | REVISIT | 单个地标的 Blender 离线破碎、动画烘焙与少量碰撞代理；先审查烘焙工具许可证 |
| Structural Authoring | KEEP 小样 | 把现有 JSON 的 Chunk / Bond / support / macro_group 导出接到 Blender Custom Properties，而非 runtime 猜拓扑 |
| Support Graph 扩展 | REVISIT | 分叉支撑、桥梁双端地基与两条可替代承重路径，各做一个夹具 |
| Dynamic Interior | REVISIT | 环梁、柱体随分量移动已成立；下一步验证一条内部可抓路径，不做家具或完整房间 |
| Advanced Damage Mask | REVISIT | 批量更新纹理、移动 Chunk UV 重映射；当前 Mesh Scar 已够用，先测真实瓶颈 |
| Scar batching | REVISIT | 少量共享拓扑纹样用 MultiMesh 合批；保留 owner-local 跟随与预算 |
| 静态废墟合并 | REVISIT | 稳定后合并可见网格和碰撞代理，避免长期多次毁坏增加绘制对象 |
| Macro 接触与旋转 | REVISIT | 更准确的旋转扫掠与安全落地，避免任意形状下粗代理与残壁短暂相交 |

保持护栏：M03 默认；原塔林不展开高级图；每块只用少量代理；深度最多 2；移动大块默认 6；碎片刚体 48；新伤痕 384。FEM、每砖约束、全城 Boolean/Voronoi、流体、无限递归不进入后续默认方案。
