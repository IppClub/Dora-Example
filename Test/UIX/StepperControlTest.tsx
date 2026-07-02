import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Column, Stepper } from "UIX";

const resultFile = Path(Content.writablePath, "UIXStepperControlTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXStepperControlTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const amount = signal(2);
const disabledAmount = signal(4);
const decRef = reference<Dora.AlignNode.Type>();
const incRef = reference<Dora.AlignNode.Type>();
const disabledIncRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Column style={{ width: 280, gap: 10 }}>
			<Stepper
				value={amount.value}
				min={1}
				max={3}
				step={1}
				decreaseRef={decRef}
				increaseRef={incRef}
				onValueChange={(value) => amount.value = value}
			/>
			<Stepper
				value={disabledAmount.value}
				min={1}
				max={5}
				disabled
				increaseRef={disabledIncRef}
				onValueChange={(value) => disabledAmount.value = value}
			/>
		</Column>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(decRef.current !== undefined, "decrease ref missing");
	expect(incRef.current !== undefined, "increase ref missing");
	expect(disabledIncRef.current !== undefined, "disabled increase ref missing");
	incRef.current!.emit(Slot.Tapped);
	expect(amount.value === 3, "stepper did not increment");
	Director.systemScheduler.schedule(once(() => {
		incRef.current!.emit(Slot.Tapped);
		expect(amount.value === 3, "stepper should clamp at max");
		decRef.current!.emit(Slot.Tapped);
		expect(amount.value === 2, "stepper did not decrement");
		Director.systemScheduler.schedule(once(() => {
			decRef.current!.emit(Slot.Tapped);
			expect(amount.value === 1, "stepper did not reach min");
			Director.systemScheduler.schedule(once(() => {
				decRef.current!.emit(Slot.Tapped);
				expect(amount.value === 1, "stepper should clamp at min");
				disabledIncRef.current!.emit(Slot.Tapped);
				expect(disabledAmount.value === 4, "disabled stepper should ignore tap");
				Content.save(resultFile, "passed");
				Log("Info", "[UIXStepperControlTest] passed");
				host.removeFromParent(true);
				root.unmount();
			}));
		}));
	}));
}));
