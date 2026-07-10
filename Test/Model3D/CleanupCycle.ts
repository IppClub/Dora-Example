// @preview-file on clear
import { App, Camera3D, Director, Model3D, Vec3, View3D, threadLoop } from "Dora";

type CleanupCase = {
	name: string;
	file: string;
	scale: number;
	animation?: string;
};

const cases: CleanupCase[] = [
	{name: "Specular", file: "Test/Model3D/Assets/Model/SpecularTest.glb", scale: 1.0},
	{name: "Clearcoat", file: "Test/Model3D/Assets/Model/ClearCoatTest.glb", scale: 1.0},
	{name: "Helmet", file: "Test/Model3D/Assets/Model/DamagedHelmet.glb", scale: 1.8},
	{name: "Fox", file: "Test/Model3D/Assets/Model/Fox.glb", scale: 0.015, animation: "Run"},
];

const view = View3D();
Director.entry.addChild(view);

const camera = Camera3D();
camera.lookAt(Vec3(0, 0.45, 4.0), Vec3(0, 0.15, 0));
Director.pushCamera(camera);

view.setEnvironmentMap("Test/Model3D/Assets/Env/warm.png");
view.setEnvironmentIntensity(1.0, 1.8, 1.2);

let model: Model3D.Type | undefined;
let index = 0;
let elapsed = 0;
let switches = 0;

function loadNext() {
	if (model) {
		model.removeFromParent(true);
		model = undefined;
	}
	index = index % cases.length;
	const item = cases[index];
	index += 1;

	const start = App.runningTime;
	model = Model3D(item.file);
	assert(model !== undefined, `failed to load ${item.file}`);
	view.scene.addChild(model);
	model.scaleX = item.scale;
	model.scaleY = item.scale;
	model.scaleZ = item.scale;
	if (item.animation) {
		model.play(item.animation, true);
	}
	switches += 1;
	print(`cleanup_cycle switch=${switches} case=${item.name} load=${(App.runningTime - start).toFixed(3)}`);
}

loadNext();

threadLoop(() => {
	elapsed += App.deltaTime;
	if (model) {
		model.angleY = model.angleY + App.deltaTime * 30;
	}
	if (elapsed > 0.8) {
		elapsed = 0;
		loadNext();
	}
	return false;
});
