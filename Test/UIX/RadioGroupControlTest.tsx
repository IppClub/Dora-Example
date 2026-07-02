import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { RadioGroup } from "UIX";

const resultFile = Path(Content.writablePath, "UIXRadioGroupControlTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXRadioGroupControlTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const value = signal("assist");
const assistRef = reference<Dora.AlignNode.Type>();
const manualRef = reference<Dora.AlignNode.Type>();
const lockedRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<RadioGroup
			value={value.value}
			direction="row"
			itemWidth={112}
			items={[
				{ id: "assist", label: "Assist", icon: "heart", ref: assistRef },
				{ id: "manual", label: "Manual", icon: "warning", ref: manualRef },
				{ id: "locked", label: "Locked", icon: "lock", disabled: true, ref: lockedRef },
			]}
			onValueChange={(next) => value.value = next}
		/>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(assistRef.current !== undefined, "assist radio ref missing");
	expect(manualRef.current !== undefined, "manual radio ref missing");
	expect(lockedRef.current !== undefined, "locked radio ref missing");
	manualRef.current!.emit(Slot.Tapped);
	expect(value.value === "manual", "radio did not switch to manual");
	Director.systemScheduler.schedule(once(() => {
		lockedRef.current!.emit(Slot.Tapped);
		expect(value.value === "manual", "disabled radio should not change value");
		assistRef.current!.emit(Slot.Tapped);
		expect(value.value === "assist", "radio did not switch back to assist");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXRadioGroupControlTest] passed");
		host.removeFromParent(true);
		root.unmount();
	}));
}));
