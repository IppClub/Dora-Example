-- [ts]: AgentDecisionParsingTests.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray -- 1
local ____exports = {} -- 1
local ____AgentDecisionParsing = require("Agent.AgentDecisionParsing") -- 2
local classifyToolCallingTurnWithoutCalls = ____AgentDecisionParsing.classifyToolCallingTurnWithoutCalls -- 3
local getDecisionPath = ____AgentDecisionParsing.getDecisionPath -- 4
local parseDSMLToolCallObjectFromText = ____AgentDecisionParsing.parseDSMLToolCallObjectFromText -- 5
local parseDecisionObject = ____AgentDecisionParsing.parseDecisionObject -- 6
local parseToolCallArguments = ____AgentDecisionParsing.parseToolCallArguments -- 7
local parseXMLToolCallObjectFromText = ____AgentDecisionParsing.parseXMLToolCallObjectFromText -- 8
local validateCompletionForRole = ____AgentDecisionParsing.validateCompletionForRole -- 9
local validateDecision = ____AgentDecisionParsing.validateDecision -- 10
function ____exports.runAgentDecisionParsingTests() -- 20
	local passed = 0 -- 21
	local total = 0 -- 22
	local failures = {} -- 23
	local function check(condition, name) -- 24
		total = total + 1 -- 25
		if condition then -- 25
			passed = passed + 1 -- 26
		else -- 26
			failures[#failures + 1] = name -- 27
		end -- 27
	end -- 24
	local wrapped = parseXMLToolCallObjectFromText("<tool_call><tool>edit_file</tool><reason>apply patch</reason><params><path>a.ts</path><old_str>old</old_str><new_str>new</new_str></params></tool_call>") -- 30
	check(wrapped.success and wrapped.obj.tool == "edit_file" and wrapped.obj.reason == "apply patch" and wrapped.obj.params.path == "a.ts", "parse wrapped XML tool call") -- 33
	local bare = parseXMLToolCallObjectFromText("<tool>delete_file</tool><reason>remove stale file</reason><params><target_file>old.ts</target_file></params>") -- 41
	check(bare.success and bare.obj.tool == "delete_file" and bare.obj.params.target_file == "old.ts", "recover XML without tool_call wrapper") -- 44
	local inferred = parseXMLToolCallObjectFromText("<params><path>a.ts</path><startLine>2</startLine><endLine>4</endLine></params>") -- 51
	check(inferred.success and inferred.obj.tool == "read_file" and inferred.obj.reason == "Inferred tool from XML params.", "infer tool from params-only XML") -- 54
	local dsml = parseDSMLToolCallObjectFromText("inspect source\n<｜｜DSML｜｜tool_calls><｜｜DSML｜｜invoke name=\"grep_files\"><｜｜DSML｜｜parameter name=\"pattern\">needle</｜｜DSML｜｜parameter><｜｜DSML｜｜parameter name=\"globs\">**/*.ts</｜｜DSML｜｜parameter></｜｜DSML｜｜invoke>") -- 61
	check(dsml.success and dsml.obj.tool == "grep_files" and dsml.obj.reason == "inspect source" and dsml.obj.params.pattern == "needle", "parse DSML invoke and preserve reason") -- 64
	local unknownDSML = parseDSMLToolCallObjectFromText("<｜｜DSML｜｜invoke name=\"unknown_tool\"></｜｜DSML｜｜invoke>") -- 72
	check( -- 75
		not unknownDSML.success and (string.find(unknownDSML.message, "unknown DSML tool", nil, true) or 0) - 1 >= 0, -- 75
		"reject unknown DSML tool" -- 75
	) -- 75
	local missingReason = parseDecisionObject({tool = "read_file", params = {}}) -- 77
	check( -- 78
		not missingReason.success and (string.find(missingReason.message, "requires top-level reason", nil, true) or 0) - 1 >= 0, -- 78
		"require reason for non-finish decision" -- 78
	) -- 78
	local finish = parseDecisionObject({tool = "finish", params = {message = "done"}}) -- 79
	check(finish.success and finish.tool == "finish", "allow finish without reason") -- 80
	local unknownDecision = parseDecisionObject({tool = "unknown", reason = "try", params = {}}) -- 81
	check( -- 82
		not unknownDecision.success and (string.find(unknownDecision.message, "unknown tool", nil, true) or 0) - 1 >= 0, -- 82
		"reject unknown decision tool" -- 82
	) -- 82
	local parsedArgs = parseToolCallArguments("grep_files", "{\"pattern\":\"needle\",\"caseSensitive\":true}") -- 84
	check(not (parsedArgs.success ~= nil) and parsedArgs.pattern == "needle" and parsedArgs.caseSensitive == true, "parse object tool-call arguments") -- 85
	local arrayArgs = parseToolCallArguments("grep_files", "[]") -- 91
	check(arrayArgs.success ~= nil and arrayArgs.success == false, "reject array tool-call arguments") -- 92
	local brokenArgs = parseToolCallArguments("grep_files", "{\"pattern\":") -- 93
	check(brokenArgs.success ~= nil and brokenArgs.success == false and brokenArgs.raw ~= nil, "retain invalid argument source") -- 94
	local validRead = validateDecision("read_file", {reads = {{path = "a.ts", startLine = 2, endLine = 4}}}) -- 96
	check( -- 97
		validRead.success and __TS__ArrayIsArray(validRead.params.reads) and validRead.params.reads[1].path == "a.ts", -- 98
		"validate and normalize decision through registry" -- 101
	) -- 101
	local legacyRead = validateDecision("read_file", {path = "a.ts"}) -- 103
	check(not legacyRead.success, "reject legacy read decision shape") -- 104
	check( -- 106
		not validateCompletionForRole("main", "finish", {message = "done"}).success, -- 106
		"finish is reserved for sub agents" -- 106
	) -- 106
	check( -- 107
		not validateCompletionForRole("sub", "finish", {message = "done"}).success, -- 107
		"sub-agent finish requires structured handoff" -- 109
	) -- 109
	check( -- 111
		validateCompletionForRole("sub", "finish", { -- 112
			message = "done", -- 113
			outcome = "completed", -- 114
			validation = {}, -- 115
			knownIssues = {}, -- 116
			assumptions = {}, -- 117
			learningCandidates = {} -- 118
		}).success, -- 118
		"accept complete sub-agent handoff" -- 120
	) -- 120
	check( -- 123
		getDecisionPath({path = " a.ts "}) == "a.ts", -- 123
		"read decision path" -- 123
	) -- 123
	check( -- 124
		getDecisionPath({target_file = " old.ts "}) == "old.ts", -- 124
		"delete decision path" -- 124
	) -- 124
	local lengthTurn = classifyToolCallingTurnWithoutCalls("main", "length", "partial output", "reasoning") -- 126
	check((lengthTurn and lengthTurn.success) == true and lengthTurn.kind == "continue" and lengthTurn.content == "partial output", "treat length as a successful loop continuation") -- 127
	local plainTextCompletion = classifyToolCallingTurnWithoutCalls("main", "stop", "  final answer  ", "reasoning") -- 131
	check((plainTextCompletion and plainTextCompletion.success) == true and plainTextCompletion.kind == "plain_text_completion" and plainTextCompletion.content == "final answer", "accept plain text completion") -- 132
	check( -- 136
		classifyToolCallingTurnWithoutCalls("main", "stop", "  ") == nil, -- 137
		"reject empty completion without a tool call" -- 138
	) -- 138
	local subPlainText = classifyToolCallingTurnWithoutCalls("sub", "stop", "done") -- 140
	check( -- 141
		(subPlainText and subPlainText.success) == false and (string.find(subPlainText.message, "must call finish", nil, true) or 0) - 1 >= 0, -- 142
		"reject sub-agent plain text completion" -- 143
	) -- 143
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 146
end -- 20
function ____exports.printAgentDecisionParsingTestResult() -- 149
	local result = ____exports.runAgentDecisionParsingTests() -- 150
	print((((((("AGENT_DECISION_PARSING_TEST success=" .. tostring(result.success)) .. " passed=") .. tostring(result.passed)) .. " total=") .. tostring(result.total)) .. " failures=") .. table.concat(result.failures, "|")) -- 151
end -- 149
return ____exports -- 149