// @preview-file off clear
import { Content, Path } from 'Dora';
import { sanitizeReadResultForHistory } from 'Agent/Runtime/HistoryProjection';
import { executeRegisteredAgentTool } from 'Agent/Tool/Executor';
import { getToolDefinition } from 'Agent/Tool/Registry';
import * as Tools from 'Agent/Tools';
import type { AgentToolExecutionContext, AgentToolName } from 'Agent/Tool/Types';

export interface AgentToolHandlersTestResult {
	success: boolean;
	passed: number;
	total: number;
	failures: string[];
}

export async function runAgentToolHandlersTests(workDir: string, runNestedCommandTests = false): Promise<AgentToolHandlersTestResult> {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];
	function check(condition: boolean, name: string): void {
		total++;
		if (condition) passed++;
		else failures.push(name);
	}
	function isTrue(value: unknown): boolean {
		return value === true;
	}

	const stopToken = { stopped: false };
	const context: AgentToolExecutionContext = {
		sessionId: 10,
		taskId: 1,
		step: 1,
		workingDir: workDir,
		role: "main",
		workMode: "code",
		useChineseResponse: false,
		disabledAgentTools: [],
		cancellation: {
			stopToken,
			isCancelled: () => stopToken.stopped,
			reason: () => undefined,
		},
		emitProgress: () => {},
		services: {},
		workflow: {},
	};
	const schemaContext = { searchDoraDocLimitMax: 20 };
	const migrated: AgentToolName[] = [
		"read_file", "grep_files", "glob_files", "search_dora_doc",
		"build", "fetch_url", "execute_command", "edit_file", "delete_file",
		"ask_user", "spawn_sub_agent", "list_sub_agents",
		"finish",
	];
	for (const name of migrated) {
		check(getToolDefinition(name)?.handler !== undefined, `${name} has registered handler`);
	}
	check(migrated.length === 13, "all registered tools have handlers");

	const read = await executeRegisteredAgentTool({
		tool: "read_file",
		input: { path: "README.md", startLine: 1, endLine: 3 },
		context,
		schemaContext,
	});
	check(read.output.success === true && typeof read.output.content === "string", "read_file returns content");

	context.workflow.resumeNarrowReadMode = true;
	const narrowRead = await executeRegisteredAgentTool({
		tool: "read_file",
		input: { path: "Test/Agent/AgentToolHandlersTests.ts", startLine: 1, endLine: 300 },
		context,
		schemaContext,
	});
	check(narrowRead.output.success === true && narrowRead.output.clipped === true && narrowRead.output.endLine === 160, "read_file preserves post-compression clipping");
	context.workflow.resumeNarrowReadMode = false;
	const batchRead = await executeRegisteredAgentTool({
		tool: "read_file",
		input: { reads: [
			{ path: "README.md", startLine: 1, endLine: 2 },
			{ path: "README.zh-CN.md", startLine: 1, endLine: 2 },
		] },
		context,
		schemaContext,
	});
	const batchReadResults = batchRead.output.results as Record<string, unknown>[] | undefined;
	check(
		batchRead.output.success === true
		&& batchRead.output.mode === "batch"
		&& batchRead.output.readCount === 2
		&& batchReadResults?.length === 2
		&& typeof batchReadResults[0].content === "string",
		"read_file batch returns independent ordered results"
	);
	const partialBatchRead = await executeRegisteredAgentTool({
		tool: "read_file",
		input: { reads: [
			{ path: "README.md", startLine: 1, endLine: 1 },
			{ path: ".agent/definitely-missing-read-batch.tmp", startLine: 1, endLine: 1 },
		] },
		context,
		schemaContext,
	});
	check(
		partialBatchRead.output.success === false
		&& partialBatchRead.output.partial === true
		&& partialBatchRead.output.succeededReadCount === 1,
		"read_file batch preserves successful reads after a failure"
	);
	const sanitizedBatchRead = sanitizeReadResultForHistory("read_file", {
		success: true,
		mode: "batch",
		results: [{ success: true, path: "large.ts", startLine: 1, endLine: 1, totalLines: 1, content: string.rep("x", 20000) }],
	});
	const sanitizedResults = sanitizedBatchRead.results as Record<string, unknown>[];
	check(sanitizedResults[0].historyContentTruncated === true, "read_file batch history truncates each successful result");

	const glob = await executeRegisteredAgentTool({
		tool: "glob_files",
		input: { path: "Test/Agent", globs: ["**/*.ts"], maxEntries: 5 },
		context,
		schemaContext,
	});
	check(glob.output.success === true && Array.isArray(glob.output.files), "glob_files returns file list");

	const grep = await executeRegisteredAgentTool({
		tool: "grep_files",
		input: { path: "README.md", pattern: "Dora SSR", limit: 5 },
		context,
		schemaContext,
	});
	check(grep.output.success === true && typeof grep.output.totalResults === "number", "grep_files returns search result");

	const beforeSearches = context.workflow.apiSearchesSinceBuild ?? 0;
	const doc = await executeRegisteredAgentTool({
		tool: "search_dora_doc",
		input: { pattern: "Node", docType: "dora-api", programmingLanguage: "ts", limit: 1 },
		context,
		schemaContext,
	});
	check(doc.output.success === true, "search_dora_doc returns result");
	check(context.workflow.apiSearchesSinceBuild === beforeSearches + 1, "search_dora_doc updates workflow counter");

	context.workflow.unbuiltEdits = true;
	context.workflow.editsSinceBuild = 2;
	context.workflow.editedPathsSinceBuild = ["Test/Agent/JsonSchemaTests.ts"];
	context.workflow.freshProjectBuildPending = true;
	const build = await executeRegisteredAgentTool({
		tool: "build",
		input: { paths: ["Test/Agent/JsonSchemaTests.ts"] },
		context,
		schemaContext,
	});
	check(build.output.success === true, "build returns success");
	check(
		!isTrue(context.workflow.unbuiltEdits)
		&& context.workflow.editsSinceBuild === 0
		&& isTrue(context.workflow.hasBuilt)
		&& isTrue(context.workflow.lastBuildSucceeded)
		&& !isTrue(context.workflow.freshProjectBuildPending),
		"build updates workflow state"
	);
	const singlePathBuild = await executeRegisteredAgentTool({
		tool: "build",
		input: { path: "Test/Agent/AgentToolBatchTests.ts" },
		context,
		schemaContext,
	});
	check(
		singlePathBuild.output.success === true
		&& singlePathBuild.output.mode === "batch"
		&& singlePathBuild.output.buildCount === 1,
		"build normalizes a historical single path into the batch executor"
	);
	const batchBuild = await executeRegisteredAgentTool({
		tool: "build",
		input: { paths: ["Test/Agent/AgentToolBatchTests.ts", "Test/Agent/AgentToolRegistryTests.ts"] },
		context,
		schemaContext,
	});
	check(
		batchBuild.output.success === true
		&& batchBuild.output.mode === "batch"
		&& batchBuild.output.buildCount === 2
		&& batchBuild.output.succeededBuildCount === 2,
		"build runs ordered targets and returns per-target results"
	);
	const rejectedFetch = await executeRegisteredAgentTool({
		tool: "fetch_url",
		input: { url: "ftp://example.invalid/file", target: ".agent/invalid-fetch" },
		context,
		schemaContext,
	});
	check(rejectedFetch.output.success === false, "fetch_url preserves controlled rejection");

	if (runNestedCommandTests) {
		context.workflow.failedTestNeedsBuild = true;
		context.workflow.failedTestHasSourceEdit = true;
		const commandPass = await executeRegisteredAgentTool({
			tool: "execute_command",
			input: { mode: "lua", code: "print('passed')", timeoutSeconds: 5 },
			context,
			schemaContext,
		});
		check(commandPass.output.success === true, "execute_command runs Lua");
		check(!isTrue(context.workflow.failedTestNeedsBuild) && !isTrue(context.workflow.failedTestHasSourceEdit), "Lua passed marker clears deterministic failure state");

		const commandFail = await executeRegisteredAgentTool({
			tool: "execute_command",
			input: { mode: "lua", code: "print('failed: 1')", timeoutSeconds: 5 },
			context,
			schemaContext,
		});
		check(commandFail.output.success === true, "execute_command returns output containing failed marker");
		check(isTrue(context.workflow.failedTestNeedsBuild) && !isTrue(context.workflow.failedTestHasSourceEdit), "Lua failed marker sets deterministic failure state");
	}

	const createdTask = Tools.createTask("AgentToolHandlersTests R5", "code");
	check(createdTask.success === true, "create isolated checkpoint task");
	if (createdTask.success) {
		context.taskId = createdTask.taskId;
		const testPath = `.agent/r5-runtime-${os.time()}.tmp`;
		const create = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: { path: testPath, old_str: "", new_str: "alpha\nbeta\n" },
			context,
			schemaContext,
		});
		check(create.output.success === true && create.output.mode === "create" && typeof create.output.checkpointId === "number", "edit_file creates checkpointed file");
		const replace = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: { path: testPath, old_str: "beta", new_str: "gamma" },
			context,
			schemaContext,
		});
		const readEdited = Tools.readFileRaw(workDir, testPath);
		check(replace.output.success === true && replace.output.mode === "replace" && readEdited.success && readEdited.content.indexOf("gamma") >= 0, "edit_file replaces exact text");
		const batchPathA = `.agent/r5-batch-a-${os.time()}.tmp`;
		const batchPathB = `.agent/r5-batch-b-${os.time()}.tmp`;
		const batch = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: {
				edits: [
					{ path: batchPathA, old_str: "", new_str: "alpha\none\n" },
					{ path: batchPathB, old_str: "", new_str: "beta\n" },
					{ path: batchPathA, old_str: "alpha", new_str: "ALPHA" },
					{ path: batchPathA, old_str: "one", new_str: "ONE" },
				],
			},
			context,
			schemaContext,
		});
		const batchA = Tools.readFileRaw(workDir, batchPathA);
		const batchB = Tools.readFileRaw(workDir, batchPathB);
		check(
			batch.output.success === true
			&& batch.output.mode === "batch"
			&& batch.output.operationCount === 4
			&& batch.output.fileCount === 2
			&& typeof batch.output.checkpointId === "number"
			&& batchA.success && batchA.content === "ALPHA\nONE\n"
			&& batchB.success && batchB.content === "beta\n",
			"edit_file batch stages ordered same-file edits and commits multiple files once"
		);
		const commonPathBatch = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: {
				path: batchPathA,
				edits: [
					{ old_str: "ALPHA", new_str: "alpha" },
					{ old_str: "ONE", new_str: "one" },
				],
			},
			context,
			schemaContext,
		});
		const commonPathA = Tools.readFileRaw(workDir, batchPathA);
		check(
			commonPathBatch.output.success === true
			&& commonPathBatch.output.succeededOperationCount === 2
			&& commonPathA.success && commonPathA.content === "alpha\none\n",
			"edit_file batch accepts a top-level default path"
		);
		const partialFailure = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: {
				edits: [
					{ path: batchPathA, old_str: "alpha", new_str: "CHANGED" },
					{ path: batchPathB, old_str: "missing", new_str: "never" },
				],
			},
			context,
			schemaContext,
		});
		const partiallyChangedA = Tools.readFileRaw(workDir, batchPathA);
		const preservedB = Tools.readFileRaw(workDir, batchPathB);
		check(
			partialFailure.output.success === true
			&& partialFailure.output.partial === true
			&& partialFailure.output.succeededOperationCount === 1
			&& partialFailure.output.failedOperationCount === 1
			&& partiallyChangedA.success && partiallyChangedA.content === "CHANGED\none\n"
			&& preservedB.success && preservedB.content === "beta\n",
			"edit_file batch retains successful replacements when another entry fails"
		);
		const planBatchPath = `.agent/plan/r5-batch-${os.time()}.tmp`;
		const deniedPlanBatchPath = `.agent/r5-plan-denied-${os.time()}.tmp`;
		const planBatch = await executeRegisteredAgentTool({
			tool: "edit_file",
			input: {
				edits: [
					{ path: planBatchPath, old_str: "", new_str: "plan" },
					{ path: deniedPlanBatchPath, old_str: "", new_str: "denied" },
				],
			},
			context: { ...context, workMode: "plan" },
			schemaContext,
		});
		check(
			planBatch.output.success === true
			&& planBatch.output.partial === true
			&& Tools.readFileRaw(workDir, planBatchPath).success
			&& !Tools.readFileRaw(workDir, deniedPlanBatchPath).success,
			"edit_file Plan batch commits allowed entries and skips denied paths"
		);
		for (const batchPath of [batchPathA, batchPathB, planBatchPath]) {
			const cleanup = await executeRegisteredAgentTool({
				tool: "delete_file",
				input: { target_file: batchPath },
				context: batchPath === planBatchPath ? { ...context, workMode: "plan" } : context,
				schemaContext,
			});
			check(cleanup.output.success === true, `clean batch test file ${batchPath}`);
		}
		const remove = await executeRegisteredAgentTool({
			tool: "delete_file",
			input: { target_file: testPath },
			context,
			schemaContext,
		});
		check(remove.output.success === true && remove.output.mode === "delete" && typeof remove.output.checkpointId === "number", "delete_file creates checkpoint and removes file");
		check(!Tools.readFileRaw(workDir, testPath).success, "delete_file removed isolated test file");
		check(isTrue(context.workflow.unbuiltEdits) && (context.workflow.editsSinceBuild ?? 0) === 12, "file side effects count only successful batch operations");
		Tools.setTaskStatus(createdTask.taskId, "DONE");
	}

	let publishedStep = 0;
	context.services.publishQuestionnaire = async request => {
		publishedStep = request.step;
		return { success: true, questionnaireId: 77 };
	};
	const ask = await executeRegisteredAgentTool({
		tool: "ask_user",
		input: {
			title: "Choose",
			questions: [{ id: "mode", prompt: "Mode?", type: "single_choice", options: [{ id: "a", label: "A" }, { id: "b", label: "B" }] }],
		},
		context: { ...context, workMode: "plan" },
		schemaContext,
	});
	check(ask.output.success === true && ask.control?.waitForUser === true && ask.control.questionnaireId === 77, "ask_user publishes structured wait control");
	check(publishedStep === context.step && context.workflow.waitingQuestionnaireId === 77, "ask_user updates waiting workflow state");

	let inheritedDisabled: AgentToolName[] = [];
	context.disabledAgentTools = ["fetch_url"];
	context.services.spawnSubAgent = async request => {
		inheritedDisabled = request.disabledAgentTools ?? [];
		return { success: true, sessionId: 11, taskId: 12, title: request.title };
	};
	const spawn = await executeRegisteredAgentTool({
		tool: "spawn_sub_agent",
		input: { title: "Worker", prompt: "Do bounded work", filesHint: ["a.ts"] },
		context,
		schemaContext,
	});
	check(spawn.output.success === true && spawn.control?.spawnedSubAgent === true && context.workflow.hasSpawnedSubAgentThisTask === true, "spawn_sub_agent returns asynchronous control");
	check(inheritedDisabled.join(",") === "fetch_url", "spawn_sub_agent inherits disabled tools");

	context.disabledAgentTools = [];
	context.services.listSubAgents = async request => ({
		success: true,
		rootSessionId: request.sessionId,
		maxConcurrent: 4,
		status: request.status ?? "active_or_recent",
		limit: request.limit ?? 5,
		offset: request.offset ?? 0,
		hasMore: false,
		sessions: [],
	});
	const listed = await executeRegisteredAgentTool({
		tool: "list_sub_agents",
		input: { status: "running", limit: 3, offset: 0 },
		context,
		schemaContext,
	});
	check(listed.output.success === true && listed.output.status === "running" && listed.output.limit === 3, "list_sub_agents uses restricted service");

	const finished = await executeRegisteredAgentTool({
		tool: "finish",
		input: {
			message: "Done",
			outcome: "partial",
			validation: [{ kind: "build", result: "passed", evidence: ["24 files"] }],
			knownIssues: ["manual not run"],
			assumptions: [],
			learningCandidates: [],
		},
		context: { ...context, role: "sub" },
		schemaContext,
	});
	check(finished.output.success === true && finished.output.message === "Done" && finished.output.concludeTask === undefined, "finish output does not expose internal control");
	check(
		finished.control?.concludeTask === true
		&& finished.control.finalMessage === "Done"
		&& finished.control.completion?.outcome === "partial",
		"finish returns structured completion control"
	);
	check(finished.control?.completion?.budgetExhausted === false, "sub-agent finish has no exhausted budget marker");

	return { success: failures.length === 0, passed, total, failures };
}

export function printAgentToolHandlersTestResult(workDir = Path(Content.writablePath, "Dora-Example")): void {
	runAgentToolHandlersTests(workDir).then(
		result => print(`AGENT_TOOL_HANDLERS_TEST success=${result.success} passed=${result.passed} total=${result.total} failures=${result.failures.join("|")}`),
		error => print(`AGENT_TOOL_HANDLERS_TEST rejected=${tostring(error)}`)
	);
}
