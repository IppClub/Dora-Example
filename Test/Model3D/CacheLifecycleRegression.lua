-- [ts]: CacheLifecycleRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySome = ____lualib.__TS__ArraySome -- 1
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Cache = ____Dora.Cache -- 2
local Content = ____Dora.Content -- 2
local Model3D = ____Dora.Model3D -- 2
local sleep = ____Dora.sleep -- 2
local thread = ____Dora.thread -- 2
local json = require("json") -- 6
local function diagnostics(file) -- 7
	local report, reason = json.decode(Cache:getLoadDiagnostics(file)) -- 8
	if not report then -- 8
		error(reason or "invalid_load_report") -- 9
	end -- 9
	return report.diagnostics -- 10
end -- 7
local modelFile = "Test/Model3D/Assets/Model/DamagedHelmet.glb" -- 13
local secondFile = "Test/Model3D/Assets/Model/Duck.glb" -- 14
local missingFile = "Test/Model3D/Assets/Model/DoesNotExist.glb" -- 15
local outputDir = "/tmp/dora-3d-cache" -- 16
local resultPath = outputDir .. "/result.txt" -- 17
local results = {} -- 18
local function emit(message) -- 20
	print(message) -- 21
	results[#results + 1] = message -- 22
end -- 20
local function fail(reason) -- 25
	emit("CACHE_SUMMARY status=FAIL reason=" .. reason) -- 26
	Content:save( -- 27
		resultPath, -- 27
		table.concat(results, "\n") .. "\n" -- 27
	) -- 27
	App.devMode = false -- 28
	App:shutdown() -- 29
	error(reason) -- 30
end -- 25
local function expect(condition, reason) -- 33
	if not condition then -- 33
		fail(reason) -- 34
	end -- 34
end -- 33
Content:remove(resultPath) -- 37
Cache:unload() -- 38
Cache.model3DBudget = 0 -- 39
thread(function() -- 41
	local cancelIssued = false -- 42
	thread(function() -- 43
		sleep(0.05) -- 44
		local state = Cache:getLoadState(modelFile) -- 45
		emit("CACHE_CANCEL_OBSERVED state=" .. state) -- 46
		expect(state == "loading", "expected_loading_before_cancel_" .. state) -- 47
		cancelIssued = Cache:cancelLoad(modelFile) -- 48
	end) -- 43
	local cancelledResult = Cache:loadAsync(modelFile) -- 51
	expect(cancelIssued, "cancel_request_was_not_accepted") -- 52
	expect(not cancelledResult, "cancelled_load_reported_success") -- 53
	expect( -- 54
		Cache:getLoadState(modelFile) == "cancelled", -- 54
		"cancelled_state_missing" -- 54
	) -- 54
	expect( -- 55
		__TS__ArraySome( -- 55
			diagnostics(modelFile), -- 55
			function(____, d) return d.code == "LOAD_CANCELLED" end -- 55
		), -- 55
		"cancelled_error_missing" -- 55
	) -- 55
	emit((("CACHE_CANCEL_RESULT state=" .. Cache:getLoadState(modelFile)) .. " report=") .. Cache:getLoadDiagnostics(modelFile)) -- 56
	local missingResult = Cache:loadAsync(missingFile) -- 58
	expect(not missingResult, "missing_load_reported_success") -- 59
	expect( -- 60
		Cache:getLoadState(missingFile) == "failed", -- 60
		"missing_failed_state_missing" -- 60
	) -- 60
	expect( -- 61
		__TS__ArraySome( -- 61
			diagnostics(missingFile), -- 61
			function(____, d) return d.code == "RESOURCE_NOT_FOUND" end -- 61
		), -- 61
		"missing_error_missing" -- 61
	) -- 61
	emit((("CACHE_ERROR_RESULT state=" .. Cache:getLoadState(missingFile)) .. " report=") .. Cache:getLoadDiagnostics(missingFile)) -- 62
	local restarted = Cache:loadAsync(modelFile) -- 64
	expect(restarted, "restart_after_cancel_failed") -- 65
	expect( -- 66
		Cache:getLoadState(modelFile) == "ready", -- 66
		"restart_ready_state_missing" -- 66
	) -- 66
	expect( -- 67
		__TS__ArrayEvery( -- 67
			diagnostics(modelFile), -- 67
			function(____, d) return d.severity ~= "error" end -- 67
		), -- 67
		"restart_left_stale_error" -- 67
	) -- 67
	emit((("CACHE_RESTART_RESULT state=" .. Cache:getLoadState(modelFile)) .. " count=") .. tostring(Cache.model3DCount)) -- 68
	local heldModel = Model3D(modelFile) -- 70
	expect(heldModel ~= nil, "held_model_create_failed") -- 71
	local secondLoaded = Cache:loadAsync(secondFile) -- 72
	expect(secondLoaded, "second_model_load_failed") -- 73
	expect(Cache.model3DCount >= 2, "cache_did_not_retain_two_models") -- 74
	local usageBefore = Cache.model3DUsage -- 75
	Cache.model3DBudget = 1 -- 76
	sleep() -- 77
	expect( -- 78
		Cache.model3DCount == 1, -- 78
		"lru_eviction_count_" .. tostring(Cache.model3DCount) -- 78
	) -- 78
	expect(Cache.model3DUsage > Cache.model3DBudget, "referenced_model_was_not_retained_over_budget") -- 79
	emit((((("CACHE_BUDGET_RESULT before=" .. tostring(usageBefore)) .. " after=") .. tostring(Cache.model3DUsage)) .. " ") .. (("budget=" .. tostring(Cache.model3DBudget)) .. " count=") .. tostring(Cache.model3DCount)) -- 80
	heldModel:cleanup() -- 85
	Cache:unload(modelFile) -- 86
	Cache.model3DBudget = 0 -- 87
	expect(Cache.model3DCount == 0, "cache_not_empty_after_release") -- 88
	emit("CACHE_SUMMARY status=PASS") -- 89
	Content:save( -- 90
		resultPath, -- 90
		table.concat(results, "\n") .. "\n" -- 90
	) -- 90
	App.devMode = false -- 91
	App:shutdown() -- 92
end) -- 41
return ____exports -- 41