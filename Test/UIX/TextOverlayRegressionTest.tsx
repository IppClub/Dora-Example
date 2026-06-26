import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Modal, Tooltip } from "UIX";

const resultFile = Path(Content.writablePath, "UIXTextOverlayRegressionTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXTextOverlayRegressionTest] ${message}`);
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
const tooltipRef = reference<Dora.AlignNode.Type>();
const modalRef = reference<Dora.AlignNode.Type>();
const open = signal(true);
const closed = signal(0);

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Tooltip
			ref={tooltipRef}
			key="wrap-tooltip"
			title="UIX"
			text="Use tabs, toggles, slider, modal and cooldown buttons for testing."
			width={220}
			style={{ left: 18, bottom: 18 }}
		/>
	</align-node>
));

modalRoot.render(() => (
	<Modal
		ref={modalRef}
		key="overlay-modal"
		open={open.value}
		title="Overlay"
		message="Modal text and controls should render in the same nvg layer."
		width={300}
		height={196}
		onClose={() => {
			closed.value += 1;
			open.value = false;
		}}
	/>
));

Director.systemScheduler.schedule(once(() => {
	expect(tooltipRef.current !== undefined, "tooltip did not mount");
	expect(tooltipRef.current!.width === 220, "tooltip width changed unexpectedly");
	expect(tooltipRef.current!.height >= 88, "tooltip height is too small for wrapped text");
	expect(modalRef.current !== undefined, "modal did not mount");
	expect(modalRef.current!.width > 0 && modalRef.current!.height > 0, "modal root did not receive visual size");
	modalRef.current!.emit(Slot.Tapped);
	expect(closed.value === 1, "modal backdrop tap did not close");
	Director.systemScheduler.schedule(once(() => {
		expect(open.value === false, "modal signal did not close");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXTextOverlayRegressionTest] passed");
		host.removeFromParent(true);
		root.unmount();
		modalRoot.unmount();
		modalHost.removeFromParent(true);
	}));
}));
