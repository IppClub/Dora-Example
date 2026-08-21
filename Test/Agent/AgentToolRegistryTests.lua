-- [ts]: AgentToolRegistryTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArrayFilter = ____lualib.__TS__ArrayFilter -- 1
local __TS__ArrayFind = ____lualib.__TS__ArrayFind -- 1
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__ArrayJoin = ____lualib.__TS__ArrayJoin -- 1
local ____exports = {} -- 1
local Registry = require("Agent.Tool.Registry") -- 2
local ____JsonSchema = require("Agent.JsonSchema") -- 3
local compileJsonSchema = ____JsonSchema.compileJsonSchema -- 3
function ____exports.runAgentToolRegistryTests() -- 14
	local passed = 0 -- 15
	local total = 0 -- 16
	local failures = {} -- 17
	local function check(condition, name) -- 18
		total = total + 1 -- 19
		if condition then -- 19
			passed = passed + 1 -- 20
		else -- 20
			failures[#failures + 1] = name -- 21
		end -- 21
	end -- 18
	local expectedNames = { -- 24
		"read_file", -- 25
		"edit_file", -- 25
		"delete_file", -- 25
		"grep_files", -- 25
		"glob_files", -- 25
		"search_dora_doc", -- 25
		"build", -- 26
		"fetch_url", -- 26
		"execute_command", -- 26
		"finish", -- 26
		"list_sub_agents", -- 26
		"spawn_sub_agent", -- 26
		"ask_user" -- 26
	} -- 26
	check(#Registry.AGENT_TOOL_DEFINITIONS == #expectedNames, "registry contains 13 tools") -- 28
	for ____, name in ipairs(expectedNames) do -- 29
		check( -- 30
			Registry.isKnownToolName(name), -- 30
			"known tool " .. name -- 30
		) -- 30
		local ____check_2 = check -- 31
		local ____opt_0 = Registry.getToolDefinition(name) -- 31
		____check_2((____opt_0 and ____opt_0.name) == name, "definition lookup " .. name) -- 31
	end -- 31
	local seen = {} -- 34
	local schemasValid = true -- 35
	for ____, definition in ipairs(Registry.AGENT_TOOL_DEFINITIONS) do -- 36
		if __TS__ArrayIndexOf(seen, definition.name) >= 0 then -- 36
			schemasValid = false -- 37
		end -- 37
		seen[#seen + 1] = definition.name -- 38
		if not compileJsonSchema(definition:inputSchema({searchDoraDocLimitMax = 20})).success then -- 38
			schemasValid = false -- 39
		end -- 39
		if not compileJsonSchema(definition.outputSchema).success then -- 39
			schemasValid = false -- 40
		end -- 40
	end -- 40
	check(schemasValid, "definitions are unique with valid input and output schemas") -- 42
	local function names(role, workMode) -- 44
		return table.concat( -- 45
			Registry.getAllowedToolsForRole(role, {workMode = workMode}), -- 45
			"," -- 45
		) -- 45
	end -- 44
	check( -- 47
		names("main", "code") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,list_sub_agents,spawn_sub_agent", -- 47
		"main code matrix" -- 47
	) -- 47
	check( -- 48
		names("main", "plan") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,ask_user", -- 48
		"main plan matrix" -- 48
	) -- 48
	check( -- 49
		names("sub", "code") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,finish", -- 49
		"sub code matrix" -- 49
	) -- 49
	check( -- 50
		names("sub", "plan") == "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,finish", -- 50
		"sub plan matrix" -- 50
	) -- 50
	check( -- 51
		__TS__ArrayIndexOf( -- 51
			Registry.getAllowedToolsForRole("main", {workMode = "code", disabledAgentTools = {"build"}}), -- 51
			"build" -- 51
		) < 0, -- 51
		"disabled tool removed" -- 51
	) -- 51
	check( -- 52
		table.concat( -- 52
			__TS__ArrayFilter( -- 52
				expectedNames, -- 52
				function(____, name) -- 52
					local ____opt_3 = Registry.getToolDefinition(name) -- 52
					return (____opt_3 and ____opt_3.handler) ~= nil -- 52
				end -- 52
			), -- 52
			"," -- 52
		) == table.concat(expectedNames, ","), -- 52
		"all tools have one registered handler" -- 52
	) -- 52
	local ____opt_5 = Registry.getToolDefinition("glob_files") -- 52
	local globValidator = ____opt_5 and ____opt_5.validateInput -- 53
	local normalizedGlob = globValidator and globValidator({path = "Assets/Script/Lib/Agent", maxEntries = 5}) -- 54
	check((normalizedGlob and normalizedGlob.success) == true and normalizedGlob.value.path == "Assets/Script/Lib/Agent" and normalizedGlob.value.maxEntries == 5, "semantic validator receives tool input without method self injection") -- 55
	local parallel = __TS__ArrayFilter( -- 57
		expectedNames, -- 57
		function(____, name) return Registry.canRunToolInParallel(name) end -- 57
	) -- 57
	check( -- 58
		table.concat(parallel, ",") == "read_file,grep_files,glob_files,search_dora_doc,list_sub_agents", -- 58
		"parallel-safe matrix" -- 58
	) -- 58
	check( -- 59
		#__TS__ArrayFilter( -- 59
			expectedNames, -- 59
			function(____, name) return Registry.canPreExecuteTool(name) end -- 59
		) == 0, -- 59
		"pre-executable baseline" -- 59
	) -- 59
	local mainSchemas = Registry.buildDecisionToolSchema("main", 20, {workMode = "code"}) -- 61
	check(#mainSchemas == 11, "main code function schema count") -- 62
	local readSchema = __TS__ArrayFind( -- 63
		mainSchemas, -- 63
		function(____, item) return item["function"].name == "read_file" end -- 63
	) -- 63
	local readParams = readSchema and readSchema["function"].parameters -- 64
	check( -- 65
		__TS__ArrayIsArray(readParams and readParams.anyOf) and #readParams.anyOf == 2, -- 65
		"read_file schema exposes composable single and batch forms" -- 65
	) -- 65
	local compiledReadSchema = compileJsonSchema(readParams) -- 66
	check( -- 67
		compiledReadSchema.success and compiledReadSchema.validator:validate({path = "a.ts"}).valid and compiledReadSchema.validator:validate({reads = {{path = "a.ts"}, {path = "b.ts", startLine = -2}}}).valid and compiledReadSchema.validator:validate({path = "a.ts", reads = {{path = "b.ts"}}}).valid, -- 68
		"read_file schema accepts single, batch, and mixed input" -- 72
	) -- 72
	local ____opt_15 = Registry.getToolDefinition("read_file") -- 72
	local readValidator = ____opt_15 and ____opt_15.validateInput -- 74
	local singleRead = readValidator and readValidator({path = "a.ts", startLine = 1, endLine = 2}) -- 75
	local arrayRead = readValidator and readValidator({reads = {{path = "a.ts"}}}) -- 76
	local mixedRead = readValidator and readValidator({path = "a.ts", startLine = 2, reads = {{path = "b.ts", startLine = 3}}}) -- 77
	check((singleRead and singleRead.success) == true and singleRead.value.path == "a.ts", "read_file validator accepts and normalizes the single form") -- 78
	check((arrayRead and arrayRead.success) == true and arrayRead.value.reads[1].path == "a.ts", "read_file validator accepts and normalizes the batch form") -- 79
	check( -- 80
		(mixedRead and mixedRead.success) == true and __TS__ArrayJoin( -- 81
			__TS__ArrayMap( -- 82
				mixedRead.value.reads, -- 82
				function(____, item) return item.path end -- 82
			), -- 82
			"," -- 82
		) == "a.ts,b.ts" and mixedRead.value.path == nil, -- 82
		"read_file validator prepends the top-level range to batch reads" -- 84
	) -- 84
	check( -- 86
		(readValidator and readValidator({reads = {}}).success) == false and (readValidator and readValidator({path = ""}).success) == false, -- 87
		"read_file validator requires at least one non-empty form" -- 89
	) -- 89
	local ____opt_33 = __TS__ArrayFind( -- 89
		mainSchemas, -- 91
		function(____, item) return item["function"].name == "build" end -- 91
	) -- 91
	local buildSchema = ____opt_33 and ____opt_33["function"].parameters -- 91
	local ____opt_35 = Registry.getToolDefinition("build") -- 91
	local buildValidator = ____opt_35 and ____opt_35.validateInput -- 92
	check( -- 93
		__TS__ArrayIsArray(buildSchema and buildSchema.anyOf) and #buildSchema.anyOf == 2, -- 93
		"build schema exposes composable paths and path forms" -- 93
	) -- 93
	local compiledBuildSchema = compileJsonSchema(buildSchema) -- 94
	check( -- 95
		compiledBuildSchema.success and compiledBuildSchema.validator:validate({paths = {"a.ts", "b.ts"}}).valid and compiledBuildSchema.validator:validate({path = "a.ts"}).valid and compiledBuildSchema.validator:validate({path = "a.ts", paths = {"b.ts"}}).valid, -- 96
		"build schema accepts single, batch, and mixed input" -- 100
	) -- 100
	local arrayBuild = buildValidator and buildValidator({paths = {"a.ts", "b.ts"}}) -- 102
	local singleBuild = buildValidator and buildValidator({path = "a.ts"}) -- 103
	local mixedBuild = buildValidator and buildValidator({path = "a.ts", paths = {"b.ts", "c.ts"}}) -- 104
	check((arrayBuild and arrayBuild.success) == true and #arrayBuild.value.paths == 2, "build validator accepts ordered targets") -- 105
	check((singleBuild and singleBuild.success) == true and singleBuild.value.paths[1] == "a.ts" and singleBuild.value.path == nil, "build validator normalizes single path to paths") -- 106
	check( -- 112
		(mixedBuild and mixedBuild.success) == true and table.concat(mixedBuild.value.paths, ",") == "a.ts,b.ts,c.ts" and mixedBuild.value.path == nil, -- 113
		"build validator prepends the top-level path to paths" -- 116
	) -- 116
	check( -- 118
		(buildValidator and buildValidator({paths = {}}).success) == false, -- 119
		"build validator rejects empty forms" -- 120
	) -- 120
	local ____opt_53 = __TS__ArrayFind( -- 120
		mainSchemas, -- 122
		function(____, item) return item["function"].name == "edit_file" end -- 122
	) -- 122
	local editSchema = ____opt_53 and ____opt_53["function"].parameters -- 122
	local editProperties = editSchema and editSchema.properties -- 123
	local editBatchSchema = editProperties and editProperties.edits -- 124
	check((editBatchSchema and editBatchSchema.minItems) == 1 and editBatchSchema.maxItems == nil, "edit_file batch is non-empty without an artificial upper bound") -- 125
	local ____opt_61 = Registry.getToolDefinition("edit_file") -- 125
	local editValidator = ____opt_61 and ____opt_61.validateInput -- 126
	local legacyEdit = editValidator and editValidator({path = "a.ts", old_str = "a", new_str = "b"}) -- 127
	local batchEdit = editValidator and editValidator({edits = {{path = "a.ts", old_str = "a", new_str = "b"}, {path = "b.ts", old_str = "", new_str = "x"}}}) -- 128
	local commonPathBatchEdit = editValidator and editValidator({path = "a.ts", edits = {{old_str = "a", new_str = "b"}, {old_str = "b", new_str = "c"}}}) -- 129
	local mixedEdit = editValidator and editValidator({path = "a.ts", old_str = "a", new_str = "b", edits = {{path = "b.ts", old_str = "b", new_str = "c"}}}) -- 130
	local emptyBatchEdit = editValidator and editValidator({edits = {}}) -- 131
	local commonPathEdits = (commonPathBatchEdit and commonPathBatchEdit.success) == true and commonPathBatchEdit.value.edits or ({}) -- 132
	check((legacyEdit and legacyEdit.success) == true and (batchEdit and batchEdit.success) == true, "edit_file validator preserves legacy form and accepts batch form") -- 133
	check(#commonPathEdits == 2 and commonPathEdits[1].path == "a.ts" and commonPathEdits[2].path == "a.ts", "edit_file batch applies top-level default path") -- 134
	check((mixedEdit and mixedEdit.success) == false and (emptyBatchEdit and emptyBatchEdit.success) == false, "edit_file validator rejects mixed and empty forms") -- 135
	local ____opt_83 = __TS__ArrayFind( -- 135
		Registry.buildDecisionToolSchema("main", 20, {workMode = "code"}), -- 137
		function(____, item) return item["function"].name == "finish" end -- 138
	) -- 138
	local mainFinish = ____opt_83 and ____opt_83["function"].parameters -- 137
	local ____opt_85 = __TS__ArrayFind( -- 137
		Registry.buildDecisionToolSchema("sub", 20, {workMode = "code"}), -- 139
		function(____, item) return item["function"].name == "finish" end -- 140
	) -- 140
	local subFinish = ____opt_85 and ____opt_85["function"].parameters -- 139
	check(mainFinish == nil, "finish is hidden from main agents") -- 141
	check( -- 142
		__TS__ArrayIsArray(subFinish and subFinish.required) and table.concat(subFinish and subFinish.required, ",") == "message,outcome,validation,knownIssues,assumptions,learningCandidates", -- 142
		"sub finish strict requirements" -- 142
	) -- 142
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 144
end -- 14
return ____exports -- 14