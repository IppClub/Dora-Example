// @preview-file on clear
import {App, Camera3D, Content, Director, Model3D, Vec3, threadLoop} from "Dora";

type Case = {
	name: string;
	file: string;
	camera: [Vec3.Type, Vec3.Type];
	scale: number;
	sampleTime: number;
};

const outputDir = "/tmp/dora-3d-animation";
const resultPath = `${outputDir}/result.txt`;
const cases: Case[] = [
	{
		name: "ordinary-node",
		file: "Test/Model3D/Assets/Model/AnimatedTriangle/AnimatedTriangle.gltf",
		camera: [Vec3(0, 0, 3), Vec3(0, 0, 0)],
		scale: 1.5,
		sampleTime: 0.6,
	},
	{
		name: "interpolation",
		file: "Test/Model3D/Assets/Model/InterpolationTest/InterpolationTest.glb",
		camera: [Vec3(0, 0, 9), Vec3(0, 0, 0)],
		scale: 0.65,
		sampleTime: 1.25,
	},
	{
		name: "multi-skin",
		file: "Test/Model3D/Assets/Model/SimpleSkin/MultiSkin.gltf",
		camera: [Vec3(0, 1, 5), Vec3(0, 1, 0)],
		scale: 1.2,
		sampleTime: 1.5,
	},
];

const view = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);
view.setEnvironmentMap("Test/Model3D/Assets/Env/studio.png");
view.setEnvironmentIntensity(1.0, 1.8, 1.2);

let current: Model3D.Type | undefined;
let index = 0;
let phase = "setup";
let frames = 0;
let screenshotPath = "";
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`ANIMATION_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function setup(item: Case) {
	view.scene.removeAllChildren(true);
	current = Model3D(item.file);
	view.addChild(current);
	current.scale = Vec3(item.scale, item.scale, item.scale);
	const duration = current.play("", true);
	if (duration <= 0) {
		finish("FAIL", `${item.name}_missing_animation`);
		return false;
	}
	camera.lookAt(item.camera[0], item.camera[1]);
	emit(`ANIMATION_BEGIN case=${item.name} duration=${duration.toFixed(3)}`);
	return true;
}

Content.remove(resultPath);

threadLoop(() => {
	const item = cases[index];
	switch (phase) {
		case "setup":
			if (!setup(item)) return true;
			phase = "sample";
			break;
		case "sample":
			if (current && current.elapsed >= item.sampleTime) {
				current.pause();
				frames = 0;
				phase = "settle";
			}
			break;
		case "settle":
			if (++frames >= 8) {
				if (!current || !current.paused || view.stats.drawCalls <= 0) {
					finish("FAIL", `${item.name}_not_sampled`);
					return true;
				}
				const output = `${outputDir}/0${index + 1}-${item.name}`;
				Content.remove(`${output}.tga`);
				screenshotPath = App.saveScreenshot(output);
				frames = 0;
				phase = "wait";
			}
			break;
		case "wait":
			if (Content.exist(screenshotPath)) {
				emit(`ANIMATION_RESULT case=${item.name} elapsed=${current?.elapsed.toFixed(3)} screenshot=${screenshotPath}`);
				index += 1;
				if (index >= cases.length) {
					finish("PASS");
					return true;
				}
				phase = "setup";
			} else if (++frames > 180) {
				finish("FAIL", `${item.name}_screenshot_timeout`);
				return true;
			}
			break;
	}
	return false;
});
