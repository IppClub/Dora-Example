// @preview-file on nolog
import { App, Color, Director, Node as DNode, loop, sleep, Vec2 } from "Dora";
import { React, createRoot, signal } from "DoraX";

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);

function renderBars(this: void, value: number) {
	const bars: React.Element[] = [];
	const active = value % 10;
	for (let i of $range(0, 9)) {
		bars.push(
			<node
				key={i}
				x={(i - 4.5) * 24}
				y={-72}
				width={16}
				height={24 + i * 4}
				anchorX={0.5}
				anchorY={0}
				color3={i <= active ? 0x55c7ff : 0x4a5568}
				opacity={i <= active ? 1 : 0.35}
			>
				<draw-node>
					<rect-shape width={16} height={24 + i * 4} fillColor={0xffffffff}/>
				</draw-node>
			</node>
		);
	}
	return bars;
}

const count = signal(0);

root.render(() =>
	<node>
		<label
			key="title"
			fontName="sarasa-mono-sc-regular"
			fontSize={32}
			text="DoraX Counter"
			y={72}
			color3={0xffffff}
		/>
		<label
			key="count"
			fontName="sarasa-mono-sc-regular"
			fontSize={52}
			text={`${count.value}`}
			color3={0xffd166}
		/>
		{renderBars(count.value)}
	</node>
);

host.schedule(loop(() => {
	sleep(0.5);
	count.value += 1;
	return false;
}));

host.onCleanup(() => {
	host.unschedule();
	root.unmount();
});

Director.clearColor = Color(0xff1f2937);
