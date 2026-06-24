import { BodyMoveType, Content, Director, Log, Node as DNode, Path, Vec2 } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXPhysicsNodesTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXPhysicsNodesTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const worldRef = useRef<Dora.PhysicsWorld.Type>();
const bodyRef = useRef<Dora.Body.Type>();
const movingRef = useRef<Dora.Body.Type>();
let contactFilterCalls = 0;

root.render(
	<physics-world ref={worldRef} showDebug>
		<contact groupA={1} groupB={2} enabled />
		<body key="terrain" ref={bodyRef} type={BodyMoveType.Static} group={1}>
			<rect-fixture width={160} height={12} friction={0.8} restitution={0.1} />
			<chain-fixture verts={[Vec2(-80, 20), Vec2(0, 40), Vec2(80, 20)]} friction={0.2} />
		</body>
		<body
			key="moving"
			ref={movingRef}
			type={BodyMoveType.Dynamic}
			group={2}
			y={120}
			linearAcceleration={Vec2(0, -10)}
			onContactFilter={() => {
				contactFilterCalls += 1;
				return true;
			}}
		>
			<disk-fixture radius={20} density={1} friction={0.4} restitution={0.2} />
			<polygon-fixture verts={[Vec2(-12, -12), Vec2(12, -12), Vec2(0, 12)]} sensorTag={3} />
		</body>
	</physics-world>
);

const world = worldRef.current;
const terrain = bodyRef.current;
const moving = movingRef.current;
expect(world !== undefined, "physics-world was not mounted");
expect(terrain !== undefined, "static body was not mounted");
expect(moving !== undefined, "dynamic body was not mounted");
expect(host.hasChildren, "physics-world was not added to host");
expect(contactFilterCalls === 0, "contact filter should not run during mount");

root.render(
	<physics-world ref={worldRef} showDebug={false}>
		<body key="terrain" ref={bodyRef} type={BodyMoveType.Dynamic} group={1} y={20}>
			<rect-fixture width={120} height={20} friction={0.5} restitution={0.3} />
		</body>
	</physics-world>
);

expect(worldRef.current !== world, "physics-world should recreate when contact config changes");
expect(bodyRef.current !== terrain, "body should recreate when move type changes");
expect(movingRef.current === moving, "removed body ref should keep the last mounted node");

root.unmount();
expect(!host.hasChildren, "physics nodes unmount did not clear host");
host.removeFromParent(true);
Content.save(resultFile, "passed");
Log("Info", "[DoraXPhysicsNodesTest] passed");
