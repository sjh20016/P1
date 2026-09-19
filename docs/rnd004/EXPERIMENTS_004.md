# 0.04 实验与取舍

测试环境：Windows、Godot 4.7.2 Stable `ed1daf0bf`、Compatibility、Intel UHD Graphics 730。移动主工程保留 120 Hz。以下原型由项目内独立代码实现，没有复制参考仓库代码。具体帧耗时和日志见同目录 evidence。

## 参考实现与许可证审查

| 来源 | 实际研究内容 | 许可 / 版本 / 集成决定 |
|---|---|---|
| [NVIDIA Blast](https://github.com/NVIDIAGameWorks/Blast) | Chunk、Bond、Support、Damage 与 Split 的职责分离 | 仓库 `license.txt` 含 NVIDIA proprietary/confidential 条款；不视为可直接复制的宽松许可。只参考概念，不接 SDK。 |
| [Smashing](https://github.com/hanoixan/Smashing) | 读取 `src/__init__.py` 中地面集合与邻接遍历；Shock Speed / Duration | 源文件 GPL v2 或更新版本；旧 Blender 2.91 alpha 插件。独立写作者数据上的 BFS，不复制代码、不装进 Blender 5.2。 |
| [godot-destructible-body](https://github.com/toadile-gd/godot-destructible-body) | 接触点 / 法线驱动局部破坏，完整性阈值转运动物 | MIT；旧 Godot 3 runtime CSG。只取局部损伤到整体失效的模型。 |
| [godot-destruction-plugin](https://github.com/Jummit/godot-destruction-plugin) | Intact → 预切场景的延迟切换 | 代码 MIT，其他文件 CC0；小场景实践，Godot 4.7.2 的本项目接口未直接验证。不替换当前架构。 |
| [Compatibility Decal Node](https://github.com/antzGames/Godot-Compatibility-Decal-Node) | MultiMesh 实例、局部附着、Compatibility 深度投影 | MIT；README 声称测试至 4.7.1，不能据此宣称插件已在 4.7.2 验证。独立实验验证的是本项目 Mesh 方案，未安装该依赖。 |
| [Mesh2Rig](https://github.com/Sporenoe3D/Mesh2Rig) | 离线刚体结果转游戏动画的候选 | GPL；只列研究候选，没有导入代码或用其生成交付资产。 |

宏块扫描碰撞依据 Godot [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) 与 [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) 的官方接口说明。仓库历史较旧的参考，不因可以访问就视为持续维护、可直接兼容当前版本。

## D01 · Local Breach — KEEP

**Hypothesis**：完整外壳按需换成少量局部可损墙板，可以留下真实入口、周围残墙和内部空间，而不是删掉整个纵向段。

**Reference**：Jummit 的 intact/segmented 切换；toadile-gd 的接触位置与法线。

**Prototype**：16 m 外壳跨度、24 m 高、0.8 m 厚、15.2 m 内腔；4 面 × 8 列 × 12 行，384 墙板，首次有效损伤才实例化。简单内柱和横梁按 Chunk 编号随大块移动。元数据由 `tools/make_consequence_assets.py` 离线编译；本轮不是 Blender 导出器升级。

**Result**：中心 RAM 移除 4 个墙板，周围外壳仍在；邻近板切掉一个预定义角，使用一致的凸碰撞体。入口射线为空，旁边残壁射线仍命中。真实 M03 抓取与身体碰撞可以打开两侧墙，穿出后速度约 37.5 m/s，并能再次抓住出口梁。

**Performance**：首次展开的实际 CPU 耗时记入 `panel_activation_us`；旧塔林保持懒加载，不展开 4,944 个段为新墙板。

**Gameplay Observation**：只抓不松可能被保留的锚点拉回；起跳后抓取，撞入时松钩能贯穿。碰撞球按肉核视觉半径 0.5904 m 测 50% / 60% / 70%；初版边缘路线前两项通过，70% 卡在边缘，因此默认选 60%。削角后碰撞宽容度再次变化，最终测量以 `collider_race.json` 为准。触须不参与主体碰撞。

**Decision：KEEP**。保留重点样本，不推广全城；真实自由布尔切割不进入本轮。

## D02 · Scar Race — Mesh KEEP / Runtime Mask KILL 本轮集成

**Hypothesis**：附在残壁上的黑色 Mesh 可以较低集成成本记录伤害历史，且移动时无需维护世界空间贴花。

**Reference**：Compatibility Decal 的实例预算与物体附着思想；并未使用其投影 Shader。

**Prototype A**：复用固定放射 / 长切纹样，按墙板表面裁剪；MeshInstance3D 挂在墙板下，384 FIFO 上限。不是 MultiMesh 合批实现。

**Prototype B**：四张 512×512 RGBA8 面遮罩，384 次 CPU 绘制后逐次 ImageTexture.update。仅独立纹理涂写与上传试验，没有实现移动 Chunk 的 UV 重映射或成品美术质量。

**Result / Performance**：一次本机 Compatibility 原型采样，A 创建 384 个标记约 76.47 ms，顶点数组 456,192 bytes；B 绘制与上传约 1,049.65 ms，CPU 遮罩 4 MiB，GPU 纹理估计另 4 MiB。Headless 的 B 仅约 18.7 ms，说明不能用无图形后端推断上传成本。以上是原型批量创建成本，不是稳定帧率或完整内存占用；A 仍有 Node / Mesh 开销和最多 384 个绘制对象。纹理若批量合并更新可能改善，本轮没有穷尽优化。

**Gameplay Observation**：首轮每块残壁各画一个放射中心，看起来像多个独立弹孔。改成同一伤害中心及同一 Seed，使裂纹跨相邻板衔接。RAM 保留洞和径向黑痕；SLASH 是狭长黑切口与错位切唇。建筑移动时伤痕局部变换保持不变。

**Decision：KEEP A，KILL B 本轮集成**。理由是当前少量结构塔上的可见效果、跟随方式和成本；不是证明纹理方案普遍不可行。Manga Freeze 未另加到默认玩法：已有玩家 hit stop，连锁阶段观察到重复停顿会打断结构运动，因此保留连续坍塌。

## D03 · Support Graph — KEEP 于 Structural Tower

**Hypothesis**：作者定义连接关系与地基连接，比运行时猜几何相邻更容易调试，也足够表现关键结构失效。

**Reference**：Blast 的数据分层；Smashing 的 ground connectivity。

**Prototype**：4 个 Chunk、3 个 Bond、一个 foundation support。先从所有支撑 BFS，再提取未访问连通分量。切割在邻近结构接缝削弱 Bond；已成为废墟的 Chunk 不再削弱原塔的支撑。

**Result**：A-B-C-D 中切 B-C 后，A+B 保持支撑，C+D 合为同一 detached component。实际绷紧触手的 Sweep 能切断样本塔支撑并触发宏块，非直接调用 `break_segment()` 的展示替身。

**Performance**：每塔仅 4 个节点 / 3 条边；只在关键 Bond 失效后遍历。普通背景塔不建立图。

**Gameplay Observation**：最初接缝判定半宽 2.8 m，在 2 m 墙板采样的 y=9、y=-3 等位置出现窄死区。改为 3.1 m，真实 Sweep 能触发邻近弱面，未增加全城结构查询。

**Decision：KEEP**。保留明确作者弱面；不是结构工程应力模拟。

## D04 · MacroChunk Race — 分阶段运动代理 MERGE

**Hypothesis**：抖动—倾斜—下落的确定时序，能使较少物理单元产生可读的大结构运动。

**Reference**：Smashing 的 Shock timing；Godot 官方刚体和运动体 API。

**Prototype A / Tween**：单运动代理直接 tween 位置。一秒目标路径穿过地基，不会自动提供本项目所需的受击事件。需要额外扫描才可成立。

**Prototype B / Single RigidBody**：三个带 CCD 的大型单刚体，以略不同起始倾角下落。480 个物理帧，即主工程 120 Hz 下 4 秒后，速度约 1.82–2.59 m/s、均未睡眠、各记录两个接触。它能正确接触地面；本试验没有证明其永远不能稳定，也没有穷尽阻尼调参。

**Prototype C / Staged swept proxy**：0–0.22 s 小幅抖动，0.22–0.72 s 逐渐倾斜，随后受控重力下坠；每个连通分量只有一个 CharacterBody3D、四个简化壳体形状。它是分阶段动画加运动学扫描的混合方案，不是 Tween 转 RigidBody。

**Result**：中段切断生成一个包含上层墙板及内梁的运动单元。落稳后停止物理过程，恢复墙板为静态碰撞；视觉残骸与黑痕保留。

**Performance**：默认 6 个；4 / 6 / 8 预算分别做突发激活测试，结果见 `budget_stress.json`。每个宏块四个粗形状，墙板只以禁用碰撞的视觉子项跟随，不变成大量 RigidBody。当前静态废墟仍保留墙板静态碰撞，未做合批。

**Gameplay Observation**：初版只倾斜 17° 后平移，重量运动不够明显；加入下落初期持续转动，接触后停转。残骸可在两塔间形成倾斜障碍与新的抓取面。是否“有重量、好看、爽”仍需真人判断。

**Decision：MERGE C；KILL 直接 Tween 路径；REVISIT 单刚体**。低速稳定超过 0.55 s 转静态；9 s 运动时限及预算溢出也会冻结，因此任意悬空压力夹具可能在空中冻结，交付三个有地基的实验样本已验证落稳。

## D05 · Secondary Damage / RAM vs SLASH — KEEP

**Hypothesis**：宏块真正接触第二个可破坏对象后，再走同一 DamageEvent 管线，就能形成有限且可追踪的后果。

**Reference**：toadile-gd 的接触驱动完整性失效；Blast 分离 damage 与 split 的职责。

**Prototype**：`move_and_collide` 返回接触点、法线和碰撞对象；宏块生成 COLLAPSE，能量来自接触前速度。父事件深度 +1；每块 / 每栋限 3 次，间隔 0.3 s；深度 2 之后不再发起下一轮。玩家自己的 RAM/SLASH 为深度 0。

**Result**：中段切断演示中真实宏块撞伤后塔，留下局部缺口与黑痕；链深度为 1。另有脚本断言深度 2 接受、深度 3 不改变几何。没有声称该演示自然产生了三塔连锁。

**Performance**：二次碰撞、深度、48 碎片与 6 大块独立计数。SLASH 只发出 2 个低散射碎片，RAM 保留更多向前碎片；小碎屑继续 GPU 化。

**Gameplay Observation**：无 HUD 的相同视角截图可见 RAM 是洞与放射黑痕，SLASH 是长切口与错位残唇。倒塌会改变可抓面及通行空间；玩家是否主动利用它还需真人试玩验证。

**Decision：KEEP**。宏块采用粗代理，旋转阶段不做精确旋转体扫掠；不扩展为任意建筑形状的通用刚体解算器。

## D06 · Dual Pull — REVISIT

未进行双钩操作原型。DamageEvent 的 PULL 与局部张力裂纹入口已预留，但没有双锚蓄力按钮，也没有宣称“两塔拉到相撞”已经完成。先让真人判断本版洞口、切口与倒塌的辨识度，再决定是否进入 0.05。
