import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import { React, createRoot, signal, useEffect } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXHookEffectTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXHookEffectTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

function eventsText(this: void, events: string[]): string {
	return table.concat(events, ",");
}

function expectEvents(this: void, events: string[], expected: string, message: string) {
	const actual = eventsText(events);
	expect(actual === expected, `${message}: ${actual}`);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const dep = signal(1);
const spare = signal(0);
const visible = signal(true);
const events: string[] = [];

const [outsideOk] = pcall(() => useEffect(() => undefined, []));
expect(!outsideOk, "useEffect should throw outside function components");

function EffectChild(this: void, props: { key?: string; dep: number }) {
	useEffect(() => {
		events.push(`effect:${props.dep}`);
		return () => {
			events.push(`cleanup:${props.dep}`);
		};
	}, [props.dep]);
	return <node key="effect-child" x={spare.value} />;
}

function App(this: void) {
	if (!visible.value) return [];
	return <EffectChild key="effect" dep={dep.value} />;
}

root.render(App);
expectEvents(events, "effect:1", "initial effect should run after first render");

spare.value = 1;
Director.systemScheduler.schedule(once(() => {
	expectEvents(events, "effect:1", "effect should not rerun when deps are unchanged");
	dep.value = 2;
	Director.systemScheduler.schedule(once(() => {
		expectEvents(events, "effect:1,cleanup:1,effect:2", "effect should cleanup before rerun when deps change");
		visible.value = false;
		Director.systemScheduler.schedule(once(() => {
			expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2", "effect should cleanup when component is removed");
			dep.value = 3;
			visible.value = true;
			Director.systemScheduler.schedule(once(() => {
				expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2,effect:3", "effect should run when component mounts again");
				root.unmount();
				expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2,effect:3,cleanup:3", "effect should cleanup on root unmount");
				host.removeFromParent(true);
				Content.save(resultFile, "passed");
				Log("Info", "[DoraXHookEffectTest] passed");
			}));
		}));
	}));
}));
