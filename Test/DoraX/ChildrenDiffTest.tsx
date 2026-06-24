import { Content, Director, Log, Node as DNode, Path } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXChildrenDiffTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXChildrenDiffTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const aRef = useRef<Dora.Node.Type>();
const bRef = useRef<Dora.Node.Type>();
const cRef = useRef<Dora.Node.Type>();
const dRef = useRef<Dora.Node.Type>();

root.render(
	<node>
		<node key="a" ref={aRef} x={1} />
		<node key="b" ref={bRef} x={2} />
		<node key="c" ref={cRef} x={3} />
	</node>
);

const a = aRef.current;
const b = bRef.current;
const c = cRef.current;
expect(a !== undefined && b !== undefined && c !== undefined, "initial keyed children were not mounted");

root.render(
	<node>
		<node key="c" ref={cRef} x={30} />
		<node key="a" ref={aRef} x={10} />
		<node key="d" ref={dRef} x={40} />
	</node>
);

expect(cRef.current === c, "keyed child c should survive move to front");
expect(aRef.current === a, "keyed child a should survive move to middle");
expect(dRef.current !== undefined, "inserted keyed child d was not mounted");
expect(dRef.current !== b, "new key d must not reuse removed key b");
expect(cRef.current!.x === 30, "moved child c was not patched");
expect(aRef.current!.x === 10, "moved child a was not patched");
expect(dRef.current!.x === 40, "inserted child d prop was not applied");

const firstRef = useRef<Dora.Node.Type>();
const secondRef = useRef<Dora.Node.Type>();
root.render(
	<node>
		<node ref={firstRef} x={5} />
		<node ref={secondRef} x={6} />
	</node>
);
const first = firstRef.current;
const second = secondRef.current;
expect(first !== undefined && second !== undefined, "initial unkeyed children were not mounted");

root.render(
	<node>
		<node ref={firstRef} x={50} />
		<node ref={secondRef} x={60} />
	</node>
);
expect(firstRef.current === first, "first unkeyed child should be reused by index");
expect(secondRef.current === second, "second unkeyed child should be reused by index");
expect(firstRef.current!.x === 50, "first unkeyed child prop was not patched");
expect(secondRef.current!.x === 60, "second unkeyed child prop was not patched");

root.render([
	<node key="multi-a" ref={aRef} x={7} />,
	<node key="multi-b" ref={bRef} x={8} />,
]);
expect(host.hasChildren, "multi-root render did not mount children");
expect(aRef.current !== undefined && bRef.current !== undefined, "multi-root children refs were not assigned");

root.unmount();
expect(!host.hasChildren, "unmount did not remove diffed children");
host.removeFromParent(true);
Content.save(resultFile, "passed");
Log("Info", "[DoraXChildrenDiffTest] passed");
