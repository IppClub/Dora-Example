import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Node3D,
	FixtureDef3D,
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const output = "/tmp/dora-3d-compound";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(7, 5, 11), Vec3(0, 1, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -45;
light.angleY = 25;
view.addChild(light);

const world = PhysicsWorld3D();
world.gravity = Vec3(0, -9.81, 0);
view.addChild(world);

const floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(floorVisual);
const floorNode = Node3D();
floorNode.position = Vec3(0, -0.5, 0);
view.addChild(floorNode);
makeBoxBody3D(world, floorNode, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);

const compoundNode = Node3D();
compoundNode.position = Vec3(0, 4, 0);
view.addChild(compoundNode);

for (const x of [-1, 1]) {
	const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
	duck.position = Vec3(x, -0.45, 0);
	duck.scale = Vec3(0.55, 0.55, 0.55);
	compoundNode.addChild(duck);
}

const box = FixtureDef3D.box(Vec3(0.55, 0.55, 0.55));
const sphere = FixtureDef3D.sphere(0.55);
const compound = FixtureDef3D.compound();
const leftAdded = compound.addChild(box, Vec3(-1, 0, 0));
const rightAdded = compound.addChild(sphere, Vec3(1, 0, 0), Vec3(0, 30, 0));
const built = compound.build();
const frozen = !compound.addChild(box, Vec3(0, 1, 0));
const body = makeBody3D(world, compoundNode, compound, PhysicsWorld3D.Dynamic);

let elapsed = 0;
let stableFrames = 0;
let leftHit = false;
let rightHit = false;
let phase = "Falling";
let completed = false;
let captureDelay = -1;
let screenshot = "";

print("COMPOUND3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	const velocity = body.linearVelocity;
	if (elapsed > 0.5 && Math.abs(velocity.y) < 0.08 && body.position.y < 0.8) {
		stableFrames += 1;
	} else {
		stableFrames = 0;
	}

	if (!completed && stableFrames >= 8) {
		phase = "Querying";
		const y = body.position.y + 3;
		world.raycast(Vec3(body.position.x - 1, y, 0), Vec3(body.position.x - 1, y - 6, 0), (hit) => {
			leftHit = hit === body;
			return true;
		});
		world.raycast(Vec3(body.position.x + 1, y, 0), Vec3(body.position.x + 1, y - 6, 0), (hit) => {
			rightHit = hit === body;
			return true;
		});
		completed = true;
		phase = leftAdded && rightAdded && built && compound.built && frozen && leftHit && rightHit ? "PASS" : "FAIL";
		screenshot = App.saveScreenshot(`${output}/compound-shape`);
		captureDelay = 0;
	}

	if (!completed && elapsed > 8) {
		completed = true;
		phase = "FAIL";
		captureDelay = 0;
		screenshot = App.saveScreenshot(`${output}/compound-shape`);
	}

	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 2) {
			captureDelay = -1;
			const summary = `COMPOUND3D_SUMMARY status=${phase} built=${compound.built} frozen=${frozen} left=${leftHit} right=${rightHit} y=${body.position.y.toFixed(3)} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(350, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.78);
	ImGui.Begin("JOLT-C Compound Shape", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Phase: ${phase}`);
		ImGui.Text(`Built: ${compound.built}`);
		ImGui.Text(`Frozen: ${frozen}`);
		ImGui.Text(`Ray hits: ${leftHit}, ${rightHit}`);
		ImGui.Text(`Body Y: ${body.position.y.toFixed(2)}`);
	});
	return false;
});
