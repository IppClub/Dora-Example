// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const output = "/tmp/dora-3d-morph-target";
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(2.5, 2, 5), Vec3(0.5, 0.5, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0.15, 0, 1);
view.showAABB = true;

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -40;
light.angleY = 30;
view.addChild(light);

const model = Model3D("Test/Model3D/Assets/Model/SimpleMorph/SimpleMorph.gltf");
view.addChild(model);
const animationCount = model.animationCount;
const duration = model.play("", true);

let elapsed = 0;
let minWidth = Number.POSITIVE_INFINITY;
let maxWidth = 0;
let minHeight = Number.POSITIVE_INFINITY;
let maxHeight = 0;
let samples = 0;
let status = "Sampling";
let screenshot = "";
let completed = false;
let captureDelay = -1;

print("MORPH_TARGET3D_READY");
threadLoop(() => {
	elapsed += App.deltaTime;
	const min = model.getLocalBoundsMin();
	const max = model.getLocalBoundsMax();
	const width = max.x - min.x;
	const height = max.y - min.y;
	if (width > 0 && height > 0) {
		minWidth = Math.min(minWidth, width);
		maxWidth = Math.max(maxWidth, width);
		minHeight = Math.min(minHeight, height);
		maxHeight = Math.max(maxHeight, height);
		samples += 1;
	}

	if (!completed && elapsed >= Math.max(3, duration * 1.25)) {
		completed = true;
		const widthDelta = maxWidth - minWidth;
		const heightDelta = maxHeight - minHeight;
		status = animationCount > 0 && duration > 0 && samples > 30 && (widthDelta > 0.05 || heightDelta > 0.05)
			? "PASS"
			: "FAIL";
		screenshot = App.saveScreenshot(`${output}/morph-target`);
		captureDelay = 0;
	}

	if (!completed && elapsed > 12) {
		completed = true;
		status = "FAIL";
		screenshot = App.saveScreenshot(`${output}/morph-target`);
		captureDelay = 0;
	}

	if (captureDelay >= 0) {
		captureDelay += App.deltaTime;
		if (captureDelay >= 2) {
			captureDelay = -1;
			const summary = `MORPH_TARGET3D_SUMMARY status=${status} animations=${animationCount} duration=${duration.toFixed(3)} samples=${samples} width=${minWidth.toFixed(3)}..${maxWidth.toFixed(3)} height=${minHeight.toFixed(3)}..${maxHeight.toFixed(3)} screenshot=${screenshot}`;
			Content.save(`${output}/result.txt`, summary);
			print(summary);
		}
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(390, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.78);
	ImGui.Begin("glTF Morph Target", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`State: ${status}`);
		ImGui.Text(`Animations: ${animationCount}`);
		ImGui.Text(`Duration: ${duration.toFixed(3)}s`);
		ImGui.Text(`Width range: ${minWidth.toFixed(3)} .. ${maxWidth.toFixed(3)}`);
		ImGui.Text(`Height range: ${minHeight.toFixed(3)} .. ${maxHeight.toFixed(3)}`);
		ImGui.Text(`Samples: ${samples}`);
	});
	return false;
});
