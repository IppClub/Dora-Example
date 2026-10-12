# DoraX regressions

Run `./Test/DoraX/run-all.zsh` with the engine containing the matching DoraX library. The runner compiles every TSX test and checks its result marker.

`DrawNodeShapesTest.tsx` covers the new DrawNode tags through both `toNode()` and `createRoot().render()`, including geometry replacement, shape tags not creating child nodes, defaults, transparent fill and unmount cleanup. Its three visible panels are static TSX, updated dynamic TSX and equivalent direct DrawNode calls. They should draw the same image. The panel origins are at world X = -300, 0 and 300; the shapes occupy local X = [-130, 130], Y = [-190, 100].

Use the shape tags directly inside `<draw-node>`:

```tsx
<draw-node>
  <circle-shape radius={40} color={0xff40c0ff} />
  <ellipse-shape centerX={100} radiusX={40} radiusY={20} />
  <rounded-rect-shape centerY={100} width={120} height={60}
    cornerRadius={12} fillColor={0xff40c0ff} borderWidth={2} />
  <ring-shape centerX={200} innerRadius={20} outerRadius={40} />
  <sector-shape centerY={-100} radius={40} startAngle={0} endAngle={270} />
  <polyline-shape verts={[Vec2(-40, 0), Vec2(0, 40), Vec2(40, 0)]}
    radius={2} closed={false} />
  <arc-shape radius={60} startAngle={0} endAngle={180} lineRadius={2} />
  <quadratic-bezier-shape startX={0} startY={0} controlX={50} controlY={80}
    stopX={100} stopY={0} radius={2} />
  <cubic-bezier-shape startX={0} startY={0} control1X={30} control1Y={80}
    control2X={70} control2Y={-80} stopX={100} stopY={0} radius={2} />
</draw-node>
```

Import `Vec2` from `Dora` and `React` from `DoraX`. Center coordinates default to zero, colors are ARGB and default to white, and `borderWidth` defaults to zero. Stroke `radius`, `lineRadius` and `borderWidth` are half widths. Arc/sector angles use degrees from +X toward +Y, retaining the signed sweep. Dynamic shape changes follow the existing DrawNode behavior of replacing the host DrawNode.
