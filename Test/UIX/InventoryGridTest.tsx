import { Content, Director, Log, Node as DNode, Path, Slot, Vec2, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { InventoryGrid } from "UIX";
import type { InventoryItem } from "UIX";

const resultFile = Path(Content.writablePath, "UIXInventoryGridTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXInventoryGridTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const selected = signal("sword");
const items = signal<InventoryItem[]>([
	{ id: "sword", icon: "warning", quality: "rare" },
	{ id: "potion", icon: "heart", quality: "common", count: 3 },
	{ id: "gem", icon: "mana", quality: "epic", count: 2 },
]);
const gridRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<InventoryGrid
			ref={gridRef}
			items={items.value}
			columns={3}
			rows={2}
			slotSize={42}
			gap={6}
			selectedId={selected.value}
			onSelect={(id) => selected.value = id}
		/>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(gridRef.current !== undefined, "grid did not mount");
	expect(gridRef.current!.children !== undefined && gridRef.current!.children!.count === 2, "grid did not render two rows");
	const firstRow = gridRef.current!.children!.get(1) as Dora.Node.Type;
	expect(firstRow.children !== undefined && firstRow.children!.count === 3, "grid first row did not render three slots");
	const potionSlot = firstRow.children!.get(2) as Dora.Node.Type;
	potionSlot.emit(Slot.TapBegan);
	potionSlot.emit(Slot.TapMoved, { delta: Vec2(0, 12) } as Dora.Touch.Type);
	potionSlot.emit(Slot.Tapped);
	expect(selected.value === "sword", "dragged slot should not select item");
	potionSlot.emit(Slot.TapBegan);
	potionSlot.emit(Slot.Tapped);
	expect(selected.value === "potion", "slot tap did not select item");
	items.value = [
		{ id: "potion", icon: "heart", quality: "common", count: 4 },
		{ id: "gem", icon: "mana", quality: "epic", count: 2 },
		{ id: "coin", icon: "coin", quality: "legendary", count: 9 },
	];
	Director.systemScheduler.schedule(once(() => {
		expect(selected.value === "potion", "selected id should survive item reorder");
		expect(gridRef.current!.children !== undefined && gridRef.current!.children!.count === 2, "grid row count changed after reorder");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXInventoryGridTest] passed");
		host.removeFromParent(true);
		root.unmount();
	}));
}));
