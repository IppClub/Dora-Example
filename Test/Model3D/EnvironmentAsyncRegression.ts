// @preview-file on clear
import {
	App,
	Camera3D,
	Content,
	Director,
	Model3D,
	Vec3,
	threadLoop,
} from "Dora";

const outputDir = "/tmp/dora-3d-environment-async";
const resultPath = `${outputDir}/result.txt`;
const environments = [
	"Test/Model3D/Assets/Env/studio.png",
	"Test/Model3D/Assets/Env/warm.png",
];
const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
camera.lookAt(Vec3(0, 0.65, 3.0), Vec3(0, 0.25, 0));
view.setEnvironmentMap("");
view.setEnvironmentIntensity(1.0, 1.8, 1.2);

const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
view.addChild(duck);
duck.scale = Vec3(0.8, 0.8, 0.8);
duck.angleY = 25;

Content.remove(resultPath);
const results: string[] = [];
let frame = 0;
let environmentIndex = -1;
let expectedCount = 0;
let startedFrame = 0;
let startedTime = 0;
let maxDeltaMs = 0;
let maxDeltaFrame = 0;
let screenshotPath = "";
let screenshotWait = 0;

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`ENV_ASYNC_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function beginEnvironment(index: number) {
	environmentIndex = index;
	expectedCount = index + 1;
	startedFrame = frame;
	startedTime = App.runningTime;
	maxDeltaMs = 0;
	maxDeltaFrame = frame;
	screenshotPath = "";
	screenshotWait = 0;
	const accepted = view.setEnvironmentMap(environments[index]);
	emit(`ENV_ASYNC_BEGIN index=${index} accepted=${accepted} frame=${frame}`);
	if (!accepted) finish("FAIL", `request_rejected_${index}`);
}

threadLoop(() => {
	frame += 1;
	if (environmentIndex < 0 && frame >= 60) beginEnvironment(0);

	if (environmentIndex >= 0 && screenshotPath === "") {
		const deltaMs = App.deltaTime * 1000;
		if (deltaMs > maxDeltaMs) {
			maxDeltaMs = deltaMs;
			maxDeltaFrame = frame;
		}
		if (view.stats.environmentCount >= expectedCount) {
			const stats = view.stats;
			emit(
				`ENV_ASYNC_READY index=${environmentIndex} frames=${frame - startedFrame} ` +
				`total=${(App.runningTime - startedTime).toFixed(3)} maxDeltaMs=${maxDeltaMs.toFixed(1)} ` +
				`maxFrame=${maxDeltaFrame} environmentCount=${stats.environmentCount} ` +
				`uploadCommands=${stats.uploadCommands} uploadBytes=${stats.uploadBytes} ` +
				`uploadMaxUs=${stats.uploadMaxCommandMicros}`,
			);
			screenshotPath = App.saveScreenshot(
				`${outputDir}/${environmentIndex === 0 ? "01-studio" : "02-warm"}`,
			);
		}
		if (frame - startedFrame > 900) {
			finish("FAIL", `environment_timeout_${environmentIndex}`);
			return true;
		}
	}

	if (screenshotPath !== "") {
		screenshotWait += 1;
		if (Content.exist(screenshotPath)) {
			emit(`ENV_ASYNC_SCREENSHOT index=${environmentIndex} path=${screenshotPath}`);
			if (maxDeltaMs > 250) {
				finish("FAIL", `frame_budget_${environmentIndex}`);
				return true;
			}
			if (environmentIndex === 0) {
				beginEnvironment(1);
			} else {
				finish("PASS");
				return true;
			}
		} else if (screenshotWait > 180) {
			finish("FAIL", `screenshot_timeout_${environmentIndex}`);
			return true;
		}
	}
	return false;
});
