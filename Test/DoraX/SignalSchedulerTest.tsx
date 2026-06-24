import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, signal, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXSignalSchedulerTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXSignalSchedulerTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const hostA = DNode();
const hostB = DNode();
Director.entry.addChild(hostA);
Director.entry.addChild(hostB);

const rootA = createRoot(hostA);
const rootB = createRoot(hostB);
const value = signal(0);
const labelA = useRef<Dora.Label.Type>();
const labelB = useRef<Dora.Label.Type>();
let rendersA = 0;
let rendersB = 0;

rootA.render(() => {
	rendersA += 1;
	return <label key="a" ref={labelA} fontName="sarasa-mono-sc-regular" fontSize={18} text={`A:${value.value}`} />;
});
rootB.render(() => {
	rendersB += 1;
	return <label key="b" ref={labelB} fontName="sarasa-mono-sc-regular" fontSize={18} text={`B:${value.value}`} />;
});

expect(rendersA === 1 && rendersB === 1, "initial root render counts were wrong");
expect(labelA.current!.text === "A:0" && labelB.current!.text === "B:0", "initial signal text was wrong");

value.value = 1;
value.value = 2;
value.value = 3;

Director.systemScheduler.schedule(once(() => {
	expect(rendersA === 2 && rendersB === 2, "batched signal changes should schedule one update per root");
	expect(labelA.current!.text === "A:3" && labelB.current!.text === "B:3", "batched signal value was not rendered");

	rootB.unmount();
	value.value = 4;

	Director.systemScheduler.schedule(once(() => {
		expect(rendersA === 3, "mounted root did not update after second signal change");
		expect(rendersB === 2, "unmounted root should not re-render after signal change");
		expect(labelA.current!.text === "A:4", "mounted root label did not patch after second signal change");
		expect(!hostB.hasChildren, "unmounted root host still has children");
		rootA.unmount();
		hostA.removeFromParent(true);
		hostB.removeFromParent(true);
		Content.save(resultFile, "passed");
		Log("Info", "[DoraXSignalSchedulerTest] passed");
	}));
}));
