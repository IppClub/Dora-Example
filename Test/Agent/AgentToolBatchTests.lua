-- [ts]: AgentToolBatchTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____AgentToolBatch = require("Agent.AgentToolBatch") -- 2
local areAgentToolParamsEqual = ____AgentToolBatch.areAgentToolParamsEqual -- 2
local cloneAgentToolParams = ____AgentToolBatch.cloneAgentToolParams -- 2
local coalesceCompatibleAgentToolCalls = ____AgentToolBatch.coalesceCompatibleAgentToolCalls -- 2
local partitionAgentToolCalls = ____AgentToolBatch.partitionAgentToolCalls -- 2
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
	local original = {path = "a", nested = {values = {1, "x", true}}} -- 22
	local cloned = cloneAgentToolParams(original) -- 23
	check( -- 24
		areAgentToolParamsEqual(original, cloned), -- 24
		"cloned params match exactly" -- 24
	) -- 24
	cloned.nested.values = {1, "changed", true} -- 25
	check( -- 26
		not areAgentToolParamsEqual(original, cloned), -- 26
		"stale nested params do not match" -- 26
	) -- 26
	check( -- 27
		not areAgentToolParamsEqual({a = 1}, {a = 1, b = 2}), -- 27
		"extra key does not match" -- 27
	) -- 27
	check( -- 28
		not areAgentToolParamsEqual({1, 2}, {1, 2, 3}), -- 28
		"different array length does not match" -- 28
	) -- 28
	local coalescedReads = coalesceCompatibleAgentToolCalls({ -- 29
		item("read_file", "r1", {reads = {{path = "a.ts", startLine = 1, endLine = 2}}}), -- 30
		item("read_file", "r2", {reads = {{path = "b.ts"}}}), -- 31
		item("read_file", "r3", {reads = {{path = "c.ts"}, {path = "d.ts", startLine = -2, endLine = -1}}}) -- 32
	}) -- 32
	check(#coalescedReads == 1 and coalescedReads[1].toolCallId == "r1" and #coalescedReads[1].params.reads == 4, "coalesce consecutive read arrays") -- 34
	local separatedReads = coalesceCompatibleAgentToolCalls({ -- 35
		item("read_file", "r1", {reads = {{path = "a.ts"}}}), -- 36
		item("grep_files", "g1", {pattern = "x"}), -- 37
		item("read_file", "r2", {reads = {{path = "b.ts"}}}) -- 38
	}) -- 38
	check( -- 40
		#separatedReads == 3 and table.concat( -- 40
			__TS__ArrayMap( -- 40
				separatedReads, -- 40
				function(____, row) return row.toolCallId end -- 40
			), -- 40
			"," -- 40
		) == "r1,g1,r2", -- 40
		"do not coalesce across another tool" -- 40
	) -- 40
	local coalescedBuilds = coalesceCompatibleAgentToolCalls({ -- 41
		item("build", "b1", {paths = {"a.ts"}}), -- 42
		item("build", "b2", {paths = {"b.ts", "c.ts"}}) -- 43
	}) -- 43
	check( -- 45
		#coalescedBuilds == 1 and table.concat(coalescedBuilds[1].params.paths, ",") == "a.ts,b.ts,c.ts", -- 45
		"coalesce consecutive build targets in order" -- 45
	) -- 45
	local malformedArrayRecovery = planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "[{\"path\":\"game/Core.ts\",\"old_str\":\"\",\"new_str\":\"export const value = 1;\"}, [\"unattributed\", \"tail\"]"}}}) -- 46
	local malformedEdits = malformedArrayRecovery and malformedArrayRecovery.params.edits -- 52
	local ____check_9 = check -- 53
	local ____temp_8 = (malformedArrayRecovery and malformedArrayRecovery.operationCount) == 1 and malformedArrayRecovery.targets[1] == "game/Core.ts" -- 54
	if ____temp_8 then -- 54
		local ____opt_4 = malformedEdits and malformedEdits[1] -- 54
		____temp_8 = (____opt_4 and ____opt_4.new_str) == "export const value = 1;" -- 54
	end -- 54
	____check_9(____temp_8, "recover a complete edit object before malformed trailing fragments") -- 53
	local partialBatchRecovery = planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "{\"edits\":[{\"path\":\"a.ts\",\"old_str\":\"\",\"new_str\":\"alpha\"},{\"path\":\"b.ts\",\"old_str\":\"beta\",\"new_str\":\"partial\\nline"}}}) -- 59
	local partialEdits = partialBatchRecovery and partialBatchRecovery.params.edits -- 65
	local ____check_19 = check -- 66
	local ____temp_18 = (partialBatchRecovery and partialBatchRecovery.operationCount) == 2 and partialBatchRecovery.incompleteStringCount == 1 -- 67
	if ____temp_18 then -- 67
		local ____opt_14 = partialEdits and partialEdits[2] -- 67
		____temp_18 = (____opt_14 and ____opt_14.new_str) == "partial\nline" -- 67
	end -- 67
	____check_19(____temp_18, "recover closed batch entries and a decodable current new_str prefix") -- 66
	check( -- 72
		planTruncatedEditRecovery({{["function"] = {name = "edit_file", arguments = "{\"new_str\":\"orphan"}}}) == nil, -- 72
		"do not guess a truncated edit target" -- 72
	) -- 72
	check( -- 73
		planTruncatedEditRecovery({{["function"] = {name = "delete_file", arguments = "{\"target_file\":\"a.ts\""}}}) == nil, -- 73
		"do not recover other side-effect tools" -- 73
	) -- 73
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 74
end -- 9
function ____exports.printAgentToolBatchTestResult() -- 77
	local result = ____exports.runAgentToolBatchTests() -- 78
	print((((((("AGENT_TOOL_BATCH_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) -- 79
end -- 77
return ____exports -- 77