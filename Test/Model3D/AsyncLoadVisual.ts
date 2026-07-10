// @preview-file on clear
import {
	App,
	Cache,
	Camera3D,
	Color3,
	DirectionalLight3D,
	Director,
	Model3D,
	Vec2,
	Vec3,
	thread,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const file = "Test/Model3D/Assets/Model/DamagedHelmet.glb";
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

type State = "Waiting" | "Loading" | "Ready" | "Failed";

let state: State = "Waiting";
let frame = 0;
let autoStartFrames = 60;
let loadStart = 0;
let loadSeconds = 0;
let callbackFrame = 0;
let instantiateSeconds = 0;
let currentDeltaMs = 0;
let maxDeltaMs = 0;
let maxDeltaFrame = 0;
let freezeCount = 0;
let postReadyFrames = 0;
let model: Model3D.Type | undefined;

function clearModel() {
	if (model) {
		model.removeFromParent(true);
		model = undefined;
	}
}

function startAsyncLoad() {
	if (state === "Loading") return;
	clearModel();
	Cache.unload(file);
	state = "Loading";
	loadStart = App.runningTime;
	loadSeconds = 0;
	callbackFrame = 0;
	instantiateSeconds = 0;
	maxDeltaMs = 0;
	maxDeltaFrame = 0;
	freezeCount = 0;
	postReadyFrames = 0;
	print(`ASYNC_VISUAL_BEGIN frame=${frame} file=${file}`);

	thread(() => {
		const loaded = Cache.loadAsync(file);
		callbackFrame = frame;
		loadSeconds = App.runningTime - loadStart;
		if (!loaded) {
			state = "Failed";
			print(`ASYNC_VISUAL_FAILED frame=${frame}`);
			return;
		}

		const instantiateStart = App.runningTime;
		model = Model3D(file);
		instantiateSeconds = App.runningTime - instantiateStart;
		if (!model) {
			state = "Failed";
			print(`ASYNC_VISUAL_INSTANTIATE_FAILED frame=${frame}`);
			return;
		}
		model.scale = Vec3(0.95, 0.95, 0.95);
		model.angleY = 180;
		view.addChild(model);
		state = "Ready";
		postReadyFrames = 120;
		print(
			`ASYNC_VISUAL_READY callbackFrame=${callbackFrame} total=${loadSeconds.toFixed(3)} ` +
			`instantiate=${instantiateSeconds.toFixed(6)} maxDeltaMs=${maxDeltaMs.toFixed(1)}`,
		);
	});
}

const spinner = ["|", "/", "-", "\\"];
const windowFlags = [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing];

threadLoop(() => {
	frame += 1;
	currentDeltaMs = App.deltaTime * 1000;
	if (state === "Loading" || postReadyFrames > 0) {
		if (currentDeltaMs > maxDeltaMs) {
			maxDeltaMs = currentDeltaMs;
			maxDeltaFrame = frame;
		}
		if (currentDeltaMs > 100) freezeCount += 1;
		if (state === "Ready") postReadyFrames -= 1;
	}
	if (state === "Waiting") {
		autoStartFrames -= 1;
		if (autoStartFrames <= 0) startAsyncLoad();
	}
	if (model) model.angleY += App.deltaTime * 20;

	const {width} = App.visualSize;
	ImGui.SetNextWindowPos(Vec2(width - 16, 16), SetCond.FirstUseEver, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(430, 0), SetCond.FirstUseEver);
	ImGui.SetNextWindowBgAlpha(0.88);
	ImGui.Begin("Model3D Async Load Probe", windowFlags, () => {
		ImGui.Text(`Heartbeat: ${spinner[Math.floor(frame / 8) % spinner.length]}  frame=${frame}`);
		ImGui.Text(`State: ${state}`);
		ImGui.Separator();
		ImGui.Text(`Current frame: ${currentDeltaMs.toFixed(1)} ms`);
		ImGui.Text(`Max load + 2s: ${maxDeltaMs.toFixed(1)} ms`);
		ImGui.Text(`Max frame: ${maxDeltaFrame}`);
		ImGui.Text(`Frames over 100 ms: ${freezeCount}`);
		ImGui.Text(`Async total: ${loadSeconds.toFixed(3)} s`);
		ImGui.Text(`Callback frame: ${callbackFrame}`);
		ImGui.Text(`Cached Model3D(): ${instantiateSeconds.toFixed(6)} s`);
		ImGui.Separator();
		ImGui.TextWrapped("The heartbeat must keep moving during CPU parsing. A pause immediately before Ready is GPU finalize on the main thread.");
		if (ImGui.Button(state === "Loading" ? "Loading..." : "Unload + Load Async", Vec2(210, 32))) {
			startAsyncLoad();
		}
	});
	return false;
});
