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
const keyedItems = signal([1, 2, 3, 4]);
let creates = 0;
let memoBuilds = 0;
let keyedCreates = 0;
let stableRefObject: JSX.Ref<number> | undefined;
let localSignalObject: ReturnType<typeof useSignal<number>> | undefined;
const keyedNodes: LuaTable<number, Dora.Node.Type> = new LuaTable();
const keyedCreateCounts: LuaTable<number, number> = new LuaTable();

const plainRef = reference(1);
expect(plainRef.current === 1, "reference should be available outside function components");

const [useRefOk, outsideRef] = pcall(() => useRef(1));
const [useSignalOk] = pcall(() => useSignal(1));
const [useMemoOk] = pcall(() => useMemo(() => 1, []));
const [useCallbackOk] = pcall(() => useCallback(() => 1, []));
expect(useRefOk && outsideRef.current === 1, "useRef should fall back to reference outside function components");
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

function KeyedCustom(this: void, props: { key?: number; id: number }) {
	const { id } = props;
	const onCreate = useCallback(() => {
		keyedCreates += 1;
		keyedCreateCounts.set(id, (keyedCreateCounts.get(id) ?? 0) + 1);
		return DNode();
	}, [id]);
	const onMount = useCallback((node: Dora.Node.Type) => {
		keyedNodes.set(id, node);
	}, [id]);
	return (
		<custom-node
			key={id}
			x={spare.value}
			onCreate={onCreate}
			onMount={onMount}
		/>
	);
}

function renderKeyedItems(this: void) {
	const elements: React.Element[] = [
		<StableCustom key="stable" />,
		<MemoLabel key="memo" />,
	];
	for (let i of $range(1, keyedItems.value.length)) {
		const id = keyedItems.value[i - 1];
		elements.push(<KeyedCustom key={id} id={id} />);
	}
	return elements;
}

root.render(renderKeyedItems);

const customNode = customRef.current;
const keyedNode3 = keyedNodes.get(3);
const keyedNode4 = keyedNodes.get(4);
expect(customNode !== undefined, "custom node was not mounted");
expect(keyedNode3 !== undefined && keyedNode4 !== undefined, "initial keyed custom nodes were not mounted");
expect(creates === 1, "custom node should be created once on mount");
expect(keyedCreates === 4, "keyed custom nodes should be created once on mount");
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

	keyedItems.value = [1, 3, 4];

	Director.systemScheduler.schedule(once(() => {
		expect(keyedNodes.get(3) === keyedNode3, "keyed function component after deletion should keep node 3");
		expect(keyedNodes.get(4) === keyedNode4, "keyed function component after deletion should keep node 4");
		expect(keyedCreates === 4, "deleting a keyed function component should not recreate following items");
		expect(keyedCreateCounts.get(3) === 1, "keyed function component 3 should keep its hook callback");
		expect(keyedCreateCounts.get(4) === 1, "keyed function component 4 should keep its hook callback");

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
}));
