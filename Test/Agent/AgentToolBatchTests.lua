-- [ts]: AgentToolBatchTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____Batch = require("Agent.Tool.Batch") -- 2
local areAgentToolParamsEqual = ____Batch.areAgentToolParamsEqual -- 2
local cloneAgentToolParams = ____Batch.cloneAgentToolParams -- 2
local partitionAgentToolCalls = ____Batch.partitionAgentToolCalls -- 2
local ____Tools = require("Agent.Tools") -- 5
local planTruncatedEditRecovery = ____Tools.planTruncatedEditRecovery -- 5
function ____exports.runAgentToolBatchTests() -- 9
	local passed = 0 -- 10
	local total = 0 -- 11
	local failures = {} -- 12
	local function check(condition, name) -- 13
		total = total + 1 -- 13
		if condition then -- 13
			passed = passed + 1 -- 13
		else -- 13
			failures[#failures + 1] = name -- 13
		end -- 13
	end -- 13
	local function item(tool, id, params) -- 14
		if params == nil then -- 14
			params = {} -- 14
		end -- 14
		return {tool = tool, toolCallId = id, params = params} -- 14
	end -- 14
	local function safe(tool) -- 15
		return tool == "read_file" or tool == "grep_files" or tool == "glob_files" -- 15
	end -- 15
	local actions = { -- 16
		item("read_file", "1"), -- 16
		item("grep_files", "2"), -- 16
		item("edit_file", "3"), -- 16
		item("glob_files", "4"), -- 16
		item("build", "5"), -- 16
		item("read_file", "6") -- 16
	} -- 16
	local batches = partitionAgentToolCalls(actions, safe) -- 17
	check(#batches == 5, "partition count") -- 18
	check( -- 19
		batches[1].isConcurrencySafe and table.concat( -- 19
			__TS__ArrayMap( -- 19
				batches[1].actions, -- 19
				function(____, row) return row.toolCallId end -- 19
			), -- 19
			"," -- 19
		) == "1,2", -- 19
		"adjacent safe calls share parallel batch" -- 19
	) -- 19
	check(not batches[2].isConcurrencySafe and batches[2].actions[1].tool == "edit_file", "side effect is serial") -- 20
	check( -- 21
		table.concat( -- 21
			__TS__ArrayMap( -- 21
				batches, -- 21
				function(____, batch) return table.concat( -- 21
					__TS__ArrayMap( -- 21
						batch.actions, -- 21
						function(____, row) return row.toolCallId end -- 21
					), -- 21
					"" -- 21
				) end -- 21
			), -- 21
			"" -- 21
		) == "123456", -- 21
		"partition preserves order" -- 21
	) -- 21
	local parallelReads = partitionAgentToolCalls( -- 22
		{ -- 22
			item("read_file", "r1", {path = "a.ts"}), -- 23
			item("read_file", "r2", {path = "b.ts"}) -- 24
		}, -- 24
		safe -- 25
	) -- 25
	check(#parallelReads == 1 and parallelReads[1].isConcurrencySafe and #parallelReads[1].actions == 2, "multiple single-file reads share one parallel batch") -- 26
	local original = {path = "a", nested = {values = {1, "x", true}}} -- 27
	local cloned = cloneAgentToolParams(original) -- 28
	check( -- 29
		areAgentToolParamsEqual(original, cloned), -- 29
		"cloned params match exactly" -- 29
	) -- 29
	cloned.nested.values = {1, "changed", true} -- 30
	check( -- 31
		not areAgentToolParamsEqual(original, cloned), -- 31
		"stale nested params do not match" -- 31
	) -- 31
	check( -- 32
		not areAgentToolParamsEqual({a = 1}, {a = 1, b = 2}), -- 32
		"extra key does not match" -- 32
	) -- 32
	check( -- 33
		not areAgentToolParamsEqual({1, 2}, {1, 2, 3}), -- 33
		"different array length does not match" -- 33
	) -- 33
	local malformedArrayRecovery = planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "[{\"path\":\"game/Core.ts\",\"old_str\":\"\",\"new_str\":\"export const value = 1;\"}, [\"unattributed\", \"tail\"]"}}}) -- 34
	local malformedEdits = malformedArrayRecovery and malformedArrayRecovery.params.edits -- 40
	local ____check_9 = check -- 41
	local ____temp_8 = (malformedArrayRecovery and malformedArrayRecovery.operationCount) == 1 and malformedArrayRecovery.targets[1] == "game/Core.ts" -- 42
	if ____temp_8 then -- 42
		local ____opt_4 = malformedEdits and malformedEdits[1] -- 42
		____temp_8 = (____opt_4 and ____opt_4.new_str) == "export const value = 1;" -- 42
	end -- 42
	____check_9(____temp_8, "recover a complete edit object before malformed trailing fragments") -- 41
	local partialBatchRecovery = planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "{\"edits\":[{\"path\":\"a.ts\",\"old_str\":\"\",\"new_str\":\"alpha\"},{\"path\":\"b.ts\",\"old_str\":\"beta\",\"new_str\":\"partial\\nline"}}}) -- 47
	local partialEdits = partialBatchRecovery and partialBatchRecovery.params.edits -- 53
	local ____check_19 = check -- 54
	local ____temp_18 = (partialBatchRecovery and partialBatchRecovery.operationCount) == 2 and partialBatchRecovery.incompleteStringCount == 1 -- 55
	if ____temp_18 then -- 55
		local ____opt_14 = partialEdits and partialEdits[2] -- 55
		____temp_18 = (____opt_14 and ____opt_14.new_str) == "partial\nline" -- 55
	end -- 55
	____check_19(____temp_18, "recover closed batch entries and a decodable current new_str prefix") -- 54
	check( -- 60
		planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "{\"new_str\":\"orphan"}}}) == nil, -- 60
		"do not guess a truncated edit target" -- 60
	) -- 60
	check( -- 61
		planTruncatedEditRecovery({{["function"] = {name = "delete_file", arguments = "{\"target_file\":\"a.ts\""}}}) == nil, -- 61
		"do not recover other side-effect tools" -- 61
	) -- 61
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 62
end -- 9
function ____exports.printAgentToolBatchTestResult() -- 65
	local result = ____exports.runAgentToolBatchTests() -- 66
	print((((((("AGENT_TOOL_BATCH_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) -- 67
end -- 65
return ____exports -- 65