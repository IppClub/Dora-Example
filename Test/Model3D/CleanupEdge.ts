// @preview-file on clear
import { App, Camera3D, Director, Model3D, Node3D, Vec3, View3D, threadLoop } from "Dora";

type CleanupCase = {
	name: string;
	file: string;
	scale: number;
	animation?: string;
};

type Node3DHierarchyState = {
	readonly hasChildren: boolean;
};

const cases: CleanupCase[] = [
	{name: "Specular", file: "Test/Model3D/Assets/Model/SpecularTest.glb", scale: 1.0},
	{name: "Helmet", file: "Test/Model3D/Assets/Model/DamagedHelmet.glb", scale: 1.8},
	{name: "Fox", file: "Test/Model3D/Assets/Model/Fox.glb", scale: 0.015, animation: "Run"},
];

const view = View3D();
Director.entry.addChild(view);

const camera = Camera3D();
camera.lookAt(Vec3(0, 0.45, 4.0), Vec3(0, 0.15, 0));
Director.pushCamera(camera);

view.setEnvironmentMap("Test/Model3D/Assets/Env/studio.png");
view.setEnvironmentIntensity(1.0, 1.8, 1.2);

let model: Model3D.Type | undefined;
let oldModel: Model3D.Type | undefined;
let index = 0;
let elapsed = 0;
let switches = 0;

function verifyCleanupWithParent() {
	const probe = Node3D();
	view.scene.addChild(probe);
	probe.cleanup();
	assert(probe.parent === undefined, "Node3D.cleanup() should clear its parent");
	const hierarchy = view.scene as unknown as Node3DHierarchyState;
	assert(!hierarchy.hasChildren, "Node3D.cleanup() should remove the parent child reference");
	view.scene.removeAllChildren(false);
	print("cleanup_edge parent_cleanup_success=true");
}

function loadNext() {
	if (oldModel) {
		oldModel.cleanup();
		oldModel = undefined;
	}
	if (model) {
		model.removeFromParent(true);
		oldModel = model;
		model = undefined;
	}

	const item = cases[index];
	index = (index + 1) % cases.length;
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
	print(`cleanup_edge switch=${switches} case=${item.name} load=${(App.runningTime - start).toFixed(3)}`);
}

verifyCleanupWithParent();
loadNext();

threadLoop(() => {
	elapsed += App.deltaTime;
	if (model) {
		model.angleY = model.angleY + App.deltaTime * 30;
	}
	if (elapsed > 0.6) {
		elapsed = 0;
		loadNext();
	}
	return false;
});
