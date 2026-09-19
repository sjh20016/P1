# 0.07 构建记录

日期：2026-09-16。

已完成 Godot 4.7.2 Stable 无窗口导入与 Windows x64 Release 导出，构建脚本退出码 0；导入和导出日志未发现 `SCRIPT ERROR` 或 `ERROR:`。这是解析与构建检查，不是玩法运行验证。

- 本地输出：`build/RAVAGE-0.07-Windows/RAVAGE.exe`
- 分发包：`build/RAVAGE-0.07-Windows.zip`
- 包校验：旁置 `.zip.sha256` 文件；打包工具逐项检查 ZIP CRC，并比较压缩包内外 EXE 的 SHA256。
- 构建日志：`build/import-0.07.log`、`build/export-0.07.log`
- 回退包：`build/RAVAGE-0.06-Windows.zip`

按用户安排，本轮未启动游戏试玩、分项回归脚本或性能跑圈。请勿把构建成功或压缩包校验解释为玩法、物理稳定性或帧率已通过测试。
