import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { UiProvider } from "UIX";

const resultFile = Path(Content.writablePath, "UIXLayoutPatchTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXLayoutPatchTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const wide = signal(false);
const panelRef = reference<Dora.AlignNode.Type>();
let layoutCount = 0;
let renderCount = 0;

function pass(this: void) {
	Content.save(resultFile, "passed");
	Log("Info", "[UIXLayoutPatchTest] passed");
	host.removeFromParent(true);
	root.unmount();
}

function waitForPatch(this: void, framesLeft: number, firstNode: Dora.AlignNode.Type) {
	expect(panelRef.current !== undefined, "panel ref missing");
	if (renderCount >= 2) {
		expect(renderCount >= 2, `root did not rerender after signal; renderCount=${renderCount}`);
		expect(panelRef.current === firstNode, "style patch rebuilt align-node instead of patching it");
		pass();
		return;
	}
	if (framesLeft <= 0) {
		fail(`root did not rerender after signal; renderCount=${renderCount}; layoutCount=${layoutCount}`);
	}
	Director.systemScheduler.schedule(once(() => waitForPatch(framesLeft - 1, firstNode)));
}

root.render(() => {
	renderCount += 1;
		return (
			<UiProvider>
				<align-node windowRoot style={{ padding: 8 }}>
					<align-node
						ref={panelRef}
						style={{ width: wide.value ? 420 : 220, height: 120 }}
						onLayout={() => {
							layoutCount += 1;
						}}
					/>
				</align-node>
			</UiProvider>
		);
});

Director.systemScheduler.schedule(once(() => {
	expect(panelRef.current !== undefined, "panel ref missing before patch");
	const firstNode = panelRef.current!;
	wide.value = true;
	Director.systemScheduler.schedule(once(() => waitForPatch(8, firstNode)));
}));
