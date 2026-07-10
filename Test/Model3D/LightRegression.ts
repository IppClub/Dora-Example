// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	PointLight3D,
	Vec3,
	threadLoop,
} from "Dora";

const outputDir = "/tmp/dora-3d-light";
const resultPath = `${outputDir}/result.txt`;
const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
camera.lookAt(Vec3(0, 0.25, 3.2), Vec3(0, 0, 0));

let phase = "directional-setup";
let frames = 0;
let screenshotPath = "";
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function clearScene() {
	view.scene.removeAllChildren(true);
}

function loadHelmet() {
	const model = Model3D("Test/Model3D/Assets/Model/DamagedHelmet.glb");
	model.scale = Vec3(0.95, 0.95, 0.95);
	model.angleY = 180;
	view.addChild(model);
}

function setupDirectional() {
	clearScene();
	view.setEnvironmentMap("");
	view.setEnvironmentIntensity(0, 0, 1.1);
	loadHelmet();
	const light = DirectionalLight3D();
	light.color = Color3(0xfff1dc);
	light.intensity = 4.0;
	light.angleX = -20;
	light.angleY = 25;
	view.addChild(light);
}

function addPoint(position: Vec3.Type, color: number, intensity: number, range: number) {
	const light = PointLight3D();
	light.position = position;
	light.color = Color3(color);
	light.intensity = intensity;
	light.range = range;
	view.addChild(light);
}

function setupPointLights() {
	clearScene();
	view.setEnvironmentMap("");
	view.setEnvironmentIntensity(0, 0, 1.0);
	loadHelmet();
	addPoint(Vec3(-1.4, 1.1, 1.5), 0xff4c3c, 10, 4.5);
	addPoint(Vec3(1.4, 1.0, 1.2), 0x3c70ff, 10, 4.5);
	addPoint(Vec3(-1.2, -0.8, 0.8), 0x47ff76, 7, 4.0);
	addPoint(Vec3(1.2, -0.7, 0.7), 0xffb13c, 7, 4.0);
	addPoint(Vec3(0, 1.8, -1.0), 0xff45df, 5, 4.5);
	addPoint(Vec3(0, -1.5, -0.5), 0x48eaff, 5, 4.5);
}

function requestScreenshot(name: string) {
	const base = `${outputDir}/${name}`;
	Content.remove(`${base}.tga`);
	screenshotPath = App.saveScreenshot(base);
	frames = 0;
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`LIGHT_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

Content.remove(resultPath);

threadLoop(() => {
	switch (phase) {
		case "directional-setup":
			setupDirectional();
			frames = 0;
			phase = "directional-settle";
			break;
		case "directional-settle":
			if (++frames >= 30) {
				if (view.stats.drawCalls <= 0) return finish("FAIL", "directional_no_draws"), true;
				requestScreenshot("01-directional-none");
				phase = "directional-wait";
			}
			break;
		case "directional-wait":
			if (Content.exist(screenshotPath)) {
				emit(`LIGHT_RESULT case=directional-none screenshot=${screenshotPath}`);
				phase = "points-setup";
			} else if (++frames > 180) {
				finish("FAIL", "directional_screenshot_timeout");
				return true;
			}
			break;
		case "points-setup":
			setupPointLights();
			frames = 0;
			phase = "points-settle";
			break;
		case "points-settle":
			if (++frames >= 30) {
				if (view.stats.drawCalls <= 0) return finish("FAIL", "points_no_draws"), true;
				requestScreenshot("02-six-points");
				phase = "points-wait";
			}
			break;
		case "points-wait":
			if (Content.exist(screenshotPath)) {
				emit(`LIGHT_RESULT case=six-points screenshot=${screenshotPath}`);
				finish("PASS");
				return true;
			} else if (++frames > 180) {
				finish("FAIL", "points_screenshot_timeout");
				return true;
			}
			break;
	}
	return false;
});
