# 《RAVAGE》0.03 MOMENTUM / IMPACT
## Autonomous R&D 研发委托书

---

# 0. 委托性质

本阶段恢复：

**AUTONOMOUS R&D MODE / 自主研发探索模式**

不要把本文件理解成必须逐条照抄实现的工程任务清单。

你承担：

- Lead Gameplay Programmer
- Technical Designer
- Prototype Engineer
- Systems Designer
- Gameplay Researcher
- QA / Playtest Agent

用户负责：

- 真人试玩；
- 判断是否有趣；
- 判断移动是否爽；
- 判断破坏是否有重量；
- 提供主观体验反馈；
- 决定大方向是否继续。

你负责：

**调查 → 假设 → 原型 → 运行 → 测试 → 比较 → 淘汰 → 整合 → 再试玩。**

对于可逆技术和设计决策，不要等待用户逐项确认。

如果两个方案无法通过推理决定：

**做两个小实验，实际跑，然后选更好玩的。**

---

# 1. 当前项目状态

0.02 已经证明本项目在工程上可以成立。

目前已经存在：

- CharacterBody3D 高速移动；
- 双触手 Grapple；
- Spring 型拉力；
- 松钩惯性；
- 触手 Sweep；
- 高速撞击破坏；
- 大规模 Blender 固定塔林；
- 建筑分段破坏；
- 碎片预算；
- Hit Stop；
- Camera Shake；
- GPU 碎屑；
- 墨迹系统；
- 自动测试与压力测试；
- Windows 可运行 Build。

因此本阶段不再回答：

> “Godot 能不能做这个游戏？”

这个问题已经基本得到肯定答案。

本阶段回答：

> **“抓、荡、飞、撞、切到底能不能产生足够好的手感？”**

---

# 2. 当前真实问题

用户实际试玩 0.02 后，核心问题集中为：

## A. 抓取不可靠

- 经常无法准确发射到建筑；
- 准星必须过于精确；
- 高速状态下更难锁定目标；
- Miss 后反馈不明确；
- 成功抓取的反馈也不突出。

结果：

**玩家不是在选择下一处抓点，而是在和 RayCast 判定搏斗。**

---

## B. 触手缺乏力量

当前抓住建筑以后：

- 拉力建立慢；
- 很难迅速获得高速；
- 缺少瞬间被拽出去的感觉；
- Spring 物理感存在，但怪物主动发力感不足。

结果：

**数学上能够高速，体验上却显得迟钝。**

---

## C. 单触手运动语言过少

目前主要是：

```text
抓住
↓
被拉
↓
松开
```

长期不足以支撑整个高速移动游戏。

未来可以研究：

- 摆荡；
- 瞬间抓取突进；
- 收缩；
- 弹簧式发射；
- 双钩弹射；
- 建筑吸附；
- 蹬墙；
- 跳跃；
- 紧急坠落救援；
- 更后期的裂变分身移动。

但本阶段不要一次全部正式实现。

---

## D. 坠落惩罚严重破坏节奏

当前某些位置稍微不理想就可能迅速触发重置。

这严重破坏：

**高速 → 失误 → 紧急救援 → 再次恢复速度**

这个本应非常有趣的循环。

游戏应该允许玩家救回来。

而不是太早替玩家宣布失败。

---

## E. 建筑破坏存在，但玩家感觉不到

典型情况：

```text
高速飞行
↓
穿过建筑
↓
继续向前
↓
回头才发现建筑碎了
```

这意味着：

**Destruction Event 已经发生，但 Impact Event 几乎没有被玩家感知。**

主要缺少：

- 动量变化；
- 瞬间顿挫；
- 镜头反冲；
- 破坏方向；
- 声音层次；
- 建筑重量；
- 明确伤口；
- 二次建筑反应。

---

# 3. 本阶段唯一最高目标

0.03 不以增加功能数量为目标。

版本主题：

# MOMENTUM / IMPACT

必须优先让玩家感受到：

### 抓得住

