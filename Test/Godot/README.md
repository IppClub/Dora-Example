# Godot integration tests

This directory owns the Godot test hosts, projects, protocol/build regressions,
manual platform acceptance runners, dependency audits and test-package tools
previously kept under Dora-SSR `Tools/Godot`. `paths.json` records their original
locations. Production build/codegen/package tools and required package/SDK
integrity checks remain in Dora-SSR.

From the engine checkout:

```sh
xmake test-suite --repo=/path/to/Dora-Example --suite=godot-contract
xmake test-suite --repo=/path/to/Dora-Example --suite=godot-build
```

The contract suite compiles native protocol fixtures and checks package integrity
and build dispatch. The build suite inspects manifests, configures the standalone
xmake graph and checks codegen; it does not rebuild every Godot runtime or claim
GPU acceptance. Manual runners retain their required arguments and acceptance
thresholds. List cases with `xmake test-suite --repo=/path/to/Dora-Example --list`.

For individual scripts set both roots explicitly:

```sh
export DORA_ENGINE_ROOT=/path/to/Dora-SSR
export DORA_TEST_REPO=/path/to/Dora-Example
python3 "$DORA_TEST_REPO/Test/Godot/tests/runtime_abi.py" --help
```

Build native Godot test hosts with `DORA_TEST_REPO` set, or pass
`--dora_test_repo=/path/to/Dora-Example` during xmake configuration. Normal Dora
and standalone LibGodot builds do not fetch tests. C++/Objective-C++ test sources
are selected from this checkout only when their opt-in build flags are enabled.
CI resolves one immutable Dora-Example revision before invoking these runners.

Disposable Windows/Android bundles include the path resolver and test inventory;
their launchers point both roots at the extracted bundle. Keep GPU, physical
hardware and software/VM acceptance boundaries separate from build results.

Project delivery boundaries are covered by the `godot-projects` suite. The manual
`run_project_delivery.py` driver checks repository and PCK play in sequential
ordinary macOS hosts; it does not claim same-process project switching.

进程内项目切换：`run_project_switch.py --godot ... --app ... --runtime-package ... --output ...`。
限macOS Metal、普通宿主，macOS Metal默认启用，驱动不设置实验环境变量；七次源码/PCK加载使用同一个LibGodot实例，核对静态/资源/单例/输入、音频、像素、GPU和失败恢复。完整限制见引擎 `Tools/Godot/PROJECT_SWITCH.md`；不进入无需GPU的自动套件。

卸载通知及生产GodotPlayer控制器：`tests/project_switch/controller_contract.lua`含8项不依赖GPU的队列/回调/错误/关闭契约；`run_real_project_switch.py`在macOS串行验证未修改的官方2D/3D源码及PCK反复切换、像素/音频/对象与GPU计数；`run_project_lifecycle_edges.py`验证启动取消和默认配置切换及旧运行库的明确拒绝。完整命令和边界见引擎`Tools/Godot/PROJECT_SWITCH.md`。

版本检查从引擎 `Source/3rdParty/Godot/UPSTREAM.json` 读取固定版本；共享库 ABI、
Android 启动日志与暖缓存路径均使用该版本（缓存版本来自实际运行库清单）。
`test_runtime_version_guards.py` 纳入 CPU 协议回归，覆盖旧版误接受和 iOS 意外启动。
旧 4.6 时钟参考及其封存工具保留历史含义；新版时钟验收不得复用旧参考，需重新采集。
旧工程兼容测试中的 4.6 特征字段和来源审计的精确版本/摘要固定值保留。
