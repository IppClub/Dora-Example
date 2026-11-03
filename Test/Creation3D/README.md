# Creation3D 验证

运行中的引擎须属于你要验证的 Dora 工程。runner 会使用 preview 队列切换测试场景，结束后停止测试；不会杀引擎、关闭浏览器、删除锁或更改权限。

```sh
cd /path/to/Dora-Example/Example/Creation3D
lua ../../Test/Creation3D/unit.lua
# 对已启动的当前工程引擎运行；路径显式传入
python3 ../../Test/Creation3D/run.py \
  --engine /path/to/Dora-SSR/build/macosx/arm64/debug/Dora \
  --assets /path/to/Dora-SSR/Assets
```

`--case baseline|mixed|wide|recolor|fast|Failures|Jolt|Animation|LoaderFailure|Diagnostics|DiagnosticCompatibility` 可只跑一项。每次先移除该测试的旧报告，成功 preview 之外还必须有新写入的 passed 报告。preview 成功本身不证明断言通过。所有结果和截图写在本目录 `evidence/`，与被测源码一起保留。

`unit.lua` 检查参数隔离/恢复、种子布局、尺寸拒绝、动作采样；无需 Dora。`Verify.lua` 保留前一实验内部断言，补充适配检查与第二局，运行中通过直接调用玩法函数执行。`Failures.lua` 检查静态动画降级、资源/贴图缺失、超大模型、尺寸和碰撞不匹配、任意 XYZ 旋转、头尾朝向与 JSON 回存。`Animation.lua` 对 Fox 三个语义动画各采样一整周期并检查运动包络。`LoaderFailure.lua` 检查资源缺失、异步解码失败、载入成功但包围盒退化时的明确失败状态，禁止同步回退。`Jolt.lua` 独立创建两个适配外观、动态 box 碰撞体与静态地板，验证落地、接触、脚底和形状边界射线；没有将 Town 改为 Jolt。

## 原生键鼠验收

```sh
dora cli run -p /path/to/Dora-Example --entry Test/Creation3D/input-basic.lua
# 同样步骤再验证混合版
dora cli run -p /path/to/Dora-Example --entry Test/Creation3D/input-mixed.lua
```

在实际原生窗口完成下列步骤并保留对应截图与 `input-cube-live.json` / `input-Fox-live.json`：

1. 初始状态不移动、不计时，Enter 开始；WASD/方向键产生位移。
2. 向房屋移动，确认被挡；改变方向可脱离。点击地面应触发移动，遇障碍不会穿越。
3. 收集三件金色物品，确认每件只计一次，到绿色终点显示完成；胜利后位移停止。
4. 点击 Restart 按钮回到初始状态，物品全部恢复；开始并完成第二局。
5. 用 R 再次重来，检查键盘重来同样有效。

Input.lua 将两种配置的实时记录分开保存；正式复核结果为 `input-basic.json` / `input-mixed.json`，每种配置附两局通关 PNG。原始 TGA 与实时文件在 evidence/.gitignore 中忽略，避免将未复核数据当作交付结论。

Input.lua 只观察状态，绝不直接调用 move/start/restart，不合成按键。记录里出现状态变化也需核对实际窗口输入过程和截图后人工判定；观察器不会自动写入 PASS。若窗口无法访问，保存具体阻塞，标“未验证”，不以运行 Verify.lua 替代。

## 数据解释

冷启动对照另运行：

```sh
python3 ../../Test/Creation3D/profile.py --engine /path/to/Dora --assets /path/to/Dora-SSR/Assets
```

它对同步/异步各做三次显式卸载缓存后的冷启动，保留每次从加载开始的全部 150 帧，输出 performance-comparison.json 和逐帧 trace。异步最大帧超过 100ms 会失败；这是本机回归门槛，不是跨设备保证。详见 PERFORMANCE.md。

`performance.framesMs` 为 App.deltaTime 的 P50/P95/max，90 帧，场景已完成异步资源准备，包含构造与调度/VSync 影响；完整加载阶段另外由冷启动对照覆盖；不是隔离的 GPU 执行耗时。`collectMicros`、`submitMicros` 为 View3D CPU 阶段采样。`stats` 来自已完成第一局后的可见场景，三件收集物已隐藏。原生 Debug / Metal 单机结果不作跨设备 FPS 保证。注册表驻留字节是进程快照，不是严格隔离的资产增量内存。

## 引擎诊断接口验收

见 [DIAGNOSTICS.md](DIAGNOSTICS.md)。生成故障夹具后可用 `--case Diagnostics` 跑 220 项原生断言，`--case DiagnosticCompatibility` 跑 25 个已有模型。后者需要普通运行超过 preview 的 10 秒上限，runner 会等新结果文件，完成后停止场景。同步/异步错误、纹理上下文、并发/取消/重试及旧 getter 移除均由实际新构建验证。
