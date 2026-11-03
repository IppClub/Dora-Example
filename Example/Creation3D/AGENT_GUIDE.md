# 给 Agent 的最小使用说明

先阅读 README 的坐标和碰撞约定，再创建场景。保持参数、外观、玩法和碰撞配置分开；先跑基础版，再替换重点资产。

```lua
local D=require('Dora')
local P=require('Kit.Primitive')
P.preset(D.Director.entry)
local island=P.group({position={0,0,0}},D.Director.entry)
P.platform({position={0,-.15,0},size={8,.3,8},color=P.palette.grass},island)
P.house({position={2,0,-2},color=P.palette.wall},island)
P.tree({position={-2,0,-2}},island)
local ball=P.shape('sphere',{position={0,.5,0},size={1,1,1},color=0xffffd773},island)
local Motion=require('Kit.Motion')
local t=0
D.threadLoop(function()
  t=t+D.App.deltaTime
  Motion.apply(ball,'bounce',{from={0,.5,0},amplitude=.3,duration=1},t)
  return false
end)
```

组合动作时将位移放父节点，旋转/摆动放子节点，避免两次写入覆盖同一属性。`Motion.sample('path',{points={{0,0,0},{2,0,0},{2,0,-2}},duration=4},t)` 返回分段线性路径位置；用 `loop=true` 循环时路径首尾应一致。`move/rotate` 使用 `from/to/duration`，`swing/bounce` 使用 `from/amplitude/axis/duration`。采样器不创建后台任务，调用者拥有调度与生命周期。

自然语言局部修改应落为一个配置差异，不重写玩法：

| 指令 | 唯一直接修改 | 恢复 |
| --- | --- | --- |
| 道路加宽到 4.8 米 | `Config.edit(config,'roadWidth',4.8)` | 写回原值 3.4 |
| 建筑换蓝色 | `Config.edit(config,'houseColor',0xff9ab4d4)` | 写回原颜色 |
| 角色速度改为 4.5 | `Config.edit(config,'speed',4.5)` | 写回原速度 3 |

用 `Config.save(path, config)` / `Config.load(path)` 保存与恢复 JSON，始终保留原配置深拷贝和 seed。重载生成场景后检查道路实际宽度、实例颜色隔离或单位时间位移，随后跑玩法回归；只比较配置文本不够。

启动可玩样例使用 `Game.launch(config, onReady)`；先等 ready 再访问 game。低层 `Game.create` / `Adapter.load` 会同步构造，所以导入资产须先在 Dora.thread 中用 `Kit.Loader.prepare(config)` 异步准备。不要用阻塞预热或舍弃首帧数据来消除统计中的长帧。

替换模型：复制 `Assets.lua` 的 profile，填 path、源单位、旋转、目标高、允许宽深、碰撞半径/高度和动画映射。调用 `Adapter.load` 后先检查 model 是否为 nil，保存 report.diagnostics 和 report.loadReport；不要在失败后沿用旧 report 声称成功。加载错误从 Cache.getLoadDiagnostics 的 code、stage、resourcePath、textureSlot 和 message 读取，不匹配日志文本。缺动画时向用户说明静态降级。新动画需采样包络，不能把静止尺寸当作完整运动尺寸。

验收分别保留：纯 Lua 参数/动作检查、引擎逻辑回归、真实窗口输入记录、Jolt 最小集成、运行性能数据。真实输入必须从窗口键鼠触发，不能调用 `Game.move()`、`start()` 或 `restart()` 冒充。窗口受阻标“未验证”，不绕权限。GLB 字节大小不代表渲染成本；记录 View3D 三角形/draw 与帧耗时样本。
