# 项目目标

从零建立一个 Godot 4.7.2 3D 游戏 Demo。

已有资产：

* 一个 Blender 塔林白模生成插件。
* 可以使用 Blender 插件生成固定塔林场景并导出 GLB。
* 当前没有现成游戏工程。
* 暂时不做传送门角色。
* 暂时不做无限地图。

本阶段只验证一个核心循环：

**抓住建筑 → 触手拉动 → 摆荡加速 → 松开飞行 → 撞击/扫击建筑 → 建筑碎裂 → 继续移动。**

玩家暂时使用简单球体或黑色肉核占位模型。

触手暂时使用线条、Curve/Mesh 或其他轻量视觉表现。

不要为了最终美术延误玩法验证。

---

# 一、技术栈锁定

使用：

* Godot 4.7.2 Stable
* GDScript
* CharacterBody3D 玩家
* RayCast3D / PhysicsDirectSpaceState3D 进行抓取检测
* 少量 RigidBody3D 进行真实碎块物理
* GPUParticles3D 表现小碎屑和冲击尘
* Blender → GLB 作为场景资产管线

建立 Git 仓库。

每完成一个可独立运行的阶段建立一次清晰的 checkpoint/commit。

不要升级到 Godot 4.8 开发版。

---

# 二、核心工程原则

整个 Demo 必须遵循：

**玩家是假物理，碎块才是真物理。**

玩家不能使用 RigidBody3D。

触手不能使用真实绳索动力学。

建筑不能进行实时布尔切割。

整个塔不能成为完整刚体结构。

无限世界和 Chunk Streaming 暂时不实现。

破坏必须优先使用：

**完整模型 → 预制破碎模型 → 少量 RigidBody3D。**

视觉上复杂，程序上简单。

所有系统尽量保持解耦，避免一个巨大 player.gd 管理全部功能。

---

# 三、禁止事项

除非明确收到后续指令，否则禁止实现：

* SoftBody3D 触手
* Rope Simulation
* PinJoint / Generic6DOFJoint 绳索链
* Verlet Rope Simulation
* Runtime Boolean
* Runtime Voronoi fracture
* 任意 Mesh 实时切割
* 全塔结构力学模拟
* 每个建筑产生几十上百个 RigidBody
* Voxel destruction engine
* 无限地图
* Chunk streaming
* Floating origin
* NPC
* 敌人 AI
* 剧情
* 技能树
* 背包
* 联机
* Procedural runtime tower generation
* Portal 系统
* 高级血肉 Shader
* 高复杂度后处理

发现实现某功能需要引入以上系统时，优先寻找更简单的假实现。

---

# 四、工程目录建议

建立类似结构：

```text
project/
├─ assets/
│  ├─ blender_maps/
│  ├─ destructibles/
│  └─ placeholders/
│
├─ scenes/
│  ├─ player/
│  ├─ destruction/
│  ├─ vfx/
│  ├─ maps/
│  └─ debug/
│
├─ scripts/
│  ├─ player/
│  ├─ destruction/
│  ├─ camera/
│  └─ debug/
│
└─ addons/
```

核心脚本尽量拆成：

```text
player_controller.gd
grapple_controller.gd
tentacle_visual.gd
camera_controller.gd

destructible_segment.gd
destruction_manager.gd
debris_piece.gd

impact_vfx.gd
camera_shake.gd
```

---

# 五、阶段 0：建立最小测试场

不要先导入塔林。

建立极简灰盒：

```text
      █

█     ●     █

      █
```

4～8 个高大 StaticBody3D 方柱。

中央一个 CharacterBody3D 玩家。

实现：

* 鼠标控制相机
* WASD 空中微调
* 重力
* 基础空气阻力
* 最大速度限制
* 基础碰撞
* Reset 键
* 掉出地图自动重置

必须加入 Debug HUD：

```text
FPS
Velocity
Speed
Left Hook State
Right Hook State
Active RigidBodies
```

验收标准：

玩家可以稳定自由下坠、移动、碰墙。

没有触手。

没有破坏。

---

# 六、阶段 1：单触手

首先只实现一根触手。

鼠标点击时从摄像机/准星发射 RayCast。

命中可抓取 StaticBody 后记录：

```text
grapple_point : Vector3
```

不要建立物理绳子。

根据：

```text
player_position
grapple_point
rope_rest_length
```

计算人工拉力。

推荐采用 Spring + Damping 思路：

