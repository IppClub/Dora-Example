import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Constraint3D,
	Content,
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

const output = "/tmp/dora-3d-constraint";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(8, 5.5, 10), Vec3(0, 2.5, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 6;
light.angleX = -45;
light.angleY = 25;
view.addChild(light);

const world = PhysicsWorld3D();
view.addChild(world);

const vecDistance = (a: Vec3.Type, b: Vec3.Type) => {
	const x = a.x - b.x;
	const y = a.y - b.y;
	const z = a.z - b.z;
	return Math.sqrt(x * x + y * y + z * z);
};

const addDuck = (position: Vec3.Type, scale = 0.55) => {
	const node = Node3D();
	node.position = position;
	view.addChild(node);
	const model = Model3D("Test/Model3D/Assets/Model/Duck.glb");
	model.scale = Vec3(scale, scale, scale);
	model.position = Vec3(0, -0.25, 0);
	node.addChild(model);
	return node;
};

const fixedAnchorNode = addDuck(Vec3(-4, 3.4, 0), 0.3);
const fixedNode = addDuck(Vec3(-4, 2.0, 0));
const fixedAnchorBody = makeBoxBody3D(world, fixedAnchorNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);
const fixedBody = makeBoxBody3D(world, fixedNode, Vec3(0.45, 0.45, 0.45));
const fixed = Constraint3D.fixed(fixedAnchorBody, fixedBody, Vec3(-4, 2.7, 0));

const distanceAnchorNode = addDuck(Vec3(0, 4.2, 0), 0.3);
const distanceNode = addDuck(Vec3(0, 2.2, 0));
const distanceAnchorBody = makeBoxBody3D(world, distanceAnchorNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);
const distanceBody = makeSphereBody3D(world, distanceNode, 0.45);
const distance = Constraint3D.distance(
	distanceAnchorBody,
	distanceBody,
	distanceAnchorBody.position,
	distanceBody.position,
	2,
	2
);

const hingeAnchorNode = addDuck(Vec3(4, 4.2, 0), 0.3);
const hingeStart = Vec3(4.7, 3.25, 0);
const hingeNode = addDuck(hingeStart);
const hingeAnchorBody = makeBoxBody3D(world, hingeAnchorNode, Vec3(0.2, 0.2, 0.2), PhysicsWorld3D.Static);
const hingeBody = makeBoxBody3D(world, hingeNode, Vec3(0.45, 0.45, 0.45));
const hinge = Constraint3D.hinge(
	hingeAnchorBody,
	hingeBody,
	hingeAnchorBody.position,
	Vec3(0, 0, 1),
	-80,
	80
);

const disposableFirstNode = Node3D();
disposableFirstNode.position = Vec3(0, -10, 0);
view.addChild(disposableFirstNode);
const disposableSecondNode = Node3D();
disposableSecondNode.position = Vec3(1, -10, 0);
view.addChild(disposableSecondNode);
const disposableFirstBody = makeBoxBody3D(world, disposableFirstNode, Vec3(0.1, 0.1, 0.1), PhysicsWorld3D.Static);
const disposableSecondBody = makeBoxBody3D(world, disposableSecondNode, Vec3(0.1, 0.1, 0.1), PhysicsWorld3D.Static);
const disposable = Constraint3D.fixed(disposableFirstBody, disposableSecondBody, Vec3(0.5, -10, 0));
disposable.destroy();
const destroyPass = disposable.world === undefined && disposable.firstBody === undefined;

let elapsed = 0;
let maxHingeMovement = 0;
let phase = "Simulating";
let completed = false;
let captureDelay = -1;
let screenshot = "";
let measuredFixedDistance = 0;
let measuredRopeDistance = 0;
let endpointRefs =
	fixed.world === world && fixed.firstBody === fixedAnchorBody && fixed.secondBody === fixedBody;

print("CONSTRAINT3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	maxHingeMovement = Math.max(maxHingeMovement, vecDistance(hingeBody.position, hingeStart));

	if (!completed && elapsed >= 3) {
		const fixedDistance = vecDistance(fixedBody.position, fixedAnchorBody.position);
		const ropeDistance = vecDistance(distanceBody.position, distanceAnchorBody.position);
		measuredFixedDistance = fixedDistance;
		measuredRopeDistance = ropeDistance;
		const hingeRadius = vecDistance(hingeBody.position, hingeAnchorBody.position);
		const expectedHingeRadius = vecDistance(hingeStart, hingeAnchorBody.position);
		const fixedPass = Math.abs(fixedDistance - 1.4) < 0.12;
		const distancePass = Math.abs(ropeDistance - 2) < 0.08;
		const hingePass =
			Math.abs(hingeRadius - expectedHingeRadius) < 0.1 &&
			Math.abs(hingeNode.position.z) < 0.03 &&
			maxHingeMovement > 0.15;

		phase = fixedPass && distancePass && hingePass && endpointRefs && destroyPass ? "PASS" : "FAIL";
		completed = true;
		screenshot = App.saveScreenshot(`${output}/constraint-3d`);
		captureDelay = 0;
	}

	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 2) {
			captureDelay = -1;
			const summary = `CONSTRAINT3D_SUMMARY status=${phase} fixed=${measuredFixedDistance.toFixed(3)} distance=${measuredRopeDistance.toFixed(3)} hingeMove=${maxHingeMovement.toFixed(3)} refs=${endpointRefs} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(390, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.8);
	ImGui.Begin("JOLT-C Constraints", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Phase: ${phase}`);
		ImGui.Text(`Fixed distance: ${vecDistance(fixedNode.position, fixedAnchorNode.position).toFixed(3)}`);
		ImGui.Text(`Rope distance: ${vecDistance(distanceNode.position, distanceAnchorNode.position).toFixed(3)}`);
		ImGui.Text(`Hinge movement: ${maxHingeMovement.toFixed(3)}`);
		ImGui.Text(`Endpoint refs: ${endpointRefs}`);
	});
	return false;
});
