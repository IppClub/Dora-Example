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
