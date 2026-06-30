import { ButtonName, Content, KeyName, Log, Path } from "Dora";
import { CreateManager, InputEvent, Trigger, TriggerState } from "InputManager";

const resultFile = Path(Content.writablePath, "InputManagerAPITest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[InputManagerAPITest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const jumpTrigger = Trigger.Down([
	{ key: KeyName.Space },
	{ button: ButtonName.A },
]);
const qteTrigger = Trigger.Sequence([
	Trigger.Selector([
		Trigger.Selector([
			Trigger.KeyPressed(KeyName.J),
			Trigger.Block(Trigger.AnyKeyPressed()),
		]),
		Trigger.Selector([
			Trigger.ButtonPressed(ButtonName.A),
			Trigger.Block(Trigger.AnyButtonPressed()),
		]),
	]),
	Trigger.Selector([
		Trigger.KeyTimed(KeyName.J, 1),
		Trigger.ButtonTimed(ButtonName.A, 1),
	]),
]);
const qteUpdate = qteTrigger as Trigger & { onUpdate?(deltaTime: number): void };

let triggerListenerHits = 0;
const triggerListener = () => {
	triggerListenerHits += 1;
};
jumpTrigger.addListener(triggerListener);

const inputManager = CreateManager({
	Gameplay: {
		Jump: jumpTrigger,
		Charge: Trigger.Hold({ key: KeyName.LShift }, 0.05),
		Combo: Trigger.Down({ button: [ButtonName.X, ButtonName.Y] }),
	},
	QTE: {
		QuickTime: qteTrigger,
	},
});

let allEvents = 0;
let completedEvents = 0;
let onceEvents = 0;
let lastEvent: InputEvent | undefined;

const onJump = (event: InputEvent) => {
	allEvents += 1;
	lastEvent = event;
	expect(event.action === "Jump", "event action should be Jump");
	expect(event.context === "Gameplay", "event context should be Gameplay");
	expect(event.inputManager === inputManager, "event should carry the source manager");
	expect(event.trigger === jumpTrigger, "event should carry the source trigger");
};

inputManager.on("Jump", onJump);
inputManager.once("Jump", () => {
	onceEvents += 1;
});
inputManager.onCompleted("Jump", event => {
	completedEvents += 1;
	expect(event.state === TriggerState.Completed, "onCompleted should only receive completed events");
});

expect(inputManager.getEventName("Jump") === "Input.Jump", "getEventName should add Input prefix");
expect(inputManager.pushContext("Gameplay"), "Gameplay context should push");

inputManager.emitKeyDown(KeyName.Space);
expect(allEvents === 1, "key binding should emit one Jump event");
expect(completedEvents === 1, "key binding should emit one completed event");
expect(onceEvents === 1, "once handler should run once after first input");
expect(triggerListenerHits === 1, "trigger listener should run after first input");
expect(lastEvent?.state === TriggerState.Completed, "last event should be completed");
inputManager.emitKeyUp(KeyName.Space);

jumpTrigger.removeListener(triggerListener);
inputManager.emitButtonDown(ButtonName.A);
expect(allEvents === 2, "button binding should emit another Jump event");
expect(completedEvents === 2, "button binding should emit another completed event");
expect(onceEvents === 1, "once handler should not run again");
expect(triggerListenerHits === 1, "removed trigger listener should not run again");
inputManager.emitButtonUp(ButtonName.A);

inputManager.off("Jump", onJump);
inputManager.emitKeyDown(KeyName.Space);
expect(allEvents === 2, "off should disable the registered handler");
expect(completedEvents === 3, "other handlers should stay active after off");
inputManager.emitKeyUp(KeyName.Space);

let qteCanceled = 0;
let qteCompleted = 0;
inputManager.on("QuickTime", event => {
	if (event.state === TriggerState.Canceled) {
		qteCanceled += 1;
	} else if (event.state === TriggerState.Completed) {
		qteCompleted += 1;
	}
});
expect(inputManager.pushContext("QTE"), "QTE context should push");
inputManager.emitButtonDown(ButtonName.B);
qteUpdate.onUpdate?.(0.016);
expect(qteCanceled >= 1, "wrong QTE button should cancel the QTE action");
expect(qteCompleted === 0, "wrong QTE button should not complete the QTE action");
inputManager.emitButtonUp(ButtonName.B);
expect(inputManager.popContext(), "QTE context should restart after failed QTE");
expect(inputManager.pushContext("QTE"), "QTE context should restart for QTE success");

inputManager.emitButtonDown(ButtonName.A);
qteUpdate.onUpdate?.(0.016);
expect(qteCompleted >= 1, "correct QTE button should complete the QTE action");
inputManager.emitButtonUp(ButtonName.A);

expect(inputManager.popContext(), "QTE context should pop");
expect(inputManager.popContext(), "Gameplay context should pop");
inputManager.destroy();

Content.save(resultFile, "passed");
Log("Info", "[InputManagerAPITest] passed");
