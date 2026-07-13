import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
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
	FixtureDef3D,
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const output = "/tmp/dora-3d-mesh-collider";
const meshPath = "Test/Model3D/Assets/Model/Ground.gltf";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(7, 5, 10), Vec3(0, 0.8, 0));
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

const groundVisual = Model3D(meshPath);
view.addChild(groundVisual);

const sphereNode = Node3D();
sphereNode.position = Vec3(0, 3, 0);
view.addChild(sphereNode);
const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
duck.scale = Vec3(0.55, 0.55, 0.55);
duck.position = Vec3(0, -0.45, 0);
sphereNode.addChild(duck);

let phase = "Loading mesh through Content";
let meshBodyCreated = false;
let sphereBody: Body3DType | undefined;
let cacheHit = false;
let rayHit = false;
let elapsed = 0;
let loadTime = 0;
let stableFrames = 0;
let completed = false;
let captureDelay = -1;
let screenshot = "";
const loadStarted = App.runningTime;

FixtureDef3D.loadMeshAsync(meshPath, (shape) => {
	loadTime = App.runningTime - loadStarted;
	if (!shape.built) {
		phase = "FAIL: cook";
		completed = true;
		captureDelay = 0;
		screenshot = App.saveScreenshot(`${output}/mesh-collider`);
		return;
	}
	const meshNode = Node3D();
	view.addChild(meshNode);
	const meshBody = makeBody3D(world, meshNode, shape, PhysicsWorld3D.Static);
	meshBodyCreated = meshBody !== undefined;
	sphereBody = makeSphereBody3D(world, sphereNode, 0.5, PhysicsWorld3D.Dynamic);
	FixtureDef3D.loadMeshAsync(meshPath, (cached) => {
		cacheHit = cached === shape && cached.built;
	});
	phase = "Simulating";
});

print("MESH_COLLIDER3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	if (!completed && meshBodyCreated && sphereBody !== undefined && sphereBody.position.y < 0.65) {
		stableFrames += 1;
		if (stableFrames >= 8) {
			world.raycast(Vec3(2.5, 3, 0), Vec3(2.5, -3, 0), (body) => {
				rayHit = body !== sphereBody;
				return true;
			});
			completed = true;
			phase = cacheHit && rayHit ? "PASS" : "FAIL";
			screenshot = App.saveScreenshot(`${output}/mesh-collider`);
			captureDelay = 0;
		}
	} else if (!meshBodyCreated) {
		stableFrames = 0;
	}

	if (!completed && elapsed > 8) {
		completed = true;
		phase = "FAIL: timeout";
		screenshot = App.saveScreenshot(`${output}/mesh-collider`);
		captureDelay = 0;
	}

	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 2) {
			captureDelay = -1;
			const summary = `MESH_COLLIDER3D_SUMMARY status=${phase === "PASS" ? "PASS" : "FAIL"} built=${meshBodyCreated} cache=${cacheHit} ray=${rayHit} y=${sphereBody?.position.y.toFixed(3) ?? "nan"} load=${loadTime.toFixed(3)} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(380, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.78);
	ImGui.Begin("JOLT-C Mesh Collider", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Phase: ${phase}`);
		ImGui.Text(`Content + cook: ${loadTime.toFixed(3)}s`);
		ImGui.Text(`Cache hit: ${cacheHit}`);
		ImGui.Text(`Mesh ray hit: ${rayHit}`);
		ImGui.Text(`Dynamic body Y: ${sphereBody?.position.y.toFixed(2) ?? "n/a"}`);
	});
	return false;
});
