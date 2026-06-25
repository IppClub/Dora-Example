import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal, useCallback, useRef, useSignal } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXHookKeyedDiffTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXHookKeyedDiffTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

function expectSameNode(this: void, id: number, node: Dora.Node.Type | undefined, message: string) {
	expect(node !== undefined, `${message} missing baseline node ${id}`);
	expect(itemRefs.get(id)!.current === node, message);
}

function expectHostOrder(this: void, expected: number[], message: string) {
	const children = host.children;
	expect(children !== undefined, `${message} missing host children`);
	expect(children!.count === expected.length, `${message} child count mismatch`);
	for (let i of $range(1, expected.length)) {
		const child = children!.get(i) as Dora.Node.Type;
		expect(child.tag === `item-${expected[i - 1]}`, `${message} child ${i} expected item-${expected[i - 1]}, got ${child.tag}`);
	}
}

function nextFrame(this: void, callback: (this: void) => void) {
	Director.systemScheduler.schedule(once(callback));
}

const host = DNode();
Director.entry.addChild(host);

type Kind = "a" | "b";
interface ItemData {
	id: number;
	kind: Kind;
}

const root = createRoot(host);
const items = signal<ItemData[]>([
	{ id: 1, kind: "a" },
	{ id: 2, kind: "a" },
	{ id: 3, kind: "a" },
	{ id: 4, kind: "a" },
]);
const itemRefs: LuaTable<number, JSX.Ref<Dora.Node.Type>> = new LuaTable();
const itemNodes: LuaTable<number, Dora.Node.Type> = new LuaTable();
const nestedNodes: LuaTable<number, Dora.Node.Type> = new LuaTable();
const localRefs: LuaTable<number, JSX.Ref<number>> = new LuaTable();
const localSignals: LuaTable<number, ReturnType<typeof useSignal<number>>> = new LuaTable();
const createCounts: LuaTable<number, number> = new LuaTable();
const nestedCreateCounts: LuaTable<number, number> = new LuaTable();
const unmountCounts: LuaTable<number, number> = new LuaTable();

function getItemRef(this: void, id: number): JSX.Ref<Dora.Node.Type> {
	let ref = itemRefs.get(id);
	if (ref === undefined) {
		ref = reference<Dora.Node.Type>();
		itemRefs.set(id, ref);
	}
	return ref;
}

function countFor(this: void, table: LuaTable<number, number>, id: number): number {
	return table.get(id) ?? 0;
}

function ItemA(this: void, props: { key?: number; id: number }) {
	const { id } = props;
	const localRef = useRef(id);
	const localSignal = useSignal(id * 10);
	if (localRefs.get(id) === undefined) {
		localRefs.set(id, localRef);
	}
	if (localSignals.get(id) === undefined) {
		localSignals.set(id, localSignal);
	}
	const onCreate = useCallback(() => {
		createCounts.set(id, countFor(createCounts, id) + 1);
		return DNode();
	}, [id]);
	const onMount = useCallback((node: Dora.Node.Type) => {
		itemNodes.set(id, node);
	}, [id]);
	const onUnmount = useCallback(() => {
		unmountCounts.set(id, countFor(unmountCounts, id) + 1);
	}, [id]);
	return (
		<custom-node
			key={id}
			ref={getItemRef(id)}
			tag={`item-${id}`}
			x={id}
			onCreate={onCreate}
			onMount={onMount}
			onUnmount={onUnmount}
		>
			<NestedItem key={id} id={id} />
		</custom-node>
	);
}

function ItemB(this: void, props: { key?: number; id: number }) {
	const { id } = props;
	const onCreate = useCallback(() => {
		createCounts.set(id, countFor(createCounts, id) + 1);
		return DNode();
	}, [id]);
	const onMount = useCallback((node: Dora.Node.Type) => {
		itemNodes.set(id, node);
	}, [id]);
	return <custom-node key={id} ref={getItemRef(id)} tag={`item-${id}`} x={id * 10} onCreate={onCreate} onMount={onMount} />;
}

function NestedItem(this: void, props: { key?: number; id: number }) {
	const { id } = props;
	const onCreate = useCallback(() => {
		nestedCreateCounts.set(id, countFor(nestedCreateCounts, id) + 1);
		return DNode();
	}, [id]);
	const onMount = useCallback((node: Dora.Node.Type) => {
		nestedNodes.set(id, node);
	}, [id]);
	return <custom-node key={id} onCreate={onCreate} onMount={onMount} />;
}

function renderItems(this: void) {
	const elements: React.Element[] = [];
	for (let i of $range(1, items.value.length)) {
		const item = items.value[i - 1];
		if (item.kind === "a") {
			elements.push(<ItemA key={item.id} id={item.id} />);
		} else {
			elements.push(<ItemB key={item.id} id={item.id} />);
		}
	}
	return elements;
}

root.render(renderItems);

