// @preview-file on clear
import {
	App,
	Body3DType,
	Camera3D,
	Color3,
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

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(7, 4.5, 10), Vec3(0, 1.5, 0));
Director.pushCamera(camera);

view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -35;
light.angleY = 30;
view.addChild(light);

const world = PhysicsWorld3D();
world.gravity = Vec3(0, -9.81, 0);
view.addChild(world);

const floor = Node3D();
floor.position = Vec3(0, -0.5, 0);
view.addChild(floor);
const floorBody = world.createBox(floor, Vec3(5, 0.5, 4), PhysicsWorld3D.Static);
floorBody.collisionLayer = 1;

const duckFile = "Test/Model3D/Assets/Model/Duck.glb";
const ducks: Model3D.Type[] = [];
const bodies: Body3DType[] = [];
let enterCount = 0;
let stayCount = 0;
let exitCount = 0;
let sensorCount = 0;
let rayHit = "None";
let overlapCount = 0;

for (let i = 0; i < 3; i += 1) {
	const duck = Model3D(duckFile);
	duck.tag = `Duck ${i + 1}`;
	duck.position = Vec3((i - 1) * 2, 3 + i * 1.25, 0);
	duck.scale = Vec3(0.7, 0.7, 0.7);
	view.addChild(duck);
	ducks.push(duck);

	const body = world.createSphere(duck, 0.65, PhysicsWorld3D.Dynamic);
	body.collisionLayer = 0;
	body.collisionMask = 0xffffffff;
	body.onContactEnter(() => enterCount += 1);
	body.onContactStay(() => stayCount += 1);
	body.onContactExit(() => exitCount += 1);
	bodies.push(body);
}

const triggerNode = Node3D();
triggerNode.position = Vec3(0, 2.1, 0);
view.addChild(triggerNode);
const trigger = world.createBox(triggerNode, Vec3(3.5, 0.15, 2), PhysicsWorld3D.Static);
trigger.sensor = true;
trigger.onContactEnter(() => sensorCount += 1);

bodies[0].applyImpulse(Vec3(1.8, 1.0, 0));
print(`PHYSICS3D_READY bodies=${bodies.length} gravity=${world.gravity.y}`);

let queryTimer = 0;
let verificationTimer = 0;
let verified = false;
let verificationStatus = "Pending";
threadLoop(() => {
	queryTimer += App.deltaTime;
	verificationTimer += App.deltaTime;
	if (queryTimer >= 0.25) {
		queryTimer = 0;
		rayHit = "None";
		world.raycast(Vec3(0, 8, 0), Vec3(0, -1, 0), 20, (body, _point, _normal, distance) => {
			rayHit = `${body.node?.tag ?? "Collider"} @ ${distance.toFixed(2)}`;
			return true;
		});
		overlapCount = 0;
		world.overlapSphere(Vec3(0, 1, 0), 4, () => {
			overlapCount += 1;
			return false;
		});
	}

	if (!verified && verificationTimer >= 3) {
		verified = true;
		const passed = enterCount > 0
			&& stayCount > 0
			&& sensorCount > 0
			&& rayHit !== "None"
			&& overlapCount > 0;
		verificationStatus = passed ? "PASS" : "FAIL";
		const screenshot = App.saveScreenshot("/tmp/dora-3d-physics/jolt-b-runtime");
		const positions = ducks.map(duck => duck.position.y.toFixed(2)).join(",");
		const summary = `PHYSICS3D_SUMMARY status=${verificationStatus} enter=${enterCount} stay=${stayCount} exit=${exitCount} sensor=${sensorCount} ray=${rayHit} overlap=${overlapCount} y=${positions} screenshot=${screenshot}`;
		Content.save("/tmp/dora-3d-physics/summary.txt", summary);
		print(summary);
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(340, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.75);
	ImGui.Begin("JOLT-B Physics3D", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Bodies: ${bodies.length + 2}`);
		ImGui.Text(`Contact Enter / Stay / Exit: ${enterCount} / ${stayCount} / ${exitCount}`);
		ImGui.Text(`Sensor Enter: ${sensorCount}`);
		ImGui.Text(`Ray: ${rayHit}`);
		ImGui.Text(`Overlap radius 4: ${overlapCount}`);
		ImGui.Text(`Verification: ${verificationStatus}`);
		if (ImGui.Button("Impulse All", Vec2(-1, 30))) {
			for (const body of bodies) body.applyImpulse(Vec3(0, 4.5, 0));
		}
	});
	return false;
});
