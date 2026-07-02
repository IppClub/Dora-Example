import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Checkbox, Column } from "UIX";

const resultFile = Path(Content.writablePath, "UIXCheckboxControlTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXCheckboxControlTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const enabled = signal(false);
const partial = signal(false);
const disabledValue = signal(true);
const checkboxRef = reference<Dora.AlignNode.Type>();
const partialRef = reference<Dora.AlignNode.Type>();
const disabledRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Column style={{ width: 260, gap: 10 }}>
			<Checkbox
				key="checkbox-basic"
				ref={checkboxRef}
				checked={enabled.value}
				label="Enable loot hints"
				onChange={(value) => enabled.value = value}
			/>
			<Checkbox
				key="checkbox-partial"
				ref={partialRef}
				checked={partial.value}
				indeterminate={!partial.value}
				label="Mixed objectives"
				onChange={(value) => partial.value = value}
			/>
			<Checkbox
				key="checkbox-disabled"
				ref={disabledRef}
				checked={disabledValue.value}
				disabled
				label="Locked option"
				onChange={(value) => disabledValue.value = value}
			/>
		</Column>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(checkboxRef.current !== undefined, "checkbox ref missing");
	expect(partialRef.current !== undefined, "indeterminate checkbox ref missing");
	expect(disabledRef.current !== undefined, "disabled checkbox ref missing");
	checkboxRef.current!.emit(Slot.Tapped);
	expect(enabled.value === true, "checkbox did not emit checked value");
	partialRef.current!.emit(Slot.Tapped);
	expect(partial.value === true, "indeterminate checkbox did not emit checked value");
	disabledRef.current!.emit(Slot.Tapped);
	expect(disabledValue.value === true, "disabled checkbox should ignore tap");
	Content.save(resultFile, "passed");
	Log("Info", "[UIXCheckboxControlTest] passed");
	host.removeFromParent(true);
	root.unmount();
}));
