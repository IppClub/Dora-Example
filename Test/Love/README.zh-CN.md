# Dora Love 兼容层测试

本目录保存 Dora-SSR 内嵌 Love 11.5 兼容层的回归测试和固定测试资源；正式实现仍位于 Dora-SSR 仓库。

使用相邻的 Dora-SSR checkout 配置并运行原生测试：

```sh
cmake -S Test/Love -B /tmp/dora-love-tests \
  -DDORA_SSR_ROOT=/path/to/Dora-SSR \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/dora-love-tests --parallel
ctest --test-dir /tmp/dora-love-tests --output-on-failure
```

也可以通过环境变量提供 `DORA_SSR_ROOT`。CMake 与 Node.js 测试入口还会自动识别 Dora-Example 和 Dora-SSR 互为相邻 checkout，或位于同一 Workspace 上级目录的常见布局。生成的构建目录必须位于本目录之外，或使用已忽略的 `build*` 目录。

`Fixtures` 是需要版本管理的固定测试输入，并非验证输出。完整日志、截图、视频和 Sanitizer 报告应保存为 CI Artifact，而不是提交到本仓库。

## 100 款开源游戏语料

`OpenSourceGames.json` 恰好固定 100 款公开 Love 游戏，逐项记录仓库、完整 Git commit、SPDX 许可证和入口文件。按以下方式审计清单、准备本地语料，并连接正在运行的 Dora Web IDE 执行：

```sh
node Test/Love/OpenSourceGameManifestTests.mjs
node Test/Love/PrepareOpenSourceGameCorpus.mjs /tmp/dora-love-corpus
node Test/Love/OpenSourceGameManifestTests.mjs /tmp/dora-love-corpus
node Test/Love/OpenSourceGameCompatibilityWorkflowTests.mjs \
  http://127.0.0.1:8866 /tmp/dora-love-corpus
```

Android 隔离测试会先打包固定的 checkout，再为每款游戏重新冷启动 Dora 进程：

```sh
node Test/Love/PackageOpenSourceGameCorpus.mjs \
  /tmp/dora-love-corpus /tmp/dora-love-packages
Test/Love/RunAndroidOpenSourceGameCorpus.sh \
  /tmp/dora-love-packages /tmp/android-love-results.tsv emulator-5554
node Test/Love/TransientBufferLifecycleWorkflowTests.mjs \
  http://127.0.0.1:8866
```

准备脚本会检出每个仓库的指定 commit，不会测试持续变化的默认分支；游戏仓库和资源不提交到本仓库。`Results/` 下的平台报告保存实际兼容性观察，非通过结果也是测试证据，不能静默省略。
