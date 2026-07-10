// @preview-file on clear
import {
	App,
	Cache,
	Camera3D,
	Content,
	Director,
	Model3D,
	Object,
	RenderStats3D,
	Vec3,
	View,
	View3D,
	threadLoop,
} from "Dora";

type RegressionCase = {
	name: string;
	screenshot: string;
};

const outputDir = "/tmp/dora-3d-p0";
const resultPath = `${outputDir}/result.txt`;
const stressStartPath = `${outputDir}/stress-start`;
const stressEndPath = `${outputDir}/stress-end`;
const studioEnv = "Test/Model3D/Assets/Env/studio.png";
const warmEnv = "Test/Model3D/Assets/Env/warm.png";
const cases: RegressionCase[] = [
	{name: "duck", screenshot: "01-duck"},
	{name: "damaged-helmet", screenshot: "02-damaged-helmet"},
	{name: "specular", screenshot: "03-specular"},
	{name: "fox-animation", screenshot: "04-fox-animation"},
	{name: "alpha-mask-blend", screenshot: "05-alpha-mask-blend"},
	{name: "dual-view", screenshot: "06-dual-view"},
	{name: "frustum-culling", screenshot: "07-frustum-culling"},
];
const mainView = Director.entry;
const camera = Camera3D();
Director.pushCamera(camera);

let activeModels: Model3D.Type[] = [];
let auxiliaryViews: View3D.Type[] = [];
let fox: Model3D.Type | undefined;
let primaryStatsView: View3D.Type = mainView;
let secondaryStatsView: View3D.Type | undefined;
let caseIndex = 0;
let frameCount = 0;
let screenshotPath = "";
let screenshotWait = 0;
let phase = "setup";
let stressCycle = 0;
let stressBaseline: RenderStats3D | undefined;
let stressPeakInstances = 0;
let stressPeakNodes = 0;
let stressPeakVisuals = 0;
let stressBaselineObjects = 0;
let stressBaselineLuaKB = 0;
let failures: string[] = [];
let reportLines: string[] = [];

function emit(line: string) {
	print(line);
	reportLines.push(line);
}

function fail(message: string) {
	failures.push(message);
	emit(`P0_FAIL ${message}`);
}

function loadModel(
	view: View3D.Type,
	file: string,
	scale: number,
	position = Vec3(0, 0, 0),
	angleY = 0,
) {
	const model = Model3D(file);
	view.addChild(model);
	model.scale = Vec3(scale, scale, scale);
	model.position = position;
	model.angleY = angleY;
	activeModels.push(model);
	return model;
}

function setCamera(eye: Vec3.Type, target: Vec3.Type) {
	camera.lookAt(eye, target);
}

function cleanupCase() {
	mainView.scene.removeAllChildren(true);
	for (const view of auxiliaryViews) {
		view.removeFromParent(true);
	}
	activeModels = [];
	auxiliaryViews = [];
	fox = undefined;
	secondaryStatsView = undefined;
	primaryStatsView = mainView;
	View.frustumCulling = true;
}