我明显瞄向一座建筑时，触手应该聪明地抓住它。

### 拉得猛

触手命中以后，角色应该立刻产生明显运动变化。

### 荡得快

高速应该容易获得。

难点应该是：

**如何控制高速。**

而不是：

**如何辛苦爬到高速。**

### 撞得响

高速撞穿建筑时必须立即知道：

> “刚才我撞碎了一栋东西。”

### 撞完还能继续动

破坏不能把流动性彻底切断。

理想循环：

```text
抓
↓
加速
↓
摆荡
↓
释放
↓
高速飞行
↓
撞穿 / 切断
↓
产生明显顿挫
↓
仍保留大部分速度
↓
再次抓取
```

移动与破坏必须形成连续句子。

---

# 4. 第一研究主题：重新设计 Grapple Targeting

不要继续把单根精确 RayCast 当成唯一抓取方式。

研究并比较：

## Candidate A
中心 RayCast。

保留作为基准。

## Candidate B
中心 RayCast + 屏幕空间辅助吸附。

中心射线 Miss 时，在准星附近搜索候选建筑表面。

## Candidate C
Cone / Sphere / Shape Assisted Targeting。

玩家实际瞄准的是一个很窄的锥形目标区域。

系统从区域中选择最合理目标。

---

选择目标时可以综合：

```text
screen_center_distance
world_distance
visibility
surface_angle
travel_direction
current_velocity_direction
```

优先避免：

- 抓到玩家身后；
- 抓到被建筑遮挡的表面；
- 抓到极端近距离小碎片；
- 高速状态下因准星偏几像素直接 Miss。

---

# 5. Target Assist 的设计原则

Aim Assist 必须服务高速移动。

不是自动玩游戏。

玩家：

```text
明显瞄向建筑
```

系统应该理解：

```text
“他大概率想抓这座建筑。”
```

允许触手末端出现轻微自动修正。

建议额外提供：

- 当前候选抓点轻微标记；
- 可抓状态准星变化；
- 不可抓状态明确区别；
- 抓点距离反馈；
- Debug 模式显示系统为何选择该目标。

高空坠落进入危险状态时，允许提高一定抓取宽容度。

研究：

### Panic Grapple / Emergency Assist

用于：

```text
高速坠落
↓
玩家尝试抓取
↓
系统扩大有限的搜索锥
↓
找到合理建筑
↓
成功救援
```

目的不是降低难度。

目的是保护移动节奏。

---

# 6. 第二研究主题：重新进行 Grapple Movement 赛马

0.02 当前实现不是法律。

不要在现有 Spring 参数上无限补丁。

至少比较以下方案。

---

## Experiment M01
### Pure Spring

当前方案作为 Control Group。

记录：

- 命中后多久产生明显加速；
- 进入 25 m/s 需要多久；
- 摆荡圆弧是否漂亮；
- 是否容易产生软绵感。

---

## Experiment M02
### Radial Constraint / Pendulum

抓住后限制：

```text
Player → Anchor
```

径向距离。

当角色试图继续远离 Anchor：

去除部分径向速度。

尽量保留切向速度。

观察：

- 摆荡是否更清晰；
- 是否更容易保持高速；
- 是否降低“橡皮筋感”。

---

## Experiment M03
### Hybrid Grapple

当前最值得优先测试。

分为：

### Kick

抓住瞬间直接给予一次速度脉冲。

负责：

**“啪一下被拽走。”**

### Motor

抓住并持续输入时，主动向 Anchor 施加拉力。

负责：

**“触手有肌肉。”**

### Constraint / Spring

负责：

- 绳长；
- 圆弧；
- 摆荡；
- 张力。

即：

```text
Kick
= 爆发

Motor
= 持续加速

Spring / Constraint
= 轨迹塑形
```

不要让 Spring 一个人负责全部体验。

---

# 7. 给移动建立体验指标

不要只比较最大速度。

重点测量：

### T1
按下抓取到明显产生加速需要多久。

