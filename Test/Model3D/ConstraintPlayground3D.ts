import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Body3DType,
	Camera3D,
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
world.gravity = Vec3(0, -9.81, 0);
view.addChild(world);

const groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(groundModel);
const groundNode = Node3D();
groundNode.position = Vec3(0, -0.5, 0);
view.addChild(groundNode);
makeBoxBody3D(world, groundNode, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);

const anchorNode = Node3D();
anchorNode.position = Vec3(0, 4.5, 0);
view.addChild(anchorNode);
const anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb");
anchorModel.scale = Vec3(0.32, 0.32, 0.32);
anchorModel.position = Vec3(0, -0.2, 0);
anchorNode.addChild(anchorModel);
const anchorBody = makeBoxBody3D(world, anchorNode, Vec3(0.22, 0.22, 0.22), PhysicsWorld3D.Static);

const dynamicNode = Node3D();
view.addChild(dynamicNode);
const dynamicModel = Model3D("Test/Model3D/Assets/Model/Duck.glb");
dynamicModel.tag = "playground-duck";
dynamicModel.scale = Vec3(0.8, 0.8, 0.8);
dynamicModel.position = Vec3(0, -0.45, 0);
dynamicNode.addChild(dynamicModel);

const modeNames = ["Fixed", "Distance", "Hinge"];
let mode = 2;
let ropeLength = 2.8;
let hingeLimit = 80;
let impulse = 4;
let dragGain = 0.9;
let showAABB = false;
let physicsDebug = false;
let selected = false;
let body: Body3DType = makeBoxBody3D(world, dynamicNode, Vec3(0.65, 0.55, 0.65));
let constraint: Constraint3DType | undefined;
let state = "Connected";
let peakSpeed = 0;

const vecLength = (value: Vec3.Type) => Math.sqrt(
	value.x * value.x + value.y * value.y + value.z * value.z
);

function rebuild() {
	constraint?.destroy();
	constraint = undefined;
	body.removeChild(dynamicNode, false);
	body.removeFromParent(true);
	view.addChild(dynamicNode);

	const start = mode === 0
		? Vec3(1.8, 2.4, 0)
		: mode === 1
			? Vec3(ropeLength * 0.72, 4.5 - ropeLength * 0.69, 0)
			: Vec3(1.8, 2.4, 0);
	dynamicNode.position = start;
	dynamicNode.angles = Vec3(0, 0, 0);
	body = makeBoxBody3D(world, dynamicNode, Vec3(0.65, 0.55, 0.65));

	if (mode === 0) {
		constraint = Constraint3D.fixed(anchorBody, body, Vec3(0.9, 3.45, 0));
	} else if (mode === 1) {
		constraint = Constraint3D.distance(
			anchorBody,
			body,
			anchorBody.position,
			body.position,
			ropeLength,
			ropeLength
		);
	} else {
		constraint = Constraint3D.hinge(
			anchorBody,
			body,
			anchorBody.position,
			Vec3(0, 0, 1),
			-hingeLimit,
			hingeLimit
		);
	}
	state = "Connected";
	peakSpeed = 0;
}

function push(x: number, y: number) {
	body.applyLinearImpulse(Vec3(x * impulse, y * impulse, 0));
}

view.onTapBegan((touch) => {
	selected = view.pick(touch.viewLocation) === dynamicModel;
	dynamicModel.scale = selected ? Vec3(0.92, 0.92, 0.92) : Vec3(0.8, 0.8, 0.8);
});

view.onTapMoved((touch) => {
	if (!selected) return;
	const velocity = body.linearVelocity;
	body.linearVelocity = Vec3(
		velocity.x - touch.delta.x * dragGain,
		velocity.y + touch.delta.y * dragGain,
		0
	);
});

view.onTapEnded(() => {
	selected = false;
	dynamicModel.scale = Vec3(0.8, 0.8, 0.8);
});

rebuild();
print("CONSTRAINT_PLAYGROUND3D_READY");

threadLoop(() => {
	peakSpeed = Math.max(peakSpeed, vecLength(body.linearVelocity));

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(350, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.82);
	ImGui.Begin("Constraint Playground", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		let changed = false;
		[changed, mode] = ImGui.Combo("Constraint", mode, modeNames);
		if (changed) rebuild();

		if (mode === 1) {
			[changed, ropeLength] = ImGui.DragFloat("Length", ropeLength, 0.05, 1.5, 4.0, "%.2f");
			if (changed) rebuild();
		} else if (mode === 2) {
			[changed, hingeLimit] = ImGui.DragFloat("Limit", hingeLimit, 1, 10, 170, "%.0f deg");
			if (changed) rebuild();
		}

		[changed, impulse] = ImGui.DragFloat("Impulse", impulse, 0.1, 0.5, 12, "%.1f");
		[changed, dragGain] = ImGui.DragFloat("Drag Gain", dragGain, 0.05, 0.2, 2.5, "%.2f");
		[changed, showAABB] = ImGui.Checkbox("Show AABB", showAABB);
		if (changed) view.showAABB = showAABB;
		[changed, physicsDebug] = ImGui.Checkbox("Physics Debug", physicsDebug);
		if (changed) world.showDebug = physicsDebug;

		ImGui.Separator();
		ImGui.Text(`State: ${state}`);
		ImGui.Text(`Selected: ${selected}`);
		ImGui.Text(`Speed: ${vecLength(body.linearVelocity).toFixed(2)}`);
		ImGui.Text(`Peak speed: ${peakSpeed.toFixed(2)}`);
		ImGui.Text(`Position: ${body.position.x.toFixed(2)}, ${body.position.y.toFixed(2)}`);

		if (ImGui.Button("Left", Vec2(100, 30))) push(-1, 0);
		ImGui.SameLine();
		if (ImGui.Button("Up", Vec2(100, 30))) push(0, 1);
		ImGui.SameLine();
		if (ImGui.Button("Right", Vec2(100, 30))) push(1, 0);

		if (ImGui.Button("Break", Vec2(150, 30)) && constraint) {
			constraint.destroy();
			constraint = undefined;
			state = "Broken";
		}
		ImGui.SameLine();
		if (ImGui.Button("Rebuild", Vec2(150, 30))) rebuild();
	});
	return false;
});