function setupCase(index: number) {
	cleanupCase();
	const item = cases[index];
	emit(`P0_CASE_BEGIN case=${item.name}`);
	mainView.setEnvironmentMap(studioEnv);
	mainView.setEnvironmentIntensity(1.0, 1.8, 1.2);

	switch (item.name) {
		case "duck":
			setCamera(Vec3(0, 0.65, 3.0), Vec3(0, 0.25, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8, Vec3(0, 0, 0), 25);
			break;
		case "damaged-helmet":
			setCamera(Vec3(0, 0.2, 3.2), Vec3(0, 0, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/DamagedHelmet.glb", 0.95, Vec3(0, 0, 0), 180);
			break;
		case "specular":
			setCamera(Vec3(0, 0.55, 3.8), Vec3(0, 0.25, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/SpecularTest.glb", 2.5);
			break;
		case "fox-animation":
			setCamera(Vec3(0, 0.75, 3.2), Vec3(0, 0.45, 0));
			fox = loadModel(mainView, "Test/Model3D/Assets/Model/Fox.glb", 0.022, Vec3(0, 0, 0), -30);
			fox.play("Run", true);
			break;
		case "alpha-mask-blend":
			setCamera(Vec3(0, 0.45, 4.6), Vec3(0, 0.15, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/TransmissionTest.glb", 1.2, Vec3(-1.15, 0, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/ClearCoatTest.glb", 0.12, Vec3(1.15, 0, 0));
			break;
		case "dual-view": {
			mainView.scene.removeAllChildren(true);
			setCamera(Vec3(0, 0.65, 4.2), Vec3(0, 0.25, 0));
			const studioView = View3D();
			const warmView = View3D();
			Director.entry.addChild(studioView);
			Director.entry.addChild(warmView);
			studioView.setEnvironmentMap(studioEnv);
			studioView.setEnvironmentIntensity(1.0, 1.8, 1.2);
			warmView.setEnvironmentMap(warmEnv);
			warmView.setEnvironmentIntensity(1.0, 1.8, 1.2);
			loadModel(studioView, "Test/Model3D/Assets/Model/Duck.glb", 0.65, Vec3(-0.9, 0, 0), 25);
			loadModel(warmView, "Test/Model3D/Assets/Model/Duck.glb", 0.65, Vec3(0.9, 0, 0), -25);
			auxiliaryViews = [studioView, warmView];
			primaryStatsView = studioView;
			secondaryStatsView = warmView;
			break;
		}
		case "frustum-culling":
			setCamera(Vec3(0, 0.65, 3.0), Vec3(0, 0.25, 0));
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8, Vec3(0, 0, 0), 25);
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8, Vec3(100, 0, 0), 25);
			View.frustumCulling = true;
			break;
	}
}

function caseReady() {
	const expectedEnvironments = cases[caseIndex].name === "dual-view" ? 2 : 1;
	if (primaryStatsView.stats.environmentCount < expectedEnvironments) return false;
	if (cases[caseIndex].name !== "fox-animation") return true;
	if (!fox || fox.elapsed < 0.5) return false;
	fox.pause();
	return fox.paused;
}

function validateCurrentCase() {
	const item = cases[caseIndex];
	const stats = primaryStatsView.stats;
	if (stats.drawCalls <= 0) fail(`case=${item.name} reason=no_draw_calls`);
	if (stats.visibleVisuals <= 0) fail(`case=${item.name} reason=no_visible_visuals`);
	if (stats.triangles <= 0) fail(`case=${item.name} reason=no_triangles`);

	if (item.name === "fox-animation") {
		if (!fox || fox.elapsed < 0.5 || !fox.paused) {
			fail(`case=${item.name} reason=animation_not_sampled`);
		}
	} else if (item.name === "alpha-mask-blend") {
		if (stats.opaqueItems <= 0) fail(`case=${item.name} reason=no_mask_items`);
		if (stats.transparentItems <= 0) fail(`case=${item.name} reason=no_blend_items`);
	} else if (item.name === "dual-view") {
		const second = secondaryStatsView?.stats;
		if (!second || second.drawCalls <= 0) fail(`case=${item.name} reason=second_view_not_rendered`);
		if (stats.environmentCount < 2) fail(`case=${item.name} reason=environment_registry_not_isolated`);
	} else if (item.name === "frustum-culling") {
		if (stats.visibleVisuals <= 0 || stats.culledVisuals <= 0) {
			fail(`case=${item.name} reason=expected_visible_and_culled_visuals`);
		}
	}

	emit(
		`P0_RESULT case=${item.name} screenshot=${screenshotPath} ` +
		`sceneNodes=${stats.sceneNodes} visible=${stats.visibleVisuals} culled=${stats.culledVisuals} ` +
		`opaque=${stats.opaqueItems} transparent=${stats.transparentItems} draws=${stats.drawCalls} ` +
		`triangles=${stats.triangles} programs=${stats.programSwitches} materials=${stats.materialSwitches} ` +
		`textures=${stats.textureSwitches} meshes=${stats.meshSwitches} instances=${stats.modelInstanceCount} ` +
		`modelBytes=${stats.modelResidentBytes} meshBytes=${stats.meshResidentBytes} textureBytes=${stats.textureResidentBytes} ` +
		`collectUs=${stats.collectMicros} sortUs=${stats.sortMicros} submitUs=${stats.submitMicros} ` +
		`uploadCommands=${stats.uploadCommands} uploadBytes=${stats.uploadBytes} uploadUs=${stats.uploadMicros} ` +
		`uploadMaxUs=${stats.uploadMaxCommandMicros}`,
	);
}

function updateStressPeaks() {
	const stats = mainView.stats;
	stressPeakInstances = Math.max(stressPeakInstances, stats.modelInstanceCount);
	stressPeakNodes = Math.max(stressPeakNodes, stats.nodeCount);
	stressPeakVisuals = Math.max(stressPeakVisuals, stats.visualCount);
}

function setupStressScene(index: number) {
	mainView.setEnvironmentMap(studioEnv);
	mainView.setEnvironmentIntensity(1.0, 1.8, 1.2);
	switch (cases[index].name) {
		case "duck":
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8);
			break;
		case "damaged-helmet":
			loadModel(mainView, "Test/Model3D/Assets/Model/DamagedHelmet.glb", 0.95);
			break;
		case "specular":
			loadModel(mainView, "Test/Model3D/Assets/Model/SpecularTest.glb", 2.5);
			break;
		case "fox-animation": {
			const model = loadModel(mainView, "Test/Model3D/Assets/Model/Fox.glb", 0.022);
			model.play("Run", true);
			break;
		}
		case "alpha-mask-blend":
			loadModel(mainView, "Test/Model3D/Assets/Model/TransmissionTest.glb", 1.2);
			loadModel(mainView, "Test/Model3D/Assets/Model/ClearCoatTest.glb", 0.12);
			break;
		case "dual-view": {
			const first = View3D();
			const second = View3D();
			Director.entry.addChild(first);
			Director.entry.addChild(second);
			first.setEnvironmentMap(studioEnv);
			second.setEnvironmentMap(warmEnv);
			loadModel(first, "Test/Model3D/Assets/Model/Duck.glb", 0.65);
			loadModel(second, "Test/Model3D/Assets/Model/Duck.glb", 0.65);
			auxiliaryViews = [first, second];
			break;
		}
		case "frustum-culling":
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8);
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8, Vec3(100, 0, 0));
			break;
	}
}

function finish() {
	const status = failures.length === 0 ? "PASS" : "FAIL";
	emit(`P0_SUMMARY status=${status} cases=${cases.length} stressCycles=${stressCycle} failures=${failures.length}`);
	Content.save(resultPath, `${reportLines.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

Content.remove(resultPath);
Content.remove(stressStartPath);
Content.remove(stressEndPath);

threadLoop(() => {
	switch (phase) {
		case "setup":
			setupCase(caseIndex);
			frameCount = 0;
			phase = "ready";
			break;
		case "ready":
			if (caseReady()) {
				frameCount = 0;
				phase = "settle";
			}
			break;
		case "settle":
			frameCount += 1;
			if (frameCount >= 20) phase = "screenshot";
			break;
		case "screenshot": {
			const output = `${outputDir}/${cases[caseIndex].screenshot}`;
			Content.remove(`${output}.tga`);
			screenshotPath = App.saveScreenshot(output);
			if (screenshotPath === "") {
				fail(`case=${cases[caseIndex].name} reason=screenshot_request_failed`);
				phase = "next";
			} else {
				screenshotWait = 0;
				phase = "wait-screenshot";
			}
			break;
		}
		case "wait-screenshot":
			screenshotWait += 1;
			if (Content.exist(screenshotPath)) {
				validateCurrentCase();
				if (cases[caseIndex].name === "frustum-culling") {
					View.frustumCulling = false;
					frameCount = 0;
					phase = "frustum-off";
				} else {
					phase = "next";
				}
			} else if (screenshotWait > 180) {
				fail(`case=${cases[caseIndex].name} reason=screenshot_timeout`);
				phase = "next";
			}
			break;
		case "frustum-off":
			frameCount += 1;
			if (frameCount >= 4) {
				const stats = mainView.stats;
				if (stats.visibleVisuals !== 2 || stats.culledVisuals !== 0) {
					fail(`case=frustum-culling reason=disabled_switch visible=${stats.visibleVisuals} culled=${stats.culledVisuals}`);
				}
				emit(`P0_CULLING_SWITCH enabled=false visible=${stats.visibleVisuals} culled=${stats.culledVisuals}`);
				View.frustumCulling = true;
				phase = "next";
			}
			break;
		case "next":
			cleanupCase();
			caseIndex += 1;
			if (caseIndex < cases.length) {
				phase = "setup";
			} else {
				frameCount = 0;
				phase = "stress-baseline";
			}
			break;
		case "stress-baseline":
			frameCount += 1;
			if (frameCount >= 8) {
				collectgarbage("collect");
				stressBaseline = mainView.stats;
				stressBaselineObjects = Object.count;
				stressBaselineLuaKB = collectgarbage("count");
				Content.save(stressStartPath, "start\n");
				if (stressBaseline.drawCalls !== 0) {
					fail(`empty-scene reason=unexpected_3d_draw_calls draws=${stressBaseline.drawCalls}`);
				}
				emit(
					`P0_STRESS_BASELINE nodes=${stressBaseline.nodeCount} visuals=${stressBaseline.visualCount} ` +
					`instances=${stressBaseline.modelInstanceCount} models=${stressBaseline.modelCount} ` +
					`objects=${stressBaselineObjects} luaKB=${stressBaselineLuaKB.toFixed(1)}`,
				);
				phase = "stress-create";
			}
			break;
		case "stress-create":
			setupStressScene(stressCycle % cases.length);
			updateStressPeaks();
			phase = "stress-remove";
			break;
		case "stress-remove":
			updateStressPeaks();
			cleanupCase();
			stressCycle += 1;
			if (stressCycle < 300) {
				phase = "stress-create";
			} else {
				frameCount = 0;
				phase = "stress-verify";
			}
			break;
		case "stress-verify":
			frameCount += 1;
			if (frameCount >= 12 && stressBaseline) {
				collectgarbage("collect");
				const stats = mainView.stats;
				const objectCount = Object.count;
				const luaKB = collectgarbage("count");
				if (stats.modelInstanceCount !== stressBaseline.modelInstanceCount) {
					fail(`stress reason=instance_leak baseline=${stressBaseline.modelInstanceCount} actual=${stats.modelInstanceCount}`);
				}
				if (stats.nodeCount !== stressBaseline.nodeCount) {
					fail(`stress reason=node_leak baseline=${stressBaseline.nodeCount} actual=${stats.nodeCount}`);
				}
				if (stats.visualCount !== stressBaseline.visualCount) {
					fail(`stress reason=visual_leak baseline=${stressBaseline.visualCount} actual=${stats.visualCount}`);
				}
				if (objectCount > stressBaselineObjects + 2) {
					fail(`stress reason=cpp_object_growth baseline=${stressBaselineObjects} actual=${objectCount}`);
				}
				emit(
					`P0_STRESS_RESULT cycles=${stressCycle} nodes=${stats.nodeCount} visuals=${stats.visualCount} ` +
					`instances=${stats.modelInstanceCount} models=${stats.modelCount} peakNodes=${stressPeakNodes} ` +
					`peakVisuals=${stressPeakVisuals} peakInstances=${stressPeakInstances} objects=${objectCount} ` +
					`luaKB=${luaKB.toFixed(1)} luaDeltaKB=${(luaKB - stressBaselineLuaKB).toFixed(1)}`,
				);
				Content.save(stressEndPath, "end\n");
				Cache.removeUnused();
				frameCount = 0;
				phase = "cache-verify";
			}
			break;
		case "cache-verify":
			frameCount += 1;
			if (frameCount >= 12) {
				const stats = mainView.stats;
				if (
					stats.nodeCount > 1 ||
					stats.visualCount !== 0 ||
					stats.modelCount !== 0 ||
					stats.modelInstanceCount !== 0 ||
					stats.meshCount !== 0 ||
					stats.materialCount !== 0 ||
					stats.animationCount !== 0
				) {
					fail(
						`cache reason=registry_not_empty nodes=${stats.nodeCount} visuals=${stats.visualCount} ` +
						`models=${stats.modelCount} instances=${stats.modelInstanceCount} meshes=${stats.meshCount} ` +
						`materials=${stats.materialCount} animations=${stats.animationCount}`,
					);
				}
				emit(
					`P0_CACHE_RESULT nodes=${stats.nodeCount} visuals=${stats.visualCount} models=${stats.modelCount} ` +
					`meshes=${stats.meshCount} materials=${stats.materialCount} textures=${stats.textureCount} ` +
					`animations=${stats.animationCount} instances=${stats.modelInstanceCount}`,
				);
				finish();
				return true;
			}
			break;
	}
	return false;
});