目标体验：

**接近瞬时。**

### T2
一次普通合理抓取进入明显高速需要多久。

### T3
一次漂亮摆荡释放以后能保留多少速度。

### T4
连续抓取是否可以自然维持速度。

### T5
低水平玩家是否能够较容易进入高速状态。

原则：

> **高速容易获得，精准控制高速才是技术。**

---

# 8. 抓取必须有完整反馈链

一次 Grapple 应拆成：

## Fire

触手高速射出。

需要：

- 短音效；
- 肉核轻微变形；
- 发射线快速延伸；
- 极轻的 Camera impulse。

## Attach

命中建筑瞬间：

- Anchor 墨爆；
- 明确命中音；
- 触手视觉从松弛变绷紧；
- Camera 向 Anchor 微小 Kick；
- 玩家身体得到初始拉力。

## Tension

拉力增加时：

- 触手视觉越来越直；
- 粗细或抖动产生变化；
- 音效提高张力感；
- Debug 可显示 tension。

## Release

松钩必须：

- 明确释放音；
- 保留速度；
- 可以考虑极小 Release Boost；
- 不要突然削速度。

---

# 9. 第三研究主题：单触手移动 Vocabulary

不要立即增加大量独立技能键。

优先研究：

### Tap
ZIP / Snap Pull

快速点按：

```text
抓住
↓
猛烈拉近一段距离
```

服务短距离机动。

### Hold
SWING

持续按住：

进入摆荡。

### Retract
主动收绳。

### Charge / Modifier
SLINGSHOT

允许玩家通过：

```text
抓取
+
收缩 / 蓄力
+
释放
```

产生明显弹射。

首先验证：

**同一根触手能否拥有抓、荡、弹三种移动语义。**

如果已经足够有趣，再扩展动作。

---

# 10. 建筑接触移动实验

建立一个独立小实验测试：

### Adhesion

角色接近墙体时允许短暂吸附。

不是制作复杂爬墙系统。

只需要允许：

```text
高速靠近塔面
↓
贴附
↓
短暂停留
```

### Wall Launch

贴附状态按 Jump：

根据：

```text
surface_normal
+
camera_direction
```

产生一次爆发跳跃。

目的是丰富节奏：

```text
荡
↓
吸附
↓
蹬墙
↓
抓
↓
弹
↓
飞
```

如果 Adhesion 明显让节奏变拖沓：

砍掉。

---

# 11. 坠落与 Reset 必须重新设计

Reset 不应该成为普通移动流程的一部分。

检查当前所有：

- Kill Zone；
- Fall Limit；
- Spawn Reset；
- Geometry Fail Safe。

显著扩大玩家恢复空间。

设计：

### Fall Grace State

进入危险高度后：

不要立即 Reset。

允许继续：

- Grapple；
- Emergency Grapple；
- Wall Attach；
- 空中控制。

只有真正离开所有可救援范围后才 Reset。

Reset 自身也应尽可能快。

不要制造长黑屏或长加载。

---

# 12. 第四研究主题：重新设计 Impact

目前不要增加新破坏类型。

先让现有 Body Impact 真正有感觉。

将一次撞击拆成：

```text
Approach
↓
Contact
↓
Impact
↓
Penetration / Break
↓
Exit
↓
Recovery
```

而不是：

```text
speed > threshold
↓
break_segment()
```

---

# 13. 撞击必须发生动量交换

撞穿普通建筑后：

玩家应该损失部分速度。

但不能彻底停住。

研究多个区间，例如：

```text
Light Structure
保留约 85~95%

Medium
约 75~90%

Heavy
约 60~80%
```

数值只是实验初值。

实际以试玩结果为准。

---

更推荐根据碰撞法线分解 velocity：

### Tangential Component

尽量保留。

### Normal Component

明显削弱。

因此斜着撞击：

```text
↗ → 建筑
```

不会僵硬地停住。

而会：

```text
撞碎
↓
轨迹发生轻微偏折
↓
继续高速飞行
```

