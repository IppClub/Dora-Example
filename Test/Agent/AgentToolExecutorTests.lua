-- [ts]: AgentToolExecutorTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__AsyncAwaiter = ____lualib.__TS__AsyncAwaiter -- 1
local __TS__Await = ____lualib.__TS__Await -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local __TS__Delete = ____lualib.__TS__Delete -- 1
local Error = ____lualib.Error -- 1
local RangeError = ____lualib.RangeError -- 1
local ReferenceError = ____lualib.ReferenceError -- 1
local SyntaxError = ____lualib.SyntaxError -- 1
local TypeError = ____lualib.TypeError -- 1
local URIError = ____lualib.URIError -- 1
local __TS__New = ____lualib.__TS__New -- 1
local ____exports = {} -- 1
local ____AgentToolExecutor = require("Agent.AgentToolExecutor") -- 2
local executeAgentToolDefinition = ____AgentToolExecutor.executeAgentToolDefinition -- 2
local executeRegisteredAgentTool = ____AgentToolExecutor.executeRegisteredAgentTool -- 2
function ____exports.runAgentToolExecutorTests() -- 19
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 19
		local passed = 0 -- 20
		local total = 0 -- 21
		local failures = {} -- 22
		local function check(condition, name) -- 23
			total = total + 1 -- 24
			if condition then -- 24
				passed = passed + 1 -- 25
			else -- 25
				failures[#failures + 1] = name -- 26
			end -- 26
		end -- 23
		local function createContext(options) -- 29
			local stopToken = options and options.stopToken or ({stopped = false}) -- 36
			return { -- 37
				taskId = 1, -- 38
				step = 1, -- 39
				workingDir = "/tmp/project", -- 40
				role = options and options.role or "main", -- 41
				workMode = options and options.workMode or "code", -- 42
				useChineseResponse = false, -- 43
				disabledAgentTools = options and options.disabled or ({}), -- 44
				cancellation = { -- 45
					stopToken = stopToken, -- 46
					isCancelled = function() return stopToken.stopped end, -- 47
					reason = function() return stopToken.reason end -- 48
				}, -- 48
				emitProgress = function() -- 50
					local ____opt_8 = options and options.onProgress -- 50
					return ____opt_8 and ____opt_8(options) -- 50
				end, -- 50
				services = {}, -- 51
				workflow = {} -- 52
			} -- 52
		end -- 29
		local function validHandler(_context, input) -- 56
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 56
				return ____awaiter_resolve(nil, {output = {success = true, value = input.value}}) -- 56
			end) -- 56
		end -- 56
		local function createDefinition(overrides) -- 59
			return __TS__ObjectAssign( -- 60
				{ -- 60
					name = "read_file", -- 61
					roles = {"main"}, -- 62
					workModes = {"code"}, -- 63
					description = "test", -- 64
					inputSchema = function() return {type = "object", properties = {value = {type = "number"}}, required = {"value"}, additionalProperties = false} end, -- 65
					outputSchema = {type = "object", properties = {success = {type = "boolean"}, value = {type = "number"}}, required = {"success"}}, -- 71
					handler = validHandler -- 76
				}, -- 76
				overrides -- 77
			) -- 77
		end -- 59
		local schemaContext = {searchDoraDocLimitMax = 20} -- 81
		local valid = __TS__Await(executeAgentToolDefinition( -- 82
			createDefinition(), -- 82
			{value = 3}, -- 82
			createContext(), -- 82
			schemaContext -- 82
		)) -- 82
		check(valid.output.success == true and valid.output.value == 3, "execute valid handler") -- 83
		local invalidInput = __TS__Await(executeAgentToolDefinition( -- 85
			createDefinition(), -- 85
			{value = "3"}, -- 85
			createContext(), -- 85
			schemaContext -- 85
		)) -- 85
		check(invalidInput.output.code == "INVALID_TOOL_INPUT", "reject structurally invalid input") -- 86
		local extraInput = __TS__Await(executeAgentToolDefinition( -- 87
			createDefinition(), -- 87
			{value = 3, extra = true}, -- 87
			createContext(), -- 87
			schemaContext -- 87
		)) -- 87
		check(extraInput.output.code == "INVALID_TOOL_INPUT", "reject additional input property") -- 88
		local missingHandlerDefinition = createDefinition() -- 90
		__TS__Delete(missingHandlerDefinition, "handler") -- 91
		local missingHandler = __TS__Await(executeAgentToolDefinition( -- 92
			missingHandlerDefinition, -- 92
			{value = 1}, -- 92
			createContext(), -- 92
			schemaContext -- 92
		)) -- 92
		check(missingHandler.output.code == "TOOL_HANDLER_MISSING", "reject missing handler") -- 93
		local deniedRole = __TS__Await(executeAgentToolDefinition( -- 94
			createDefinition(), -- 94
			{value = 1}, -- 94
			createContext({role = "sub"}), -- 94
			schemaContext -- 94
		)) -- 94
		check(deniedRole.output.code == "TOOL_ROLE_DENIED", "enforce role guard") -- 95
		local deniedMode = __TS__Await(executeAgentToolDefinition( -- 96
			createDefinition(), -- 96
			{value = 1}, -- 96
			createContext({workMode = "plan"}), -- 96
			schemaContext -- 96
		)) -- 96
		check(deniedMode.output.code == "TOOL_MODE_DENIED", "enforce work mode guard") -- 97
		local disabled = __TS__Await(executeAgentToolDefinition( -- 98
			createDefinition(), -- 98
			{value = 1}, -- 98
			createContext({disabled = {"read_file"}}), -- 98
			schemaContext -- 98
		)) -- 98
		check(disabled.output.code == "TOOL_DISABLED", "enforce disabled tool guard") -- 99
		local editDefinition = createDefinition({ -- 101
			name = "edit_file", -- 102
			roles = {"main"}, -- 103
			workModes = {"code", "plan"}, -- 104
			inputSchema = function() return {type = "object", properties = {path = {type = "string"}, old_str = {type = "string"}, new_str = {type = "string"}}, required = {"path", "old_str", "new_str"}} end -- 105
		}) -- 105
		local deniedPlanPath = __TS__Await(executeAgentToolDefinition( -- 111
			editDefinition, -- 111
			{path = "src/a.ts", old_str = "a", new_str = "b"}, -- 111
			createContext({workMode = "plan"}), -- 111
			schemaContext -- 111
		)) -- 111
		check(deniedPlanPath.output.code == "PLAN_PATH_DENIED", "enforce Plan path guard") -- 112
		local allowedPlanPath = __TS__Await(executeAgentToolDefinition( -- 113
			editDefinition, -- 113
			{path = ".agent/plan/PLAN.md", old_str = "a", new_str = "b"}, -- 113
			createContext({workMode = "plan"}), -- 113
			schemaContext -- 113
		)) -- 113
		check(allowedPlanPath.output.success == true, "allow Plan document edit") -- 114
		local deleteDefinition = createDefinition({ -- 116
			name = "delete_file", -- 117
			workModes = {"code", "plan"}, -- 118
			inputSchema = function() return {type = "object", properties = {target_file = {type = "string"}}, required = {"target_file"}} end -- 119
		}) -- 119
		local protectedPlan = __TS__Await(executeAgentToolDefinition( -- 125
			deleteDefinition, -- 125
			{target_file = ".agent/plan/PLAN.md"}, -- 125
			createContext({workMode = "plan"}), -- 125
			schemaContext -- 125
		)) -- 125
		check(protectedPlan.output.code == "PROTECTED_AGENT_DOCUMENT", "protect fixed Plan document") -- 126
		local normalizedPlanDelete = __TS__Await(executeAgentToolDefinition( -- 127
			deleteDefinition, -- 128
			{target_file = ".agent\\plan\\notes.md"}, -- 129
			createContext({workMode = "plan"}), -- 130
			schemaContext -- 131
		)) -- 131
		check(normalizedPlanDelete.output.success == true, "normalize delete path before Plan guard") -- 133
		local protectedMemory = __TS__Await(executeAgentToolDefinition( -- 134
			deleteDefinition, -- 134
			{target_file = ".agent/main/MEMORY.md"}, -- 134
			createContext(), -- 134
			schemaContext -- 134
		)) -- 134
		check(protectedMemory.output.code == "PROTECTED_AGENT_MEMORY", "protect Agent memory deletion") -- 135
		local stopped = {stopped = true, reason = "user stopped"} -- 137
		local cancelled = __TS__Await(executeAgentToolDefinition( -- 138
			createDefinition(), -- 138
			{value = 1}, -- 138
			createContext({stopToken = stopped}), -- 138
			schemaContext -- 138
		)) -- 138
		check(cancelled.output.code == "TOOL_CANCELLED" and cancelled.output.message == "user stopped", "cancel before execution") -- 139
		local throwing = __TS__Await(executeAgentToolDefinition( -- 141
			createDefinition({handler = function() -- 141
				return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 141
					error( -- 142
						__TS__New(Error, "boom"), -- 142
						0 -- 142
					) -- 142
				end) -- 142
			end}), -- 142
			{value = 1}, -- 143
			createContext(), -- 143
			schemaContext -- 143
		)) -- 143
		check(throwing.output.code == "TOOL_EXECUTION_FAILED", "normalize handler exception") -- 144
		local invalidOutput = __TS__Await(executeAgentToolDefinition( -- 146
			createDefinition({handler = function() return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 146
				return ____awaiter_resolve(nil, {output = {success = "yes"}}) -- 146
			end) end}), -- 146
			{value = 1}, -- 148
			createContext(), -- 148
			schemaContext -- 148
		)) -- 148
		check(invalidOutput.output.code == "INVALID_TOOL_OUTPUT", "reject invalid output schema") -- 149
		local nonJsonOutput = __TS__Await(executeAgentToolDefinition( -- 150
			createDefinition({handler = function() return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 150
				return ____awaiter_resolve(nil, {output = {success = true, value = math.huge}}) -- 150
			end) end}), -- 150
			{value = 1}, -- 152
			createContext(), -- 152
			schemaContext -- 152
		)) -- 152
		check(nonJsonOutput.output.code == "INVALID_TOOL_OUTPUT", "reject non-JSON output") -- 153
		local semanticReject = __TS__Await(executeAgentToolDefinition( -- 155
			createDefinition({validateInput = function() return {success = false, message = "semantic failure"} end}), -- 155
			{value = 1}, -- 157
			createContext(), -- 157
			schemaContext -- 157
		)) -- 157
		check(semanticReject.output.code == "INVALID_TOOL_INPUT" and semanticReject.output.message == "semantic failure", "run semantic input validator") -- 158
		local semanticNormalize = __TS__Await(executeAgentToolDefinition( -- 159
			createDefinition({validateInput = function(value) return { -- 159
				success = true, -- 160
				value = __TS__ObjectAssign({}, value, {value = 4}) -- 160
			} end}), -- 160
			{value = 1}, -- 161
			createContext(), -- 161
			schemaContext -- 161
		)) -- 161
		check(semanticNormalize.output.value == 4, "use semantic normalized input") -- 162
		local control = __TS__Await(executeAgentToolDefinition( -- 164
			createDefinition({handler = function() return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 164
				return ____awaiter_resolve(nil, {output = {success = true, value = 1}, control = {concludeTask = true}}) -- 164
			end) end}), -- 164
			{value = 1}, -- 166
			createContext(), -- 166
			schemaContext -- 166
		)) -- 166
		local ____check_14 = check -- 167
		local ____opt_12 = control.control -- 167
		____check_14((____opt_12 and ____opt_12.concludeTask) == true and control.output.concludeTask == nil, "keep control separate from canonical output") -- 167
		local progressCount = 0 -- 169
		local progressDefinition = createDefinition({handler = function(context, input) -- 170
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 170
				context:emitProgress({success = false, progress = 0.5}) -- 172
				return ____awaiter_resolve(nil, {output = {success = true, value = input.value}}) -- 172
			end) -- 172
		end}) -- 171
		__TS__Await(executeAgentToolDefinition( -- 176
			progressDefinition, -- 176
			{value = 1}, -- 176
			createContext({onProgress = function() -- 176
				local ____progressCount_15 = progressCount -- 176
				progressCount = ____progressCount_15 + 1 -- 176
				return ____progressCount_15 -- 176
			end}), -- 176
			schemaContext -- 176
		)) -- 176
		check(progressCount == 1, "forward progress without settling result") -- 177
		local cancelDuringToken = {stopped = false} -- 179
		local cancelDuring = __TS__Await(executeAgentToolDefinition( -- 180
			createDefinition({handler = function(_context, input) -- 180
				return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 180
					cancelDuringToken.stopped = true -- 182
					cancelDuringToken.reason = "cancel during handler" -- 183
					return ____awaiter_resolve(nil, {output = {success = true, value = input.value}}) -- 183
				end) -- 183
			end}), -- 181
			{value = 1}, -- 186
			createContext({stopToken = cancelDuringToken}), -- 186
			schemaContext -- 186
		)) -- 186
		check(cancelDuring.output.code == "TOOL_CANCELLED", "cancel after handler cleanup") -- 187
		local afterDenialRan = false -- 189
		local monotonicGuards = { -- 190
			function() return nil end, -- 191
			function() return {denied = true, code = "DENIED", message = "no"} end, -- 192
			function() -- 193
				afterDenialRan = true -- 193
				return nil -- 193
			end -- 193
		} -- 193
		local monotonic = __TS__Await(executeAgentToolDefinition( -- 195
			createDefinition(), -- 195
			{value = 1}, -- 195
			createContext(), -- 195
			schemaContext, -- 195
			monotonicGuards -- 195
		)) -- 195
		check(monotonic.output.code == "DENIED" and not afterDenialRan, "guard denial is monotonic") -- 196
		local unknown = __TS__Await(executeRegisteredAgentTool({ -- 198
			tool = "not_a_tool", -- 199
			input = {}, -- 200
			context = createContext(), -- 201
			schemaContext = schemaContext -- 202
		})) -- 202
		check(unknown.output.code == "UNKNOWN_TOOL", "reject unknown registered tool") -- 204
		return ____awaiter_resolve(nil, {success = #failures == 0, passed = passed, total = total, failures = failures}) -- 204
	end) -- 204
end -- 19
function ____exports.printAgentToolExecutorTestResult() -- 209
	local ____self_16 = ____exports.runAgentToolExecutorTests() -- 209
	____self_16["then"]( -- 209
		____self_16, -- 209
		function(____, result) return print((((((("AGENT_TOOL_EXECUTOR_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) end, -- 211
		function(____, ____error) return print("AGENT_TOOL_EXECUTOR_TEST rejected=" .. tostring(____error)) end -- 212
	) -- 212
end -- 209
return ____exports -- 209