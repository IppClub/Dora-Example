// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	DirectionalLight3D,
	Director,
	Model3D,
	Vec2,
	Vec3,
	View,
	sleep,
	thread,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const modelFile = "Test/Model3D/Assets/Model/Duck.glb";
const view = Director.entry;
const models: Model3D.Type[] = [];
let selected: Model3D.Type | undefined;
let selectedName = "None";
let loading = false;
let lastPoint = Vec2.zero;
let showAABB = true;

const camera = Camera3D();
camera.lookAt(Vec3(0, 1.1, 8), Vec3(0, 0.8, 0));
Director.pushCamera(camera);

view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);
view.showAABB = showAABB;

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 3.5;
light.angleX = -30;
light.angleY = 35;
view.addChild(light);

function select(model: Model3D.Type | undefined) {
	if (selected) selected.scale = Vec3(0.8, 0.8, 0.8);
	selected = model;
	selectedName = model?.tag ?? "None";
	if (selected) selected.scale = Vec3(1.0, 1.0, 1.0);
}

view.onTapped((touch) => {
	lastPoint = touch.viewLocation;
	select(view.pick(touch.viewLocation));
});

const placements = [
	{name: "Left", position: Vec3(-2.2, 0, 0), angle: 25},
	{name: "Center", position: Vec3(0, 0, 0), angle: 0},
	{name: "Right", position: Vec3(2.2, 0, 0), angle: -25},
];
for (const item of placements) {
	const model = Model3D(modelFile);
	model.tag = item.name;
	model.position = item.position;
	model.angleY = item.angle;
	model.scale = Vec3(0.8, 0.8, 0.8);
	view.addChild(model);
	models.push(model);
}
print(`PICKING_DEMO_READY models=${models.length} showAABB=${showAABB}`);
thread(() => {
	for (let i = 0; i < 30; i += 1) sleep();
	const stats = view.stats;
	print(`PICKING_DEMO_RENDER visible=${stats.visibleVisuals} draws=${stats.drawCalls}`);
});

threadLoop(() => {
	if (selected) selected.angleY += App.deltaTime * 45;

	ImGui.SetNextWindowPos(Vec2(View.size.width - 12, 12), SetCond.FirstUseEver, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(300, 0), SetCond.FirstUseEver);
	ImGui.SetNextWindowBgAlpha(0.7);
	ImGui.Begin("Model3D Picking", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`State: ${loading ? "Loading" : "Ready"}`);
		ImGui.Text(`Selected: ${selectedName}`);
		ImGui.Text(`View Point: ${lastPoint.x.toFixed(1)}, ${lastPoint.y.toFixed(1)}`);
		ImGui.Text(`Models: ${models.length}`);
		let changed = false;
		[changed, showAABB] = ImGui.Checkbox("Show AABB", showAABB);
		if (changed) view.showAABB = showAABB;
		if (ImGui.Button("Clear Selection", Vec2(-1, 30))) select(undefined);
	});

	return false;
});
