# DrawNode 绘图测试

本目录包含 DrawNode 几何回归、CPU 网格生成基准，以及原生渲染用例。Python 测试直接提取指定 Dora-SSR 工作区的生产绘图实现；只替换存储和渲染接收端，不复制引擎算法。需要 Python 3 和支持 C++17、AddressSanitizer、UndefinedBehaviorSanitizer 的 C++ 编译器，可通过 `CXX` 指定。

在 Dora-Example 根目录运行：

```sh
python3 Test/DrawNode/test_drawnode_geometry.py --engine-root /path/to/Dora-SSR
python3 Test/DrawNode/benchmark_drawnode_sectors.py --engine-root /path/to/Dora-SSR
```

也可以设置 `DORA_SSR_ROOT`。未指定路径时，脚本尝试在各级父目录下查找 Dora-SSR 工作区。基准使用七次调用的中位数，输出 CPU 微秒、顶点数和三角形数，不代表帧率或 GPU 耗时。对比保存的引擎源码：

```sh
python3 Test/DrawNode/benchmark_drawnode_sectors.py --source /path/to/saved/DrawNode.cpp
```

原生渲染用例：

- `test_drawnode_shapes.lua`：新增接口、默认参数和闭合曲线。
- `test_drawnode_boundaries.lua`：小尺寸、大坐标、相交边框和极宽描边。
- `test_drawnode_sector_strokes.lua`：八种极宽透明扇形描边，适合优化前后截图对比。

这些 Lua 文件返回接收截图路径的函数。将用例复制到独立原生测试项目的 `Script` 目录，在该项目的 `Script/init.lua` 中调用，例如：

```lua
require("Script/test_drawnode_sector_strokes")("/tmp/dora-sector-strokes.tga")
```

用测试引擎启动该独立项目：

```sh
/path/to/Dora --asset /path/to/isolated-test-project
```

用例会在第四帧保存截图、第十二帧关闭测试引擎，因此应在独立进程中运行。截图和编译中间产物放在临时目录，不写入仓库。
