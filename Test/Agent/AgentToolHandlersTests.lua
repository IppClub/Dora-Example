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
local ____HistoryProjection = require("Agent.Runtime.HistoryProjection") -- 3
local sanitizeReadResultForHistory = ____HistoryProjection.sanitizeReadResultForHistory -- 3
local ____Executor = require("Agent.Tool.Executor") -- 4
local executeRegisteredAgentTool = ____Executor.executeRegisteredAgentTool -- 4
local ____Registry = require("Agent.Tool.Registry") -- 5
local getToolDefinition = ____Registry.getToolDefinition -- 5
local Tools = require("Agent.Tools") -- 6
function ____exports.runAgentToolHandlersTests(workDir, runNestedCommandTests) -- 16
	if runNestedCommandTests == nil then -- 16
		runNestedCommandTests = false -- 16
	end -- 16
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 16
		local passed = 0 -- 17
		local total = 0 -- 18
		local failures = {} -- 19
		local function check(condition, name) -- 20
			total = total + 1 -- 21
			if condition then -- 21
				passed = passed + 1 -- 22
			else -- 22
				failures[#failures + 1] = name -- 23
			end -- 23
		end -- 20
		local function isTrue(value) -- 25
			return value == true -- 26
		end -- 25
		local stopToken = {stopped = false} -- 29
		local context = { -- 30
			sessionId = 10, -- 31
			taskId = 1, -- 32
			step = 1, -- 33
			workingDir = workDir, -- 34
			role = "main", -- 35
			workMode = "code", -- 36
			useChineseResponse = false, -- 37
			disabledAgentTools = {}, -- 38
			cancellation = { -- 39
				stopToken = stopToken, -- 40
				isCancelled = function() return stopToken.stopped end, -- 41
				reason = function() return nil end -- 42
			}, -- 42
			emitProgress = function() -- 44
			end, -- 44
			services = {}, -- 45
			workflow = {} -- 46
		} -- 46
		local schemaContext = {searchDoraDocLimitMax = 20} -- 48
		local migrated = { -- 49
			"read_file", -- 50
			"grep_files", -- 50
			"glob_files", -- 50
			"search_dora_doc", -- 50
			"build", -- 51
			"fetch_url", -- 51
			"execute_command", -- 51
			"edit_file", -- 51
			"delete_file", -- 51
			"ask_user", -- 52
			"spawn_sub_agent", -- 52
			"list_sub_agents", -- 52
			"finish" -- 53
		} -- 53
		for ____, name in ipairs(migrated) do -- 55
			local ____check_2 = check -- 56
			local ____opt_0 = getToolDefinition(name) -- 56
			____check_2((____opt_0 and ____opt_0.handler) ~= nil, name .. " has registered handler") -- 56
		end -- 56
		check(#migrated == 13, "all registered tools have handlers") -- 58
		local read = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {path = "README.md", startLine = 1, endLine = 3}, context = context, schemaContext = schemaContext})) -- 60
		check( -- 66
			read.output.success == true and type(read.output.content) == "string", -- 66
			"read_file returns content" -- 66
		) -- 66
		context.workflow.resumeNarrowReadMode = true -- 68
		local narrowRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {path = "Test/Agent/AgentToolHandlersTests.ts", startLine = 1, endLine = 300}, context = context, schemaContext = schemaContext})) -- 69
		check(narrowRead.output.success == true and narrowRead.output.clipped == true and narrowRead.output.endLine == 160, "read_file preserves post-compression clipping") -- 75
		context.workflow.resumeNarrowReadMode = false -- 76
		local batchRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "README.md", startLine = 1, endLine = 2}, {path = "README.zh-CN.md", startLine = 1, endLine = 2}}}, context = context, schemaContext = schemaContext})) -- 77
		local batchReadResults = batchRead.output.results -- 86
		check( -- 87
			batchRead.output.success == true and batchRead.output.mode == "batch" and batchRead.output.readCount == 2 and (batchReadResults and #batchReadResults) == 2 and type(batchReadResults[1].content) == "string", -- 88
			"read_file batch returns independent ordered results" -- 93
		) -- 93
		local partialBatchRead = __TS__Await(executeRegisteredAgentTool({tool = "read_file", input = {reads = {{path = "README.md", startLine = 1, endLine = 1}, {path = ".agent/definitely-missing-read-batch.tmp", startLine = 1, endLine = 1}}}, context = context, schemaContext = schemaContext})) -- 95
		check(partialBatchRead.output.success == false and partialBatchRead.output.partial == true and partialBatchRead.output.succeededReadCount == 1, "read_file batch preserves successful reads after a failure") -- 104
		local sanitizedBatchRead = sanitizeReadResultForHistory( -- 110
			"read_file", -- 110
			{ -- 110
				success = true, -- 111
				mode = "batch", -- 112
				results = {{ -- 113
					success = true, -- 113
					path = "large.ts", -- 113
					startLine = 1, -- 113
					endLine = 1, -- 113
					totalLines = 1, -- 113
					content = string.rep("x", 20000) -- 113
				}} -- 113
			} -- 113
		) -- 113
		local sanitizedResults = sanitizedBatchRead.results -- 115
		check(sanitizedResults[1].historyContentTruncated == true, "read_file batch history truncates each successful result") -- 116
		local glob = __TS__Await(executeRegisteredAgentTool({tool = "glob_files", input = {path = "Test/Agent", globs = {"**/*.ts"}, maxEntries = 5}, context = context, schemaContext = schemaContext})) -- 118
		check( -- 124
			glob.output.success == true and __TS__ArrayIsArray(glob.output.files), -- 124
			"glob_files returns file list" -- 124
		) -- 124
		local grep = __TS__Await(executeRegisteredAgentTool({tool = "grep_files", input = {path = "README.md", pattern = "Dora SSR", limit = 5}, context = context, schemaContext = schemaContext})) -- 126
		check( -- 132
			grep.output.success == true and type(grep.output.totalResults) == "number", -- 132
			"grep_files returns search result" -- 132
		) -- 132
		local beforeSearches = context.workflow.apiSearchesSinceBuild or 0 -- 134
		local doc = __TS__Await(executeRegisteredAgentTool({tool = "search_dora_doc", input = {pattern = "Node", docType = "dora-api", programmingLanguage = "ts", limit = 1}, context = context, schemaContext = schemaContext})) -- 135
		check(doc.output.success == true, "search_dora_doc returns result") -- 141
		check(context.workflow.apiSearchesSinceBuild == beforeSearches + 1, "search_dora_doc updates workflow counter") -- 142
		context.workflow.unbuiltEdits = true -- 144
		context.workflow.editsSinceBuild = 2 -- 145
		context.workflow.editedPathsSinceBuild = {"Test/Agent/JsonSchemaTests.ts"} -- 146
		context.workflow.freshProjectBuildPending = true -- 147
		local build = __TS__Await(executeRegisteredAgentTool({tool = "build", input = {paths = {"Test/Agent/JsonSchemaTests.ts"}}, context = context, schemaContext = schemaContext})) -- 148
		check(build.output.success == true, "build returns success") -- 154
		check( -- 155
			not isTrue(context.workflow.unbuiltEdits) and context.workflow.editsSinceBuild == 0 and isTrue(context.workflow.hasBuilt) and isTrue(context.workflow.lastBuildSucceeded) and not isTrue(context.workflow.freshProjectBuildPending), -- 156
			"build updates workflow state" -- 161
		) -- 161
		local singlePathBuild = __TS__Await(executeRegisteredAgentTool({tool = "build", input = {path = "Test/Agent/AgentToolBatchTests.ts"}, context = context, schemaContext = schemaContext})) -- 163
		check(singlePathBuild.output.success == true and singlePathBuild.output.mode == "batch" and singlePathBuild.output.buildCount == 1, "build normalizes a historical single path into the batch executor") -- 169
		local batchBuild = __TS__Await(executeRegisteredAgentTool({tool = "build", input = {paths = {"Test/Agent/AgentToolBatchTests.ts", "Test/Agent/AgentToolRegistryTests.ts"}}, context = context, schemaContext = schemaContext})) -- 175
		check(batchBuild.output.success == true and batchBuild.output.mode == "batch" and batchBuild.output.buildCount == 2 and batchBuild.output.succeededBuildCount == 2, "build runs ordered targets and returns per-target results") -- 181
		local rejectedFetch = __TS__Await(executeRegisteredAgentTool({tool = "fetch_url", input = {url = "ftp://example.invalid/file", target = ".agent/invalid-fetch"}, context = context, schemaContext = schemaContext})) -- 188
		check(rejectedFetch.output.success == false, "fetch_url preserves controlled rejection") -- 194
		if runNestedCommandTests then -- 194
			context.workflow.failedTestNeedsBuild = true -- 197
			context.workflow.failedTestHasSourceEdit = true -- 198
			local commandPass = __TS__Await(executeRegisteredAgentTool({tool = "execute_command", input = {mode = "lua", code = "print('passed')", timeoutSeconds = 5}, context = context, schemaContext = schemaContext})) -- 199
			check(commandPass.output.success == true, "execute_command runs Lua") -- 205
			check( -- 206
				not isTrue(context.workflow.failedTestNeedsBuild) and not isTrue(context.workflow.failedTestHasSourceEdit), -- 206
				"Lua passed marker clears deterministic failure state" -- 206
			) -- 206
			local commandFail = __TS__Await(executeRegisteredAgentTool({tool = "execute_command", input = {mode = "lua", code = "print('failed: 1')", timeoutSeconds = 5}, context = context, schemaContext = schemaContext})) -- 208
			check(commandFail.output.success == true, "execute_command returns output containing failed marker") -- 214
			check( -- 215
				isTrue(context.workflow.failedTestNeedsBuild) and not isTrue(context.workflow.failedTestHasSourceEdit), -- 215
				"Lua failed marker sets deterministic failure state" -- 215
			) -- 215
		end -- 215
		local createdTask = Tools.createTask("AgentToolHandlersTests R5", "code") -- 218
		check(createdTask.success == true, "create isolated checkpoint task") -- 219
		if createdTask.success then -- 219
			context.taskId = createdTask.taskId -- 221
			local testPath = (".agent/r5-runtime-" .. tostring(os.time())) .. ".tmp" -- 222
			local create = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = testPath, old_str = "", new_str = "alpha\nbeta\n"}, context = context, schemaContext = schemaContext})) -- 223
			check( -- 229
				create.output.success == true and create.output.mode == "create" and type(create.output.checkpointId) == "number", -- 229
				"edit_file creates checkpointed file" -- 229
			) -- 229
			local replace = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = testPath, old_str = "beta", new_str = "gamma"}, context = context, schemaContext = schemaContext})) -- 230
			local readEdited = Tools.readFileRaw(workDir, testPath) -- 236
			check( -- 237
				replace.output.success == true and replace.output.mode == "replace" and readEdited.success and (string.find(readEdited.content, "gamma", nil, true) or 0) - 1 >= 0, -- 237
				"edit_file replaces exact text" -- 237
			) -- 237
			local batchPathA = (".agent/r5-batch-a-" .. tostring(os.time())) .. ".tmp" -- 238
			local batchPathB = (".agent/r5-batch-b-" .. tostring(os.time())) .. ".tmp" -- 239
			local batch = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {edits = {{path = batchPathA, old_str = "", new_str = "alpha\none\n"}, {path = batchPathB, old_str = "", new_str = "beta\n"}, {path = batchPathA, old_str = "alpha", new_str = "ALPHA"}, {path = batchPathA, old_str = "one", new_str = "ONE"}}}, context = context, schemaContext = schemaContext})) -- 240
			local batchA = Tools.readFileRaw(workDir, batchPathA) -- 253
			local batchB = Tools.readFileRaw(workDir, batchPathB) -- 254
			check( -- 255
				batch.output.success == true and batch.output.mode == "batch" and batch.output.operationCount == 4 and batch.output.fileCount == 2 and type(batch.output.checkpointId) == "number" and batchA.success and batchA.content == "ALPHA\nONE\n" and batchB.success and batchB.content == "beta\n", -- 256
				"edit_file batch stages ordered same-file edits and commits multiple files once" -- 263
			) -- 263
			local commonPathBatch = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {path = batchPathA, edits = {{old_str = "ALPHA", new_str = "alpha"}, {old_str = "ONE", new_str = "one"}}}, context = context, schemaContext = schemaContext})) -- 265
			local commonPathA = Tools.readFileRaw(workDir, batchPathA) -- 277
			check(commonPathBatch.output.success == true and commonPathBatch.output.succeededOperationCount == 2 and commonPathA.success and commonPathA.content == "alpha\none\n", "edit_file batch accepts a top-level default path") -- 278
			local partialFailure = __TS__Await(executeRegisteredAgentTool({tool = "edit_file", input = {edits = {{path = batchPathA, old_str = "alpha", new_str = "CHANGED"}, {path = batchPathB, old_str = "missing", new_str = "never"}}}, context = context, schemaContext = schemaContext})) -- 284
			local partiallyChangedA = Tools.readFileRaw(workDir, batchPathA) -- 295
			local preservedB = Tools.readFileRaw(workDir, batchPathB) -- 296
			check(partialFailure.output.success == true and partialFailure.output.partial == true and partialFailure.output.succeededOperationCount == 1 and partialFailure.output.failedOperationCount == 1 and partiallyChangedA.success and partiallyChangedA.content == "CHANGED\none\n" and preservedB.success and preservedB.content == "beta\n", "edit_file batch retains successful replacements when another entry fails") -- 297
			local planBatchPath = (".agent/plan/r5-batch-" .. tostring(os.time())) .. ".tmp" -- 306
			local deniedPlanBatchPath = (".agent/r5-plan-denied-" .. tostring(os.time())) .. ".tmp" -- 307
			local planBatch = __TS__Await(executeRegisteredAgentTool({ -- 308
				tool = "edit_file", -- 309
				input = {edits = {{path = planBatchPath, old_str = "", new_str = "plan"}, {path = deniedPlanBatchPath, old_str = "", new_str = "denied"}}}, -- 310
				context = __TS__ObjectAssign({}, context, {workMode = "plan"}), -- 316
				schemaContext = schemaContext -- 317
			})) -- 317
			check( -- 319
				planBatch.output.success == true and planBatch.output.partial == true and Tools.readFileRaw(workDir, planBatchPath).success and not Tools.readFileRaw(workDir, deniedPlanBatchPath).success, -- 320
				"edit_file Plan batch commits allowed entries and skips denied paths" -- 324
			) -- 324
			for ____, batchPath in ipairs({batchPathA, batchPathB, planBatchPath}) do -- 326
				local cleanup = __TS__Await(executeRegisteredAgentTool({ -- 327
					tool = "delete_file", -- 328
					input = {target_file = batchPath}, -- 329
					context = batchPath == planBatchPath and __TS__ObjectAssign({}, context, {workMode = "plan"}) or context, -- 330
					schemaContext = schemaContext -- 331
				})) -- 331
				check(cleanup.output.success == true, "clean batch test file " .. batchPath) -- 333
			end -- 333
			local remove = __TS__Await(executeRegisteredAgentTool({tool = "delete_file", input = {target_file = testPath}, context = context, schemaContext = schemaContext})) -- 335
			check( -- 341
				remove.output.success == true and remove.output.mode == "delete" and type(remove.output.checkpointId) == "number", -- 341
				"delete_file creates checkpoint and removes file" -- 341
			) -- 341
			check( -- 342
				not Tools.readFileRaw(workDir, testPath).success, -- 342
				"delete_file removed isolated test file" -- 342
			) -- 342
			check( -- 343
				isTrue(context.workflow.unbuiltEdits) and (context.workflow.editsSinceBuild or 0) == 12, -- 343
				"file side effects count only successful batch operations" -- 343
			) -- 343
			Tools.setTaskStatus(createdTask.taskId, "DONE") -- 344
		end -- 344
		local publishedStep = 0 -- 347
		context.services.publishQuestionnaire = function(____, request) -- 348
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 348
				publishedStep = request.step -- 349
				return ____awaiter_resolve(nil, {success = true, questionnaireId = 77}) -- 349
			end) -- 349
		end -- 348
		local ask = __TS__Await(executeRegisteredAgentTool({ -- 352
			tool = "ask_user", -- 353
			input = {title = "Choose", questions = {{id = "mode", prompt = "Mode?", type = "single_choice", options = {{id = "a", label = "A"}, {id = "b", label = "B"}}}}}, -- 354
			context = __TS__ObjectAssign({}, context, {workMode = "plan"}), -- 358
			schemaContext = schemaContext -- 359
		})) -- 359
		local ____check_8 = check -- 361
		local ____temp_7 = ask.output.success == true -- 361
		if ____temp_7 then -- 361
			local ____opt_5 = ask.control -- 361
			____temp_7 = (____opt_5 and ____opt_5.waitForUser) == true -- 361
		end -- 361
		____check_8(____temp_7 and ask.control.questionnaireId == 77, "ask_user publishes structured wait control") -- 361
		check(publishedStep == context.step and context.workflow.waitingQuestionnaireId == 77, "ask_user updates waiting workflow state") -- 362
		local inheritedDisabled = {} -- 364
		context.disabledAgentTools = {"fetch_url"} -- 365
		context.services.spawnSubAgent = function(____, request) -- 366
			return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 366
				inheritedDisabled = request.disabledAgentTools or ({}) -- 367
				return ____awaiter_resolve(nil, {success = true, sessionId = 11, taskId = 12, title = request.title}) -- 367
			end) -- 367
		end -- 366
		local spawn = __TS__Await(executeRegisteredAgentTool({tool = "spawn_sub_agent", input = {title = "Worker", prompt = "Do bounded work", filesHint = {"a.ts"}}, context = context, schemaContext = schemaContext})) -- 370
		local ____check_12 = check -- 376
		local ____temp_11 = spawn.output.success == true -- 376
		if ____temp_11 then -- 376
			local ____opt_9 = spawn.control -- 376
			____temp_11 = (____opt_9 and ____opt_9.spawnedSubAgent) == true -- 376
		end -- 376
		____check_12(____temp_11 and context.workflow.hasSpawnedSubAgentThisTask == true, "spawn_sub_agent returns asynchronous control") -- 376
		check( -- 377
			table.concat(inheritedDisabled, ",") == "fetch_url", -- 377
			"spawn_sub_agent inherits disabled tools" -- 377
		) -- 377
		context.disabledAgentTools = {} -- 379
		context.services.listSubAgents = function(____, request) return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 380
			return ____awaiter_resolve(nil, { -- 380
				success = true, -- 381
				rootSessionId = request.sessionId, -- 382
				maxConcurrent = 4, -- 383
				status = request.status or "active_or_recent", -- 384
				limit = request.limit or 5, -- 385
				offset = request.offset or 0, -- 386
				hasMore = false, -- 387
				sessions = {} -- 388
			}) -- 388
		end) end -- 388
		local listed = __TS__Await(executeRegisteredAgentTool({tool = "list_sub_agents", input = {status = "running", limit = 3, offset = 0}, context = context, schemaContext = schemaContext})) -- 390
		check(listed.output.success == true and listed.output.status == "running" and listed.output.limit == 3, "list_sub_agents uses restricted service") -- 396
		local finished = __TS__Await(executeRegisteredAgentTool({ -- 398
			tool = "finish", -- 399
			input = { -- 400
				message = "Done", -- 401
				outcome = "partial", -- 402
				validation = {{kind = "build", result = "passed", evidence = {"24 files"}}}, -- 403
				knownIssues = {"manual not run"}, -- 404
				assumptions = {}, -- 405
				learningCandidates = {} -- 406
			}, -- 406
			context = __TS__ObjectAssign({}, context, {role = "sub"}), -- 408
			schemaContext = schemaContext -- 409
		})) -- 409
		check(finished.output.success == true and finished.output.message == "Done" and finished.output.concludeTask == nil, "finish output does not expose internal control") -- 411
		local ____check_18 = check -- 412
		local ____opt_13 = finished.control -- 412
		local ____temp_17 = (____opt_13 and ____opt_13.concludeTask) == true and finished.control.finalMessage == "Done" -- 413
		if ____temp_17 then -- 413
			local ____opt_15 = finished.control.completion -- 413
			____temp_17 = (____opt_15 and ____opt_15.outcome) == "partial" -- 413
		end -- 413
		____check_18(____temp_17, "finish returns structured completion control") -- 412
		local ____check_23 = check -- 418
		local ____opt_21 = finished.control -- 418
		local ____opt_19 = ____opt_21 and ____opt_21.completion -- 418
		____check_23((____opt_19 and ____opt_19.budgetExhausted) == false, "sub-agent finish has no exhausted budget marker") -- 418
		return ____awaiter_resolve(nil, {success = #failures == 0, passed = passed, total = total, failures = failures}) -- 418
	end) -- 418
end -- 16
function ____exports.printAgentToolHandlersTestResult(workDir) -- 423
	if workDir == nil then -- 423
		workDir = Path(Content.writablePath, "Dora-Example") -- 423
	end -- 423
	local ____self_24 = ____exports.runAgentToolHandlersTests(workDir) -- 423
	____self_24["then"]( -- 423
		____self_24, -- 423
		function(____, result) return print((((((("AGENT_TOOL_HANDLERS_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) end, -- 425
		function(____, ____error) return print("AGENT_TOOL_HANDLERS_TEST rejected=" .. tostring(____error)) end -- 426
	) -- 426
end -- 423
return ____exports -- 423