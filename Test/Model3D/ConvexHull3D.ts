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
	FixtureDef3DType,
	PhysicsWorld3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const output = "/tmp/dora-3d-convex-hull";
const modelPath = "Test/Model3D/Assets/Model/Duck.glb";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(7, 5, 10), Vec3(0, 1, 0));
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

const floorNode = Node3D();
floorNode.position = Vec3(0, -0.5, 0);
view.addChild(floorNode);
makeBoxBody3D(world, floorNode, Vec3(7, 0.5, 4), PhysicsWorld3D.Static);

const hullNode = Node3D();
hullNode.position = Vec3(0, 4, 0);
view.addChild(hullNode);
const duck = Model3D(modelPath);
hullNode.addChild(duck);

let phase = "Loading convex hull through Content";
let hullShape: FixtureDef3DType | undefined;
let hullBody: Body3DType | undefined;
let hullBuilt = false;
let cacheHit = false;
let cacheIsolated = false;
let dynamicCreated = false;
let rotated = false;
let rayHit = false;
let elapsed = 0;
let loadTime = 0;
let stableFrames = 0;
let completed = false;
let captureDelay = -1;
let screenshot = "";
const loadStarted = App.runningTime;

FixtureDef3D.loadConvexHullAsync(modelPath, (shape) => {
	loadTime = App.runningTime - loadStarted;
	hullShape = shape;
	hullBuilt = shape.built;
	if (!hullBuilt) {
		phase = "FAIL: hull cook";
		completed = true;
		captureDelay = 0;
		return;
	}
	FixtureDef3D.loadConvexHullAsync(modelPath, (cached) => {
		cacheHit = cached === shape && cached.built;
	});
	FixtureDef3D.loadMeshAsync(modelPath, (mesh) => {
		cacheIsolated = mesh !== shape && mesh.built;
	});
	hullBody = makeBody3D(world, hullNode, shape, PhysicsWorld3D.Dynamic);
	dynamicCreated = hullBody !== undefined;
	hullBody.angularVelocity = Vec3(0.4, 1.2, 0.25);
	phase = "Dynamic hull falling";
});

print("CONVEX_HULL3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	rotated = rotated || Math.abs(hullNode.angles.y) > 5 || Math.abs(hullNode.angles.x) > 5;
	if (
		!completed
		&& hullBody !== undefined
		&& elapsed > 1
		&& hullBody.position.y < 2
		&& Math.abs(hullBody.linearVelocity.y) < 0.08
	) {
		stableFrames += 1;
		if (stableFrames >= 20) {
			const position = hullBody.position;
			world.raycast(Vec3(position.x, position.y + 5, position.z), Vec3(position.x, position.y - 5, position.z), (body) => {
				rayHit = body === hullBody;
				return true;
			});
			completed = true;
			phase = hullBuilt && cacheHit && cacheIsolated && dynamicCreated && rotated && rayHit ? "PASS" : "FAIL";
			screenshot = App.saveScreenshot(`${output}/convex-hull`);
			captureDelay = 0;
		}
	} else if (!dynamicCreated) {
		stableFrames = 0;
	}

	if (!completed && elapsed > 12) {
		completed = true;
		phase = "FAIL: timeout";
		screenshot = App.saveScreenshot(`${output}/convex-hull`);
		captureDelay = 0;
	}

	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 2) {
			captureDelay = -1;
			const summary = `CONVEX_HULL3D_SUMMARY status=${phase === "PASS" ? "PASS" : "FAIL"} built=${hullBuilt} cache=${cacheHit} isolated=${cacheIsolated} dynamic=${dynamicCreated} rotated=${rotated} ray=${rayHit} y=${hullBody?.position.y.toFixed(3) ?? "nan"} load=${loadTime.toFixed(3)} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(380, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.78);
	ImGui.Begin("JOLT-C Dynamic Convex Hull", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Phase: ${phase}`);
		ImGui.Text(`Content + cook: ${loadTime.toFixed(3)}s`);
		ImGui.Text(`Hull built/cache: ${hullBuilt}/${cacheHit}`);
		ImGui.Text(`Mesh cache isolated: ${cacheIsolated}`);
		ImGui.Text(`Dynamic/rotated/ray: ${dynamicCreated}/${rotated}/${rayHit}`);
		ImGui.Text(`Body Y: ${hullBody?.position.y.toFixed(2) ?? "n/a"}`);
	});
	return false;
});
