# 结构化模型加载诊断：实现与验收（2026-10-27）

已完成引擎同步/异步诊断及 Creation3D 接入。按用户确认合并接口，仅保留 Cache.getLoadDiagnostics(filename)，旧 getLoadError 已从 C++、Lua、TL/TS、Wasm、Rust、Wa、C# 和原缓存测试中移除。getLoadState 保留为轻量状态轮询，不承担另一套错误格式。

## 单一接口

```lua
local ok = Cache:load(path) -- 或在 Dora.thread 中 Cache:loadAsync(path)
local report = assert(require("json").decode(Cache:getLoadDiagnostics(path)))
for _, d in ipairs(report.diagnostics) do
    if d.severity == "error" then print(d.code, d.stage, d.resourcePath, d.textureSlot, d.message) end
end
```

跨语言统一返回 version=1 的 JSON 字符串，避免为各绑定维护不同的对象生命周期。报告含 modelPath、state、diagnostics；每项含 code、severity、stage、resourcePath、textureSlot、imageIndex、materialIndex、message。无法解析路径时保留请求名，其余通常为解析后的路径。图像/材质索引从 0 开始；不适用的上下文为 null。错误按 code 判断，不解析日志或 message 文本。

以下是损坏外部贴图的实际报告（文档中仅替换了工作区前缀，原始数据见 evidence/diagnostics.json）：

```json
{
  "diagnostics": [
    {
      "resourcePath": "<Dora-Example>/Test/Creation3D/Fixtures/Diagnostics/corrupt.png",
      "severity": "error",
      "stage": "images",
      "message": "The image format could not be determined",
      "imageIndex": 0,
      "code": "IMAGE_DECODE_FAILED",
      "materialIndex": 0,
      "textureSlot": "pbrMetallicRoughness.baseColorTexture"
    }
  ],
  "state": "failed",
  "version": 1,
  "modelPath": "<Dora-Example>/Test/Creation3D/Fixtures/Diagnostics/decode-image.glb"
}
```

## 实现边界

- Rust 导入器显式传递每次操作自己的诊断集合；通过回调交回 C++ 对应加载任务，未使用全局 last-error。
- 同步 Cache.load 与异步 Cache.loadAsync 使用同一解析、buffer、image 诊断逻辑；外部、嵌入及共享贴图均保留材质槽上下文。
- 仍采用 Content 的资源 I/O；异步缺依赖时由实际 importer 返回具体 image/slot 失败，不用笼统的依赖读取错误覆盖它。
- C++ 缓存发布路径级最终快照，先更新完成/取消状态再回调；缓存命中保留原警告，成功重试清除旧错误，旧 JSON 快照保持独立。
- 超宽贴图回退、放宽扩展校验、没有可渲染几何等成功导入情形明确带 warning。ready 表示资源加载完成，不承诺每项视觉特性完整。
- 环境贴图失败也保留原因，避免合并旧接口时丢失它原有的信息。
- Creation3D Kit/Diagnostics.lua 解码版本化报告；Loader 汇总每个资源的报告；Adapter 在构造 Model3D 前先检查同步缓存结果，避免资源失败触发 Debug 构造断言，并保留实例化失败诊断。

## 实际发现并修正的崩溃

畸形 POSITION accessor 索引触发 gltf-json 1.4 校验钩子的越界 panic，导致原生进程终止。现在先完成反序列化，在调用该钩子前验证 primitive 属性引用，再执行其余标准校验。此文件返回 GLTF_VALIDATION_FAILED；仅对 Unsupported 扩展问题保留既有的放宽校验兼容行为，并输出 warning。没有用 panic 捕获或忽略所有校验错误来绕过问题。

## 验收结果

| 范围 | 证据 | 结果 |
| --- | --- | --- |
| 原生同步/异步接口、报告格式、getter 合并 | evidence/diagnostics.json | 220 项断言 PASS |
| 缺文件、解析失败、越界引用、缺 buffer、短 buffer、缺贴图、外部/嵌入解码失败、共享槽、非法 URI | 同上，各比较 sync/async 完整报告 | PASS |
| 无几何、扩展校验警告、超宽贴图回退、缓存命中保留 warning | 同上 | PASS |
| 失败重试、并发不同模型、同路径合并请求、取消回调、迟到结果、取消后重试 | 同上 | PASS |
| 现有 PBR、动画、morph、skin、基础场景资产 | evidence/diagnosticcompatibility.json | 25 个已有模型 PASS |
| Rust loader | evidence/rust-model-loader.txt | 11 项 PASS，含 4 项新诊断/防崩溃测试 |
| 原 CacheLifecycleRegression.ts 迁移、重新编译和原生执行 | evidence/cache-lifecycle.txt | 取消、重试、缓存预算/淘汰 PASS |
| Creation3D 全套游戏逻辑、局部修改、异常资源、动画与 Jolt | 对应 evidence JSON | 全部 PASS |

新 Debug / Metal 二进制 SHA256：`4fc7f77229e9dbd4c077854da3547abc05d22fa2825253ce576a23c2fe9b2281`。本轮确实重新编译并运行新引擎；初期旧进程与 Rust 静态库未重新链接的测试不计为通过，最终结果来自确认包含边界防护的新二进制。

异步冷启动另外复查一次，包含加载阶段全部 150 帧：最大帧 28.608ms，就绪 443.348ms。仍低于本机 100ms 回归门槛，未重新引入此前约 343ms 阻塞。旧的三次冷启动对照见 PERFORMANCE.md，属于前一构建。

## 复跑

```sh
python3 Test/Creation3D/generate_diagnostic_fixtures.py
python3 Test/Creation3D/run.py --engine /path/to/Dora --assets /path/to/Dora-SSR/Assets --case Diagnostics
python3 Test/Creation3D/run.py --engine /path/to/Dora --assets /path/to/Dora-SSR/Assets --case DiagnosticCompatibility
```

省略 --case 跑全部。兼容性语料使用普通运行和结果文件等待，因为完整导入超过 preview 的 10 秒上限；不会把截断运行算作通过。CacheLifecycle.lua 为迁移后的原缓存测试提供根路径入口，该原测试完成后会关闭测试引擎。

未注入 GPU 分配失败或设备丢失；相关错误路径已接线并编译，但不把它们算作实际故障注入通过。未运行 Windows、Web、Wa 或 C# 应用；已更新相关声明和生成绑定，原生构建包含 Wasm 绑定编译。诊断采用遇到致命错误即停止的导入流程，不声称穷尽一个文件中的所有潜在错误。

新测试中的 cancel.glb 是既有 Fox.glb 的本地相同副本，版权沿用 Example/Creation3D/CREDITS.md；其他 GLB 为原创 cube 派生的确定性失败夹具。没有调用生成服务或网络资源。代码尚未提交或推送。
