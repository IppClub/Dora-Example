import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXSignalDependencyTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXSignalDependencyTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const hostA = DNode();
const hostB = DNode();
const hostStatic = DNode();
Director.entry.addChild(hostA);
Director.entry.addChild(hostB);
Director.entry.addChild(hostStatic);

const rootA = createRoot(hostA);
const rootB = createRoot(hostB);
const rootStatic = createRoot(hostStatic);
const signalA = signal(0);
const signalB = signal(0);
const labelA = reference<Dora.Label.Type>();
const labelB = reference<Dora.Label.Type>();
const labelStatic = reference<Dora.Label.Type>();
let rendersA = 0;
let rendersB = 0;
let rendersStatic = 0;

rootA.render(() => {
	rendersA += 1;
	return <label ref={labelA} fontName="sarasa-mono-sc-regular" fontSize={18} text={`A:${signalA.value}`} />;
});
rootB.render(() => {
	rendersB += 1;
	return <label ref={labelB} fontName="sarasa-mono-sc-regular" fontSize={18} text={`B:${signalB.value}`} />;
});
rootStatic.render(() => {
	rendersStatic += 1;
	return <label ref={labelStatic} fontName="sarasa-mono-sc-regular" fontSize={18} text="static" />;
});

expect(rendersA === 1 && rendersB === 1 && rendersStatic === 1, "initial render counts were wrong");

signalA.value = 1;

Director.systemScheduler.schedule(once(() => {
	expect(rendersA === 2, "signalA should update rootA");
	expect(rendersB === 1, "signalA should not update rootB");
	expect(rendersStatic === 1, "signalA should not update a root that reads no signal");
	expect(labelA.current!.text === "A:1", "rootA did not patch signalA value");
	expect(labelB.current!.text === "B:0", "rootB text changed unexpectedly");

	signalB.value = 2;
	signalB.value = 3;

	Director.systemScheduler.schedule(once(() => {
		expect(rendersA === 2, "signalB should not update rootA");
		expect(rendersB === 2, "batched signalB changes should update rootB once");
		expect(rendersStatic === 1, "signalB should not update static root");
		expect(labelB.current!.text === "B:3", "rootB did not render latest signalB value");

		rootA.unmount();
		rootB.unmount();
		rootStatic.unmount();
		hostA.removeFromParent(true);
		hostB.removeFromParent(true);
		hostStatic.removeFromParent(true);
		Content.save(resultFile, "passed");
		Log("Info", "[DoraXSignalDependencyTest] passed");
	}));
}));
