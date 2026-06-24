import { Content, Director, Log, Node as DNode, Path, Vec2 } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXSpecialNodesTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXSpecialNodesTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const drawRef = useRef<Dora.DrawNode.Type>();
const clipRef = useRef<Dora.ClipNode.Type>();
const customRef = useRef<Dora.Node.Type>();
const customCreatedA = DNode();
const customCreatedB = DNode();
let createA = 0;
let createB = 0;

function makeA(this: void) {
	createA += 1;
	return customCreatedA;
}

function makeB(this: void) {
	createB += 1;
	return customCreatedB;
}

root.render(
	<node>
		<draw-node key="draw" ref={drawRef}>
			<dot-shape x={0} y={0} radius={4} color={0xffffffff} />
			<segment-shape startX={-10} startY={-10} stopX={10} stopY={10} radius={2} color={0xffffffff} />
			<rect-shape width={20} height={10} fillColor={0xffffffff} borderWidth={1} borderColor={0xff000000} />
			<polygon-shape verts={[Vec2(-8, -8), Vec2(8, -8), Vec2(0, 8)]} fillColor={0xffffffff} />
			<verts-shape verts={[[Vec2(-4, 4), 0xffffffff], [Vec2(4, 4), 0xffffffff], [Vec2(0, -4), 0xffffffff]]} />
		</draw-node>
		<clip-node key="clip" ref={clipRef} stencil={
			<draw-node>
				<rect-shape width={12} height={12} fillColor={0xffffffff} />
			</draw-node>
		}>
			<node />
		</clip-node>
		<custom-node key="custom" ref={customRef} onCreate={makeA} />
	</node>
);

const draw = drawRef.current;
const clip = clipRef.current;
const custom = customRef.current;
expect(draw !== undefined, "draw-node was not mounted");
expect(clip !== undefined, "clip-node was not mounted");
expect(custom === customCreatedA, "custom-node did not use onCreate result");
expect(createA === 1, "custom-node onCreate should run once on initial mount");
expect(clip!.hasChildren, "clip-node child was not mounted");

root.render(
	<node>
		<draw-node key="draw" ref={drawRef}>
			<rect-shape width={30} height={20} fillColor={0xff00ff00} />
		</draw-node>
		<custom-node key="custom" ref={customRef} onCreate={makeB} />
	</node>
);

expect(drawRef.current !== draw, "draw-node should recreate when its shape definition changes");
expect(customRef.current === customCreatedB, "custom-node should recreate when onCreate changes");
expect(createB === 1, "new custom-node onCreate should run once");

root.unmount();
expect(!host.hasChildren, "special nodes unmount did not clear host");
host.removeFromParent(true);
Content.save(resultFile, "passed");
Log("Info", "[DoraXSpecialNodesTest] passed");
