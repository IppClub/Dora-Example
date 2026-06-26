import { Content, Director, Log, Node as DNode, Path, Slot, Vec2, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Column, ScrollView, Text } from "UIX";

const resultFile = Path(Content.writablePath, "UIXScrollViewTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXScrollViewTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const scrollRef = reference<Dora.AlignNode.Type>();
const offset = signal(0);
const rerenderTick = signal(0);

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Text text={`Tick ${rerenderTick.value}`} style={{ width: 100, height: 24 }} />
		<ScrollView
			ref={scrollRef}
			width={160}
			height={64}
			contentHeight={168}
			wheelSpeed={20}
			onScroll={(value) => offset.value = value}
		>
			<Column style={{ gap: 4, width: 160 }}>
				<Text text="Row A" style={{ width: 150, height: 28 }} />
				<Text text="Row B" style={{ width: 150, height: 28 }} />
				<Text text="Row C" style={{ width: 150, height: 28 }} />
				<Text text="Row D" style={{ width: 150, height: 28 }} />
				<Text text="Row E" style={{ width: 150, height: 28 }} />
			</Column>
		</ScrollView>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(scrollRef.current !== undefined, "scroll view did not mount");
	expect(scrollRef.current!.children !== undefined && scrollRef.current!.children!.count === 3, "scroll content or input layers missing");
	expect(scrollRef.current!.width === 160 && scrollRef.current!.height === 64, "scroll view hit size was not synced");
	const originalScrollNode = scrollRef.current!;
	let contentNode = scrollRef.current!.children!.get(1) as Dora.Node.Type;
	let inputOverlay = scrollRef.current!.children!.get(2) as Dora.Node.Type;
	expect(inputOverlay.width === 160 && inputOverlay.height === 64, "scroll input overlay hit size was not synced");
	inputOverlay.emit(Slot.MouseWheel, Vec2(0, 1));
	Director.systemScheduler.schedule(once(() => {
		expect(offset.value === 20, "mouse wheel did not update scroll offset");
		contentNode = scrollRef.current!.children!.get(1) as Dora.Node.Type;
		expect(contentNode.y === 20, "scroll content y did not follow offset direction");
		inputOverlay = scrollRef.current!.children!.get(2) as Dora.Node.Type;
		inputOverlay.emit(Slot.MouseWheel, Vec2(0, 100));
		Director.systemScheduler.schedule(once(() => {
			expect(offset.value === 104, "scroll offset did not clamp to max");
			const dragCapture = scrollRef.current!.children!.get(3) as Dora.Node.Type;
			expect(dragCapture.width === 160 && dragCapture.height === 64, "scroll drag capture hit size was not synced");
			expect(dragCapture.swallowTouches === false, "scroll drag capture should not swallow button taps by default");
			const touch = { first: true, enabled: true, location: Vec2(40, 48), delta: Vec2(0, -30) } as Dora.Touch.Type;
			dragCapture.emit(Slot.TapFilter, touch);
			expect(touch.enabled === true, "drag touch was rejected inside scroll view");
			dragCapture.emit(Slot.TapMoved, touch);
			Director.systemScheduler.schedule(once(() => {
				expect(offset.value === 74, "tap drag did not update scroll offset");
				contentNode = scrollRef.current!.children!.get(1) as Dora.Node.Type;
				expect(contentNode.y === 74, "scroll content y did not follow tap drag");
				rerenderTick.value += 1;
				Director.systemScheduler.schedule(once(() => {
					expect(scrollRef.current === originalScrollNode, "scroll view node was recreated by parent rerender");
					expect(offset.value === 74, "scroll offset changed after parent rerender");
					contentNode = scrollRef.current!.children!.get(1) as Dora.Node.Type;
					expect(contentNode.y === 74, "scroll content y changed after parent rerender");
					Content.save(resultFile, "passed");
					Log("Info", "[UIXScrollViewTest] passed");
					host.removeFromParent(true);
					root.unmount();
				}));
			}));
		}));
	}));
}));
