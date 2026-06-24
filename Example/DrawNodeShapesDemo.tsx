// @preview-file on nolog
import { App, Color, Director, Node as DNode, Vec2, loop, sleep } from "Dora";
import { React, createRoot, signal } from "DoraX";

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const tick = signal(0);

function shapeColor(this: void, index: number) {
	const palette = [0xffff6b6b, 0xff4ecdc4, 0xffffd166, 0xffa78bfa, 0xfff97316];
	return palette[(tick.value + index) % palette.length];
}

root.render(() =>
	<node>
		<label
			key="title"
			fontName="sarasa-mono-sc-regular"
			fontSize={28}
			text="DoraX DrawNode Shapes"
			y={135}
			color3={0xffffff}
		/>
		<draw-node key={`draw-${tick.value}`}>
			<dot-shape x={-150} y={10} radius={20 + tick.value % 8} color={shapeColor(0)} />
			<segment-shape startX={-90} startY={-24} stopX={-40} stopY={48} radius={5} color={shapeColor(1)} />
			<rect-shape centerX={35} centerY={12} width={54} height={54} fillColor={shapeColor(2)} borderWidth={3} borderColor={0xffffffff} />
			<polygon-shape
				verts={[Vec2(110, -28), Vec2(164, -18), Vec2(142, 42)]}
				fillColor={shapeColor(3)}
				borderWidth={3}
				borderColor={0xffffffff}
			/>
			<verts-shape verts={[[Vec2(-22, -90), shapeColor(4)], [Vec2(22, -90), shapeColor(1)], [Vec2(0, -46), shapeColor(3)]]} />
		</draw-node>
		<label
			key="hint"
			fontName="sarasa-mono-sc-regular"
			fontSize={18}
			text={`shape refresh ${tick.value}`}
			y={-135}
			color3={0xd1d5db}
		/>
	</node>
);

host.schedule(loop(() => {
	sleep(0.6);
	tick.value += 1;
	return false;
}));

host.onCleanup(() => {
	host.unschedule();
	root.unmount();
});

Director.clearColor = Color(0xff0f172a);
