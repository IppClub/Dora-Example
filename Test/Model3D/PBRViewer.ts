// @preview-file on clear
import { App, Camera3D, Content, Director, Model3D, Vec2, Vec3, View, threadLoop } from "Dora";
import { SetCond, WindowFlag } from "ImGui";
import * as ImGui from "ImGui";

type Case = {
	name: string;
	file: string;
	description: string;
	scale: number;
	camera: [number, number, number, number, number, number];
	angleX?: number;
	angleY?: number;
	animation?: string;
};

type LightingProfile = {
	diffuse: number;
	specular: number;
	exposure: number;
};

const metalRoughPackage = Content.getFullPath("Test/Model3D/Assets/Model/MetalRoughSpheres.glb.zip");
if (Content.searchPaths.indexOf(metalRoughPackage) < 0) {
	Content.addSearchPath(metalRoughPackage);
}

const cases: Case[] = [
	{
		name: "Specular",
		file: "Test/Model3D/Assets/Model/SpecularTest.glb",
		description: "KHR_materials_specular and color/factor response.",
		scale: 1,
		camera: [0, 0.55, 3.8, 0, 0.25, 0],
	},
	{
		name: "Metal Rough",
		file: "MetalRoughSpheres.glb",
		description: "Metallic-roughness grid with texture-driven material values.",
		scale: 0.7,
		camera: [0, 0.4, 4.2, 0, 0.1, 0],
		angleX: 15,
	},
	{
		name: "Clearcoat",
		file: "Test/Model3D/Assets/Model/ClearCoatTest.glb",
		description: "KHR_materials_clearcoat factor, roughness, and normal texture.",
		scale: 1,
		camera: [0, 0.45, 3.8, 0, 0.1, 0],
		angleY: -20,
	},
	{
		name: "Transmission",
		file: "Test/Model3D/Assets/Model/TransmissionTest.glb",
		description: "KHR_materials_transmission with environment refraction approximation.",
		scale: 1,
		camera: [0, 0.5, 4.2, 0, 0.15, 0],
	},
	{
		name: "Volume",
		file: "Test/Model3D/Assets/Model/CompareVolume.glb",
		description: "KHR_materials_volume attenuation and thickness.",
		scale: 1,
		camera: [0, 0.45, 4.2, 0, 0.1, 0],
	},
	{
		name: "Sheen",
		file: "Test/Model3D/Assets/Model/SheenCloth/SheenCloth.gltf",
		description: "KHR_materials_sheen color and roughness texture.",
		scale: 1.2,
		camera: [0, 0.35, 3.2, 0, 0.2, 0],
		angleY: -20,
	},
	{
		name: "Anisotropy Strength",
		file: "Test/Model3D/Assets/Model/AnisotropyStrengthTest.glb",
		description: "KHR_materials_anisotropy strength sweep.",
		scale: 1.2,
		camera: [0, 0.35, 3.6, 0, 0.1, 0],
		angleX: 15,
	},
	{
		name: "Anisotropy Texture",
		file: "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb",
		description: "KHR_materials_anisotropy rotation and texture channels.",
		scale: 1.2,
		camera: [0, 0.35, 3.6, 0, 0.1, 0],
		angleX: 15,
	},
	{
		name: "Emissive Strength",
		file: "Test/Model3D/Assets/Model/EmissiveStrengthTest.glb",
		description: "KHR_materials_emissive_strength.",
		scale: 1.4,
		camera: [0, 0.15, 3, 0, 0, 0],
	},
	{
		name: "Unlit",
		file: "Test/Model3D/Assets/Model/UnlitTest.glb",
		description: "KHR_materials_unlit bypass path.",
		scale: 1.4,
		camera: [0, 0.1, 2.8, 0, 0, 0],
	},
	{
		name: "Damaged Helmet",
		file: "Test/Model3D/Assets/Model/DamagedHelmet.glb",
		description: "Real-world baseline asset using core PBR maps.",
		scale: 1.8,
		camera: [0, 0.2, 3.2, 0, 0, 0],
		angleY: 180,
	},
	{
		name: "Fox Animation",
		file: "Test/Model3D/Assets/Model/Fox.glb",
		description: "Skinned model and glTF animation playback.",
		scale: 0.015,
		camera: [0, 0.75, 3.2, 0, 0.45, 0],
		animation: "Run",
	},
	{
		name: "Frustum Culling",
		file: "Test/Model3D/Assets/Model/Duck.glb",
		description: "Render queue culling check using View.frustumCulling.",
		scale: 0.8,
		camera: [0, 0.65, 3.0, 0, 0.25, 0],
		angleY: 25,
	},
];

