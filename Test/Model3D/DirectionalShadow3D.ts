// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Vec3,
	threadLoop,
} from "Dora";

const outputDir = "/tmp/dora-3d-shadow";
const resultPath = `${outputDir}/result.txt`;
const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
camera.lookAt(Vec3(4.8, 3.7, 6.5), Vec3(0, 0.25, 0));
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0.18, 0.05, 1.0);

const ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
ground.position = Vec3(0, -0.72, 0);
view.addChild(ground);

const alphaCaster = Model3D("Test/Model3D/Assets/Model/AlphaMaskCaster.gltf");
// The source plane spans z=-3..3. After the X rotation and 0.22 scale,
// y=-0.06 places its lower edge exactly on the ground at y=-0.72.
alphaCaster.position = Vec3(2.2, -0.06, -1.15);
alphaCaster.scale = Vec3(0.22, 0.22, 0.22);
alphaCaster.angleX = 90;
view.addChild(alphaCaster);

const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
duck.position = Vec3(-1.15, -0.7, 0);
duck.scale = Vec3(0.8, 0.8, 0.8);
duck.angleY = -25;
view.addChild(duck);

const fox = Model3D("Test/Model3D/Assets/Model/Fox.glb");
fox.position = Vec3(1.0, -0.7, 0.2);
fox.scale = Vec3(0.018, 0.018, 0.018);
fox.angleY = 145;
fox.play("Walk", true);
view.addChild(fox);

const light = DirectionalLight3D();
light.color = Color3(0xfff0d8);
light.intensity = 4.5;
light.angleX = -48;
light.angleY = -35;
light.shadowBias = 0.004;
light.shadowNormalBias = 0.02;
view.addChild(light);

let phase = "without-shadow";
let frames = 0;
let screenshotPath = "";
const results: string[] = [];

function capture(name: string) {
	const base = `${outputDir}/${name}`;
	Content.remove(`${base}.tga`);
	screenshotPath = App.saveScreenshot(base);
	frames = 0;
}

function finish(status: "PASS" | "FAIL", reason = "") {
	const summary = `SHADOW_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`;
	print(summary);
	results.push(summary);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

Content.remove(resultPath);
threadLoop(() => {
	switch (phase) {
		case "without-shadow":
			if (++frames >= 45) {
				fox.pause();
				capture("01-disabled");
				phase = "wait-disabled";
			}
			break;
		case "wait-disabled":
			if (Content.exist(screenshotPath)) {
				results.push(`SHADOW_RESULT case=disabled screenshot=${screenshotPath}`);
				light.castShadow = true;
				frames = 0;
				phase = "with-shadow";
			} else if (++frames > 180) {
				finish("FAIL", "disabled_screenshot_timeout");
				return true;
			}
			break;
		case "with-shadow":
			if (++frames >= 45) {
				capture("02-enabled");
				phase = "wait-enabled";
			}
			break;
		case "wait-enabled":
			if (Content.exist(screenshotPath)) {
				results.push(`SHADOW_RESULT case=enabled screenshot=${screenshotPath}`);
				if (view.stats.drawCalls > 0) finish("PASS");
				else finish("FAIL", "no_draws");
				return true;
			} else if (++frames > 180) {
				finish("FAIL", "enabled_screenshot_timeout");
				return true;
			}
			break;
	}
	return false;
});