---

# 14. 建立统一 Impact Feedback Stack

Heavy Impact 不应依赖单一 Hit Stop。

同时触发少量：

- Hit Stop；
- Velocity loss；
- Camera kick；
- Camera shake；
- 短 FOV pulse；
- 玩家视觉 squash；
- 方向性大碎片；
- 方向性 GPU debris；
- 墨爆；
- 低频主体撞击音；
- 高频建筑裂解音。

每个单项都不要过强。

目标是多个弱反馈叠加成：

**非常明确的“砰”。**

---

# 15. 所有破坏反馈必须表现方向

建筑碎片不能只是随机爆炸。

至少考虑：

```text
player_velocity
impact_normal
contact_position
```

让：

- 碎片大致沿冲击方向飞散；
- 墨迹沿运动方向拖开；
- 建筑出口方向破坏感更重；
- Camera kick 与撞击方向一致。

玩家必须能够仅凭瞬间画面知道：

**刚才是我从这个方向把东西撞穿的。**

---

# 16. Body Impact 与 Tentacle Sweep 必须形成差异

当前两个阈值和结果过于接近。

逐渐建立：

### Body

**Blunt / Ram**

特点：

- 更高速度需求；
- 强重量感；
- 大块破坏；
- 明显自身减速；
- 建筑飞散。

### Tensioned Tentacle

**Slash / Sever**

特点：

- 依赖 Tension；
- 速度门槛可以稍低；
- 玩家自身减速较少；
- 产生明显切断方向；
- 更适合精准破坏。

目标：

玩家应该主动学习：

> “撞击适合砸。”

> “绷紧触手适合切。”

---

# 17. 第五研究主题：最低成本的建筑重量反馈

0.02 目前容易出现：

```text
中间一段消失
上下建筑继续悬浮
```

这对技术稳定有利。

但视觉重量不足。

研究一个极简：

# Fake Structural Reaction

例如某个 Segment 被切断后：

允许附近极少量相关结构进入：

```text
tilt
↓
delay
↓
fall
↓
cleanup
```

优先选择：

- Tween Visual；
- 简单下降代理；
- 一个大型粗略 RigidBody；
- 少量二次碎片。

不要建立真实建筑力学。

目的只是制造：

> “切掉关键部位以后，这座塔真的有重量。”

---

# 18. 重新执行“破坏改变路线”实验

这是旧研发方向中未充分验证的重要内容。

设计一个小型专用测试区。

例如：

```text
玩家
↓
一堵阻挡摆荡路线的建筑
```

必须通过：

```text
撞穿
或
触手切断
```

形成：

```text
洞口 / 缺口
```

然后：

```text
穿过
↓
看到原本不可见的新 Anchor
↓
重新抓取
↓
进入另一条移动路线
```

至少制作：

### Route Test A
撞穿墙形成捷径。

### Route Test B
切掉结构制造新的摆荡角度。

### Route Test C
破坏暴露建筑内部空间。

如果破坏仍然只是：

> “分数和视觉奖励”

则继续调整。

---

# 19. 专门建立三分钟 Gameplay Test Course

从当前 Blender 塔林或灰盒中圈出一条测试路线。

不追求自然关卡。

它是 Gameplay Laboratory。

建议顺序：

```text
Spawn
↓
简单抓点
↓
第一次高速拉动
↓
大摆荡
↓
松钩飞跃
↓
Body Impact
↓
窄塔间 Sequential Grapple
↓
Tentacle Sweep
↓
高速坠落
↓
Emergency Recovery
↓
墙面吸附 / 蹬墙实验区
↓
大型终点破坏
```

作用：

让不同移动算法可以在完全相同环境下比较。

---

# 20. 自动记录 Gameplay Telemetry

记录：

```text
First Grapple Time

Grapple Miss Rate

Successful Grapple Count

Average Grapple Distance

Time To 20m/s

Time To 30m/s

Average Speed

Peak Speed

Time Above 30m/s

Release Speed

Fall Recovery Count

Reset Count

Body Impact Count

Tentacle Sweep Count

Average Impact Speed

Speed Loss After Impact
```

