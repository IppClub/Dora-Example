// @preview-file on clear
import {
	App,
	Body3DType,
	Camera3D,
	Color3,
	DirectionalLight3D,
	Director,
	Model3D,
	Node3D,
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(8, 6, 12), Vec3(0, 2, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);
view.showAABB = false;

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 5;
light.angleX = -40;
light.angleY = 30;
view.addChild(light);

const world = PhysicsWorld3D();
view.addChild(world);

const groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(groundModel);
const groundNode = Node3D();
groundNode.position = Vec3(0, -0.5, 0);
view.addChild(groundNode);
const groundBody = world.createBox(groundNode, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);
groundBody.collisionLayer = 1;

const platformNode = Node3D();
platformNode.position = Vec3(0, 1.0, -1.2);
view.addChild(platformNode);
const platformModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
platformModel.scale = Vec3(0.35, 0.15, 0.35);
platformNode.addChild(platformModel);
const platformBody = world.createBox(platformNode, Vec3(2.2, 0.2, 1.3), PhysicsWorld3D.Kinematic);
platformBody.collisionLayer = 1;

const sensorNode = Node3D();
sensorNode.position = Vec3(0, 2.8, 0);
view.addChild(sensorNode);
const sensorBody = world.createBox(sensorNode, Vec3(2.6, 0.12, 2.0), PhysicsWorld3D.Static);
sensorBody.sensor = true;
sensorBody.collisionLayer = 2;

type Actor = {
	node: Node3D.Type;
	model: Model3D.Type;
	body: Body3DType;
	name: string;
};

const actors: Actor[] = [];
const shapeNames = ["Box", "Sphere", "Capsule"];
let shapeIndex = 1;
let selected: Actor | undefined;
let spawnSerial = 0;
let gravity = -9.81;
let impulse = 5;
let dragGain = 0.8;
let platformMotion = true;
let collisionEnabled = true;
let physicsDebug = false;
let enterCount = 0;
let stayCount = 0;
let exitCount = 0;
let sensorCount = 0;
let rayResult = "None";
let overlapCount = 0;
let elapsed = 0;

function selectedShape() {
	switch (shapeIndex) {
		case 2: return {index: 1, name: "Sphere"};
		case 3: return {index: 2, name: "Capsule"};
		default: return {index: 0, name: "Box"};
	}
}

function spawn(position?: Vec3.Type) {
	spawnSerial += 1;
	const shape = selectedShape();
	const node = Node3D();
	node.position = position ?? Vec3((spawnSerial % 5 - 2) * 1.2, 6 + spawnSerial * 0.18, 0);
	view.addChild(node);
	const model = Model3D("Test/Model3D/Assets/Model/Duck.glb");
	model.tag = `jolt-actor-${spawnSerial}`;
	model.scale = Vec3(0.62, 0.62, 0.62);
	model.position = Vec3(0, -0.35, 0);
	node.addChild(model);

	const body = shape.index === 0
		? world.createBox(node, Vec3(0.58, 0.5, 0.58))
		: shape.index === 1
			? world.createSphere(node, 0.58)
			: world.createCapsule(node, 0.45, 0.42);
	body.collisionLayer = 0;
	body.collisionMask = collisionEnabled ? 0xffffffff : 1 << 2;
	const actor: Actor = {node, model, body, name: `${shape.name} ${spawnSerial}`};
	body.onContactEnter((other) => {
		enterCount += 1;
		if (other === sensorBody) sensorCount += 1;
	});
	body.onContactStay(() => stayCount += 1);
	body.onContactExit(() => exitCount += 1);
	actors.push(actor);
	return actor;
}

function select(actor: Actor | undefined) {
	if (selected) selected.model.scale = Vec3(0.62, 0.62, 0.62);
	selected = actor;
	if (selected) selected.model.scale = Vec3(0.78, 0.78, 0.78);
}

function clearActors() {
	select(undefined);
	while (actors.length > 0) {
		const actor = actors.pop()!;
		actor.body.destroy();
		actor.node.removeFromParent(true);
	}
}

function updateCollisionMasks() {
	for (const actor of actors) actor.body.collisionMask = collisionEnabled ? 0xffffffff : 1 << 2;
}

function queryScene() {
	rayResult = "None";
	world.raycast(Vec3(0, 9, 0), Vec3(0, -1, 0), 20, (body, _point, _normal, distance) => {
		rayResult = `${body.node?.tag ?? "Collider"} @ ${distance.toFixed(2)}`;
		return true;
	});
	overlapCount = 0;
	world.overlapSphere(Vec3(0, 2.5, 0), 3.5, () => {
		overlapCount += 1;
		return false;
	});
}

view.onTapBegan((touch) => {
	const picked = view.pick(touch.viewLocation);
	select(actors.find((actor) => actor.model === picked));
});

view.onTapMoved((touch) => {
	if (!selected) return;
	const velocity = selected.body.linearVelocity;
	selected.body.linearVelocity = Vec3(
		velocity.x - touch.delta.x * dragGain,
		velocity.y + touch.delta.y * dragGain,
		velocity.z
	);
});

for (let i = 0; i < 5; i += 1) spawn(Vec3((i - 2) * 1.3, 4.5 + i * 0.8, 0));
world.showDebug = physicsDebug;
print("JOLT_DYNAMICS_LAB_READY");

threadLoop(() => {
	elapsed += App.deltaTime;
	if (platformMotion) platformNode.position = Vec3(Math.sin(elapsed * 1.2) * 2.8, 1.0, -1.2);
	world.gravity = Vec3(0, gravity, 0);
	queryScene();

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(390, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.82);
	ImGui.Begin("JOLT Dynamics Lab", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		let changed = false;
		[changed, shapeIndex] = ImGui.Combo("Spawn Shape", shapeIndex, shapeNames);
		[changed, gravity] = ImGui.DragFloat("Gravity", gravity, 0.2, -30, 10, "%.2f");
		[changed, impulse] = ImGui.DragFloat("Impulse", impulse, 0.2, 0.5, 20, "%.1f");
		[changed, dragGain] = ImGui.DragFloat("Drag Gain", dragGain, 0.05, 0.1, 2.5, "%.2f");
		[changed, platformMotion] = ImGui.Checkbox("Kinematic Platform", platformMotion);
		[changed, collisionEnabled] = ImGui.Checkbox("Ground Collision", collisionEnabled);
		if (changed) updateCollisionMasks();
		[changed, physicsDebug] = ImGui.Checkbox("Physics Debug", physicsDebug);
		if (changed) world.showDebug = physicsDebug;

		ImGui.Separator();
		ImGui.Text(`Selected: ${selected?.name ?? "None"}`);
		ImGui.Text(`Bodies: ${actors.length}`);
		ImGui.Text(`Enter / Stay / Exit: ${enterCount} / ${stayCount} / ${exitCount}`);
		ImGui.Text(`Sensor enters: ${sensorCount}`);
		ImGui.Text(`Ray: ${rayResult}`);
		ImGui.Text(`Overlap: ${overlapCount}`);

		if (ImGui.Button("Spawn", Vec2(115, 30))) spawn();
		ImGui.SameLine();
		if (ImGui.Button("Delete", Vec2(115, 30)) && selected) {
			const target = selected;
			select(undefined);
			target.body.destroy();
			target.node.removeFromParent(true);
			const index = actors.indexOf(target);
			if (index >= 0) actors.splice(index, 1);
		}
		ImGui.SameLine();
		if (ImGui.Button("Clear", Vec2(115, 30))) clearActors();

		if (ImGui.Button("Force Left", Vec2(115, 30)) && selected) selected.body.applyForce(Vec3(-impulse * 20, 0, 0));
		ImGui.SameLine();
		if (ImGui.Button("Impulse Up", Vec2(115, 30)) && selected) selected.body.applyImpulse(Vec3(0, impulse, 0));
		ImGui.SameLine();
		if (ImGui.Button("Spin", Vec2(115, 30)) && selected) selected.body.angularVelocity = Vec3(0, impulse, impulse * 0.4);
	});
	return false;
});
