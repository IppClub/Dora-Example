import { Content, Director, Log, Node as DNode, Path, Slot, Vec2, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Button, CooldownButton } from "UIX";

const resultFile = Path(Content.writablePath, "UIXInteractionStateTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXInteractionStateTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const disabledClicks = signal(0);
const castCount = signal(0);
const cooldown = signal(1);
const dragButtonClicks = signal(0);
const disabledButtonRef = reference<Dora.AlignNode.Type>();
const cooldownButtonRef = reference<Dora.AlignNode.Type>();
const dragButtonRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8, flexDirection: "row", gap: 8 }}>
		<Button ref={disabledButtonRef} disabled onClick={() => disabledClicks.value += 1}>Disabled</Button>
		<CooldownButton ref={cooldownButtonRef} icon="play" cooldown={cooldown.value} maxCooldown={2} onCast={() => castCount.value += 1} />
		<Button ref={dragButtonRef} swallowTouches={false} onClick={() => dragButtonClicks.value += 1}>Drag</Button>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(disabledButtonRef.current !== undefined, "disabled button was not mounted");
	expect(cooldownButtonRef.current !== undefined, "cooldown button was not mounted");
	expect(dragButtonRef.current !== undefined, "drag button was not mounted");
	disabledButtonRef.current!.emit(Slot.Tapped);
	cooldownButtonRef.current!.emit(Slot.Tapped);
	dragButtonRef.current!.emit(Slot.TapBegan);
	dragButtonRef.current!.emit(Slot.TapMoved, { delta: Vec2(0, 12) } as Dora.Touch.Type);
	dragButtonRef.current!.emit(Slot.Tapped);
	expect(disabledClicks.value === 0, "disabled button should not be invoked during render");
	expect(castCount.value === 0, "cooling button should not cast while cooling");
	expect(dragButtonClicks.value === 0, "dragged button should not click");
	dragButtonRef.current!.emit(Slot.TapBegan);
	dragButtonRef.current!.emit(Slot.Tapped);
	expect(dragButtonClicks.value === 1, "non-dragged button should click");
	cooldown.value = 0;
	Director.systemScheduler.schedule(once(() => {
		expect(cooldown.value === 0, "cooldown signal did not patch");
		cooldownButtonRef.current!.emit(Slot.Tapped);
		expect(castCount.value === 1, "ready cooldown button should cast when tapped");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXInteractionStateTest] passed");
		host.removeFromParent(true);
		root.unmount();
	}));
}));