```text
distance > rest_length
    ↓
产生指向 grapple_point 的 spring_force
    ↓
根据沿绳方向速度加入 damping
    ↓
直接修改 CharacterBody3D.velocity
```

允许参数：

```text
rest_length
spring_strength
damping
max_pull_force
max_speed
air_control
gravity
```

触手视觉只要求：

玩家连接抓点的一条线。

可以增加非常轻微的视觉弯曲或 wiggle，但视觉触手不得参与物理。

验收标准：

玩家能够：

```text
下坠
→ 抓住高处
→ 绳长绷紧
→ 形成圆弧摆荡
→ 松开
→ 保留速度飞出去
```

如果手感不舒服，优先调整参数，不增加复杂物理。

---

# 七、阶段 2：双触手

在单触手稳定后扩展：

```text
Left Hook
Right Hook
```

左右鼠标分别控制。

两根触手独立保存：

```text
grapple_point
rest_length
active
```

最终玩家受力：

```text
gravity
+ left_hook_force
+ right_hook_force
+ air_control
```

然后限制最大速度。

必须避免：

* 两根触手导致 NaN
* 玩家卡入建筑后高速弹飞
* 极短绳长产生无限大拉力
* 高频抓取造成抖动

增加：

```text
minimum_rope_length
maximum_rope_length
maximum_hook_force
```

验收测试：

1. 单钩摆荡。
2. 左右交替抓塔。
3. 两根同时抓不同建筑。
4. 自由落体最后一刻抓住建筑。
5. 高速松钩后保持惯性。

做到这里暂停增加系统。

先确认移动本身已经有趣。

---

# 八、阶段 3：破坏测试块

仍然不要导入整个塔林的破坏系统。

制作一个：

```text
DestructibleTestBlock
```

结构：

```text
DestructibleSegment
├─ IntactVisual
├─ IntactCollision
└─ BrokenScene
```

默认使用完整版本。

满足破坏条件时：

```text
关闭 intact collision
隐藏 intact mesh
实例化 broken scene
```

BrokenScene 只允许：

**3～6 个大碎块。**

每块：

```text
RigidBody3D
MeshInstance3D
简单 CollisionShape3D
```

给碎块初始线速度和角速度。

3～6 秒后：

淡出、隐藏或销毁。

绝对不要把一个方块碎成几十块。

验收标准：

玩家高速撞击测试块：

```text
完整
↓
瞬间碎裂
↓
3～6块大碎块飞出
```

低速轻碰不能轻易破坏。

---

# 九、阶段 4：移动速度成为破坏资源

计算玩家相对于建筑的：

```text
impact_velocity
```

建立几个非常简单的阈值：

```text
低速
不破坏

中速
破坏

高速
破坏 + 更强冲击反馈
```

第一版不要模拟材质。

统一用：

```text
destruction_threshold
```

建立统一接口：

```text
DestructibleSegment.break_segment(
    hit_position,
    hit_direction,
    strength
)
```

以后无论触手、撞击、其他角色，都只能调用这个接口。

不要把破坏逻辑写进 Player。

---

# 十、阶段 5：触手扫击破坏

这是这个 Demo 最关键的新机制。

目的：

玩家高速飞行时，如果触手处于绷紧状态，触手扫过建筑，也能切断可破坏段。

不要进行真正几何切割。

每个物理帧保存：

```text
上一帧触手线段
当前帧触手线段
```

使用：

* ShapeCast
* 多点采样
* Segment/Sweep collision
* 或其他稳定的近似检测

找到触手轨迹经过的 DestructibleSegment。

触发破坏前检查：

```text
玩家速度
触手是否绷紧
触手扫动速度
Cooldown
```

例如：

```text
if hook_tension > threshold
and player_speed > cut_speed_threshold
and target cooldown == false:
    target.break_segment(...)
```

这只是：

**Sweep Detection → Break Event**

不是：

**Sweep Detection → Runtime Mesh Slicing**

目标效果：

```text
Tower A       Tower B

█████\       /█████
██████\  ●  /██████
██████ \   / ██████

玩家高速移动
触手横扫中间建筑
建筑段断裂
```

这一步完成后，核心玩法基本成立。

---

# 十一、阶段 6：加入最小爽感反馈

只有核心玩法成立以后才加 VFX。

一次明显破坏包括：

1. 3～6 个真实大碎块。
2. GPU 小碎屑。
3. GPU 灰尘。
4. Camera Shake。
5. 很短的 Hit Stop。
6. 简单冲击音效占位。
7. 短促速度线或屏幕冲击效果。

Hit Stop 必须极短。

