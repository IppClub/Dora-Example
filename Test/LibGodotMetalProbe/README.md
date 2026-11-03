# macOS LibGodot Metal 探针兼容入口

早期独立Metal原型已由完整GodotNode整合替代。`run.sh`现在转到`Tools/Godot/test_macos.sh`，使用vendor源码与原生xmake，不再下载另一份Godot、安装或调用SCons。旧构建流程及说明保存在[历史目录](../Godot/history/2026-11-03-xmake-only-legacy-probe/)。

```sh
Tools/LibGodotMetalProbe/run.sh --build-only
DORA_GODOT_PROBE_BUFFERS=3 Tools/LibGodotMetalProbe/run.sh
```

`DORA_GODOT_PROBE_OUTPUT`映射为标准GodotNode测试的结果目录；报告使用当前GodotNode校验格式。Debug/Release由`DORA_GODOT_TARGET`选择。旧原型源码保留用于历史查阅，不是当前LibGodot构建输入。当前平台状态与构建说明见[维护指南](../Godot/MAINTENANCE.md)。
