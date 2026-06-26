import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Column, Slider, Tabs, Toggle } from "UIX";

const resultFile = Path(Content.writablePath, "UIXSecondaryControlsTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXSecondaryControlsTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const enabled = signal(false);
const tab = signal("stats");
const sliderValue = signal(0.35);
const toggleRef = reference<Dora.AlignNode.Type>();
const tabsRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Column style={{ width: 260, gap: 10 }}>
			<Toggle
				ref={toggleRef}
				checked={enabled.value}
				label="Enabled"
				onChange={(value) => enabled.value = value}
			/>
			<Slider
				value={sliderValue.value}
				min={0}
				max={1}
				showValue
				onValueChange={(value) => sliderValue.value = value}
			/>
			<Tabs
				ref={tabsRef}
				value={tab.value}
				items={[
					{ id: "stats", label: "Stats" },
					{ id: "gear", label: "Gear" },
				]}
				onValueChange={(value) => tab.value = value}
			/>
		</Column>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(toggleRef.current !== undefined, "toggle ref missing");
	expect(tabsRef.current !== undefined, "tabs ref missing");
	toggleRef.current!.emit(Slot.Tapped);
	expect(enabled.value === true, "toggle did not emit changed value");
	const tabChildren = tabsRef.current!.children;
	expect(tabChildren !== undefined && tabChildren.count >= 2, "tabs did not mount item buttons");
	(tabChildren!.get(2) as Dora.Node.Type).emit(Slot.Tapped);
	expect(tab.value === "gear", "tabs did not emit selected value");
	expect(sliderValue.value === 0.35, "slider controlled value should remain unchanged without touch input");
	Content.save(resultFile, "passed");
	Log("Info", "[UIXSecondaryControlsTest] passed");
	host.removeFromParent(true);
	root.unmount();
}));
