# 传送门角色 0.1 · 游戏资产

默认 Portal 场景现已使用浅蓝短发、黑色高领披风和单侧黑手套的低模角色。运行根目录 `开始传送门原型.cmd`，进入原始垂直峡谷；场景的 132 个塔体继续支持局部破坏。

## 交付文件

- `角色资产/PortalAnomaly_01.blend`：可编辑模型、UV、骨骼、八个动作及内嵌贴图。
- `project/assets/characters/portal_anomaly/portal_anomaly.glb`：可直接导入的带绑定模型。
- 同目录 `pixel_atlas_128.png`：128×128、14 色像素图集；`model_report.json` 记录部件、规格和动作。
- `tools/build_portal_character.py`：可重复构建源。运行 Blender 后台脚本会覆盖上述生成资产，手工修改 `.blend` 前应另存版本。
- `docs/portal-character/00-character-views.png`：引擎实际渲染的正侧背面；06–09 图片为峡谷内运行截图。

## 轮廓与材质

2,520 个三角面，约 4 头身，高 1.969 米，21 根骨骼，单网格、单材质，每顶点最多两个骨骼影响。头脸和四肢收窄；下颌有轮廓转折，侧发沿头部弯折。原像素图集和冷色体系保留，UV 改为覆盖完整衣片，避免每个小面重复同一条褶皱。

披风由肩部覆盖层、背片和三片不对称长尾组成，使用薄片、4 mm 边缘和几何折痕；根部与脊柱混合权重，尾部使用三根独立骨骼。没有实时布料求解。材质为双面 Unlit、最近邻采样，明暗由图集承担；不依赖 PBR 贴图。

## 骨骼与动画

骨架：root / pelvis / spine / head；左右 upper_arm / forearm / hand、thigh / shin / foot；cape_L / cape_C / cape_R、hair_back、pendant。

| 动作 | 时长 | 游戏接入 |
|---|---:|---|
| Idle | 2 s | 地面待机 |
| Run | 0.8 s | WASD，随移动速度调节播放速度 |
| Jump | 0.6 s | 短按空格起跳 |
| Fall | 1 s | 下落、Shift 循环蓄速 |
| Land | 0.4 s | 落地、撞击 |
| Cast | 0.8 s | 放门；瞄准与长空格停留在施法姿态 |
| Cut | 0.8 s | 切割释放 |
| Dash | 0.6 s | 突进、穿门、冲门 |

动作是用于验证的基础骨骼动画，不含面部绑定和手指骨骼。披风随动作小幅摆动。物理移动继续由玩家控制器负责，动画不写玩家根节点位置。

## 特效锚点

`PortalCharacter.socket_position(name)` 返回世界坐标：`FX_CastHand` 右侧黑手套、`FX_Chest` 吊坠、`FX_Waist` 腰部、`FX_Foot_L/R` 脚底、`FX_Cape` 披风尾部。锚点已经随相应骨骼动作更新；本轮不新增粒子包。

## 验证与边界

Godot 4.7.1 Compatibility 下，角色测试 25/25（无窗口与真实渲染分别通过），原传送门魔法 43/43、混合穿门 34/34。测试包括权重归一、导入动作与锚点、实际移动跳跃、动作切换、循环下落、取消与重置。详细结果见 `docs/portal-character/*results.json`。

运行 `powershell -ExecutionPolicy Bypass -File tools/portal.ps1 -Character` 重建预览并执行渲染集成测试；`-Check` 包含角色回归。Blender 重建命令：`blender --background --factory-startup --disable-autoexec --python tools/build_portal_character.py`。

模型是表现层替换，仍使用现有半径 0.72 m 的球形碰撞代理，未改成人形胶囊；头部与披风不单独碰撞。Shift 期间显示裁切后的两份角色实现循环下坠，物理角色与摄像机不会反复传送。正常时只显示一份。镜头高度改为更适合人形的构图。真人手感、极端近墙时披风穿插与细致动作打磨仍可继续迭代；本轮没有重新做全场压力基准测试。
