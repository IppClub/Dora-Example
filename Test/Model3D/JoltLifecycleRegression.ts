import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Body3DType,
	CharacterController3DType,
	Constraint3D,
Constraint3DType,
	Content,
	Director,
	Node3D,
	FixtureDef3D,
	FixtureDef3DType,
	PhysicsWorld3D,
	Vec3,
	threadLoop,
} from "Dora";

const output = "/tmp/dora-3d-jolt-lifecycle";
const resultPath = `${output}/result.txt`;
const worldCycles = 1000;
const asyncCases = [
	{path: "Test/Model3D/Assets/Model/Duck.glb", hull: true},
	{path: "Test/Model3D/Assets/Model/Duck.glb", hull: false},
	{path: "Test/Model3D/Assets/Model/Fox.glb", hull: true},
	{path: "Test/Model3D/Assets/Model/Fox.glb", hull: false},
];
const asyncCycles = asyncCases.length;
const handlersPerCycle = 8;

let lifecycleCompleted = 0;
let asyncCompleted = 0;
let pendingHandlers = 0;
let pendingShape: FixtureDef3DType | undefined;
let pendingFailed = false;
let asyncReady = false;
let finished = false;

function finish(status: "PASS" | "FAIL", reason = "none") {
	if (finished) return;
	finished = true;
	const summary =
		`JOLT_LIFECYCLE_SUMMARY status=${status} reason=${reason} ` +
		`worldCycles=${lifecycleCompleted}/${worldCycles} ` +
		`asyncCycles=${asyncCompleted}/${asyncCycles} handlers=${handlersPerCycle}`;
	print(summary);
	Content.save(resultPath, `${summary}\n`);
	App.devMode = false;
	App.shutdown();
}

function runWorldCycle() {
	const world = PhysicsWorld3D();
	Director.entry.addChild(world);
	const firstNode = Node3D();
	const secondNode = Node3D();
	const characterNode = Node3D();
	Director.entry.addChild(firstNode);
	Director.entry.addChild(secondNode);
	Director.entry.addChild(characterNode);

	const first: Body3DType = makeBoxBody3D(world, firstNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);
	const second: Body3DType = makeSphereBody3D(world, secondNode, 0.2);
	const constraint: Constraint3DType = Constraint3D.fixed(first, second, Vec3(0, 0, 0));
	const character: CharacterController3DType = world.createCharacter(characterNode, 0.45, 0.25);

	world.removeFromParent(true);
	const valid = first.world === undefined
		&& second.world === undefined
		&& constraint.world === undefined
		&& constraint.firstBody === undefined
		&& constraint.secondBody === undefined
		&& character.world === undefined
		&& character.node === undefined;
	first.removeFromParent(true);
	second.removeFromParent(true);
	characterNode.removeFromParent(true);
	if (!valid) finish("FAIL", `world_cleanup_${lifecycleCompleted}`);
	else lifecycleCompleted += 1;
}

function startAsyncCycle() {
	const testCase = asyncCases[asyncCompleted];
	pendingHandlers = handlersPerCycle;
	pendingShape = undefined;
	pendingFailed = false;
	asyncReady = false;
	const handler = (shape: FixtureDef3DType) => {
		if (!shape.built) pendingFailed = true;
		if (pendingShape === undefined) pendingShape = shape;
		else if (pendingShape !== shape) pendingFailed = true;
		pendingHandlers -= 1;
		if (pendingHandlers === 0) asyncReady = true;
	};
	for (let i = 0; i < handlersPerCycle; i += 1) {
		if (testCase.hull) FixtureDef3D.loadConvexHullAsync(testCase.path, handler);
		else FixtureDef3D.loadMeshAsync(testCase.path, handler);
	}
}

function consumeAsyncCycle() {
	asyncReady = false;
	const shape = pendingShape;
	if (pendingFailed || shape === undefined || !shape.built) {
		finish("FAIL", `async_load_${asyncCompleted}`);
		return;
	}

	const world = PhysicsWorld3D();
	Director.entry.addChild(world);
	const node = Node3D();
	Director.entry.addChild(node);
	const motion = asyncCases[asyncCompleted].hull ? PhysicsWorld3D.Dynamic : PhysicsWorld3D.Static;
	const body = makeBody3D(world, node, shape, motion);
	if (body === undefined || body.world !== world) {
		finish("FAIL", `async_body_${asyncCompleted}`);
		return;
	}
	world.removeFromParent(true);
	if (body.world !== undefined) {
		finish("FAIL", `async_world_cleanup_${asyncCompleted}`);
		return;
	}
	body.removeFromParent(true);
	asyncCompleted += 1;
	if (asyncCompleted < asyncCycles) startAsyncCycle();
	else finish("PASS");
}

Content.remove(resultPath);
print("JOLT_LIFECYCLE_REGRESSION_READY");

threadLoop(() => {
	if (finished) return true;
	if (lifecycleCompleted < worldCycles) {
		for (let i = 0; i < 10 && lifecycleCompleted < worldCycles && !finished; i += 1) runWorldCycle();
		if (lifecycleCompleted === worldCycles) startAsyncCycle();
		return false;
	}
	if (asyncReady) consumeAsyncCycle();
	return false;
});