const node1 = itemRefs.get(1)!.current;
const node2 = itemRefs.get(2)!.current;
const node3 = itemRefs.get(3)!.current;
const node4 = itemRefs.get(4)!.current;
const nested1 = nestedNodes.get(1);
const nested3 = nestedNodes.get(3);
const ref1 = localRefs.get(1);
const ref3 = localRefs.get(3);
const signal1 = localSignals.get(1);
const signal3 = localSignals.get(3);
expect(node1 !== undefined && node2 !== undefined && node3 !== undefined && node4 !== undefined, "initial keyed nodes were not mounted");
expect(nested1 !== undefined && nested3 !== undefined, "initial nested keyed nodes were not mounted");
expect(createCounts.get(1) === 1 && createCounts.get(4) === 1, "initial items should be created once");
expect(nestedCreateCounts.get(1) === 1 && nestedCreateCounts.get(3) === 1, "initial nested items should be created once");
expectHostOrder([1, 2, 3, 4], "initial host children order");

items.value = [
	{ id: 4, kind: "a" },
	{ id: 2, kind: "a" },
	{ id: 1, kind: "a" },
	{ id: 3, kind: "a" },
];

nextFrame(() => {
	expectSameNode(1, node1, "reordered keyed item 1 should keep node");
	expectSameNode(2, node2, "reordered keyed item 2 should keep node");
	expectSameNode(3, node3, "reordered keyed item 3 should keep node");
	expectSameNode(4, node4, "reordered keyed item 4 should keep node");
	expect(nestedNodes.get(1) === nested1, "nested keyed child should keep node after parent reorder");
	expect(localRefs.get(1) === ref1 && localSignals.get(1) === signal1, "useRef/useSignal should follow reordered key 1");
	expect(localRefs.get(3) === ref3 && localSignals.get(3) === signal3, "useRef/useSignal should follow reordered key 3");
	expect(createCounts.get(1) === 1 && createCounts.get(4) === 1, "reorder should not recreate keyed items");
	expect(nestedCreateCounts.get(1) === 1 && nestedCreateCounts.get(3) === 1, "reorder should not recreate nested keyed items");
	expectHostOrder([4, 2, 1, 3], "reordered host children order");

	items.value = [
		{ id: 4, kind: "a" },
		{ id: 2, kind: "a" },
		{ id: 5, kind: "a" },
		{ id: 1, kind: "a" },
		{ id: 3, kind: "a" },
	];

	nextFrame(() => {
		const node5 = itemRefs.get(5)!.current;
		expectSameNode(1, node1, "insert before keyed item 1 should keep node");
		expectSameNode(3, node3, "insert before keyed item 3 should keep node");
		expectSameNode(4, node4, "insert should keep earlier keyed item 4");
		expect(node5 !== undefined, "inserted keyed item 5 was not mounted");
		expect(createCounts.get(5) === 1, "inserted keyed item 5 should be created once");
		expect(createCounts.get(1) === 1 && createCounts.get(3) === 1, "insert should not recreate following keyed items");
		expectHostOrder([4, 2, 5, 1, 3], "inserted host children order");

		items.value = [
			{ id: 4, kind: "a" },
			{ id: 1, kind: "a" },
			{ id: 6, kind: "a" },
			{ id: 3, kind: "a" },
		];

		nextFrame(() => {
			const node6 = itemRefs.get(6)!.current;
			expectSameNode(1, node1, "delete insert reorder should keep keyed item 1");
			expectSameNode(3, node3, "delete insert reorder should keep keyed item 3");
			expectSameNode(4, node4, "delete insert reorder should keep keyed item 4");
			expect(node6 !== undefined, "mixed update inserted keyed item 6 was not mounted");
			expect(itemRefs.get(2)!.current === undefined, "removed keyed item 2 ref should be cleared");
			expect(itemRefs.get(5)!.current === undefined, "removed keyed item 5 ref should be cleared");
			expect(unmountCounts.get(2) === 1, "removed keyed item 2 should unmount once");
			expect(createCounts.get(1) === 1 && createCounts.get(3) === 1 && createCounts.get(4) === 1, "mixed update should not recreate kept keyed items");
			expectHostOrder([4, 1, 6, 3], "mixed update host children order");

			items.value = [
				{ id: 4, kind: "a" },
				{ id: 1, kind: "b" },
				{ id: 6, kind: "a" },
				{ id: 3, kind: "a" },
			];

			nextFrame(() => {
				expect(itemRefs.get(1)!.current !== node1, "same key with different component type should recreate item 1");
				expect(createCounts.get(1) === 2, "type change should create item 1 again");
				expectSameNode(3, node3, "type change of sibling should keep keyed item 3");
				expectSameNode(4, node4, "type change of sibling should keep keyed item 4");
				expectHostOrder([4, 1, 6, 3], "type change host children order");
				root.unmount();
				expect(!host.hasChildren, "hook keyed diff test unmount did not clear host");
				host.removeFromParent(true);
				Content.save(resultFile, "passed");
				Log("Info", "[DoraXHookKeyedDiffTest] passed");
			});
		});
	});
});
