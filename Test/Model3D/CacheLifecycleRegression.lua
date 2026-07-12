-- [ts]: CacheLifecycleRegression.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Cache = ____Dora.Cache -- 2
local Content = ____Dora.Content -- 2
local Model3D = ____Dora.Model3D -- 2
local sleep = ____Dora.sleep -- 2
local thread = ____Dora.thread -- 2
local modelFile = "Test/Model3D/Assets/Model/DamagedHelmet.glb" -- 4
local secondFile = "Test/Model3D/Assets/Model/Duck.glb" -- 5
local missingFile = "Test/Model3D/Assets/Model/DoesNotExist.glb" -- 6
local outputDir = "/tmp/dora-3d-cache" -- 7
local resultPath = outputDir .. "/result.txt" -- 8
local results = {} -- 9
local function emit(message) -- 11
	print(message) -- 12
	results[#results + 1] = message -- 13
end -- 11
local function fail(reason) -- 16
	emit("CACHE_SUMMARY status=FAIL reason=" .. reason) -- 17
	Content:save( -- 18
		resultPath, -- 18
		table.concat(results, "\n") .. "\n" -- 18
	) -- 18
	App.devMode = false -- 19
	App:shutdown() -- 20
	error(reason) -- 21
end -- 16
local function expect(condition, reason) -- 24
	if not condition then -- 24
		fail(reason) -- 25
	end -- 25
end -- 24
Content:remove(resultPath) -- 28
Cache:unload() -- 29
Cache.model3DBudget = 0 -- 30
thread(function() -- 32
	local cancelIssued = false -- 33
	thread(function() -- 34
		sleep(0.05) -- 35
		local state = Cache:getLoadState(modelFile) -- 36
		emit("CACHE_CANCEL_OBSERVED state=" .. state) -- 37
		expect(state == "loading", "expected_loading_before_cancel_" .. state) -- 38
		cancelIssued = Cache:cancelLoad(modelFile) -- 39
	end) -- 34
	local cancelledResult = Cache:loadAsync(modelFile) -- 42
	expect(cancelIssued, "cancel_request_was_not_accepted") -- 43
	expect(not cancelledResult, "cancelled_load_reported_success") -- 44
	expect( -- 45
		Cache:getLoadState(modelFile) == "cancelled", -- 45
		"cancelled_state_missing" -- 45
	) -- 45
	expect( -- 46
		#Cache:getLoadError(modelFile) > 0, -- 46
		"cancelled_error_missing" -- 46
	) -- 46
	emit((("CACHE_CANCEL_RESULT state=" .. Cache:getLoadState(modelFile)) .. " error=") .. Cache:getLoadError(modelFile)) -- 47
	local missingResult = Cache:loadAsync(missingFile) -- 49
	expect(not missingResult, "missing_load_reported_success") -- 50
	expect( -- 51
		Cache:getLoadState(missingFile) == "failed", -- 51
		"missing_failed_state_missing" -- 51
	) -- 51
	expect( -- 52
		#Cache:getLoadError(missingFile) > 0, -- 52
		"missing_error_missing" -- 52
	) -- 52
	emit((("CACHE_ERROR_RESULT state=" .. Cache:getLoadState(missingFile)) .. " error=") .. Cache:getLoadError(missingFile)) -- 53
	local restarted = Cache:loadAsync(modelFile) -- 55
	expect(restarted, "restart_after_cancel_failed") -- 56
	expect( -- 57
		Cache:getLoadState(modelFile) == "ready", -- 57
		"restart_ready_state_missing" -- 57
	) -- 57
	expect( -- 58
		Cache:getLoadError(modelFile) == "", -- 58
		"restart_left_stale_error" -- 58
	) -- 58
	emit((("CACHE_RESTART_RESULT state=" .. Cache:getLoadState(modelFile)) .. " count=") .. tostring(Cache.model3DCount)) -- 59
	local heldModel = Model3D(modelFile) -- 61
	expect(not not heldModel, "held_model_create_failed") -- 62
	local secondLoaded = Cache:loadAsync(secondFile) -- 63
	expect(secondLoaded, "second_model_load_failed") -- 64
	expect(Cache.model3DCount >= 2, "cache_did_not_retain_two_models") -- 65
	local usageBefore = Cache.model3DUsage -- 66
	Cache.model3DBudget = 1 -- 67
	sleep() -- 68
	expect( -- 69
		Cache.model3DCount == 1, -- 69
		"lru_eviction_count_" .. tostring(Cache.model3DCount) -- 69
	) -- 69
	expect(Cache.model3DUsage > Cache.model3DBudget, "referenced_model_was_not_retained_over_budget") -- 70
	emit((((("CACHE_BUDGET_RESULT before=" .. tostring(usageBefore)) .. " after=") .. tostring(Cache.model3DUsage)) .. " ") .. (("budget=" .. tostring(Cache.model3DBudget)) .. " count=") .. tostring(Cache.model3DCount)) -- 71
	heldModel:cleanup() -- 76
	Cache:unload(modelFile) -- 77
	Cache.model3DBudget = 0 -- 78
	expect(Cache.model3DCount == 0, "cache_not_empty_after_release") -- 79
	emit("CACHE_SUMMARY status=PASS") -- 80
	Content:save( -- 81
		resultPath, -- 81
		table.concat(results, "\n") .. "\n" -- 81
	) -- 81
	App.devMode = false -- 82
	App:shutdown() -- 83
end) -- 32
return ____exports -- 32