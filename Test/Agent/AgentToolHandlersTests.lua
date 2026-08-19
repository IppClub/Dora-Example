-- [ts]: AgentToolHandlersTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__AsyncAwaiter = ____lualib.__TS__AsyncAwaiter -- 1
local __TS__Await = ____lualib.__TS__Await -- 1
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Content = ____Dora.Content -- 2
local Path = ____Dora.Path -- 2
local ____AgentToolExecutor = require("Agent.AgentToolExecutor") -- 3
local executeRegisteredAgentTool = ____AgentToolExecutor.executeRegisteredAgentTool -- 3
local ____AgentToolRegistry = require("Agent.AgentToolRegistry") -- 4
local getToolDefinition = ____AgentToolRegistry.getToolDefinition -- 4
local Tools = require("Agent.Tools") -- 5
function ____exports.runAgentToolHandlersTests(workDir, runNestedCommandTests) -- 15
	if runNestedCommandTests == nil then -- 15
		runNestedCommandTests = false -- 15
	end -- 15
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 15
		local passed = 0 -- 16
		local total = 0 -- 17
		local failures = {} -- 18
		local function check(condition, name) -- 19
			total = total + 1 -- 20
			if condition then -- 20
				passed = passed + 1 -- 21
			else -- 21
				failures[#failures + 1] = name -- 22
			end -- 22
		end -- 19
		local function isTrue(value) -- 24
			return value == true -- 25
		end -- 24
		local stopToken = {stopped = false} -- 28
		local context = { -- 29
			sessionId = 10, -- 30
			taskId = 1, -- 31
			step = 1, -- 32
			workingDir = workDir, -- 33
			role = "main", -- 34
			workMode = "code", -- 35
			useChineseResponse = false, -- 36
			disabledAgentTools = {}, -- 37
			cancellation = { -- 38
				stopToken = stopToken, -- 39
				isCancelled = function() return stopToken.stopped end, -- 40
				reason = function() return nil end -- 41
			}, -- 41
			emitProgress = function() -- 43
			end, -- 43
			services = {}, -- 44
			workflow = {} -- 45
		} -- 45
		local schemaContext = {searchDoraDocLimitMax = 20} -- 47
		local migrated = { -- 48
			"read_file", -- 49
			"grep_files", -- 49
			"glob_files", -- 49
			"search_dora_doc", -- 49
			"build", -- 50
			"fetch_url", -- 50
			"execute_command", -- 50
			"edit_file", -- 50
			"delete_file", -- 50
			"ask_user", -- 51
			"spawn_sub_agent", -- 51
			"list_sub_agents", -- 51
			"finish" -- 52
		} -- 52
		for ____, name in ipairs(migrated) do -- 54
			local ____check_2 = check -- 55
			local ____opt_0 = getToolDefinition(name) -- 55
			____check_2((____opt_0 and ____opt_0.handler) ~= nil, name .. " has registered handler") -- 55
		end -- 55
		check(#migrated == 13, "all registered tools have handlers") -- 57
		local read = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "README.md", startLine = 1, endLine = 3}}}, context = context, schemaContext = schemaContext})) -- 59
		local readResults = read.output.results -- 65
		local ____check_8 = check -- 66
		local ____temp_7 = read.output.success == true -- 66
		if ____temp_7 then -- 66
			local ____opt_3 = readResults and readResults[1] -- 66
			____temp_7 = type(____opt_3 and ____opt_3.content) == "string" -- 66
		end -- 66
		____check_8(____temp_7, "read_file returns one-item batch content") -- 66
		context.workflow.resumeNarrowReadMode = true -- 68
		local narrowRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "Test/Agent/AgentToolHandlersTests.ts", startLine = 1, endLine = 300}}}, context = context, schemaContext = schemaContext})) -- 69
		local narrowResults = narrowRead.output.results -- 75
		local ____check_19 = check -- 76
		local ____temp_13 = narrowRead.output.success == true -- 76
		if ____temp_13 then -- 76
			local ____opt_9 = narrowResults and narrowResults[1] -- 76
			____temp_13 = (____opt_9 and ____opt_9.clipped) == true -- 76
		end -- 76
		local ____temp_13_18 = ____temp_13 -- 76
		if ____temp_13_18 then -- 76
			local ____opt_14 = narrowResults and narrowResults[1] -- 76
			____temp_13_18 = (____opt_14 and ____opt_14.endLine) == 160 -- 76
		end -- 76
		____check_19(____temp_13_18, "read_file preserves post-compression clipping") -- 76
		context.workflow.resumeNarrowReadMode = false -- 77
		local batchRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "README.md", startLine = 1, endLine = 2}, {path = "README.zh-CN.md", startLine = 1, endLine = 2}}}, context = context, schemaContext = schemaContext})) -- 78
		local batchReadResults = batchRead.output.results -- 87
		check(batchRead.output.success == true and batchRead.output.readCount == 2 and (batchReadResults and #batchReadResults) == 2, "read_file batch returns independent ordered results") -- 88
		local partialBatchRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "README.md", startLine = 1, endLine = 1}, {path = ".agent/definitely-missing-read-batch.tmp", startLine = 1, endLine = 1}}}, context = context, schemaContext = schemaContext})) -- 89
		check(partialBatchRead.output.success == false and partialBatchRead.output.partial == true and partialBatchRead.output.succeededReadCount == 1, "read_file batch preserves successful reads after a failure") -- 98
		local glob = __TS__Await(executeRegisteredAgentTool({tool = "glob_files", input = {path = "Test/Agent", globs = {"**/*.ts"}, maxEntries = 5}, context = context, schemaContext = schemaContext})) -- 100
		check( -- 106
			glob.output.success == true and __TS__ArrayIsArray(glob.output.files), -- 106
			"glob_files returns file list" -- 106
		) -- 106
		local grep = __TS__Await(executeRegisteredAgentTool({tool = "grep_files", input = {path = "README.md", pattern = "Dora SSR", limit = 5}, context = context, schemaContext = schemaContext})) -- 108
		check( -- 114
			grep.output.success == true and type(grep.output.totalResults) == "number", -- 114
			"grep_files returns search result" -- 114
		) -- 114
		local beforeSearches = context.workflow.apiSearchesSinceBuild or 0 -- 116
		local doc = __TS__Await(executeRegisteredAgentTool({tool = "search_dora_doc", input = {pattern = "Node", docType = "dora-api", programmingLanguage = "ts", limit = 1}, context = context, schemaContext = schemaContext})) -- 117
		check(doc.output.success == true, "search_dora_doc returns result") -- 123
		check(context.workflow.apiSearchesSinceBuild == beforeSearches + 1, "search_dora_doc updates workflow counter") -- 124
		context.workflow.unbuiltEdits = true -- 126
		context.workflow.editsSinceBuild = 2 -- 127
		context.workflow.editedPathsSinceBuild = {"Test/Agent/JsonSchemaTests.ts"} -- 128
		context.workflow.freshProjectBuildPending = true -- 129
		local build = __TS__Await(executeRegisteredAgentTool({tool = "build", input = {paths = {"Test/Agent/JsonSchemaTests.ts"}}, context = context, schemaContext = schemaContext})) -- 130
		check(build.output.success == true, "build returns success") -- 136
		check( -- 137
			not isTrue(context.workflow.unbuiltEdits) and context.workflow.editsSinceBuild == 0 and isTrue(context.workflow.hasBuilt) and isTrue(context.workflow.lastBuildSucceeded) and not isTrue(context.workflow.freshProjectBuildPending), -- 138
			"build updates workflow state" -- 143
		) -- 143
		local batchBuild = __TS__Await(executeRegisteredAgentTool({tool = "build", input = {paths = {"Test/Agent/AgentToolBatchTests.ts", "Test/Agent/AgentToolRegistryTests.ts"}}, context = context, schemaContext = schemaContext})) -- 145
		check(batchBuild.output.success == true and batchBuild.output.buildCount == 2 and batchBuild.output.succeededBuildCount == 2, "build batch compiles independent targets in one call") -- 151
		local rejectedFetch = __TS__Await(executeRegisteredAgentTool({tool = "fetch_url", input = {url = "ftp://example.invalid/file", target = ".agent/invalid-fetch"}, context = context, schemaContext = schemaContext})) -- 153
		check(rejectedFetch.output.success == false, "fetch_url preserves controlled rejection") -- 159
		if runNestedCommandTests then -- 159
			context.workflow.failedTestNeedsBuild = true -- 162
			context.workflow.failedTestHasSourceEdit = true -- 163
			local commandPass = __TS__Await(executeRegisteredAgentTool({tool = "execute_command", input = {mode = "lua", code = "print('passed')", timeoutSeconds = 5}, context = context, schemaContext = schemaContext})) -- 164
			check(commandPass.output.success == true, "execute_command runs Lua") -- 170
			check( -- 171
				not isTrue(context.workflow.failedTestNeedsBuild) and not isTrue(context.workflow.failedTestHasSourceEdit), -- 171
				"Lua passed marker clears deterministic failure state" -- 171
			) -- 171
			local commandFail = __TS__Await(executeRegisteredAgentTool({tool = "execute_command", input = {mode = "lua", code = "print('failed: 1')", timeoutSeconds = 5}, context = context, schemaContext = schemaContext})) -- 173
			check(commandFail.output.success == true, "execute_command returns output containing failed marker") -- 179
			check( -- 180
				isTrue(context.workflow.failedTestNeedsBuild) and not isTrue(context.workflow.failedTestHasSourceEdit), -- 180
				"Lua failed marker sets deterministic failure state" -- 180
			) -- 180
		end -- 180
		local createdTask = Tools.createTask("AgentToolHandlersTests R5", "code") -- 183
		check(createdTask.success == true, "create isolated checkpoint task") -- 184
		if createdTask.success then -- 184
			context.taskId = createdTask.taskId -- 186
			local testPath = (".agent/r5-runtime-" .. tostring(os.time())) .. ".tmp" -- 187
			local create = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = testPath, old_str = "", new_str = "alpha\nbeta\n"}, context = context, schemaContext = schemaContext})) -- 188
			check( -- 194
				create.output.success == true and create.output.mode == "create" and type(create.output.checkpointId) == "number", -- 194
				"edit_file creates checkpointed file" -- 194
			) -- 194
			local replace = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = testPath, old_str = "beta", new_str = "gamma"}, context = context, schemaContext = schemaContext})) -- 195
			local readEdited = Tools.readFileRaw(workDir, testPath) -- 201
			check( -- 202
				replace.output.success == true and replace.output.mode == "replace" and readEdited.success and (string.find(readEdited.content, "gamma", nil, true) or 0) - 1 >= 0, -- 202
				"edit_file replaces exact text" -- 202
			) -- 202
			local batchPathA = (".agent/r5-batch-a-" .. tostring(os.time())) .. ".tmp" -- 203
			local batchPathB = (".agent/r5-batch-b-" .. tostring(os.time())) .. ".tmp" -- 204
			local batch = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {edits = {{path = batchPathA, old_str = "", new_str = "alpha\none\n"}, {path = batchPathB, old_str = "", new_str = "beta\n"}, {path = batchPathA, old_str = "alpha", new_str = "ALPHA"}, {path = batchPathA, old_str = "one", new_str = "ONE"}}}, context = context, schemaContext = schemaContext})) -- 205
			local batchA = Tools.readFileRaw(workDir, batchPathA) -- 218
			local batchB = Tools.readFileRaw(workDir, batchPathB) -- 219
			check( -- 220
				batch.output.success == true and batch.output.mode == "batch" and batch.output.operationCount == 4 and batch.output.fileCount == 2 and type(batch.output.checkpointId) == "number" and batchA.success and batchA.content == "ALPHA\nONE\n" and batchB.success and batchB.content == "beta\n", -- 221
				"edit_file batch stages ordered same-file edits and commits multiple files once" -- 228
			) -- 228
			local commonPathBatch = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = batchPathA, edits = {{old_str = "ALPHA", new_str = "alpha"}, {old_str = "ONE", new_str = "one"}}}, context = context, schemaContext = schemaContext})) -- 230
			local commonPathA = Tools.readFileRaw(workDir, batchPathA) -- 242
			check(commonPathBatch.output.success == true and commonPathBatch.output.succeededOperationCount == 2 and commonPathA.success and commonPathA.content == "alpha\none\n", "edit_file batch accepts a top-level default path") -- 243
			local partialFailure = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {edits = {{path = batchPathA, old_str = "alpha", new_str = "CHANGED"}, {path = batchPathB, old_str = "missing", new_str = "never"}}}, context = context, schemaContext = schemaContext})) -- 249
			local partiallyChangedA = Tools.readFileRaw(workDir, batchPathA) -- 260
			local preservedB = Tools.readFileRaw(workDir, batchPathB) -- 261
			check(partialFailure.output.success == true and partialFailure.output.partial == true and partialFailure.output.succeededOperationCount == 1 and partialFailure.output.failedOperationCount == 1 and partiallyChangedA.success and partiallyChangedA.content == "CHANGED\none\n" and preservedB.success and preservedB.content == "beta\n", "edit_file batch retains successful replacements when another entry fails") -- 262
			local planBatchPath = (".agent/plan/r5-batch-" .. tostring(os.time())) .. ".tmp" -- 271
			local deniedPlanBatchPath = (".agent/r5-plan-denied-" .. tostring(os.time())) .. ".tmp" -- 272
			local planBatch = __TS__Await(executeRegisteredAgentTool({ -- 273
				tool = "edit_file", -- 274
				input = {edits = {{path = planBatchPath, old_str = "", new_str = "plan"}, {path = deniedPlanBatchPath, old_str = "", new_str = "denied"}}}, -- 275
				context = __TS__ObjectAssign({}, context, {workMode = "plan"}), -- 281
				schemaContext = schemaContext -- 282
			})) -- 282
			check( -- 284
				planBatch.output.success == true and planBatch.output.partial == true and Tools.readFileRaw(workDir, planBatchPath).success and not Tools.readFileRaw(workDir, deniedPlanBatchPath).success, -- 285
				"edit_file Plan batch commits allowed entries and skips denied paths" -- 289
			) -- 289
			for ____, batchPath in ipairs({batchPathA, batchPathB, planBatchPath}) do -- 291
				local cleanup = __TS__Await(executeRegisteredAgentTool({ -- 292
					tool = "delete_file", -- 293
					input = {target_file = batchPath}, -- 294
					context = batchPath == planBatchPath and __TS__ObjectAssign({}, context, {workMode = "plan"}) or context, -- 295
					schemaContext = schemaContext -- 296
				})) -- 296
				check(cleanup.output.success == true, "clean batch test file " .. batchPath) -- 298
			end -- 298
			local remove = __TS__Await(executeRegisteredAgentTool({tool = "delete_file", input = {target_file = testPath}, context = context, schemaContext = schemaContext})) -- 300
			check( -- 306
				remove.output.success == true and remove.output.mode == "delete" and type(remove.output.checkpointId) == "number", -- 306
				"delete_file creates checkpoint and removes file" -- 306
			) -- 306
			check( -- 307
				not Tools.readFileRaw(workDir, testPath).success, -- 307
				"delete_file removed isolated test file" -- 307
			) -- 307
			check( -- 308
				isTrue(context.workflow.unbuiltEdits) and (context.workflow.editsSinceBuild or 0) == 12, -- 308
				"file side effects count only successful batch operations" -- 308
			) -- 308
			Tools.setTaskStatus(createdTask.taskId, "DONE") -- 309
		end -- 309
		local publishedStep = 0 -- 312
		context.services.publishQuestionnaire = function(____, request) -- 313
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 313
				publishedStep = request.step -- 314
				return ____awaiter_resolve(nil, {success = true, questionnaireId = 77}) -- 314
			end) -- 314
		end -- 313
		local ask = __TS__Await(executeRegisteredAgentTool({ -- 317
			tool = "ask_user", -- 318
			input = {title = "Choose", questions = {{id = "mode", prompt = "Mode?", type = "single_choice", options = {{id = "a", label = "A"}, {id = "b", label = "B"}}}}}, -- 319
			context = __TS__ObjectAssign({}, context, {workMode = "plan"}), -- 323
			schemaContext = schemaContext -- 324
		})) -- 324
		local ____check_25 = check -- 326
		local ____temp_24 = ask.output.success == true -- 326
		if ____temp_24 then -- 326
			local ____opt_22 = ask.control -- 326
			____temp_24 = (____opt_22 and ____opt_22.waitForUser) == true -- 326
		end -- 326
		____check_25(____temp_24 and ask.control.questionnaireId == 77, "ask_user publishes structured wait control") -- 326
		check(publishedStep == context.step and context.workflow.waitingQuestionnaireId == 77, "ask_user updates waiting workflow state") -- 327
		local inheritedDisabled = {} -- 329
		context.disabledAgentTools = {"fetch_url"} -- 330
		context.services.spawnSubAgent = function(____, request) -- 331
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 331
				inheritedDisabled = request.disabledAgentTools or ({}) -- 332
				return ____awaiter_resolve(nil, {success = true, sessionId = 11, taskId = 12, title = request.title}) -- 332
			end) -- 332
		end -- 331
		local spawn = __TS__Await(executeRegisteredAgentTool({tool = "spawn_sub_agent", input = {title = "Worker", prompt = "Do bounded work", filesHint = {"a.ts"}}, context = context, schemaContext = schemaContext})) -- 335
		local ____check_29 = check -- 341
		local ____temp_28 = spawn.output.success == true -- 341
		if ____temp_28 then -- 341
			local ____opt_26 = spawn.control -- 341
			____temp_28 = (____opt_26 and ____opt_26.spawnedSubAgent) == true -- 341
		end -- 341
		____check_29(____temp_28 and context.workflow.hasSpawnedSubAgentThisTask == true, "spawn_sub_agent returns asynchronous control") -- 341
		check( -- 342
			table.concat(inheritedDisabled, ",") == "fetch_url", -- 342
			"spawn_sub_agent inherits disabled tools" -- 342
		) -- 342
		context.disabledAgentTools = {} -- 344
		context.services.listSubAgents = function(____, request) return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 345
			return ____awaiter_resolve(nil, { -- 345
				success = true, -- 346
				rootSessionId = request.sessionId, -- 347
				maxConcurrent = 4, -- 348
				status = request.status or "active_or_recent", -- 349
				limit = request.limit or 5, -- 350
				offset = request.offset or 0, -- 351
				hasMore = false, -- 352
				sessions = {} -- 353
			}) -- 353
		end) end -- 353
		local listed = __TS__Await(executeRegisteredAgentTool({tool = "list_sub_agents", input = {status = "running", limit = 3, offset = 0}, context = context, schemaContext = schemaContext})) -- 355
		check(listed.output.success == true and listed.output.status == "running" and listed.output.limit == 3, "list_sub_agents uses restricted service") -- 361
		local finished = __TS__Await(executeRegisteredAgentTool({ -- 363
			tool = "finish", -- 364
			input = { -- 365
				message = "Done", -- 366
				outcome = "partial", -- 367
				validation = {{kind = "build", result = "passed", evidence = {"24 files"}}}, -- 368
				knownIssues = {"manual not run"}, -- 369
				assumptions = {}, -- 370
				learningCandidates = {} -- 371
			}, -- 371
			context = __TS__ObjectAssign({}, context, {role = "sub"}), -- 373
			schemaContext = schemaContext -- 374
		})) -- 374
		check(finished.output.success == true and finished.output.message == "Done" and finished.output.concludeTask == nil, "finish output does not expose internal control") -- 376
		local ____check_35 = check -- 377
		local ____opt_30 = finished.control -- 377
		local ____temp_34 = (____opt_30 and ____opt_30.concludeTask) == true and finished.control.finalMessage == "Done" -- 378
		if ____temp_34 then -- 378
			local ____opt_32 = finished.control.completion -- 378
			____temp_34 = (____opt_32 and ____opt_32.outcome) == "partial" -- 378
		end -- 378
		____check_35(____temp_34, "finish returns structured completion control") -- 377
		local ____check_40 = check -- 383
		local ____opt_38 = finished.control -- 383
		local ____opt_36 = ____opt_38 and ____opt_38.completion -- 383
		____check_40((____opt_36 and ____opt_36.budgetExhausted) == false, "sub-agent finish has no exhausted budget marker") -- 383
		return ____awaiter_resolve(nil, {success = #failures == 0, passed = passed, total = total, failures = failures}) -- 383
	end) -- 383
end -- 15
function ____exports.printAgentToolHandlersTestResult(workDir) -- 388
	if workDir == nil then -- 388
		workDir = Path(Content.writablePath, "Dora-Example") -- 388
	end -- 388
	local ____self_41 = ____exports.runAgentToolHandlersTests(workDir) -- 388
	____self_41["then"]( -- 388
		____self_41, -- 388
		function(____, result) return print((((((("AGENT_TOOL_HANDLERS_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) end, -- 390
		function(____, ____error) return print("AGENT_TOOL_HANDLERS_TEST rejected=" .. tostring(____error)) end -- 391
	) -- 391
end -- 388
return ____exports -- 388