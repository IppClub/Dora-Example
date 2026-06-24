import { Content, Director, Ease, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, toAction, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXActionLifecycleTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[DoraXActionLifecycleTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const nodeRef = useRef<Dora.Node.Type>();
let enters = 0;
let exits = 0;
let cleanups = 0;
let mounts = 0;
let unmounts = 0;

const action = toAction(
	<sequence>
		<scale time={0.01} start={1} stop={1.1} easing={Ease.OutQuad} />
		<move-x time={0.01} start={0} stop={8} />
	</sequence>
);
expect(action !== undefined, "toAction should build a sequence action");

Director.systemScheduler.schedule(once(() => {
	root.render(
		<node
			key="tracked"
			ref={nodeRef}
			onMount={(node) => {
				mounts += 1;
				node.perform(action);
			}}
			onEnter={() => {
				enters += 1;
			}}
			onExit={() => {
				exits += 1;
			}}
			onCleanup={() => {
				cleanups += 1;
			}}
			onUnmount={() => {
				unmounts += 1;
			}}
		/>
	);

	const tracked = nodeRef.current;
	expect(tracked !== undefined, "tracked node was not mounted");
	expect(mounts === 1, "onMount should run once on initial mount");

	Director.systemScheduler.schedule(once(() => {
	root.render([]);

	Director.systemScheduler.schedule(once(() => {
	expect(mounts === 1, "onMount should not rerun when node is removed");
	expect(!host.hasChildren, "diff removal should clear tracked node from host");
	expect(unmounts === 1, "onUnmount should run when diff removes node");

	root.render(
		<node
			key="tracked"
			ref={nodeRef}
			onEnter={() => {
				enters += 1;
			}}
			onExit={() => {
				exits += 1;
			}}
			onCleanup={() => {
				cleanups += 1;
			}}
			onUnmount={() => {
				unmounts += 1;
			}}
		/>
	);

	Director.systemScheduler.schedule(once(() => {
	expect(nodeRef.current !== tracked, "removed node should mount as a new instance when added again");

	root.unmount();

			Director.systemScheduler.schedule(once(() => {
	expect(!host.hasChildren, "lifecycle unmount did not clear host");
	expect(unmounts === 2, "onUnmount should run during root unmount");
	host.removeFromParent(true);
	Content.save(resultFile, "passed");
	Log("Info", "[DoraXActionLifecycleTest] passed");
			}));
		}));
	}));
	}));
}));