数据不是为了替代真人手感。

它用于帮助定位：

> “为什么这一版感觉更慢？”

---

# 21. AI Playtest 记录

每个核心 Experiment 至少记录：

```text
最爽的一刻

最迟钝的一刻

最常 Miss 的情况

最容易卡死的情况

最容易突然 Reset 的情况

最容易失速的位置

是否容易进入高速

高速状态是否容易维持

撞击是否明显

撞击是否过度减速

破坏是否改变路线
```

不要只记录：

```text
No Error
PASS
```

技术通过不等于 Gameplay 通过。

---

# 22. 实验赛马制度

建议至少建立：

```text
M01_PureSpring
M02_RadialConstraint
M03_HybridKickMotorSpring
```

如果必要，可以使用：

- Git Worktree；
- 独立实验场景；
- 参数 Profile；
- Subagent。

最终形成：

```text
KEEP
KILL
MERGE
REVISIT
```

不要因为 0.02 已经实现 Pure Spring 就偏袒它。

---

# 23. 本阶段允许自主重构

允许：

- 更换 Grapple 算法；
- 删除现有 Spring 部分代码；
- 重写 Target Selection；
- 重写 Fall Reset；
- 修改 CharacterBody Movement；
- 修改 Camera；
- 修改 Impact 判定；
- 修改撞击速度处理；
- 修改 Sweep 条件；
- 添加实验控制台；
- 添加参数 Profile；
- 建立 Gameplay Test Map；
- 删除贡献很小的旧效果。

但不要为了代码优雅进行与体验无关的大规模重构。

---

# 24. 暂时不正式开发的未来动作

以下属于未来 Gameplay Vocabulary。

允许建立纸面设计、接口预留或极小原型。

但本阶段禁止把它们全部做成正式功能：

### Movement

- 裂变分身移动；
- 高阶多锚移动；
- 长距离特殊冲刺。

### Destruction

- 双钩拉扯塔体；
- 触手单点穿刺；
- 螺旋旋转触手；
- 巨型范围切割；
- 高阶连锁坍塌。

这些只有在：

**基础 Grapple + Momentum + Impact 已经明显好玩**

以后才进入正式制作。

---

# 25. 但允许进行一个未来破坏动作的快速实验

如果基础手感已经完成，并且还有研发余量：

优先实验：

# Dual Hook Pull / 双钩拉扯

原因：

现有系统已经有双 Grapple 和 Tension。

基础结构可能只需要：

```text
Anchor A
↓
Player
↓
Anchor B

Tension > threshold
↓
Break selected Segment
```

它能够验证：

> “触手不仅是移动工具，也能主动拆楼。”

但只能作为额外 Experiment。

不能抢占本阶段基础手感任务。

---

# 26. Blender 与地图策略

继续维持：

**Blender 整图烘焙。**

不要：

- Runtime Tower Generator；
- Infinite Procedural City；
- 把 Blender 生成器移入 Godot。

当前 358 建筑固定塔林已经足够进行玩法实验。

不要继续扩充地图规模。

优先从现有地图挑一个：

**高密度、高低差明显、抓点丰富的区域**

作为 Gameplay Course。

---

# 27. 视觉调整只服务 Gameplay Readability

0.03 允许处理：

### 镜头

- 玩家模型略微缩小；
- Camera 稍后移；
- 玩家稍低于视觉中心；
- 给前方路线更多空间。

### 空间层次

探索：

- 近景 AO；
- Cavity；
- 简单 Vertex Color；
- 雾层级；
- 轻微明度分层。

目标：

玩家高速移动时能够迅速判断：

```text
近
中
远
```

不要开始制作正式复杂材质。

---

# 28. 墨迹系统暂停扩张

现有 Ink 系统已经具备足够技术基础。

暂时不要增加：

