# Godot 4.7.2 退出异常定位

## 现象与证据

部分场景生命周期、宏块和预算测试完成全部断言后，进程仍返回 `0xC0000005`。Windows Application Error 与五份 Godot 转储均指向引擎模块偏移 `0x547F2C`；这不是断言失败，也不能通过忽略进程退出码处理。

2026-09-14 读取 Windows 已有 minidump，并对本机官方 `ed1daf0bf` 可执行文件反汇编。故障指令是 `mov r12, [r13 + 8]`，附近顺序为 cache clear、遍历脚本链表、清空函数参数与返回类型引用、清空脚本、取下一个链表项、释放当前引用。该指令序列与 [4.7.2 GDScriptLanguage::finish](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gdscript/gdscript.cpp#L2228) 一致。没有 PDB，因此函数名来自源码与机器码对照推断，不是假称获得带符号调用栈。

上游 [退出阶段资源寿命问题 #119279](https://github.com/godotengine/godot/issues/119279) 与 [4.8 的多阶段脚本清理修复 #120976](https://github.com/godotengine/godot/pull/120976) 提供了相关背景。上游案例并非本项目的精确复现，不能只靠问题标题就认定同一根因。

## 项目内修复

发现 `RavagePlayer` 的 hooks 数组引用 `GrappleController`，后者的 player 成员又声明为 `RavagePlayer`，形成脚本资源类型循环。把后者改为原生 `CharacterBody3D` 接口，并明确触手绘制起点的 Vector3 类型。没有修改抓钩算法、运动参数、输入、摄像机或坠落恢复。

修复后使用原来的脚本、断言和 Godot 4.7.2 运行回归；不强行结束进程、不隐藏退出码、不换引擎版本。早期诊断曾尝试字体和伤痕清理，均不能单独解释原生崩溃；内嵌中文字体与伤痕显式解绑各有独立用途，但不记作已证明的崩溃修复。

## 验证规则

`tools/run_checks.ps1` 同时检查断言文本、脚本错误、引擎错误、泄漏警告以及原生退出码。19 个脚本及长期回归全部通过，最终返回 0；记录见 `evidence/regression.txt`，图形与独立发布程序另核对退出码。调试用下载、原始转储及引擎源码留在本机临时目录，不进入游戏或公开仓库。
