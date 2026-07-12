// @preview-file on clear
import {
	App,
	Camera3D,
	Color,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	MaterialAlphaMode3D,
	Model3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(0, 2.2, 8), Vec3(0, 1, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0.2, 0, 1);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -35;
light.angleY = 25;
view.addChild(light);

const file = "Test/Model3D/Assets/Model/Duck.glb";
const changed = Model3D(file);
changed.position = Vec3(-1.5, 0, 0);
view.addChild(changed);

const original = Model3D(file);
original.position = Vec3(1.5, 0, 0);
view.addChild(original);

const changedMaterial = changed.getMaterial(0);
const originalMaterial = original.getMaterial(0);
if (!changedMaterial || !originalMaterial) {
	error("Duck material slot 0 is missing");
}

const originalColor = originalMaterial.baseColor.toARGB();
const originalMetallic = originalMaterial.metallic;
const originalRoughness = originalMaterial.roughness;

changedMaterial.baseColor = Color(0xffff4040);
changedMaterial.emissive = Color3(0x220000);
changedMaterial.metallic = 1;
changedMaterial.roughness = 0.15;
changedMaterial.alphaMode = MaterialAlphaMode3D.Opaque;
changedMaterial.alphaCutoff = 0.45;
changedMaterial.clearNormalTexture();

const copyOnWriteValid = changed.materialCount === 1
	&& original.materialCount === 1
	&& changedMaterial.baseColor.toARGB() === 0xffff4040
	&& Math.abs(changedMaterial.metallic - 1) < 0.001
	&& Math.abs(changedMaterial.roughness - 0.15) < 0.001
	&& originalMaterial.baseColor.toARGB() === originalColor
	&& Math.abs(originalMaterial.metallic - originalMetallic) < 0.001
	&& Math.abs(originalMaterial.roughness - originalRoughness) < 0.001;

let elapsed = 0;
let status = "Pending";
threadLoop(() => {
	elapsed += App.deltaTime;
	if (status === "Pending" && elapsed >= 1.5) {
		status = copyOnWriteValid ? "PASS" : "FAIL";
		const screenshot = App.saveScreenshot("/tmp/dora-3d-material/material-runtime");
		const summary = `MATERIAL3D_SUMMARY status=${status} slots=${changed.materialCount} changedColor=${changedMaterial.baseColor.toARGB()} originalColor=${originalMaterial.baseColor.toARGB()} changedMetallic=${changedMaterial.metallic.toFixed(2)} originalMetallic=${originalMaterial.metallic.toFixed(2)} changedRoughness=${changedMaterial.roughness.toFixed(2)} originalRoughness=${originalMaterial.roughness.toFixed(2)} screenshot=${screenshot}`;
		Content.save("/tmp/dora-3d-material/summary.txt", summary);
		print(summary);
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(470, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.8);
	ImGui.Begin("Material3D Copy-on-write", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Material slots: ${changed.materialCount}`);
		ImGui.Text(`Changed: metallic ${changedMaterial.metallic.toFixed(2)}, roughness ${changedMaterial.roughness.toFixed(2)}`);
		ImGui.Text(`Original: metallic ${originalMaterial.metallic.toFixed(2)}, roughness ${originalMaterial.roughness.toFixed(2)}`);
		ImGui.Text("Left instance changed, right instance unchanged");
		ImGui.Text(`Verification: ${status}`);
	});
	return false;
});
