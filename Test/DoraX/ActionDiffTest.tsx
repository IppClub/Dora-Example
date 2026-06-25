import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import * as Dora from "Dora";
import { React, createRoot, signal, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXActionDiffTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXActionDiffTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

function afterFrames(this: void, frames: number, callback: (this: void) => void) {
	if (frames <= 0) {
		callback();
		return;
	}
	Director.systemScheduler.schedule(once(() => {
		afterFrames(frames - 1, callback);
	}));
}

const host = DNode();
const exclusiveHost = DNode();
const loopHost = DNode();
const multiHost = DNode();
const conflictHost = DNode();
Director.entry.addChild(host);
Director.entry.addChild(exclusiveHost);
Director.entry.addChild(loopHost);
Director.entry.addChild(multiHost);
Director.entry.addChild(conflictHost);

const root = createRoot(host);
const exclusiveRoot = createRoot(exclusiveHost);
const loopRoot = createRoot(loopHost);
const multiRoot = createRoot(multiHost);
const conflictRoot = createRoot(conflictHost);
const nodeRef = useRef<Dora.Node.Type>();
const exclusiveRef = useRef<Dora.Node.Type>();
const loopRef = useRef<Dora.Node.Type>();
const multiRef = useRef<Dora.Node.Type>();
const conflictRef = useRef<Dora.Node.Type>();
const nodeY = signal(0);
const actionStop = signal(10);
const exclusiveStop = signal(100);
const loopStop = signal(40);
const multiStop = signal(30);
let actionEnds = 0;
let exclusiveEnds = 0;
let warningCount = 0;

const doraRuntime = Dora as unknown as {
	Log(this: void, level: "Info" | "Warn" | "Error", msg: string): void;
};
const originalLog = doraRuntime.Log;

root.render(() =>
	<node
		key="animated"
		ref={nodeRef}
		y={nodeY.value}
		onActionEnd={() => {
			actionEnds += 1;
		}}
	>
		<move-x time={0.01} start={0} stop={actionStop.value} />
	</node>
);

const node = nodeRef.current;
expect(node !== undefined, "animated node was not mounted");

exclusiveRoot.render(() =>
	<node
		key="exclusive"
		ref={exclusiveRef}
		onActionEnd={() => {
			exclusiveEnds += 1;
		}}
	>
		<move-x
			exclusive
			time={exclusiveStop.value === 100 ? 0.5 : 0.01}
			start={0}
			stop={exclusiveStop.value}
		/>
	</node>
);

const exclusiveNode = exclusiveRef.current;
expect(exclusiveNode !== undefined, "exclusive animated node was not mounted");

loopRoot.render(() =>
	<node key="loop-exclusive" ref={loopRef}>
		<loop exclusive>
			<move-x time={0.01} start={0} stop={loopStop.value} />
			<delay time={0.01} />
		</loop>
	</node>
);

const loopNode = loopRef.current;
expect(loopNode !== undefined, "loop exclusive node was not mounted");

multiRoot.render(() =>
	<node key="multi-exclusive" ref={multiRef}>
		<move-x exclusive time={0.01} start={0} stop={multiStop.value} />
		<move-y exclusive time={0.01} start={0} stop={-multiStop.value} />
	</node>
);

const multiNode = multiRef.current;
expect(multiNode !== undefined, "multi exclusive node was not mounted");

doraRuntime.Log = (level, msg) => {
	if (level === "Warn" && string.find(msg, "exclusive action children") !== undefined) {
		warningCount += 1;
		return;
	}
	originalLog(level, msg);
};

conflictRoot.render(
	<node key="conflict" ref={conflictRef}>
		<loop exclusive>
			<move-x time={0.01} start={0} stop={25} />
			<delay time={0.01} />
		</loop>
		<move-y exclusive time={0.01} start={0} stop={25} />
	</node>
);

const conflictNode = conflictRef.current;
expect(conflictNode !== undefined, "conflict exclusive node was not mounted");
doraRuntime.Log = originalLog;

afterFrames(8, () => {
	expect(actionEnds === 1, "initial action child should run on mount");
	expect(nodeRef.current === node, "initial action should keep mounted node");
	expect(nodeRef.current!.x === 10, "initial action did not apply final x");
	expect(loopRef.current === loopNode, "loop exclusive should keep mounted node");
	expect(loopRef.current!.x === 40, "loop exclusive should run on mount");
	expect(multiRef.current === multiNode, "multi exclusive should keep mounted node");
	expect(multiRef.current!.x === 30 && multiRef.current!.y === -30, "multiple exclusive action children should run as a spawn");
	expect(warningCount === 1, "mixed loop and non-loop exclusive actions should warn once");
	expect(conflictRef.current === conflictNode, "conflict exclusive should keep mounted node");
	expect(conflictRef.current!.x === 25, "first exclusive loop group should run during conflict");
	expect(conflictRef.current!.y === 0, "conflicting non-loop exclusive group should be ignored");

	nodeY.value = 5;

	afterFrames(2, () => {
		expect(nodeRef.current === node, "ordinary prop patch should reuse animated node");
		expect(nodeRef.current!.y === 5, "ordinary prop patch did not apply");
		expect(actionEnds === 1, "unchanged action child should not run again");

		actionStop.value = 20;

		afterFrames(8, () => {
			expect(nodeRef.current === node, "changed action child should patch animated node");
			expect(actionEnds === 2, "changed action child should run again");
			expect(nodeRef.current!.x === 20, "changed action did not apply final x");

			exclusiveStop.value = 200;

			afterFrames(8, () => {
				expect(exclusiveRef.current === exclusiveNode, "exclusive action patch should reuse node");
			expect(exclusiveEnds === 1, "exclusive action patch should replace the previous running action");
			expect(exclusiveRef.current!.x === 200, "exclusive action patch should not be overwritten by the previous action");

			loopStop.value = 80;
			multiStop.value = 60;

			afterFrames(8, () => {
				expect(loopRef.current === loopNode, "loop exclusive patch should reuse node");
				expect(loopRef.current!.x === 80, "loop exclusive patch should perform with loop=true");
				expect(multiRef.current === multiNode, "multi exclusive patch should reuse node");
				expect(multiRef.current!.x === 60 && multiRef.current!.y === -60, "multiple exclusive patch should perform as a spawn");
				root.unmount();
				exclusiveRoot.unmount();
				loopRoot.unmount();
				multiRoot.unmount();
				conflictRoot.unmount();
				expect(!host.hasChildren, "action diff unmount did not clear host");
				expect(!exclusiveHost.hasChildren, "exclusive action diff unmount did not clear host");
				expect(!loopHost.hasChildren, "loop exclusive action diff unmount did not clear host");
				expect(!multiHost.hasChildren, "multi exclusive action diff unmount did not clear host");
				expect(!conflictHost.hasChildren, "conflict exclusive action diff unmount did not clear host");
				host.removeFromParent(true);
				exclusiveHost.removeFromParent(true);
				loopHost.removeFromParent(true);
				multiHost.removeFromParent(true);
				conflictHost.removeFromParent(true);
				Content.save(resultFile, "passed");
				Log("Info", "[DoraXActionDiffTest] passed");
			});
		});
	});
});
});
