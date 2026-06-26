import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Modal, ToastStack, Tooltip } from "UIX";

const resultFile = Path(Content.writablePath, "UIXOverlayComponentsTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXOverlayComponentsTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const modalHost = DNode();
Director.ui.addChild(modalHost, 10000);
const root = createRoot(host);
const modalRoot = createRoot(modalHost);
const modalOpen = signal(true);
const closeCount = signal(0);
const modalRef = reference<Dora.AlignNode.Type>();
const toastRef = reference<Dora.AlignNode.Type>();
const tooltipRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Tooltip
			ref={tooltipRef}
			title="Skill"
			text="Deals damage and starts cooldown."
			style={{ left: 16, top: 16 }}
		/>
		<ToastStack
			ref={toastRef}
			items={[
				{ id: "a", title: "Loot", message: "Coins +75" },
				{ id: "b", message: "Shield ready" },
			]}
			style={{ right: 16, top: 16 }}
		/>
	</align-node>
));

modalRoot.render(() => (
	<Modal
		ref={modalRef}
		open={modalOpen.value}
		title="Confirm"
		message="Close this modal?"
		onClose={() => {
			closeCount.value += 1;
			modalOpen.value = false;
		}}
	/>
));

Director.systemScheduler.schedule(once(() => {
	expect(tooltipRef.current !== undefined, "tooltip did not mount");
	expect(toastRef.current !== undefined, "toast stack did not mount");
	expect(toastRef.current!.children !== undefined && toastRef.current!.children!.count === 2, "toast stack did not render two items");
	expect(modalRef.current !== undefined, "modal did not mount");
	modalRef.current!.emit(Slot.Tapped);
	expect(closeCount.value === 1, "modal backdrop did not invoke onClose");
	Director.systemScheduler.schedule(once(() => {
		expect(modalOpen.value === false, "modal open signal did not update");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXOverlayComponentsTest] passed");
		host.removeFromParent(true);
		root.unmount();
		modalRoot.unmount();
		modalHost.removeFromParent(true);
	}));
}));
