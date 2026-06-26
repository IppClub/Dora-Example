import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import { React, createRoot, signal } from "DoraX";
import { PaintNode, UiProvider } from "UIX";

const resultFile = Path(Content.writablePath, "UIXUnmountCleanupTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXUnmountCleanupTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const width = signal(80);
let renderPasses = 0;
let mountCount = 0;

root.render(() => {
	renderPasses += 1;
	return (
		<UiProvider>
			<align-node windowRoot style={{ padding: 8 }}>
				<align-node style={{ width: width.value, height: 40 }}>
					<PaintNode
						onMountNode={() => {
							mountCount += 1;
						}}
						painter={() => {}}
					/>
				</align-node>
			</align-node>
		</UiProvider>
	);
});

Director.systemScheduler.schedule(once(() => {
	expect(mountCount === 1, `paint node did not mount once; mountCount=${mountCount}`);
	root.unmount();
	expect(!host.hasChildren, "root unmount did not remove host children");
	const before = renderPasses;
	width.value = 180;
	Director.systemScheduler.schedule(once(() => {
		expect(renderPasses === before, "signal rerendered after root unmount");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXUnmountCleanupTest] passed");
		host.removeFromParent(true);
	}));
}));