const testNames = cases.map(item => item.name);
const windowFlags = [
	WindowFlag.NoSavedSettings,
	WindowFlag.NoFocusOnAppearing,
];

const view = Director.entry;

const camera = Camera3D();
Director.pushCamera(camera);

let currentCase = 1;
let loadedCase = 0;
let currentModel: Model3D.Type | undefined;
let autoRotate = true;
let envIndex = 1;
let environmentLoaded = false;
let diffuseIntensity = 1.0;
let specularIntensity = 1.8;
let exposure = 1.2;
const noneLighting: LightingProfile = {diffuse: 1.0, specular: 1.0, exposure: 1.2};
const environmentLighting: LightingProfile = {diffuse: 1.0, specular: 1.8, exposure: 1.2};
let loadSeconds = 0;
let elapsed = 0;
let cameraDistance = 0;
let cameraHeight = 0;
let yaw = 0;
let animationSpeed = 1.0;
let pendingCase = 0;
let pendingFrames = 0;
let loadState = "Ready";
let frustumCulling = View.frustumCulling;

const environmentNames = ["None", "Studio", "Warm"];
const environmentFiles = [
	"Test/Model3D/Assets/Env/studio.png",
	"Test/Model3D/Assets/Env/warm.png",
];

function lightingProfile(index: number) {
	return index === 1 ? noneLighting : environmentLighting;
}

function saveLighting(index: number) {
	const lighting = lightingProfile(index);
	lighting.diffuse = diffuseIntensity;
	lighting.specular = specularIntensity;
	lighting.exposure = exposure;
}

function loadLighting(index: number) {
	const lighting = lightingProfile(index);
	diffuseIntensity = lighting.diffuse;
	specularIntensity = lighting.specular;
	exposure = lighting.exposure;
}

function applyEnvironment() {
	const start = App.runningTime;
	if (envIndex === 1) {
		environmentLoaded = view.setEnvironmentMap("");
	} else {
		environmentLoaded = view.setEnvironmentMap(environmentFiles[envIndex - 2]);
	}
	view.setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure);
	print(`PBRViewer environment ${environmentNames[envIndex - 1]} loaded=${environmentLoaded} time=${App.runningTime - start}`);
}

function applyCamera(item: Case) {
	const [eyeX, eyeY, eyeZ, atX, atY, atZ] = item.camera;
	const orbitX = Math.sin(yaw) * cameraDistance;
	const orbitZ = Math.cos(yaw) * cameraDistance;
	camera.lookAt(Vec3(eyeX + orbitX, eyeY + cameraHeight, eyeZ + orbitZ), Vec3(atX, atY, atZ));
}

function unloadModel() {
	if (currentModel) {
		currentModel.removeFromParent(true);
		currentModel = undefined;
	}
}

function requestLoadCase(index: number) {
	if (pendingCase === index && pendingFrames > 0) {
		return;
	}
	unloadModel();
	pendingCase = index;
	pendingFrames = 2;
	loadState = `Preparing ${cases[index - 1].name}`;
}

function loadCaseNow(index: number) {
	const item = cases[index - 1];
	const start = App.runningTime;
	loadState = `Loading ${item.name}`;
	currentModel = Model3D(item.file);
	loadSeconds = App.runningTime - start;
	loadedCase = index;
	elapsed = 0;
	yaw = 0;
	cameraDistance = 0;
	cameraHeight = 0;
	if (!currentModel) {
		loadState = "Failed";
		print(`PBRViewer failed to load ${item.file}`);
		return;
	}
	view.scene.addChild(currentModel);
	currentModel.scaleX = item.scale;
	currentModel.scaleY = item.scale;
	currentModel.scaleZ = item.scale;
	currentModel.angleX = item.angleX ?? 0;
	currentModel.angleY = item.angleY ?? 0;
	if (item.animation && currentModel.play) {
		currentModel.speed = animationSpeed;
		currentModel.play(item.animation, true);
	}
	applyCamera(item);
	loadState = "Ready";
	print(`PBRViewer case ${item.name} load=${loadSeconds} file=${item.file}`);
}

applyEnvironment();
requestLoadCase(currentCase);

