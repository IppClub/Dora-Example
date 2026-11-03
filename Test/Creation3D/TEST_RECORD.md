# Creation3D 本轮验收记录（2026-10-27）

本轮结果：通过本机首期范围验收。逻辑函数回归与真实窗口输入分别有证据；未用逻辑调用替代键鼠。Restart 已按用户指出的问题居中，并修正背景、文字、点击矩形和点击穿透。

## 环境与来源

- macOS 26.6.2（25G83），Apple M1 Pro，Metal，Dora 服务自报 1.9.4.4。
- 引擎源码基线：`6a05611e3dc82e7cbf83a8e8505b2d8af0f7a2c0`；Dora-Example 基线：`386cf0d6e933bd5eb809341ae81620c8eaefbf89`。本轮 helper、样例、测试为此基线之上的本地新增文件。
- 最终逻辑回归、性能与真实输入使用当前工程 `build/macosx/arm64/debug/Dora.app`。二进制 SHA256：`afe9acf944813c13e660b3b1765e0a7e6669cf7abd54cc8518a612ed2c82b309`。
- CLI 客户端 / 初期独立调试进程 SHA256：`7bc6df9f3f4052e9e75433809e2c4883ffbbc5429e67fd2bba4c2da5de8f2733`。源码基线不是二进制内嵌提交来源证明；此前工具包与长帧优化阶段没有重编译引擎；本次诊断阶段已重编译并验证新引擎，见 DIAGNOSTICS.md。
- 初期 CUA 绑定超时；结束本轮自行启动的独立进程后，绑定当前工程 .app 成功。没有修改权限、删除实例锁或终止用户既有进程。

## 验收矩阵

| 项目 | 本轮证据 | 结果 |
| --- | --- | --- |
| 参数、恢复、seed、尺寸校验、五类动作采样 | `evidence/unit.txt`，41 个断言 | PASS |
| 四种原创基础 GLB 与本地 Fox 完整性 | `evidence/assets.json` | PASS，Fox 与原 fixture 字节一致 |
| baseline 游戏逻辑 | `evidence/baseline.json`，18 个断言，含重来与第二局 | PASS，直接逻辑调用 |
| mixed 游戏逻辑 | `evidence/mixed.json`，25 个断言，含重来与第二局 | PASS，直接逻辑调用 |
| wide 游戏逻辑 | `evidence/wide.json`，18 个断言，含重来与第二局 | PASS，直接逻辑调用 |
| recolor 游戏逻辑 | `evidence/recolor.json`，18 个断言，含重来与第二局 | PASS，直接逻辑调用 |
| fast 游戏逻辑 | `evidence/fast.json`，18 个断言，含重来与第二局 | PASS，直接逻辑调用 |
| 异步加载失败 | `evidence/loaderfailure.json`，缺资源、解码失败与退化模型三项 | PASS |
| 单参数局部修改 | `evidence/edits.json`，三个变体只改一个配置键，树布局不变；unit 验证精确恢复 | PASS |
| 缺动画、缺 GLB、缺贴图、异常尺寸、碰撞拒绝、XYZ 旋转与朝向 | `evidence/failures.json`，17 个断言 | PASS |
| Fox idle/walk/run 实际播放与运动包络 | `evidence/animation.json`，各采样一整周期 | PASS |
| 独立 Jolt 适配 | `evidence/jolt.json`，cube / Fox 落地、接触、可见边界、内外射线 | PASS，未迁移 Town |
| 基础版真实键鼠 | `evidence/input-basic.json`、freeze/restart JSON、两局通关 PNG | PASS |
| 混合版真实键鼠 | `evidence/input-mixed.json`、freeze/restart JSON、两局通关 PNG | PASS |

## 实际参数效果

| 修改 | 道路完整宽度（m） | 建筑 ARGB | 0.1 秒实际位移（m） |
| --- | ---: | --- | ---: |
| baseline | 3.40 | `0xffe2ac76` | 0.30 |
| mixed | 3.40 | `0xffe2ac76` | 0.30 |
| wide | 4.80 | `0xffe2ac76` | 0.30 |
| recolor | 3.40 | `0xff9ab4d4` | 0.30 |
| fast | 3.40 | `0xffe2ac76` | 0.45 |

道路宽度变化同时按公式更新建筑退界；布局 seed、收集位置、碰撞实现与其他玩法不变。混合版只改 asset ID，玩法源文件不变。恢复测试逐键比较完整配置，不用近似视觉判断代替。

## 真实输入的独立证据

