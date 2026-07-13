import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	Body3DType,
	Camera3D,
	CharacterController3DType,
	Color3,
	Constraint3D,
Constraint3DType,
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
camera.lookAt(Vec3(7, 5, 11), Vec3(0, 2, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 5;
light.angleX = -40;
light.angleY = 30;
view.addChild(light);

const world = PhysicsWorld3D();
view.addChild(world);

const floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(floorVisual);
const floorNode = Node3D();
floorNode.position = Vec3(0, -0.5, 0);
view.addChild(floorNode);
makeBoxBody3D(world, floorNode, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);

const anchorNode = Node3D();
anchorNode.position = Vec3(0, 4.5, 0);
view.addChild(anchorNode);
const anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb");
anchorModel.scale = Vec3(0.3, 0.3, 0.3);
anchorNode.addChild(anchorModel);
const anchorBody = makeBoxBody3D(world, anchorNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);

const actorNode = Node3D();
view.addChild(actorNode);
const actorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb");
actorModel.scale = Vec3(0.72, 0.72, 0.72);
actorModel.position = Vec3(0, -0.4, 0);
actorNode.addChild(actorModel);

let actorBody: Body3DType;
let actorConstraint: Constraint3DType;
let actorGeneration = 0;
let bodyCascadePass = false;
let worldCleanupPass = false;
let stressRunning = false;
let stressTarget = 0;
let stressCycles = 0;
let stressFailures = 0;
let lastCharacterEmpty = false;
let physicsDebug = false;

function rebuildActor() {
	if (actorGeneration > 0) {
		actorConstraint.destroy();
		actorBody.removeFromParent(true);
	}
	actorGeneration += 1;
	actorNode.position = Vec3(1.8, 2.2, 0);
	actorNode.angles = Vec3(0, 0, 0);
	actorBody = makeBoxBody3D(world, actorNode, Vec3(0.6, 0.55, 0.6));
	actorConstraint = Constraint3D.hinge(
		anchorBody,
		actorBody,
		anchorNode.position,
		Vec3(0, 0, 1),
		-85,
		85
	);
}

function destroyBodyCascade() {
	actorBody.removeFromParent(true);
	bodyCascadePass = actorBody.world === undefined
		&& actorConstraint.world === undefined
		&& actorConstraint.firstBody === undefined;
}

function runWorldCleanupCycle() {
	const cycleWorld = PhysicsWorld3D();
	view.addChild(cycleWorld);
	const firstNode = Node3D();
	firstNode.position = Vec3(0, -20, 0);
	view.addChild(firstNode);
	const secondNode = Node3D();
	secondNode.position = Vec3(1, -20, 0);
	view.addChild(secondNode);
	const characterNode = Node3D();
	characterNode.position = Vec3(0, -20, 2);
	view.addChild(characterNode);

	const first = makeBoxBody3D(cycleWorld, firstNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);
	const second = makeSphereBody3D(cycleWorld, secondNode, 0.2);
	const constraint = Constraint3D.fixed(first, second, Vec3(0.5, -20, 0));
	const character: CharacterController3DType = cycleWorld.createCharacter(characterNode, 0.45, 0.25);

	cycleWorld.removeFromParent(true);
	worldCleanupPass = first.world === undefined
		&& second.world === undefined
		&& constraint.world === undefined
		&& character.world === undefined;
	lastCharacterEmpty = character.node === undefined;
	if (!worldCleanupPass || !lastCharacterEmpty) stressFailures += 1;
	stressCycles += 1;
	firstNode.removeFromParent(true);
	secondNode.removeFromParent(true);
	characterNode.removeFromParent(true);
}

function beginStress(count: number) {
	stressTarget = stressCycles + count;
	stressRunning = true;
}

rebuildActor();
runWorldCleanupCycle();
print("JOLT_LIFECYCLE_LAB_READY");

threadLoop(() => {
	if (stressRunning) {
		for (let i = 0; i < 4 && stressCycles < stressTarget; i += 1) runWorldCleanupCycle();
		if (stressCycles >= stressTarget) stressRunning = false;
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(410, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.82);
	ImGui.Begin("JOLT Lifecycle Lab", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Visible generation: ${actorGeneration}`);
		ImGui.Text(`Body cascade cleanup: ${bodyCascadePass}`);
		ImGui.Text(`World cleanup: ${worldCleanupPass}`);
		ImGui.Text(`Character cleanup: ${lastCharacterEmpty}`);
		ImGui.Text(`Stress cycles / failures: ${stressCycles} / ${stressFailures}`);
		ImGui.Text(`Stress state: ${stressRunning ? "Running" : "Idle"}`);
		let changed = false;
		[changed, physicsDebug] = ImGui.Checkbox("Physics Debug", physicsDebug);
		if (changed) world.showDebug = physicsDebug;

		if (ImGui.Button("Destroy Body", Vec2(185, 30))) destroyBodyCascade();
		ImGui.SameLine();
		if (ImGui.Button("Rebuild Actor", Vec2(185, 30))) rebuildActor();

		if (ImGui.Button("World Cycle", Vec2(120, 30))) runWorldCleanupCycle();
		ImGui.SameLine();
		if (ImGui.Button("Stress 100", Vec2(120, 30))) beginStress(100);
		ImGui.SameLine();
		if (ImGui.Button("Stress 1000", Vec2(120, 30))) beginStress(1000);
	});
	return false;
});
