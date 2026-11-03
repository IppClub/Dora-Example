# 混合版长帧定位与优化记录（2026-10-27）

结论：长帧来自冷缓存下的同步 GLB 加载。默认样例入口改为 Game.launch，复用 Cache.loadAsync 的后台解析和分帧上传，资源就绪后才构造场景。没有修改引擎或降低模型/贴图质量。

## 证据与根因

最终分阶段 trace 在不执行玩法回归的混合版中复现 336.8–342.4ms 最大帧；Game.create 约 330–335ms，其中 Adapter.load 约 306–308ms，GLB 图像引用预检不足 1ms。初期热缓存 trace 中同样创建约 8ms，整套直接逻辑回归约 7ms。渲染 collect/submit 在约 1ms 数量级，主要阻塞位于同步载入路径。证据为 profile-mixed 的初期 trace，以及下面显式清缓存的对照。

源码拥有路径：Model3D::init → Model3DCache::load → dora_3d_load_gltf。此调用会同步完成 glTF/图像处理与上传；原入口直接调用 Adapter.load，所以这些工作占用游戏线程。本轮定位到该调用边界，没有单独测量 PNG 解码和 mip 链生成各占多少时间，因此不进一步声称某一个纹理子步骤占了全部耗时。

已有 Model3DCache::loadAsync 将依赖解析与 CPU 资源准备交给 AsyncThread，上传通过既有 drainUploads 预算执行（源码预算为每帧 2ms、512KiB）。Kit/Loader.lua 使用这条公开 Cache.loadAsync 路径，没有增加渲染接口。

## 最终冷启动对照

同一机器、同一个 Debug/Metal 二进制；每次显式卸载四种场景资产缓存。同步与异步各三次，从入口加载开始保留全部 150 帧，没有丢弃加载/预热帧。同步场景和异步场景最终均为 3096 三角形（尚未收集物品）；GLB 哈希未变。

| 模式 / 次数 | 同步 Adapter.load（ms） | 资源就绪（ms） | 场景构造（ms） | 整段最大帧（ms） | 帧 P95（ms） |
| --- | ---: | ---: | ---: | ---: | ---: |
| cold-sync-1 | 306.632 | 330.173 | 330.170 | 338.046 | 8.334 |
| cold-sync-2 | 306.139 | 335.354 | 335.346 | 342.364 | 8.334 |
| cold-sync-3 | 308.403 | 330.692 | 330.690 | 336.827 | 8.334 |
| cold-async-1 | 0.942 | 435.094 | 17.140 | 21.294 | 8.334 |
| cold-async-2 | 1.124 | 435.321 | 17.501 | 22.186 | 8.334 |
| cold-async-3 | 0.874 | 442.121 | 17.183 | 21.925 | 8.336 |

最终同步最大帧范围 336.8–342.4ms，异步为 21.3–22.2ms。场景就绪延迟约 0.44 秒，同步路径约 0.33 秒；此优化消除的是主线程集中阻塞，没有声称总载入时长变短。等待时显示进度，准备完成后显示开始界面。仍有约 17ms 的场景构造工作，不能由此承诺所有帧都低于 16.7ms。

## 复跑与失败检查

运行 Test/Creation3D/profile.py（--engine 与 --assets 同主 runner），会生成 performance-comparison.json、cold-*-trace.json 与 preview 原始响应。每次 async 冷启动超过 100ms 会使本机回归失败；这个门槛不是跨设备保证。加载入口状态为 loading/ready/failed，失败不会同步回退。低层 Game.create/Adapter.load 仍为同步接口，调用者须先准备资源。

本轮重跑：41 个纯 Lua 断言；baseline/mixed/wide/recolor/fast 五组游戏逻辑与第二局；单参数修改隔离；17 个资源/尺寸/朝向失败检查；Jolt 两种外观；三个动画完整周期；LoaderFailure 的缺文件、异步解码失败、退化模型适配失败三个检查，均通过。

两种配置分别重新执行真实窗口 Enter/W/D/Up、鼠标收集与终点、胜利后 S 冻结、按钮重来、第二局、R 复位。input-basic.json / input-mixed.json 的 observer.loading 记录了本轮资源准备/构造耗时，两局通关截图已更新。没有直接调用玩法函数代替这项操作。

## 交付变更

- Kit/Loader.lua：预检、异步准备、错误诊断。
- Game.launch 与五个运行入口：加载进度、成功后创建、失败状态；保持游戏参数与玩法。
- Verify.lua：等待 launch 完成后再跑逻辑，单独保存 loading 时间。
- Profile.lua / ProfileRun.lua / profile.py：冷缓存 A/B 与逐帧数据。
- LoaderFailure.lua：异步失败和适配失败回归；run.py 纳入全套。

引擎二进制与原验收记录相同（SHA256 afe9acf944813c13e660b3b1765e0a7e6669cf7abd54cc8518a612ed2c82b309）。未重新编译、未提交或推送。
