import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, signal, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXRootUnmountTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXRootUnmountTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const value = signal(0);
const labelRef = useRef<Dora.Label.Type>();
let renders = 0;

root.render(() => {
	renders += 1;
	return <label ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text={`value:${value.value}`} />;
});

expect(renders === 1, "initial render count was wrong");
expect(host.hasChildren, "initial root render did not mount child");

root.unmount();
expect(!host.hasChildren, "unmount should remove root children");

value.value = 1;

Director.systemScheduler.schedule(once(() => {
	expect(renders === 1, "unmounted root should not update after signal change");

	root.render(() => {
		renders += 1;
		return <label ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text={`value:${value.value}`} />;
	});
	expect(renders === 2, "unmounted root should be renderable again");
	expect(labelRef.current!.text === "value:1", "rerendered root did not read latest signal value");

	value.value = 2;

	Director.systemScheduler.schedule(once(() => {
		expect(renders === 3, "rerendered root should subscribe to signal again");
		expect(labelRef.current!.text === "value:2", "rerendered root did not patch signal value");
		root.unmount();
		host.removeFromParent(true);
		Content.save(resultFile, "passed");
		Log("Info", "[DoraXRootUnmountTest] passed");
	}));
}));
