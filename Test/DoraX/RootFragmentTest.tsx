import { Content, Director, Log, Node as DNode, Path } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, toNode, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXRootFragmentTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXRootFragmentTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const staticLabelRef = useRef<Dora.Label.Type>();
const staticNode = toNode(
	<>
		<label ref={staticLabelRef} fontName="sarasa-mono-sc-regular" fontSize={18}>static</label>
		<node x={12} />
	</>
);
expect(staticNode !== undefined, "toNode fragment did not create a wrapper node");
expect(staticNode!.hasChildren, "toNode fragment wrapper did not receive children");
expect(staticLabelRef.current !== undefined, "toNode did not assign label ref");
expect(staticLabelRef.current!.text === "static", "toNode did not preserve primitive label text");
staticNode!.removeFromParent(true);

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const aRef = useRef<Dora.Node.Type>();
const bRef = useRef<Dora.Node.Type>();

root.render(
	<>
		<node key="a" ref={aRef} x={1} />
		<node key="b" ref={bRef} x={2} />
	</>
);
const a = aRef.current;
const b = bRef.current;
expect(a !== undefined && b !== undefined, "root fragment children were not mounted");
expect(host.hasChildren, "root fragment did not add children to host");

root.render(<node key="a" ref={aRef} x={3} />);
expect(aRef.current === a, "root should reuse keyed child when fragment becomes single node");
expect(aRef.current!.x === 3, "single-node render did not patch reused child");
expect(bRef.current === undefined, "removed child ref should be cleared");

root.render([]);
expect(!host.hasChildren, "empty root render did not remove all children");

root.unmount();
host.removeFromParent(true);
Content.save(resultFile, "passed");
Log("Info", "[DoraXRootFragmentTest] passed");
