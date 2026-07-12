// @preview-file on clear
import {
	App,
	Cache,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Node,
	Vec2,
	Vec3,
	View,
	sleep,
	thread,
} from "Dora";

const modelFile = "Test/Model3D/Assets/Model/DamagedHelmet.glb";
const outputDir = "/tmp/dora-3d-picking";
const resultPath = `${outputDir}/result.txt`;
const results: string[] = [];
const view = Director.entry;

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`PICKING_SUMMARY status=${status}${reason !== "" ? ` reason=${reason}` : ""}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function pointOnRay(origin: Vec3.Type, direction: Vec3.Type, distance: number) {
	return Vec3(
		origin.x + direction.x * distance,
		origin.y + direction.y * distance,
		origin.z + direction.z * distance,
	);
}

Content.remove(resultPath);
Cache.unload(modelFile);
if (!Cache.load(modelFile)) {
	finish("FAIL", "model_load_failed");
} else {
	const camera = Camera3D();
	Director.pushCamera(camera);
	camera.lookAt(Vec3(0, 0, 8), Vec3(0, 0, 0));
	view.setEnvironmentMap("");
	view.setEnvironmentIntensity(0, 0, 1);

	const light = DirectionalLight3D();
	light.color = Color3(0xffffff);
	light.intensity = 3;
	light.angleX = -25;
	light.angleY = 30;
	view.addChild(light);

	const input = Node();
	input.size = View.size;
	input.onTapped((touch) => {
		const hit = view.pick(touch.viewLocation);
		if (hit) {
			hit.scale = Vec3(1.8, 1.8, 1.8);
			emit(`PICKING_TOUCH hit=true x=${touch.viewLocation.x.toFixed(1)} y=${touch.viewLocation.y.toFixed(1)}`);
		} else {
			emit(`PICKING_TOUCH hit=false x=${touch.viewLocation.x.toFixed(1)} y=${touch.viewLocation.y.toFixed(1)}`);
		}
	});
	view.addChild(input);

	thread(() => {
		for (let i = 0; i < 3; i += 1) sleep();

		const point = Vec2(View.size.width * 0.5, View.size.height * 0.5);
		const origin = view.getRayOrigin(point);
		const direction = view.getRayDirection(point);
		const length = math.sqrt(
			direction.x * direction.x + direction.y * direction.y + direction.z * direction.z,
		);
		emit(
			`PICKING_RAY origin=${origin.x.toFixed(3)},${origin.y.toFixed(3)},${origin.z.toFixed(3)} ` +
			`direction=${direction.x.toFixed(3)},${direction.y.toFixed(3)},${direction.z.toFixed(3)} length=${length.toFixed(4)}`,
		);
		if (math.abs(length - 1) > 0.001) {
			finish("FAIL", "ray_not_normalized");
			return;
		}
		if (math.abs(direction.x) > 0.001 || math.abs(direction.y) > 0.001 || direction.z > -0.999) {
			finish("FAIL", "center_ray_not_camera_forward");
			return;
		}

		const nearModel = Model3D(modelFile);
		const farModel = Model3D(modelFile);
		if (!nearModel || !farModel) {
			finish("FAIL", "model_instance_failed");
			return;
		}
		nearModel.position = pointOnRay(origin, direction, 3);
		farModel.position = pointOnRay(origin, direction, 5);
		nearModel.tag = "near";
		farModel.tag = "far";
		nearModel.scale = Vec3(1.5, 1.5, 1.5);
		farModel.scale = Vec3(1.5, 1.5, 1.5);
		view.addChild(farModel);
		view.addChild(nearModel);
		for (let i = 0; i < 3; i += 1) sleep();

		const nearestHit = view.pick(point);
		emit(`PICKING_NEAREST_HIT tag=${nearestHit?.tag ?? "none"}`);
		if (nearestHit?.tag !== "near") {
			finish("FAIL", `nearest_model_not_selected_${nearestHit?.tag ?? "none"}`);
			return;
		}
		emit("PICKING_NEAREST status=PASS");

		nearModel.visible = false;
		sleep();
		if (view.pick(point)?.tag !== "far") {
			finish("FAIL", "hidden_model_not_skipped");
			return;
		}
		emit("PICKING_VISIBILITY status=PASS");

		farModel.visible = false;
		sleep();
		if (view.pick(point) !== undefined) {
			finish("FAIL", "miss_expected");
			return;
		}
		emit("PICKING_MISS status=PASS");
		finish("PASS");
	});
}