- 流体；
- 液体模拟；
- 湿度；
- 高复杂度动态 Decal；
- 无限痕迹。

只允许改进：

**墨迹形状语言。**

例如：

```text
Anchor
= 小墨点

Wall Scrape
= 长拖痕

Tentacle Slash
= 细长切痕

Heavy Impact
= 大片方向性墨爆
```

让玩家的高速运动逐渐把白色塔林“写脏”。

---

# 29. 性能继续作为护栏，而不是主任务

维持：

- 玩家 CharacterBody3D；
- 环境 StaticBody3D；
- 短命 Debris RigidBody3D；
- GPU Small Debris；
- Debris Budget；
- Ink Budget。

增加一个新的压力测试：

```text
依次激活大量建筑分段
↓
每栋随机破坏 1~3 Segment
↓
保持破坏状态
↓
持续运行
```

目的：

测试大量建筑进入 segmented state 后的长期性能。

另建立：

```text
60Hz
90Hz
120Hz
```

Physics Tick A/B Test。

当前不要直接降低 120Hz。

如果 60/90Hz 在 Sweep 已存在的情况下手感和稳定性接近，可考虑降低以释放 CPU。

---

# 30. 强制停止条件

如果经过一轮移动算法赛马后：

### Grapple 仍然不好玩

禁止继续添加新技能。

继续修 Grapple。

如果：

### Body Impact 仍然没有感觉

禁止继续制作新破坏攻击。

继续修 Impact。

如果：

### 玩家仍经常因为普通失误被 Reset

继续修 Fall Recovery。

如果：

### 破坏仍然没有改变路线

继续修 Destruction → Movement Loop。

不要用更多功能掩盖基础问题。

---

# 31. 0.03 最低验收体验

最终 Build 至少做到：

### 抓得准

玩家明显瞄向建筑时绝大多数合理操作可以成功抓取。

Miss 必须能够理解为什么 Miss。

### 抓得有力

触手命中瞬间立即产生明确运动反馈。

### 很快进入高速

不需要长时间摆荡才能体验速度。

### 松手漂亮

释放以后速度自然延续。

### 坠落可救

一般操作失误不立即 Reset。

玩家拥有明显的自救窗口。

### 撞击明确

高速撞穿建筑时不用回头确认。

玩家在接触瞬间就知道自己破坏了建筑。

### 撞完还能动

破坏产生顿挫，但不会频繁把高速运动彻底终止。

### 触手切割和身体撞击已有不同感觉

即使仍使用相同 Destruction backend。

### 至少有一个破坏真正改变移动路线的测试场景。

---

# 32. 最终交付

交付：

## Playable Build

可以直接运行的 0.03。

## CHANGELOG_RND_003.md

只记录重要变化。

## EXPERIMENTS_003.md

重点记录：

```text
尝试了哪些移动算法

Pure Spring 是否保留

Target Assist 做了什么

哪些方案被砍掉

为什么

Impact 做过哪些实验

哪些反馈最有效
```

## PLAYTEST_003.md

记录：

- AI 实际测试结果；
- 自动 Telemetry；
- 当前最好玩的动作组合；
- 当前最大遗留问题。

## TECH_RADAR_003.md

把：

- 双钩拉扯；
- 单点穿刺；
- 螺旋切割；
- 裂变移动；
- Fake Structure；
- Support Graph；

记录为未来研究候选。

不要现在全部实现。

---

# 33. 本阶段的一句话

本阶段不是：

> “给 0.02 加更多技能和更多破坏方式。”

而是：

> **“把 0.02 已经存在的高速移动和建筑破坏，从‘技术上能够发生’，自主研发成‘玩家能够清晰感觉到，而且愿意反复做’。”**

现在最重要的不是功能数量。

而是建立 RAVAGE 的动作语法：

# 抓得住 → 拉得猛 → 飞得快 → 撞得响 → 还能继续飞。

先把这一句话做成立。

之后拉扯、穿刺、旋切、裂变移动才有值得生长的土壤。