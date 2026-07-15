import { makeBody3D, makeBoxBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Body3D,
	Body3DType,
	BodyDef3D,
	Camera3D,
	Color3,
	DirectionalLight3D,
	Director,
	Model3D,
	Node3D,
	FixtureDef3D,
	FixtureDef3DType,
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(9, 6, 13), Vec3(0, 1.5, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);
view.showAABB = true;

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 5;
light.angleX = -45;
light.angleY = 25;
view.addChild(light);

const world = PhysicsWorld3D();
view.addChild(world);

const floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(floorVisual);
const floorNode = Node3D();
floorNode.position = Vec3(0, -0.5, 0);
view.addChild(floorNode);
makeBoxBody3D(world, floorNode, Vec3(8, 0.5, 4), PhysicsWorld3D.Static);

const childBox = FixtureDef3D.box(Vec3(0.55, 0.5, 0.55));
const childSphere = FixtureDef3D.sphere(0.58);
const compound = FixtureDef3D.compound();
compound.addChild(childBox, Vec3(-0.9, 0, 0), Vec3(0, 0, -12));
compound.addChild(childSphere, Vec3(0.9, 0, 0));
compound.build();
const frozen = !compound.addChild(childBox, Vec3(0, 1, 0));

type CompoundActor = {node: Node3D.Type; body: Body3DType};
const compounds: CompoundActor[] = [];
let serial = 0;

function spawnCompound() {
	serial += 1;
	const node = Node3D();
	node.position = Vec3(-2.7 + (serial % 3) * 0.4, 3.5 + serial * 0.45, 0);
	view.addChild(node);
	for (const x of [-0.9, 0.9]) {
		const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
		duck.position = Vec3(x, -0.4, 0);
		duck.scale = Vec3(0.48, 0.48, 0.48);
		node.addChild(duck);
	}
	const body = makeBody3D(world, node, compound, PhysicsWorld3D.Dynamic);
	compounds.push({node, body});
}

function clearCompounds() {
	while (compounds.length > 0) {
		const actor = compounds.pop()!;
		actor.body.removeFromParent(true);
	}
}

const meshPath = "Test/Model3D/Assets/Model/Ground.gltf";
const meshNode = Node3D();
meshNode.position = Vec3(3.2, 1.2, 0);
view.addChild(meshNode);
const meshVisual = Model3D(meshPath);
meshVisual.scale = Vec3(0.55, 0.55, 0.55);
meshNode.addChild(meshVisual);

let meshShape: FixtureDef3DType | undefined;
let meshBody: Body3DType | undefined;
let meshState = "Not loaded";
let meshLoadTime = 0;
let cacheHit = false;
let dynamicRejected = false;
let elapsed = 0;
let physicsDebug = false;

const kinematicNode = Node3D();
kinematicNode.position = Vec3(3.2, 3.0, 0);
view.addChild(kinematicNode);
const kinematicPlatform = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
kinematicPlatform.scale = Vec3(0.28, 0.12, 0.28);
kinematicNode.addChild(kinematicPlatform);
const kinematicBody = makeBoxBody3D(
	world,
	kinematicNode,
	Vec3(1.8, 0.2, 1.0),
	PhysicsWorld3D.Kinematic
);
let moveKinematic = true;

function createMeshBody() {
	if (!meshShape) return;
	if (meshBody) {
		const position = meshBody.position;
		meshBody.removeChild(meshNode, false);
		meshBody.removeFromParent(true);
		view.addChild(meshNode);
		meshNode.position = position;
	}
	meshBody = makeBody3D(world,
		meshNode,
		meshShape,
		PhysicsWorld3D.Static
	);
	meshState = meshBody !== undefined ? "Static ready" : "Body creation rejected";
}

function loadMesh() {
	meshState = "Loading through Content";
	const started = App.runningTime;
	FixtureDef3D.loadMeshAsync(meshPath, (shape) => {
		meshLoadTime = App.runningTime - started;
		if (!shape.built) {
			meshState = "Cook failed";
			return;
		}
		meshShape = shape;
		createMeshBody();
		FixtureDef3D.loadMeshAsync(meshPath, (cached) => {
			cacheHit = cached === shape;
		});
	});
}

function testDynamicRejection() {
	if (!meshShape) return;
	const probe = Node3D();
	probe.position = Vec3(0, -20, 0);
	view.addChild(probe);
	const def = BodyDef3D();
	def.type = PhysicsWorld3D.Dynamic;
	def.attach(meshShape);
	const rejected = Body3D(def, world, probe.position, probe.angles);
	dynamicRejected = rejected === undefined;
	if (rejected !== undefined) rejected.removeFromParent(true);
	probe.removeFromParent(true);
}

for (let i = 0; i < 3; i += 1) spawnCompound();
loadMesh();
print("JOLT_SHAPE_LAB_READY");

threadLoop(() => {
	elapsed += App.deltaTime;
	if (moveKinematic) {
		kinematicBody.position = Vec3(3.2, 3.0 + Math.sin(elapsed * 1.5) * 0.7, 0);
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(390, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.82);
	ImGui.Begin("JOLT Shape Lab", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text("Compound Builder");
		ImGui.Text(`Built / frozen: ${compound.built} / ${frozen}`);
		ImGui.Text(`Shared bodies: ${compounds.length}`);
		if (ImGui.Button("Spawn Compound", Vec2(175, 30))) spawnCompound();
		ImGui.SameLine();
		if (ImGui.Button("Clear Compounds", Vec2(175, 30))) clearCompounds();

		ImGui.Separator();
		ImGui.Text("glTF Mesh Collider");
		ImGui.Text(`State: ${meshState}`);
		ImGui.Text(`Content + cook: ${meshLoadTime.toFixed(3)}s`);
		ImGui.Text(`Cache hit: ${cacheHit}`);
		ImGui.Text(`Dynamic rejected: ${dynamicRejected}`);
		let changed = false;
		[changed, moveKinematic] = ImGui.Checkbox("Move Kinematic Platform", moveKinematic);
		[changed, physicsDebug] = ImGui.Checkbox("Physics Debug", physicsDebug);
		if (changed) world.showDebug = physicsDebug;
		if (ImGui.Button("Reload Cached", Vec2(175, 30))) loadMesh();
		ImGui.SameLine();
		if (ImGui.Button("Test Dynamic", Vec2(175, 30))) testDynamicRejection();
	});
	return false;
});
