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

const file = "Test/Model3D/Assets/Model/DamagedHelmet.glb";
const outputDir = "/tmp/dora-3d-async";
const resultPath = `${outputDir}/result.txt`;
const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
camera.lookAt(Vec3(0, 0.2, 3.2), Vec3(0, 0, 0));
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1.1);
const light = DirectionalLight3D();
light.color = Color3(0xfff1dc);
light.intensity = 4;
light.angleX = -20;
light.angleY = 25;
view.addChild(light);

Cache.unload(file);
Content.remove(resultPath);

let frame = 0;
let completed = 0;
let successes = 0;
let started = 0;
let startFrame = 0;
let requestsStarted = false;
let instantiated = false;
let model: Model3D.Type | undefined;
let instantiateSeconds = 0;
let screenshotPath = "";
let screenshotFrames = 0;
let screenshotReady = false;
let measureFrames = 0;
let maxDeltaMs = 0;
let maxDeltaFrame = 0;
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`ASYNC_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function request(index: number) {
	thread(() => {
		const success = Cache.loadAsync(file);
		if (success) successes += 1;
		completed += 1;
		emit(`ASYNC_CALLBACK index=${index} success=${success} frame=${frame}`);
	});
}

threadLoop(() => {
	frame += 1;
	if (!requestsStarted && frame >= 60) {
		requestsStarted = true;
		started = App.runningTime;
		startFrame = frame;
		maxDeltaMs = 0;
		maxDeltaFrame = 0;
		request(1);
		request(2);
	}
	if (!instantiated && completed === 2) {
		if (successes !== 2) {
			finish("FAIL", "preload_failed");
			return true;
		}
		const loadSeconds = App.runningTime - started;
		const loadFrames = frame - startFrame;
		const instantiateStart = App.runningTime;
		model = Model3D(file);
		instantiateSeconds = App.runningTime - instantiateStart;
		if (!model) {
			finish("FAIL", "cached_model_create_failed");
			return true;
		}
		view.addChild(model);
		model.scale = Vec3(0.95, 0.95, 0.95);
		model.angleY = 180;
		instantiated = true;
		measureFrames = 120;
		emit(
			`ASYNC_RESULT callbacks=${completed} frames=${loadFrames} total=${loadSeconds.toFixed(3)} ` +
			`instantiate=${instantiateSeconds.toFixed(6)}`,
		);
		if (loadFrames < 1) {
			finish("FAIL", "main_loop_did_not_advance");
			return true;
		}
	}
	if (
		instantiated &&
		measureFrames === 0 &&
		screenshotPath === "" &&
		view.stats.drawCalls > 0 &&
		frame - startFrame > 20
	) {
		screenshotPath = App.saveScreenshot(`${outputDir}/async-damaged-helmet`);
	}
	if (requestsStarted && (!instantiated || measureFrames > 0)) {
		const deltaMs = App.deltaTime * 1000;
		if (deltaMs > maxDeltaMs) {
			maxDeltaMs = deltaMs;
			maxDeltaFrame = frame;
		}
	}
	if (instantiated && measureFrames > 0) {
		measureFrames -= 1;
	}
	if (screenshotPath !== "") {
		screenshotFrames += 1;
		if (Content.exist(screenshotPath)) {
			screenshotReady = true;
		}
		if (screenshotFrames > 180) {
			finish("FAIL", "screenshot_timeout");
			return true;
		}
	}
	if (screenshotReady && measureFrames === 0) {
		emit(`ASYNC_SCREENSHOT path=${screenshotPath}`);
		emit(`ASYNC_FRAME_RESULT maxDeltaMs=${maxDeltaMs.toFixed(1)} frame=${maxDeltaFrame}`);
		if (maxDeltaMs > 250) {
			finish("FAIL", "upload_frame_budget_exceeded");
		} else {
			finish("PASS");
		}
		return true;
	}
	return false;
});
