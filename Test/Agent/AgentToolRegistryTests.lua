-- [ts]: AgentToolRegistryTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArrayFilter = ____lualib.__TS__ArrayFilter -- 1
local __TS__ArrayFind = ____lualib.__TS__ArrayFind -- 1
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray -- 1
local ____exports = {} -- 1
local Registry = require("Agent.Tool.Registry") -- 2
local ____JsonSchema = require("Agent.JsonSchema") -- 3
local compileJsonSchema = ____JsonSchema.compileJsonSchema -- 3
function ____exports.runAgentToolRegistryTests() -- 13
	local passed = 0 -- 14
	local total = 0 -- 15
	local failures = {} -- 16
	local function check(condition, name) -- 17
		total = total + 1 -- 18
		if condition then -- 18
			passed = passed + 1 -- 19
		else -- 19
			failures[#failures + 1] = name -- 20
		end -- 20
	end -- 17
	local expectedNames = { -- 23
		"read_file", -- 24
		"edit_file", -- 24
		"delete_file", -- 24
		"grep_files", -- 24
		"glob_files", -- 24
		"search_dora_doc", -- 24
		"build", -- 25
		"fetch_url", -- 25
		"execute_command", -- 25
		"finish", -- 25
		"list_sub_agents", -- 25
		"spawn_sub_agent", -- 25
		"ask_user" -- 25
	} -- 25
	check(#Registry.AGENT_TOOL_DEFINITIONS == #expectedNames, "registry contains 13 tools") -- 27
	for ____, name in ipairs(expectedNames) do -- 28
		check( -- 29
			Registry.isKnownToolName(name), -- 29
			"known tool " .. name -- 29
		) -- 29
		local ____check_2 = check -- 30
		local ____opt_0 = Registry.getToolDefinition(name) -- 30
		____check_2((____opt_0 and ____opt_0.name) == name, "definition lookup " .. name) -- 30
	end -- 30
	local seen = {} -- 33
	local schemasValid = true -- 34
	for ____, definition in ipairs(Registry.AGENT_TOOL_DEFINITIONS) do -- 35
		if __TS__ArrayIndexOf(seen, definition.name) >= 0 then -- 35
			schemasValid = false -- 36
		end -- 36
		seen[#seen + 1] = definition.name -- 37
		if not compileJsonSchema(definition:inputSchema({searchDoraDocLimitMax = 20})).success then -- 37
			schemasValid = false -- 38
		end -- 38
		if not compileJsonSchema(definition.outputSchema).success then -- 38
			schemasValid = false -- 39
		end -- 39
	end -- 39
	check(schemasValid, "definitions are unique with valid input and output schemas") -- 41
	local function names(role, workMode) -- 43
		return table.concat( -- 44
			Registry.getAllowedToolsForRole(role, {workMode = workMode}), -- 44
			"," -- 44
		) -- 44
	end -- 43
	check( -- 46
		names("main", "code") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,list_sub_agents,spawn_sub_agent", -- 46
		"main code matrix" -- 46
	) -- 46
	check( -- 47
		names("main", "plan") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,ask_user", -- 47
		"main plan matrix" -- 47
	) -- 47
	check( -- 48
		names("sub", "code") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,finish", -- 48
		"sub code matrix" -- 48
	) -- 48
	check( -- 49
		names("sub", "plan") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,finish", -- 49
		"sub plan matrix" -- 49
	) -- 49
	check( -- 50
		__TS__ArrayIndexOf( -- 50
			Registry.getAllowedToolsForRole("main", {workMode = "code", disabledAgentTools = {"build"}}), -- 50
			"build" -- 50
		) < 0, -- 50
		"disabled tool removed" -- 50
	) -- 50
	check( -- 51
		table.concat( -- 51
			__TS__ArrayFilter( -- 51
				expectedNames, -- 51
				function(____, name) -- 51
					local ____opt_3 = Registry.getToolDefinition(name) -- 51
					return (____opt_3 and ____opt_3.handler) ~= nil -- 51
				end -- 51
			), -- 51
			"," -- 51
		) == table.concat(expectedNames, ","), -- 51
		"all tools have one registered handler" -- 51
	) -- 51
	local ____opt_5 = Registry.getToolDefinition("glob_files") -- 51
	local globValidator = ____opt_5 and ____opt_5.validateInput -- 52
	local normalizedGlob = globValidator and globValidator({path = "Assets/Script/Lib/Agent", maxEntries = 5}) -- 53
	check((normalizedGlob and normalizedGlob.success) == true and normalizedGlob.value.path == "Assets/Script/Lib/Agent" and normalizedGlob.value.maxEntries == 5, "semantic validator receives tool input without method self injection") -- 54
	local parallel = __TS__ArrayFilter( -- 56
		expectedNames, -- 56
		function(____, name) return Registry.canRunToolInParallel(name) end -- 56
	) -- 56
	check( -- 57
		table.concat(parallel, ",") == "read_file,grep_files,glob_files,search_dora_doc,list_sub_agents", -- 57
		"parallel-safe matrix" -- 57
	) -- 57
	check( -- 58
		#__TS__ArrayFilter( -- 58
			expectedNames, -- 58
			function(____, name) return Registry.canPreExecuteTool(name) end -- 58
		) == 0, -- 58
		"pre-executable baseline" -- 58
	) -- 58
	local mainSchemas = Registry.buildDecisionToolSchema("main", 20, {workMode = "code"}) -- 60
	check(#mainSchemas == 11, "main code function schema count") -- 61
	local readSchema = __TS__ArrayFind( -- 62
		mainSchemas, -- 62
		function(____, item) return item["function"].name == "read_file" end -- 62
	) -- 62
	local readParams = readSchema and readSchema["function"].parameters -- 63
	local readProperties = readParams and readParams.properties -- 64
	local readBatchSchema = readProperties and readProperties.reads -- 65
	check( -- 66
		__TS__ArrayIsArray(readParams and readParams.required) and table.concat(readParams.required, ",") == "reads" and (readBatchSchema and readBatchSchema.minItems) == 1 and readBatchSchema.maxItems == nil, -- 66
		"read_file requires an unbounded reads array" -- 66
	) -- 66
	local ____opt_21 = Registry.getToolDefinition("read_file") -- 66
	local readValidator = ____opt_21 and ____opt_21.validateInput -- 67
	local batchRead = readValidator and readValidator({reads = {{path = "a.ts", startLine = 1, endLine = 2}, {path = "b.ts", startLine = -2}}}) -- 68
	local legacyRead = readValidator and readValidator({path = "a.ts", startLine = 1, endLine = 2}) -- 69
	local emptyRead = readValidator and readValidator({reads = {}}) -- 70
	check((batchRead and batchRead.success) == true and #batchRead.value.reads == 2, "read_file validator accepts and normalizes reads") -- 71
	check((legacyRead and legacyRead.success) == false and (emptyRead and emptyRead.success) == false, "read_file validator rejects legacy and empty forms") -- 72
	local ____opt_35 = __TS__ArrayFind( -- 72
		mainSchemas, -- 73
		function(____, item) return item["function"].name == "build" end -- 73
	) -- 73
	local buildSchema = ____opt_35 and ____opt_35["function"].parameters -- 73
	local ____opt_37 = Registry.getToolDefinition("build") -- 73
	local buildValidator = ____opt_37 and ____opt_37.validateInput -- 74
	check( -- 75
		__TS__ArrayIsArray(buildSchema and buildSchema.required) and table.concat(buildSchema.required, ",") == "paths", -- 75
		"build schema requires paths" -- 75
	) -- 75
	check( -- 76
		(buildValidator and buildValidator({paths = {"a.ts", "b.ts"}}).success) == true, -- 76
		"build validator accepts paths" -- 76
	) -- 76
	check( -- 77
		(buildValidator and buildValidator({path = "a.ts"}).success) == false and (buildValidator and buildValidator({paths = {}}).success) == false, -- 77
		"build validator rejects legacy and empty forms" -- 77
	) -- 77
	local ____opt_47 = __TS__ArrayFind( -- 77
		mainSchemas, -- 78
		function(____, item) return item["function"].name == "edit_file" end -- 78
	) -- 78
	local editSchema = ____opt_47 and ____opt_47["function"].parameters -- 78
	local editProperties = editSchema and editSchema.properties -- 79
	local editBatchSchema = editProperties and editProperties.edits -- 80
	check((editBatchSchema and editBatchSchema.minItems) == 1 and editBatchSchema.maxItems == nil, "edit_file batch is non-empty without an artificial upper bound") -- 81
	local ____opt_55 = Registry.getToolDefinition("edit_file") -- 81
	local editValidator = ____opt_55 and ____opt_55.validateInput -- 82
	local legacyEdit = editValidator and editValidator({path = "a.ts", old_str = "a", new_str = "b"}) -- 83
	local batchEdit = editValidator and editValidator({edits = {{path = "a.ts", old_str = "a", new_str = "b"}, {path = "b.ts", old_str = "", new_str = "x"}}}) -- 84
	local commonPathBatchEdit = editValidator and editValidator({path = "a.ts", edits = {{old_str = "a", new_str = "b"}, {old_str = "b", new_str = "c"}}}) -- 85
	local mixedEdit = editValidator and editValidator({path = "a.ts", old_str = "a", new_str = "b", edits = {{path = "b.ts", old_str = "b", new_str = "c"}}}) -- 86
	local emptyBatchEdit = editValidator and editValidator({edits = {}}) -- 87
	local commonPathEdits = (commonPathBatchEdit and commonPathBatchEdit.success) == true and commonPathBatchEdit.value.edits or ({}) -- 88
	check((legacyEdit and legacyEdit.success) == true and (batchEdit and batchEdit.success) == true, "edit_file validator preserves legacy form and accepts batch form") -- 89
	check(#commonPathEdits == 2 and commonPathEdits[1].path == "a.ts" and commonPathEdits[2].path == "a.ts", "edit_file batch applies top-level default path") -- 90
	check((mixedEdit and mixedEdit.success) == false and (emptyBatchEdit and emptyBatchEdit.success) == false, "edit_file validator rejects mixed and empty forms") -- 91
	local ____opt_77 = __TS__ArrayFind( -- 91
		Registry.buildDecisionToolSchema("main", 20, {workMode = "code"}), -- 93
		function(____, item) return item["function"].name == "finish" end -- 94
	) -- 94
	local mainFinish = ____opt_77 and ____opt_77["function"].parameters -- 93
	local ____opt_79 = __TS__ArrayFind( -- 93
		Registry.buildDecisionToolSchema("sub", 20, {workMode = "code"}), -- 95
		function(____, item) return item["function"].name == "finish" end -- 96
	) -- 96
	local subFinish = ____opt_79 and ____opt_79["function"].parameters -- 95
	check(mainFinish == nil, "finish is hidden from main agents") -- 97
	check( -- 98
		__TS__ArrayIsArray(subFinish and subFinish.required) and table.concat(subFinish and subFinish.required, ",") == "message,outcome,validation,knownIssues,assumptions,learningCandidates", -- 98
		"sub finish strict requirements" -- 98
	) -- 98
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 100
end -- 13
return ____exports -- 13