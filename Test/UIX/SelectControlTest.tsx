import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { ScrollView, Select } from "UIX";

const resultFile = Path(Content.writablePath, "UIXSelectControlTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXSelectControlTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const selected = signal("normal");
const open = signal(false);
const selectRef = reference<Dora.AlignNode.Type>();
const scrollRef = reference<Dora.AlignNode.Type>();
let mountedScroll: Dora.AlignNode.Type | undefined;

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<ScrollView key="select-scroll" ref={scrollRef} width={220} height={96} contentHeight={open.value ? 220 : 116}>
			<Select
				ref={selectRef}
				value={selected.value}
				open={open.value}
				items={[
					{ id: "story", label: "Story", icon: "heart" },
					{ id: "normal", label: "Normal", icon: "check" },
					{ id: "hard", label: "Hard", icon: "warning" },
					{ id: "locked", label: "Locked", icon: "lock", disabled: true },
				]}
				onOpenChange={(value) => open.value = value}
				onValueChange={(value) => selected.value = value}
				style={{ width: 180 }}
			/>
		</ScrollView>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(scrollRef.current !== undefined, "scroll ref missing");
	mountedScroll = scrollRef.current;
	expect(selectRef.current !== undefined, "select ref missing");
	expect(selectRef.current!.children !== undefined && selectRef.current!.children!.count === 1, "closed select should only render trigger");
	const trigger = selectRef.current!.children!.get(1) as Dora.Node.Type;
	trigger.emit(Slot.Tapped);
	Director.systemScheduler.schedule(once(() => {
		expect(scrollRef.current === mountedScroll, "scroll view remounted after opening select");
		expect(open.value === true, "trigger did not open select");
		expect(selectRef.current!.children !== undefined && selectRef.current!.children!.count === 2, "open select did not render menu");
		const menu = selectRef.current!.children!.get(2) as Dora.Node.Type;
		expect(menu.children !== undefined && menu.children!.count === 5, "menu should render surface plus four items");
		const hard = menu.children!.get(4) as Dora.Node.Type;
		hard.emit(Slot.Tapped);
		Director.systemScheduler.schedule(once(() => {
			expect(scrollRef.current === mountedScroll, "scroll view remounted after selecting item");
			expect(selected.value === "hard", "select item did not update value");
			expect(open.value === false, "select did not close after item click");
			open.value = true;
			Director.systemScheduler.schedule(once(() => {
				expect(scrollRef.current === mountedScroll, "scroll view remounted after reopening select");
				const reopenedMenu = selectRef.current!.children!.get(2) as Dora.Node.Type;
				const locked = reopenedMenu.children!.get(5) as Dora.Node.Type;
				locked.emit(Slot.Tapped);
				Director.systemScheduler.schedule(once(() => {
					expect(selected.value === "hard", "disabled select item should not update value");
					Content.save(resultFile, "passed");
					Log("Info", "[UIXSelectControlTest] passed");
					host.removeFromParent(true);
					root.unmount();
				}));
			}));
		}));
	}));
}));
