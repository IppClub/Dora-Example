import { makeBody3D, makeBoxBody3D, makeCapsuleBody3D, makeSphereBody3D } from "PhysicsBody3D";
// @preview-file on clear
import {
	App,
	Body3DType,
	Camera3D,
	Content,
	Director,
	Node3D,
	PhysicsWorld3D,
	Vec3,
	View,
	sleep,
	thread,
} from "Dora";

type Sample = {
	count: number;
	debug: boolean;
	frameP50: number;
	frameP95: number;
	collectP95: number;
	submitP95: number;
};

const outputDir = "/tmp/dora-3d-jolt-profile";
const resultPath = `${outputDir}/result.txt`;
const phasePath = `${outputDir}/phase.txt`;
const counts = [100, 250, 500];
const warmupFrames = 90;
const sampleFrames = 120;
const results: string[] = [];
const view = Director.entry;

function emit(message: string) {
	print(message);
	results.push(message);
}

function fail(reason: string): never {
	emit(`JOLT_PROFILE_SUMMARY status=FAIL reason=${reason}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
	error(reason);
}

function percentile(values: number[], p: number) {
	values.sort((a, b) => a - b);
	return values[math.floor((values.length - 1) * p)] ?? 0;
}

function waitFrames(count: number) {
	for (let index = 0; index < count; index += 1) sleep();
}

const camera = Camera3D();
camera.lookAt(Vec3(22, 18, 28), Vec3(0, 4, 0));
Director.pushCamera(camera);
View.frustumCulling = false;
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0, 0, 1);

const world = PhysicsWorld3D();
view.addChild(world);

const floor = Node3D();
floor.position = Vec3(0, -0.5, 0);
view.addChild(floor);
makeBoxBody3D(world, floor, Vec3(30, 0.5, 30), PhysicsWorld3D.Static);

function runPhase(count: number, debug: boolean): Sample {
	const bodies: Body3DType[] = [];
	const side = math.ceil(math.sqrt(count));
	for (let index = 0; index < count; index += 1) {
		const node = Node3D();
		const column = index % side;
		const row = math.floor(index / side);
		node.position = Vec3(
			(column - (side - 1) * 0.5) * 1.15,
			1.2 + (index % 7) * 1.05,
			(row - (side - 1) * 0.5) * 1.15,
		);
		view.addChild(node);
		let body: Body3DType;
		switch (index % 3) {
			case 1:
				body = makeSphereBody3D(world, node, 0.42);
				break;
			case 2:
				body = makeCapsuleBody3D(world, node, 0.32, 0.3);
				break;
			default:
				body = makeBoxBody3D(world, node, Vec3(0.4, 0.4, 0.4));
				break;
		}
		bodies.push(body);
	}

	world.showDebug = debug;
	Content.save(phasePath, `${count}:${debug ? "debug" : "plain"}`);
	waitFrames(warmupFrames);

	const frame: number[] = [];
	const collect: number[] = [];
	const submit: number[] = [];
	for (let index = 0; index < sampleFrames; index += 1) {
		sleep();
		const stats = view.stats;
		frame.push(App.deltaTime * 1000);
		collect.push(stats.collectMicros);
		submit.push(stats.submitMicros);
	}

	const sample: Sample = {
		count,
		debug,
		frameP50: percentile(frame, 0.5),
		frameP95: percentile(frame, 0.95),
		collectP95: percentile(collect, 0.95),
		submitP95: percentile(submit, 0.95),
	};
	emit(
		`JOLT_PROFILE count=${count} debug=${debug} ` +
		`frameP50Ms=${sample.frameP50.toFixed(3)} frameP95Ms=${sample.frameP95.toFixed(3)} ` +
		`collectP95Us=${sample.collectP95} submitP95Us=${sample.submitP95}`,
	);

	world.showDebug = false;
	for (const body of bodies) body.removeFromParent(true);
	waitFrames(5);
	return sample;
}

Content.remove(resultPath);
Content.remove(phasePath);
thread(() => {
	for (const count of counts) {
		runPhase(count, false);
		runPhase(count, true);
	}
	Content.save(phasePath, "cleanup");
	waitFrames(5);
	const stats = view.stats;
	if (stats.modelInstanceCount !== 0 || stats.visualCount !== 0) {
		fail(`cleanup_registry_models_${stats.modelInstanceCount}_visuals_${stats.visualCount}`);
	}
	emit("JOLT_PROFILE_SUMMARY status=PASS");
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
});
