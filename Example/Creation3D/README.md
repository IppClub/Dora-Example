# Creation3D：轻量程序化 3D 创作工具包

本例复用 Dora `Model3D`、GLB、节点、材质和动画接口。基础 GLB 是离线生成的资产；运行时进行节点组合，不生成顶点网格。没有新增渲染器、3D 编辑器或生成服务依赖。

## 最短运行

将 Dora-Example 作为 Workspace 使用，或用已启动的 Dora 原生引擎运行此目录。以下命令中的 `dora` 代表你当前工程的 Dora 命令：

```sh
dora cli run -p /path/to/Dora-Example/Example/Creation3D
# 同一玩法，只换主角配置
dora cli run -p /path/to/Dora-Example/Example/Creation3D --entry mixed.lua
```

`Enter` 开始；`WASD` / 方向键移动；点击地面设定目的地；收集三个金色包裹，再走到绿色终点。`R` 或 Restart 按钮重来。移动键或点击也可开始。点击移动不寻路；撞到房屋应改方向。

基础版读取 `configs/basic.json`，混合版读取 `configs/mixed.json`。两者仅 `asset` 不同，`Game.lua` 不变。`wide.lua`、`recolor.lua`、`fast.lua` 分别演示“道路加宽”“建筑换色”“角色加速”，每次仅改变一个配置键。道路退界由道路宽度派生；树的随机布局只受 `seed` 影响。重新运行 `init.lua` 恢复基础配置。

入口使用 `Game.launch(config, onReady)`：返回 `{phase, ready, game, diagnostics}`，加载时显示进度，就绪后才创建玩法。`game` 只在 ready 后可用；失败 phase 为 failed，不假装成功。保留的 `Game.create(config)` 是低层同步构造接口，适用于资源已准备的调用者，直接冷加载导入 GLB 会阻塞主线程。

独立使用适配层时，先在 Dora.thread 中调用 `Kit.Loader.prepare(config)`，成功后再调用 `Adapter.load`。性能对照与完整加载阶段数据见 `../../Test/Creation3D/PERFORMANCE.md`。

## 文件与复用

| 文件 | 用途 |
| --- | --- |
| `Kit/Primitive.lua` | 方块、球、圆柱、XZ 平面；树、房屋、道路、平台；配色、相机、灯光预设 |
| `Kit/Diagnostics.lua` | 解码引擎 version=1 加载报告，统一同步/异步错误与纹理上下文 |
| `Kit/Loader.lua` | 线程中异步准备 GLB，复用引擎解析和分批上传；失败不回退到同步加载 |
| `Kit/Config.lua` | 参数校验、深拷贝、单键修改、JSON 保存/载入、独立固定种子随机布局 |
| `Kit/Adapter.lua` | GLB 本地资源预检；单位、XYZ 旋转、包围盒、脚底、尺寸、碰撞包络；语义动画映射 |
| `Kit/Motion.lua` | 绝对时间移动、旋转、摆动、弹跳、分段路径采样及应用，可组合到父子节点 |
| `Assets.lua` | 人工可覆写的资产适配配置，不从文件名推断单位和朝向 |
| `generate_assets.py` | 无依赖、确定性生成四个原创基础 GLB；不修改 Fox |
| `assets/` | 基础资产和带动画的本地 Fox；来源见 `CREDITS.md` |

在新项目复制 `Kit/`、`assets/` 和需要的资产配置即可使用。helper 通过项目搜索路径访问 `assets/`；在 Dora-Example 根目录运行时先将本目录加入 Content 搜索路径，参见测试入口。不要让同一场景同时创建多个游戏实例；重载通过 Dora 的 stop/run 清理旧场景与调度器。

所有尺寸为完整尺寸，米制、Y 向上，游戏前方为 -Z；旋转单位为度，顺序采用引擎 intrinsic XYZ。基础形状原点在中心，平面位于 XZ。`shape(kind, options, parent)` 的通用字段为 `position`、`size`、`rotation`、`color`、`roughness`、`metallic`。组合件的同名字段变换其父节点。材质逐实例修改。

