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
	Vec3,
	View,
	sleep,
	thread,
} from "Dora";

type Sample = {
	count: number;
	frameP50: number;
	frameP95: number;
	collectP50: number;
	collectP95: number;
	sortP50: number;
	sortP95: number;
	submitP50: number;
	submitP95: number;
};

const file = "Test/Model3D/Assets/Model/Fox.glb";
const outputDir = "/tmp/dora-3d-animation-profile";
const resultPath = `${outputDir}/result.txt`;
const counts = [1, 10, 25, 50];
const warmupFrames = 30;
const sampleFrames = 120;
const results: string[] = [];
const view = Director.entry;

function emit(message: string) {
	print(message);
	results.push(message);
}

function fail(reason: string): never {
	emit(`ANIMATION_PROFILE_SUMMARY status=FAIL reason=${reason}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
	error(reason);
}

function percentile(values: number[], p: number) {
	values.sort((a, b) => a - b);
	const index = math.floor((values.length - 1) * p);
	return values[index] ?? 0;
}

function waitFrames(count: number) {
	for (let index = 0; index < count; index += 1) sleep();
}

const camera = Camera3D();
Director.pushCamera(camera);
View.frustumCulling = false;
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);
const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 3;
light.angleX = -25;
light.angleY = 30;
view.addChild(light);

function runPhase(count: number): Sample {
	if (!Cache.load(file)) fail(`${count}_load_failed`);
	const side = math.ceil(math.sqrt(count));
	const spacing = 1.8;
	const models: Model3D.Type[] = [];
	for (let index = 0; index < count; index += 1) {
		const model = Model3D(file);
		if (!model) fail(`${count}_instance_${index}_failed`);
		const x = (index % side - (side - 1) * 0.5) * spacing;
		const y = (math.floor(index / side) - (side - 1) * 0.5) * spacing;
		model.position = Vec3(x, y, 0);
		model.scale = Vec3(0.015, 0.015, 0.015);
		view.addChild(model);
		if (model.play("Run", true) <= 0) fail(`${count}_animation_${index}_failed`);
		models.push(model);
	}
	camera.lookAt(Vec3(0, 0, math.max(12, side * 2.3)), Vec3(0, 0, 0));
	waitFrames(warmupFrames);

	const before = view.stats;
	if (before.modelInstanceCount !== count) {
		fail(`${count}_instance_count_${before.modelInstanceCount}`);
	}
	if (before.drawCalls < count) fail(`${count}_draw_calls_${before.drawCalls}`);

	const frame: number[] = [];
	const collect: number[] = [];
	const sort: number[] = [];
	const submit: number[] = [];
	for (let index = 0; index < sampleFrames; index += 1) {
		sleep();
		const stats = view.stats;
		frame.push(App.deltaTime * 1000);
		collect.push(stats.collectMicros);
		sort.push(stats.sortMicros);
		submit.push(stats.submitMicros);
	}
	const sample: Sample = {
		count,
		frameP50: percentile(frame, 0.5),
		frameP95: percentile(frame, 0.95),
		collectP50: percentile(collect, 0.5),
		collectP95: percentile(collect, 0.95),
		sortP50: percentile(sort, 0.5),
		sortP95: percentile(sort, 0.95),
		submitP50: percentile(submit, 0.5),
		submitP95: percentile(submit, 0.95),
	};
	emit(
		`ANIMATION_PROFILE count=${count} ` +
		`frameP50Ms=${sample.frameP50.toFixed(3)} frameP95Ms=${sample.frameP95.toFixed(3)} ` +
		`collectP50Us=${sample.collectP50} collectP95Us=${sample.collectP95} ` +
		`sortP50Us=${sample.sortP50} sortP95Us=${sample.sortP95} ` +
		`submitP50Us=${sample.submitP50} submitP95Us=${sample.submitP95}`,
	);

	for (const model of models) model.removeFromParent(true);
	waitFrames(3);
	if (view.stats.modelInstanceCount !== 0) {
		fail(`${count}_cleanup_instances_${view.stats.modelInstanceCount}`);
	}
	return sample;
}

Content.remove(resultPath);
Cache.unload();
Cache.model3DBudget = 0;

thread(() => {
	for (const count of counts) runPhase(count);
	Cache.unload(file);
	waitFrames(3);
	emit("ANIMATION_PROFILE_SUMMARY status=PASS");
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
});
