import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal, useCallback, useMemo, useRef, useSignal } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXHookMemoTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXHookMemoTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const customRef = reference<Dora.Node.Type>();
const labelRef = reference<Dora.Label.Type>();
const tick = signal(0);
const spare = signal(0);
const dep = signal(1);
let creates = 0;
let memoBuilds = 0;
let stableRefObject: JSX.Ref<number> | undefined;
let localSignalObject: ReturnType<typeof useSignal<number>> | undefined;

const plainRef = reference(1);
expect(plainRef.current === 1, "reference should be available outside function components");

const [useRefOk] = pcall(() => useRef(1));
const [useSignalOk] = pcall(() => useSignal(1));
const [useMemoOk] = pcall(() => useMemo(() => 1, []));
const [useCallbackOk] = pcall(() => useCallback(() => 1, []));
expect(!useRefOk, "useRef should throw outside function components");
expect(!useSignalOk, "useSignal should throw outside function components");
expect(!useMemoOk, "useMemo should throw outside function components");
expect(!useCallbackOk, "useCallback should throw outside function components");

function StableCustom(this: void) {
	const localRef = useRef(3);
	const localSignal = useSignal(5);
	if (stableRefObject === undefined) {
		stableRefObject = localRef;
	}
	if (localSignalObject === undefined) {
		localSignalObject = localSignal;
	}
	if (spare.value === 1) {
		(localRef as unknown as { current: number }).current = 9;
		localSignal.value = 8;
	}
	const onCreate = useCallback(() => {
		creates += 1;
		return DNode();
	}, []);
	return <custom-node key="custom" ref={customRef} x={tick.value} onCreate={onCreate} />;
}

function MemoLabel(this: void) {
	const memo = useMemo(() => {
		memoBuilds += 1;
		return { text: `dep:${dep.value}` };
	}, [dep.value]);
	return (
		<label
			key="label"
			ref={labelRef}
			fontName="sarasa-mono-sc-regular"
			fontSize={18}
			text={`${memo.text};spare:${spare.value}`}
		/>
	);
}

root.render(() =>
	<node>
		<StableCustom />
		<MemoLabel />
	</node>
);

const customNode = customRef.current;
expect(customNode !== undefined, "custom node was not mounted");
expect(creates === 1, "custom node should be created once on mount");
expect(memoBuilds === 1, "memo should build once on mount");
expect(labelRef.current!.text === "dep:1;spare:0", "initial memo label text was wrong");

tick.value = 10;
spare.value = 1;

Director.systemScheduler.schedule(once(() => {
	expect(customRef.current === customNode, "stable useCallback should prevent custom-node recreation");
	expect(creates === 1, "stable custom onCreate should not run again");
	expect(customRef.current!.x === 10, "custom node prop should still patch after stable callback render");
	expect(stableRefObject !== undefined && stableRefObject.current === 9, "useRef should reuse the same ref object across renders");
	expect(localSignalObject !== undefined && localSignalObject.value === 8, "useSignal should reuse the same signal across renders");
	expect(memoBuilds === 1, "useMemo should not rebuild when deps are unchanged");
	expect(labelRef.current!.text === "dep:1;spare:1", "label should still patch with memoized value");

	dep.value = 2;

	Director.systemScheduler.schedule(once(() => {
		expect(memoBuilds === 2, "useMemo should rebuild when deps change");
		expect(labelRef.current!.text === "dep:2;spare:1", "label should render rebuilt memo value");
		root.unmount();
		expect(!host.hasChildren, "hook memo test unmount did not clear host");
		host.removeFromParent(true);
		Content.save(resultFile, "passed");
		Log("Info", "[DoraXHookMemoTest] passed");
	}));
}));