## 资产适配契约

`Adapter.load(profile, parent)` 返回 `model, report`，失败时 model 为 nil，report 包含有错误等级的诊断，不附加不合格外观。玩法位置属于根节点，模型旋转和缩放属于外观子树，碰撞配置属于玩法；替换 Fox 不更改 `move`、收集或终点逻辑。

`unitsToMeters` 声明源单位；`targetHeight` 计算统一比例，保持长宽高比例；`rotation` 声明人工确认的朝向；旋转后的八角点共同决定中心和脚底偏移。`maxFootprint` 为允许的 X/Z 完整宽深；`collider.radius` 是自由转向时的保守平面包络半径，`height` 为从脚底起的垂直区间。Town 用该半径对房屋 AABB 做保守扩张，采用子步避免穿透。这是脚本逻辑碰撞。

Fox 当前目标高 0.75m；静止尺寸约 0.239 × 0.750 × 1.468m。半径 0.95m、高 0.9m 的碰撞配置与基础角色不同，允许边界为 1.9 × 1.9m。适配层不会沿用小角色的半径。Fox 的 180° Y 旋转通过头/尾骨骼附着点验证，头朝 -Z。

`scaleOverride` 可手工覆写归一化前的比例因子（最终节点 scale = 此值 × unitsToMeters），`offsetOverride` 可覆写旋转后米制平移。覆写仍须通过尺寸与碰撞检查。配置放入 `Assets.lua` 并随项目保存；新增资产 ID 后只需在场景 JSON 中选择它，无须改玩法或 Config helper。场景保存请使用明确的绝对路径，以免相对路径保存到引擎 writablePath。不要通过无限放大 `maxFootprint` 隐藏碰撞不匹配；调整资产比例或明确更新碰撞和通道空间后重跑验证。

加载诊断统一来自 `Cache.getLoadDiagnostics` 的版本化 JSON，不解析日志。引擎提供 RESOURCE_NOT_FOUND、RESOURCE_READ_FAILED、GLTF_PARSE_FAILED、GLTF_VALIDATION_FAILED、IMAGE_DECODE_FAILED 等 code，并包含阶段、资源路径、图像/材质索引和纹理槽；同步和异步均适用。Adapter 另提供 INVALID_BOUNDS、INVALID_SCALE、MODEL_TOO_LARGE、FOOTPRINT_EXCEEDED、COLLIDER_MISMATCH 等适配诊断。可选的 preflight helper 仅作本地引用预检，不是运行时权威结果。详见 `../../Test/Creation3D/DIAGNOSTICS.md`；本工具包要求具有该接口的新引擎。当前适配针对本地 GLB，源模型需提供 Y-up 数据或显式旋转校正。

动画配置将 idle/walk/run 映射为 Survey/Walk/Run。`Adapter.play` 返回 `playing:<clip>` 或 `static:<semantic>`；缺失动画会诊断并停止播放，明确降级为静态外观，玩法仍可移动。没有动画混合、重定向或骨骼生成。通用加载先检查静止包围盒；`Adapter.checkEnvelope(report)` 按原始比例和脚底偏移检查当前动画帧，不重新拟合；groundTolerance 为显式允许的脚底误差（Fox 为 0.06m，Run 实测最大约 0.055m 下探；静止脚底仍在 0，碰撞不追随每帧脚部变形）。动画包络需另测，本例对三个 Fox clip 各采样一整周期。人工换资产后应重新执行动画包络测试。

## 验证与当前限制

见 `../../Test/Creation3D/README.md`、`../../Test/Creation3D/TEST_RECORD.md`。逻辑、静态降级、异常资产、实际渲染和独立 Jolt 集成有运行证据。

**两种配置均完成真实原生窗口键鼠验收。** 使用当前工程 Dora.app，通过原生窗口键盘和鼠标分别完成移动、障碍、收集、结束、重来与第二局。记录与截图见测试目录；它们与直接调用玩法函数的逻辑回归分开。Restart 的居中、点击区域与事件穿透问题也在真实操作中修正并复测。