不要为了 Hit Stop 破坏物理稳定性。

所有参数必须集中可调。

建议建立：

```text
ImpactProfile
```

例如：

```text
small
medium
heavy
```

而不是把震屏、粒子数量和停顿时间散落在代码里。

黑白漫画表现暂时只做最低限度。

例如：

```text
白闪
+
黑色碎片
+
速度线
+
短震屏
```

不制作最终 Shader。

---

# 十二、阶段 7：导入 Blender 塔林白模

此时才开始接入现有 Blender 资产。

第一版地图采用：

**Blender 整图烘焙。**

不做运行时程序生成。

流程：

```text
Blender 塔林插件
↓
生成固定地图
↓
导出 GLB
↓
Godot
```

先把整片塔林视作：

**Static Environment。**

主要功能：

* 提供视觉建筑
* 提供碰撞
* 提供 Grapple Surface

不要要求整个地图可破坏。

选择少量明显区域替换成：

```text
Destructible Tower Segment
```

例如第一版只有：

```text
5～15个可破坏塔段
```

也完全可以。

原则：

**环境可以很大，可破坏对象必须少。**

如果现有 Blender 插件生成的是完整合并 Mesh，不要立即重写整个插件。

优先：

1. 用现有白模做背景。
2. 在几个关键位置放置独立可破坏测试塔段。
3. 证明玩法。
4. 后续再修改 Blender 插件输出结构。

---

# 十三、第一版地图规模

不要做无限地图。

使用一张有限固定地图。

推荐表现方式：

```text
玩家活动区域
+
大量白模高塔
+
远景雾
+
黑暗/漫画天空
```

地图边界可以隐藏在：

* 虚空
* 雾
* 高低落差
* 远景塔林

玩家跌落过深直接 Reset。

第一版游戏循环可以只有：

```text
Spawn
↓
摆荡
↓
撞碎建筑
↓
继续摆荡
↓
计分
↓
跌落 / 重置
```

不需要胜利条件。

---

# 十四、性能护栏

Demo 第一版主动限制：

每次建筑破坏：

```text
3～6 RigidBody
```

建议场景同时活跃真实碎片：

```text
< 60
```

碎片生命周期：

```text
约 3～6 秒
```

超过预算时优先回收最旧碎片。

粒子承担绝大部分“小碎片”表现。

不要把远处建筑变成 RigidBody。

不要给每座塔开启持续物理模拟。

Player 使用 CharacterBody3D。

静态建筑使用 StaticBody3D。

只有已经被击碎的大碎块短暂使用 RigidBody3D。

---

# 十五、Debug 工具必须保留

开发阶段增加可开关 Debug Draw。

显示：

```text
抓钩射线
抓点
触手当前长度
Rest Length
触手 tension
Player velocity vector
触手 sweep 区域
破坏碰撞位置
```

HUD 显示：

```text
FPS
Speed
Hook L/R
Tension L/R
RigidBody count
Destruction event count
```

如果出现物理 Bug，要优先通过这些信息查原因，不允许无目的增加补丁。

---

# 十六、最终 Prototype 0.01 验收标准

完成版本必须能够连续完成以下行为：

```text
玩家从塔上跳下
↓
左触手抓住建筑
↓
形成摆荡
↓
松开
↓
高速飞向下一座塔
↓
右触手抓住另一座塔
↓
再次改变方向
↓
高速撞击可破坏塔段
↓
塔段碎裂
↓
碎片飞散
↓
继续移动
```

额外验收：

* 玩家移动稳定。
* 双触手不会轻易炸飞。
* 无需真正绳索模拟。
* 无需实时 Mesh 切割。
* 一次破坏不会制造大量刚体。
* 固定 Blender 塔林地图能够正常运行。
* 至少一个区域能体验“触手扫过建筑并使建筑断裂”。
* Debug HUD 能帮助调参。
* 核心参数可以从 Inspector 调整。
* 连续游玩数分钟不会发生明显物理失控或碎片无限积累。

完成以上内容后：

**停止增加功能。**

先形成可玩 build。

---

# 十七、开发优先级

严格按照：

```text
Movement
↓
Single Grapple
↓
Dual Grapple
↓
Destructible Block
↓
Speed Based Destruction
↓
Tentacle Sweep
↓
Game Feel / VFX
↓
Blender Tower Map
```

如果后面的功能影响前面的稳定性，优先回退。

整个 Prototype 0.01 的最高判断标准只有一个：

> “在塔之间荡过去并把东西撞碎/切断，本身是否足够有趣？”

