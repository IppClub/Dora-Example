// @preview-file on clear
import {App, Cache, Content, Model3D, sleep, thread} from "Dora";

const modelFile = "Test/Model3D/Assets/Model/DamagedHelmet.glb";
const secondFile = "Test/Model3D/Assets/Model/Duck.glb";
const missingFile = "Test/Model3D/Assets/Model/DoesNotExist.glb";
const outputDir = "/tmp/dora-3d-cache";
const resultPath = `${outputDir}/result.txt`;
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function fail(reason: string): never {
	emit(`CACHE_SUMMARY status=FAIL reason=${reason}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
	error(reason);
}

function expect(condition: boolean, reason: string) {
	if (!condition) fail(reason);
}

Content.remove(resultPath);
Cache.unload();
Cache.model3DBudget = 0;

thread(() => {
	let cancelIssued = false;
	thread(() => {
		sleep(0.05);
		const state = Cache.getLoadState(modelFile);
		emit(`CACHE_CANCEL_OBSERVED state=${state}`);
		expect(state === "loading", `expected_loading_before_cancel_${state}`);
		cancelIssued = Cache.cancelLoad(modelFile);
	});

	const cancelledResult = Cache.loadAsync(modelFile);
	expect(cancelIssued, "cancel_request_was_not_accepted");
	expect(!cancelledResult, "cancelled_load_reported_success");
	expect(Cache.getLoadState(modelFile) === "cancelled", "cancelled_state_missing");
	expect(Cache.getLoadError(modelFile).length > 0, "cancelled_error_missing");
	emit(`CACHE_CANCEL_RESULT state=${Cache.getLoadState(modelFile)} error=${Cache.getLoadError(modelFile)}`);

	const missingResult = Cache.loadAsync(missingFile);
	expect(!missingResult, "missing_load_reported_success");
	expect(Cache.getLoadState(missingFile) === "failed", "missing_failed_state_missing");
	expect(Cache.getLoadError(missingFile).length > 0, "missing_error_missing");
	emit(`CACHE_ERROR_RESULT state=${Cache.getLoadState(missingFile)} error=${Cache.getLoadError(missingFile)}`);

	const restarted = Cache.loadAsync(modelFile);
	expect(restarted, "restart_after_cancel_failed");
	expect(Cache.getLoadState(modelFile) === "ready", "restart_ready_state_missing");
	expect(Cache.getLoadError(modelFile) === "", "restart_left_stale_error");
	emit(`CACHE_RESTART_RESULT state=${Cache.getLoadState(modelFile)} count=${Cache.model3DCount}`);

	const heldModel = Model3D(modelFile);
	expect(!!heldModel, "held_model_create_failed");
	const secondLoaded = Cache.loadAsync(secondFile);
	expect(secondLoaded, "second_model_load_failed");
	expect(Cache.model3DCount >= 2, "cache_did_not_retain_two_models");
	const usageBefore = Cache.model3DUsage;
	Cache.model3DBudget = 1;
	sleep();
	expect(Cache.model3DCount === 1, `lru_eviction_count_${Cache.model3DCount}`);
	expect(Cache.model3DUsage > Cache.model3DBudget, "referenced_model_was_not_retained_over_budget");
	emit(
		`CACHE_BUDGET_RESULT before=${usageBefore} after=${Cache.model3DUsage} ` +
		`budget=${Cache.model3DBudget} count=${Cache.model3DCount}`,
	);

	heldModel.cleanup();
	Cache.unload(modelFile);
	Cache.model3DBudget = 0;
	expect(Cache.model3DCount === 0, "cache_not_empty_after_release");
	emit("CACHE_SUMMARY status=PASS");
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
});