通过 CUA 操作实际 Dora 原生窗口：Enter 开始，W 移动，D 持续撞墙，点击三处物品与终点；通关后 S 无位移；点击居中的 Restart 后人物停在初始位置且三件物品恢复；Up 开始并完成第二局，最后 R 复位。两种配置分别执行。观察器只读状态和键盘，没有直接调用 Game.move/start/restart。

| 配置 | 第一局 / 第二局 | 障碍命中计数 | 已采样的真实按键 |
| --- | --- | ---: | --- |
| basic | 1 / 2 均通关，随后复位第 3 局 | 74 | D:145, R:19, Return:18, S:58, Up:97, W:98 |
| mixed | 1 / 2 均通关，随后复位第 3 局 | 94 | D:147, R:18, Return:16, S:59, Up:97, W:90 |

按键数字是观察到按住该键的帧数，不是独立操作次数。`input-*-round-1.png` / `round-2.png` 来自实际游玩时引擎截图，且窗口画面经过 CUA 观察。原始 TGA 本机保留但不纳入 Git；正式 review JSON 的 screenshots 字段指向 PNG。

## 实际运行数据

以下为异步资源准备完成后的第一局场景采样，三件物品已隐藏；每配置 90 帧。完整加载阶段的全部帧另由 PERFORMANCE.md 的冷启动对照覆盖。帧耗时为 App.deltaTime，包含调度/VSync 与首次载入窗口影响，不是隔离 GPU 时间。

| 场景 | 可见 / draw | 三角形 | 帧 P50 / P95 / max（ms） | collect P95（µs） | submit P95（µs） |
| --- | --- | ---: | --- | ---: | ---: |
| baseline | 33 / 33 | 2720 | 8.334 / 8.334 / 16.275 | 759 | 541 |
| mixed | 32 / 32 | 3060 | 8.334 / 8.334 / 8.334 | 838 | 507 |
| wide | 33 / 33 | 2720 | 8.334 / 8.334 / 8.334 | 719 | 553 |
| recolor | 33 / 33 | 2720 | 8.334 / 8.342 / 15.944 | 757 | 554 |
| fast | 33 / 33 | 2720 | 8.334 / 8.334 / 9.155 | 746 | 545 |

此前约 343ms 长帧现已定位到同步 GLB 冷加载，默认入口改为异步资源准备。三次冷缓存对照将最大帧降至 21.3–22.2ms；根因、完整加载阶段数据与复跑命令见 PERFORMANCE.md。未测大规模场景、跨平台、长期内存、GPU 独立计时与动画混合。驻留资源字节见原始 JSON，是进程注册表快照；不以 GLB 文件大小代替性能结论。

## 动画与碰撞的明确容差

Fox 静止尺寸约 0.239 × 0.750 × 1.468m；配置允许宽深 1.9 × 1.9m、平面半径 0.95m、高 0.9m。三个动画实测包络见 animation.json；Run 最大半径约 0.872m、最高约 0.851m，并有约 0.055m 的脚部下探。因此 profile 明确设置 groundTolerance=0.06m。静止脚底对齐地面，动画脚部变形不逐帧重拟合碰撞体。这个容差是显式记录的近似，不是精确三角网格碰撞。

Jolt 用保守 box 验证静止外观与碰撞边界；Town 使用自由转向保守圆形 footprint 对 AABB 的脚本检测，二者形状策略不同。两个 Jolt 体均有地板接触；本次最终脚底误差在测试的 0.06m 容差内，具体数值保留在 jolt.json。

## 交付边界

所有源码与资产在 `Example/Creation3D/` 和 `Test/Creation3D/`；引擎接口清单在 Dora-SSR `Docs/design/3d/08-programmatic-creation-kit.md`。没有调用 Tripo、上传资产、改渲染器或加入完整动画混合系统。Mesh3D / Geometry 另列后续；结构化导入诊断是可选接口增强。本轮尚未提交或推送。

## 长帧优化复验

默认入口改为异步加载后，完整脚本回归、冷启动对照，以及两种配置各两局真实窗口输入均已重新执行并通过。详见 [PERFORMANCE.md](PERFORMANCE.md)。

## 结构化诊断接口复验

统一接口、工具包接入和失败用例已完成：220 项原生断言、11 项 Rust loader 测试、25 个已有模型、迁移后的缓存生命周期测试及全套工具包回归均通过。新二进制信息和边界见 [DIAGNOSTICS.md](DIAGNOSTICS.md)。此前真实键鼠记录仍为前轮证据，本轮新增的接口验收采用实际引擎加载而非模拟加载。
