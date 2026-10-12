import { Color, Content, Director, DrawNode, Log, Node, Path, Rect, Vec2 } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, toNode } from "DoraX";

// Three identical panels: static TSX, updated dynamic TSX, direct engine calls.
// Capture the scene to compare the panels without depending on tessellation details.
const resultFile = Path(Content.writablePath, "DoraXDrawNodeShapesTest.result");
Content.save(resultFile, "running");
const drawRef = reference<Dora.DrawNode.Type>();
const fill = 0x8040c0ff;
const border = 0xc0ff8040;
const verts = [Vec2(-95, -20), Vec2(-80, -45), Vec2(-65, -15)];

function shapes(this: void, x: number, radius: number) {
	return <draw-node x={x} ref={drawRef}>
		<circle-shape centerX={-80} centerY={70} radius={radius} color={fill} />
		<ellipse-shape centerX={0} centerY={70} radiusX={28} radiusY={16} color={fill} />
		<rounded-rect-shape centerX={80} centerY={70} width={48} height={36} cornerRadius={9} fillColor={fill} borderWidth={3} borderColor={border} />
		<ring-shape centerX={-80} innerRadius={12} outerRadius={25} fillColor={fill} borderWidth={3} borderColor={border} />
		<sector-shape radius={25} startAngle={35} endAngle={-235} fillColor={fill} borderWidth={4} borderColor={border} />
		<arc-shape centerX={80} radius={25} startAngle={-25} endAngle={245} lineRadius={4} color={border} />
		<polyline-shape verts={verts} radius={4} color={fill} closed />
		<quadratic-bezier-shape startX={-25} startY={-75} controlX={0} controlY={-15} stopX={25} stopY={-65} radius={4} color={border} />
		<cubic-bezier-shape startX={55} startY={-65} control1X={60} control1Y={-10} control2X={100} control2Y={-110} stopX={105} stopY={-65} radius={4} color={border} />
		<rect-shape centerX={-80} centerY={-110} width={36} height={20} fillColor={fill} borderWidth={2} borderColor={border} />
		{/* Default center, color, stroke and open polyline; explicit transparent fill. */}
		<circle-shape radius={3} />
		<ellipse-shape radiusX={5} radiusY={2} />
		<rounded-rect-shape centerY={-110} width={20} height={15} cornerRadius={4} />
		<ring-shape centerX={80} centerY={-110} innerRadius={5} outerRadius={10} />
		<sector-shape centerY={-145} radius={10} startAngle={0} endAngle={360} fillColor={0} borderWidth={2} />
		<polyline-shape verts={[Vec2(60, -145), Vec2(80, -135), Vec2(100, -145)]} radius={2} />
		<arc-shape radius={7} startAngle={0} endAngle={180} lineRadius={1} />
		<quadratic-bezier-shape startX={-10} startY={-170} controlX={0} controlY={-150} stopX={10} stopY={-170} radius={1} />
		<cubic-bezier-shape startX={65} startY={-170} control1X={70} control1Y={-150} control2X={90} control2Y={-190} stopX={95} stopY={-170} radius={1} />
	</draw-node>;
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) error(`[DoraXDrawNodeShapesTest] ${message}`);
}

const staticNode = toNode(shapes(-300, 24));
expect(staticNode !== undefined, "static draw-node missing");
expect(!staticNode!.hasChildren, "static shape tags must not create scene children");
Director.entry.addChild(staticNode!);

const host = Node();
Director.entry.addChild(host);
const root = createRoot(host);
root.render(shapes(0, 8));
const first = drawRef.current;
expect(first !== undefined, "dynamic draw-node missing");
root.render(shapes(0, 24));
expect(drawRef.current !== first, "shape updates must redraw geometry");
expect(!drawRef.current!.hasChildren, "dynamic shape tags must not create scene children");
expect(host.children?.count === 1, "update must replace the old draw-node");

const direct = DrawNode();
direct.x = 300;
direct.drawCircle(Vec2(-80, 70), 24, Color(fill));
direct.drawEllipse(Vec2(0, 70), 28, 16, Color(fill));
direct.drawRoundedRect(Rect(56, 52, 48, 36), 9, Color(fill), 3, Color(border));
direct.drawRing(Vec2(-80, 0), 12, 25, Color(fill), 3, Color(border));
direct.drawSector(Vec2.zero, 25, 35, -235, Color(fill), 4, Color(border));
direct.drawArc(Vec2(80, 0), 25, -25, 245, 4, Color(border));
direct.drawPolyline(verts, 4, Color(fill), true);
direct.drawQuadraticBezier(Vec2(-25, -75), Vec2(0, -15), Vec2(25, -65), 4, Color(border));
direct.drawCubicBezier(Vec2(55, -65), Vec2(60, -10), Vec2(100, -110), Vec2(105, -65), 4, Color(border));
direct.drawRect(Rect(-98, -120, 36, 20), Color(fill), 2, Color(border));
direct.drawCircle(Vec2.zero, 3, Color(0xffffffff));
direct.drawEllipse(Vec2.zero, 5, 2, Color(0xffffffff));
direct.drawRoundedRect(Rect(-10, -117.5, 20, 15), 4, Color(0xffffffff), 0, Color(0xffffffff));
direct.drawRing(Vec2(80, -110), 5, 10, Color(0xffffffff), 0, Color(0xffffffff));
direct.drawSector(Vec2(0, -145), 10, 0, 360, Color(0), 2, Color(0xffffffff));
direct.drawPolyline([Vec2(60, -145), Vec2(80, -135), Vec2(100, -145)], 2, Color(0xffffffff), false);
direct.drawArc(Vec2.zero, 7, 0, 180, 1, Color(0xffffffff));
direct.drawQuadraticBezier(Vec2(-10, -170), Vec2(0, -150), Vec2(10, -170), 1, Color(0xffffffff));
direct.drawCubicBezier(Vec2(65, -170), Vec2(70, -150), Vec2(90, -190), Vec2(95, -170), 1, Color(0xffffffff));
Director.entry.addChild(direct);

// Check unmount independently while keeping the comparison scene visible.
const cleanupHost = Node();
const cleanupRoot = createRoot(cleanupHost);
cleanupRoot.render(shapes(0, 24));
cleanupRoot.unmount();
expect(!cleanupHost.hasChildren, "unmount must clear geometry and children");
expect(drawRef.current === undefined, "unmount must clear the reference");
Content.save(resultFile, "passed");
Log("Info", "[DoraXDrawNodeShapesTest] passed");
