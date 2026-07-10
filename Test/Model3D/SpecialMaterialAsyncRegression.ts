// @preview-file on clear
import {
	App,
	Cache,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Vec3,
	thread,
	threadLoop,
} from "Dora";

type Case = {
	name: string;
	file: string;
	scale: number;
	camera: [number, number, number, number, number, number];
};

const cases: Case[] = [
	{
		name: "anisotropy-packed",
		file: "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb",
		scale: 1.2,
		camera: [0, 0.35, 3.6, 0, 0.1, 0],
	},
	{
		name: "thickness-sheen-packed",
		file: "Test/Model3D/Assets/Model/SheenVolume/SheenVolume.gltf",
		scale: 25,
		camera: [0, 0.35, 3.4, 0, 0.2, 0],
	},
];

const outputDir = "/tmp/dora-3d-special-async";
const resultPath = `${outputDir}/result.txt`;
const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1.1);
const light = DirectionalLight3D();
light.color = Color3(0xfff1dc);
light.intensity = 4;
light.angleX = -20;
light.angleY = 25;
view.addChild(light);

let frame = 0;
let caseIndex = -1;
let state: "warmup" | "loading" | "measure" | "screenshot" | "done" = "warmup";
let stateFrames = 0;
let loadStart = 0;
let maxDeltaMs = 0;
let maxDeltaFrame = 0;
let screenshotPath = "";
let model: Model3D.Type | undefined;
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	state = "done";
	emit(`SPECIAL_ASYNC_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function startNextCase() {
	if (model) {
		model.removeFromParent(true);
		model = undefined;
	}
	caseIndex += 1;
	if (caseIndex >= cases.length) {
		finish("PASS");
		return;
	}
	const item = cases[caseIndex];
	Cache.unload(item.file);
	const [ex, ey, ez, tx, ty, tz] = item.camera;
	camera.lookAt(Vec3(ex, ey, ez), Vec3(tx, ty, tz));
	maxDeltaMs = 0;
	maxDeltaFrame = 0;
	loadStart = App.runningTime;
	state = "loading";
	emit(`SPECIAL_ASYNC_BEGIN case=${item.name}`);
	thread(() => {
		if (!Cache.loadAsync(item.file)) {
			finish("FAIL", `${item.name}_load_failed`);
			return;
		}
		model = Model3D(item.file);
		if (!model) {
			finish("FAIL", `${item.name}_instantiate_failed`);
			return;
		}
		model.scale = Vec3(item.scale, item.scale, item.scale);
		view.addChild(model);
		state = "measure";
		stateFrames = 120;
		emit(
			`SPECIAL_ASYNC_READY case=${item.name} total=${(App.runningTime - loadStart).toFixed(3)}`,
		);
	});
}

Content.remove(resultPath);

threadLoop(() => {
	frame += 1;
	if (state === "done") return true;
	if (state === "warmup") {
		stateFrames += 1;
		if (stateFrames >= 60) startNextCase();
		return false;
	}
	if (state === "loading" || state === "measure") {
		const deltaMs = App.deltaTime * 1000;
		if (deltaMs > maxDeltaMs) {
			maxDeltaMs = deltaMs;
			maxDeltaFrame = frame;
		}
	}
	if (state === "measure") {
		stateFrames -= 1;
		if (stateFrames <= 0) {
			const item = cases[caseIndex];
			emit(
				`SPECIAL_ASYNC_FRAME case=${item.name} maxDeltaMs=${maxDeltaMs.toFixed(1)} frame=${maxDeltaFrame}`,
			);
			if (maxDeltaMs > 250) {
				finish("FAIL", `${item.name}_frame_budget_exceeded`);
				return true;
			}
			const prefix = caseIndex === 0 ? "01" : "02";
			screenshotPath = App.saveScreenshot(`${outputDir}/${prefix}-${item.name}`);
			state = "screenshot";
			stateFrames = 0;
		}
	}
	if (state === "screenshot") {
		stateFrames += 1;
		if (Content.exist(screenshotPath)) {
			emit(`SPECIAL_ASYNC_SCREENSHOT case=${cases[caseIndex].name} path=${screenshotPath}`);
			state = "warmup";
			stateFrames = 0;
		} else if (stateFrames > 180) {
			finish("FAIL", `${cases[caseIndex].name}_screenshot_timeout`);
			return true;
		}
	}
	return false;
});
