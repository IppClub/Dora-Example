import { Content, Director, Log, Node as DNode, Path, Slot, Vec2, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Button, Column, Panel, Text } from "UIX";

const resultFile = Path(Content.writablePath, "UIXPanelScrollTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXPanelScrollTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const panelRef = reference<Dora.AlignNode.Type>();
const offset = signal(0);

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Panel
			ref={panelRef}
			title="Bag"
			padding={8}
			headerHeight={24}
			scroll
			scrollContentHeight={180}
			scrollWheelSpeed={20}
			onScroll={(value) => offset.value = value}
			style={{ width: 180, height: 120 }}
		>
			<Column key="panel-scroll-content" style={{ gap: 6, width: "100%" }}>
				<Text text="Inventory" style={{ width: 160, height: 28 }} />
				<Button key="a" style={{ width: 140, height: 36 }}>Loot</Button>
				<Button key="b" style={{ width: 140, height: 36 }}>Trade</Button>
				<Button key="c" style={{ width: 140, height: 36 }}>Drop</Button>
			</Column>
		</Panel>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(panelRef.current !== undefined, "panel did not mount");
	expect(panelRef.current!.children !== undefined && panelRef.current!.children!.count >= 3, "panel scroll child missing");
	const scrollNode = panelRef.current!.children!.get(3) as Dora.Node.Type;
	expect(scrollNode.children !== undefined && scrollNode.children!.count === 3, "panel scroll input layers missing");
	expect(scrollNode.width > 0 && scrollNode.height > 0, "panel scroll hit size was not synced");
	const inputOverlay = scrollNode.children!.get(2) as Dora.Node.Type;
	expect(inputOverlay.width > 0 && inputOverlay.height > 0, "panel scroll input overlay hit size was not synced");
	inputOverlay.emit(Slot.MouseWheel, Vec2(0, 1));
	Director.systemScheduler.schedule(once(() => {
		expect(offset.value === 20, "panel scroll did not forward wheel offset");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXPanelScrollTest] passed");
		host.removeFromParent(true);
		root.unmount();
	}));
}));
