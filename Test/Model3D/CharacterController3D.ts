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
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const output = "/tmp/dora-3d-character";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(8, 4.5, 10), Vec3(1.5, 1, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -40;
light.angleY = 25;
view.addChild(light);

const world = PhysicsWorld3D();
world.gravity = Vec3(0, -9.81, 0);
view.addChild(world);

const floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
view.addChild(floorVisual);
const floor = Node3D();
floor.position = Vec3(0, -0.5, 0);
view.addChild(floor);
world.createBox(floor, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);

const characterNode = Node3D();
characterNode.position = Vec3(-2.5, 3, 0);
view.addChild(characterNode);
const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
duck.scale = Vec3(0.65, 0.65, 0.65);
duck.position = Vec3(0, 0.15, 0);
characterNode.addChild(duck);

const character = world.createCharacter(characterNode, 0.5, 0.3, 50, 0.4);
character.collisionLayer = 0;
character.collisionMask = 0xffffffff;

let phase = "Falling";
let groundedFrames = 0;
let walkedFrom = 0;
let jumped = false;
let jumpPeak = 0;
let relandedFrames = 0;
let completed = false;
let elapsed = 0;
let captureDelay = -1;
let screenshot = "";

print("CHARACTER3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	jumpPeak = Math.max(jumpPeak, characterNode.position.y);

	if (!jumped && character.grounded) {
		groundedFrames += 1;
		if (phase === "Falling" && groundedFrames >= 5) {
			phase = "Walking";
			walkedFrom = characterNode.position.x;
			character.desiredVelocity = Vec3(2, 0, 0);
		}
		if (phase === "Walking" && characterNode.position.x - walkedFrom > 1.2) {
			phase = "Jumping";
			jumped = true;
			jumpPeak = characterNode.position.y;
			character.jump(5);
		}
	} else if (jumped && !character.grounded) {
		phase = "Airborne";
	} else if (jumped && character.grounded && phase === "Airborne") {
		phase = "Relanded";
		relandedFrames = 1;
		character.desiredVelocity = Vec3(0, 0, 0);
	} else if (phase === "Relanded" && character.grounded && !completed) {
		relandedFrames += 1;
		if (relandedFrames < 5) return false;
		completed = true;
		phase = "PASS";
		screenshot = App.saveScreenshot(`${output}/character-controller`);
		captureDelay = 0;
	}
	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 0.75) {
			captureDelay = -1;
			const summary = `CHARACTER3D_SUMMARY status=PASS x=${characterNode.position.x.toFixed(3)} y=${characterNode.position.y.toFixed(3)} peak=${jumpPeak.toFixed(3)} grounded=${character.grounded} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	if (!completed && elapsed > 10) {
		completed = true;
		phase = "FAIL";
		const summary = `CHARACTER3D_SUMMARY status=FAIL x=${characterNode.position.x.toFixed(3)} y=${characterNode.position.y.toFixed(3)} peak=${jumpPeak.toFixed(3)} grounded=${character.grounded}`;
		Content.save(`${output}/result.txt`, summary);
		print(summary);
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(330, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.78);
	ImGui.Begin("JOLT-C Character", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Phase: ${phase}`);
		ImGui.Text(`Position: ${characterNode.position.x.toFixed(2)}, ${characterNode.position.y.toFixed(2)}`);
		ImGui.Text(`Velocity: ${character.velocity.x.toFixed(2)}, ${character.velocity.y.toFixed(2)}`);
		ImGui.Text(`Grounded: ${character.grounded}`);
		if (ImGui.Button("Jump", Vec2(-1, 30))) character.jump(5);
	});
	return false;
});