不是画面质量。

不是地图规模。

不是技术复杂度。

---

# 附录 A：参考项目及偷师策略

## A1. OverlordDestro/DestroHook

用途：

**Grappling Hook / Swing Movement。**

它是 Godot 4 的 spring-based grappling hook 实现。

重点研究：

* Spring force。
* Damping。
* Rest length。
* CharacterBody 与 Grapple 配合方式。
* 收绳/放绳。
* Hook Visual 与 Hook Physics 分离。

推荐：

**研究其数学和控制器结构，然后写自己的极简版本。**

不要因为它是插件就让整个项目绑定插件内部架构。

它最值得借鉴的核心是：

```text
CharacterBody.velocity
+
Spring/Damping
```

而不是物理绳子。

由于该项目最初针对较早的 Godot 4.x 版本，正式复制代码前检查当前 4.7.2 API 兼容性和仓库许可证。

---

## A2. kernelshreyak/blade-cutter

用途：

**研究高速切割动作如何判定。**

这是一个真正进行 runtime mesh slicing 的项目。

不要复制它的实时 Mesh slicing pipeline。

重点偷：

```text
previous position
current position
velocity
cut direction
valid cut threshold
cooldown
```

把刀刃逻辑改造成：

```text
Tentacle Sweep Detector
```

我们只需要知道：

> “触手刚才有没有以足够高的速度扫过这个建筑？”

之后直接调用：

```text
break_segment()
```

不进行三角面重建。

---

## A3. robertvaradan/VoronoiShatter

用途：

**预制碎裂资产实验。**

它支持在 Godot 编辑阶段生成 Voronoi fracture，并可以创建刚体碎片。

作者本身也建议：

> 游戏实际使用时优先 pre-shatter，而不是 Just-In-Time fracture。

因此如果后续 Blender 手工制作 broken variants 太麻烦，可以尝试：

```text
Blender完整塔段
↓
Godot Editor
↓
VoronoiShatter
↓
提前生成碎片
↓
保存为 PackedScene
```

运行时：

```text
Intact
↓
Broken PackedScene
```

注意：

这是实验性插件。

不要批量对整个塔林运行。

只用于少数、低复杂度、封闭 manifold 的可破坏塔段。

---

## A4. the-dunk/Godot-Destruction

用途：

**破坏系统总体设计参考。**

该项目明确指出：

如果不需要完全动态破坏，pre-computed destruction 更高效，也更容易控制碎片和触发条件。

这与本项目架构一致。

重点学习：

```text
damage event
↓
destruction strength
↓
precomputed fragments
↓
debris
```

不要第一阶段引入它完整的 Runtime Destruction。

---

## A5. anasrar/godot-object-pooling

用途：

**后期减少碎片和 VFX 的频繁 instantiate/free。**

Prototype 初期可以正常 instantiate + queue_free。

只有 profiling 出现明显卡顿后再引入 Pool。

未来可以建立：

```text
DebrisPool
ParticlePool
ImpactVFXPool
```

不要因为“未来可能需要”而提前复杂化。

---

## A6. Zylann/godot_voxel

用途：

**仅作为未来假无限地图 / Chunk Streaming 的架构参考。**

不要安装。

不要用于当前 Demo。

未来如果进入塔林 streaming 阶段，只研究：

```text
world position
↓
chunk coordinate
↓
load nearby
↓
unload distant
```

它的 voxel destruction、terrain meshing 等功能都不属于当前项目范围。

---

# 附录 B：算法组合

本 Demo 不需要发明新的复杂算法。

建议最终形成：

```text
CharacterBody3D
+
Spring Grapple
+
RayCast
+
Tentacle Sweep Detection
+
Destructible State Machine
+
Precomputed Fragments
+
Short-lived RigidBodies
+
GPU debris
```

即：

### 移动

参考 DestroHook：

```text
Spring + Damping → velocity
```

### 抓取

Godot：

```text
RayCast3D → grapple point
```

### 触手切割判定

参考 Blade Cutter：

```text
previous/current sweep
+
velocity threshold
+
tension threshold
+
cooldown
```

### 建筑破坏

参考 VoronoiShatter / Godot-Destruction：

```text
Intact
→
Broken prefab
```

### 物理

```text
Player = CharacterBody3D

Environment = StaticBody3D

Debris = temporary RigidBody3D
```

### 特效

```text
few real fragments
+
many GPU fake fragments
+
camera shake
+
hit stop
```

这就是 Prototype 0.01 的完整技术骨架。

不要扩大。