threadLoop(() => {
	const deltaTime = App.deltaTime;
	if (pendingCase > 0) {
		pendingFrames -= 1;
		if (pendingFrames <= 0) {
			const index = pendingCase;
			pendingCase = 0;
			loadCaseNow(index);
		}
	}
	elapsed += deltaTime;
	const item = cases[loadedCase > 0 ? loadedCase - 1 : currentCase - 1];
	if (currentModel && autoRotate) {
		currentModel.angleY = (item.angleY ?? 0) + elapsed * 22.5;
	}
	if (loadedCase > 0) {
		applyCamera(item);
	}

	const {width} = App.visualSize;
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), SetCond.FirstUseEver, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(330, 0), SetCond.FirstUseEver);
	ImGui.SetNextWindowBgAlpha(0.42);
	ImGui.Begin("glTF PBR", windowFlags, () => {
		ImGui.Text("Model3D glTF PBR");
		ImGui.Separator();
		let changed = false;
		[changed, currentCase] = ImGui.Combo("Case", currentCase, testNames);
		if (changed) {
			requestLoadCase(currentCase);
		}

		const selected = cases[currentCase - 1];
		ImGui.TextWrapped(selected.description);
		ImGui.Text(`State: ${loadState}`);
		ImGui.Text(`Load: ${loadSeconds.toFixed(3)}s`);
		ImGui.Text(`File: ${selected.file}`);
		ImGui.Separator();

		[changed, autoRotate] = ImGui.Checkbox("Auto Rotate", autoRotate);
		[changed, frustumCulling] = ImGui.Checkbox("Frustum Culling", frustumCulling);
		if (changed) {
			View.frustumCulling = frustumCulling;
		}

		ImGui.PushItemWidth(-80, () => {
			[changed, cameraDistance] = ImGui.DragFloat("Orbit", cameraDistance, 0.02, -8, 8, "%.2f");
			[changed, cameraHeight] = ImGui.DragFloat("Height", cameraHeight, 0.02, -2, 2, "%.2f");
			[changed, yaw] = ImGui.DragFloat("Yaw", yaw, 0.01, -3.14, 3.14, "%.2f");
		});

		if (selected.animation && currentModel) {
			ImGui.Separator();
			ImGui.Text(`Animation: ${selected.animation}`);
			ImGui.Text(`Time: ${currentModel.elapsed.toFixed(2)} / ${currentModel.duration.toFixed(2)}`);
			ImGui.Text(`State: ${currentModel.playing ? currentModel.paused ? "Paused" : "Playing" : "Stopped"}`);
			ImGui.PushItemWidth(-80, () => {
				let speedChanged = false;
				[speedChanged, animationSpeed] = ImGui.DragFloat("Anim Speed", animationSpeed, 0.05, 0, 3, "%.2f");
				if (speedChanged) {
					currentModel!.speed = animationSpeed;
				}
			});
			if (ImGui.Button(currentModel.paused ? "Resume Anim" : "Pause Anim", Vec2(120, 30))) {
				if (currentModel.paused) {
					currentModel.resume();
				} else {
					currentModel.pause();
				}
			}
			ImGui.SameLine();
			if (ImGui.Button("Restart Anim", Vec2(120, 30))) {
				currentModel.play(selected.animation, true);
			}
		}

		ImGui.Separator();
		const previousEnvIndex = envIndex;
		[changed, envIndex] = ImGui.Combo("Env", envIndex, environmentNames);
		if (changed) {
			saveLighting(previousEnvIndex);
			loadLighting(envIndex);
			applyEnvironment();
		}
		ImGui.PushItemWidth(-80, () => {
			let envChanged = false;
			[envChanged, diffuseIntensity] = ImGui.DragFloat("Diffuse", diffuseIntensity, 0.05, 0, 4, "%.2f");
			if (envChanged) changed = true;
			[envChanged, specularIntensity] = ImGui.DragFloat("Specular", specularIntensity, 0.05, 0, 4, "%.2f");
			if (envChanged) changed = true;
			[envChanged, exposure] = ImGui.DragFloat("Exposure", exposure, 0.05, 0.1, 4, "%.2f");
			if (envChanged) changed = true;
		});
		if (changed) {
			saveLighting(envIndex);
			view.setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure);
		}
		if (ImGui.Button(loadedCase === currentCase ? "Reload" : "Load", Vec2(120, 30))) {
			requestLoadCase(currentCase);
		}
		ImGui.SameLine();
		if (ImGui.Button("Reset View", Vec2(120, 30))) {
			cameraDistance = 0;
			cameraHeight = 0;
			yaw = 0;
			applyCamera(item);
		}

		ImGui.Separator();
		const stats = view.stats;
		ImGui.Text(`Draws: ${stats.drawCalls}  Triangles: ${stats.triangles}`);
		ImGui.Text(`Visible: ${stats.visibleVisuals}  Culled: ${stats.culledVisuals}`);
		ImGui.Text(`Opaque: ${stats.opaqueItems}  Transparent: ${stats.transparentItems}`);
		ImGui.Text(`Program/Material: ${stats.programSwitches}/${stats.materialSwitches}`);
		ImGui.Text(`Texture/Mesh: ${stats.textureSwitches}/${stats.meshSwitches}`);
	});

	return false;
});
