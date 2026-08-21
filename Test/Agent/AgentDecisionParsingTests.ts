// @preview-file off clear
import {
	classifyToolCallingTurnWithoutCalls,
	getDecisionPath,
	parseDSMLToolCallObjectFromText,
	parseDecisionObject,
	parseToolCallArguments,
	parseXMLToolCallObjectFromText,
	validateCompletionForRole,
	validateDecision,
} from 'Agent/Runtime/DecisionParsing';

export interface AgentDecisionParsingTestResult {
	success: boolean;
	passed: number;
	total: number;
	failures: string[];
}

export function runAgentDecisionParsingTests(): AgentDecisionParsingTestResult {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];
	function check(condition: boolean, name: string): void {
		total++;
		if (condition) passed++;
		else failures.push(name);
	}

	const wrapped = parseXMLToolCallObjectFromText(
		"<tool_call><tool>edit_file</tool><reason>apply patch</reason><params><path>a.ts</path><old_str>old</old_str><new_str>new</new_str></params></tool_call>"
	);
	check(
		wrapped.success
		&& wrapped.obj.tool === "edit_file"
		&& wrapped.obj.reason === "apply patch"
		&& (wrapped.obj.params as Record<string, unknown>).path === "a.ts",
		"parse wrapped XML tool call"
	);

	const bare = parseXMLToolCallObjectFromText(
		"<tool>delete_file</tool><reason>remove stale file</reason><params><target_file>old.ts</target_file></params>"
	);
	check(
		bare.success
		&& bare.obj.tool === "delete_file"
		&& (bare.obj.params as Record<string, unknown>).target_file === "old.ts",
		"recover XML without tool_call wrapper"
	);

	const inferred = parseXMLToolCallObjectFromText(
		"<params><path>a.ts</path><startLine>2</startLine><endLine>4</endLine></params>"
	);
	check(
		inferred.success
		&& inferred.obj.tool === "read_file"
		&& inferred.obj.reason === "Inferred tool from XML params.",
		"infer tool from params-only XML"
	);

	const dsml = parseDSMLToolCallObjectFromText(
		"inspect source\n<｜｜DSML｜｜tool_calls><｜｜DSML｜｜invoke name=\"grep_files\"><｜｜DSML｜｜parameter name=\"pattern\">needle</｜｜DSML｜｜parameter><｜｜DSML｜｜parameter name=\"globs\">**/*.ts</｜｜DSML｜｜parameter></｜｜DSML｜｜invoke>"
	);
	check(
		dsml.success
		&& dsml.obj.tool === "grep_files"
		&& dsml.obj.reason === "inspect source"
		&& (dsml.obj.params as Record<string, unknown>).pattern === "needle",
		"parse DSML invoke and preserve reason"
	);

	const unknownDSML = parseDSMLToolCallObjectFromText(
		"<｜｜DSML｜｜invoke name=\"unknown_tool\"></｜｜DSML｜｜invoke>"
	);
	check(!unknownDSML.success && unknownDSML.message.indexOf("unknown DSML tool") >= 0, "reject unknown DSML tool");

	const missingReason = parseDecisionObject({ tool: "read_file", params: {} });
	check(!missingReason.success && missingReason.message.indexOf("requires top-level reason") >= 0, "require reason for non-finish decision");
	const finish = parseDecisionObject({ tool: "finish", params: { message: "done" } });
	check(finish.success && finish.tool === "finish", "allow finish without reason");
	const unknownDecision = parseDecisionObject({ tool: "unknown", reason: "try", params: {} });
	check(!unknownDecision.success && unknownDecision.message.indexOf("unknown tool") >= 0, "reject unknown decision tool");

	const parsedArgs = parseToolCallArguments("grep_files", "{\"pattern\":\"needle\",\"caseSensitive\":true}");
	check(
		!("success" in parsedArgs)
		&& parsedArgs.pattern === "needle"
		&& parsedArgs.caseSensitive === true,
		"parse object tool-call arguments"
	);
	const arrayArgs = parseToolCallArguments("grep_files", "[]");
	check("success" in arrayArgs && arrayArgs.success === false, "reject array tool-call arguments");
	const brokenArgs = parseToolCallArguments("grep_files", "{\"pattern\":");
	check("success" in brokenArgs && brokenArgs.success === false && brokenArgs.raw !== undefined, "retain invalid argument source");

	const validRead = validateDecision("read_file", { path: "a.ts", startLine: 2, endLine: 4 });
	check(
		validRead.success
		&& validRead.params.path === "a.ts"
		&& validRead.params.startLine === 2
		&& validRead.params.endLine === 4,
		"validate and normalize decision through registry"
	);
	const batchRead = validateDecision("read_file", { reads: [{ path: "a.ts" }, { path: "b.ts", startLine: -2 }] });
	check(
		batchRead.success
		&& Array.isArray(batchRead.params.reads)
		&& (batchRead.params.reads as Record<string, unknown>[]).length === 2,
		"accept and normalize batch read decision"
	);
	const mixedRead = validateDecision("read_file", { path: "a.ts", reads: [{ path: "b.ts" }] });
	check(
		mixedRead.success
		&& (mixedRead.params.reads as Record<string, unknown>[]).map(item => item.path).join(",") === "a.ts,b.ts",
		"accept and normalize mixed read decision forms"
	);

	check(!validateCompletionForRole("main", "finish", { message: "done" }).success, "finish is reserved for sub agents");
	check(
		!validateCompletionForRole("sub", "finish", { message: "done" }).success,
		"sub-agent finish requires structured handoff"
	);
	check(
		validateCompletionForRole("sub", "finish", {
			message: "done",
			outcome: "completed",
			validation: [],
			knownIssues: [],
			assumptions: [],
			learningCandidates: [],
		}).success,
		"accept complete sub-agent handoff"
	);

	check(getDecisionPath({ path: " a.ts " }) === "a.ts", "read decision path");
	check(getDecisionPath({ target_file: " old.ts " }) === "old.ts", "delete decision path");

	const lengthTurn = classifyToolCallingTurnWithoutCalls("main", "length", "partial output", "reasoning");
	check(
		lengthTurn?.success === true && lengthTurn.kind === "continue" && lengthTurn.content === "partial output",
		"treat length as a successful loop continuation"
	);
	const plainTextCompletion = classifyToolCallingTurnWithoutCalls("main", "stop", "  final answer  ", "reasoning");
	check(
		plainTextCompletion?.success === true && plainTextCompletion.kind === "plain_text_completion" && plainTextCompletion.content === "final answer",
		"accept plain text completion"
	);
	check(
		classifyToolCallingTurnWithoutCalls("main", "stop", "  ") === undefined,
		"reject empty completion without a tool call"
	);
	const subPlainText = classifyToolCallingTurnWithoutCalls("sub", "stop", "done");
	check(
		subPlainText?.success === false && subPlainText.message.indexOf("must call finish") >= 0,
		"reject sub-agent plain text completion"
	);

	return { success: failures.length === 0, passed, total, failures };
}

export function printAgentDecisionParsingTestResult(): void {
	const result = runAgentDecisionParsingTests();
	print(`AGENT_DECISION_PARSING_TEST success=${result.success} passed=${result.passed} total=${result.total} failures=${result.failures.join("|")}`);
}
