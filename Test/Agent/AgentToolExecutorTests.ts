// @preview-file off clear
import { executeAgentToolDefinition, executeRegisteredAgentTool } from 'Agent/AgentToolExecutor';
import type { AgentToolGuard } from 'Agent/AgentToolGuards';
import type {
	AgentToolDefinition,
	AgentToolExecutionContext,
	AgentToolHandler,
	AgentToolName,
} from 'Agent/AgentToolTypes';
import type { StopToken } from 'Agent/Utils';

export interface AgentToolExecutorTestResult {
	success: boolean;
	passed: number;
	total: number;
	failures: string[];
}

export async function runAgentToolExecutorTests(): Promise<AgentToolExecutorTestResult> {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];
	function check(condition: boolean, name: string): void {
		total++;
		if (condition) passed++;
		else failures.push(name);
	}

	function createContext(options?: {
		role?: "main" | "sub";
		workMode?: "code" | "plan";
		disabled?: AgentToolName[];
		stopToken?: StopToken;
		onProgress?: () => void;
	}): AgentToolExecutionContext {
		const stopToken = options?.stopToken ?? { stopped: false };
		return {
			taskId: 1,
			step: 1,
			workingDir: "/tmp/project",
			role: options?.role ?? "main",
			workMode: options?.workMode ?? "code",
			useChineseResponse: false,
			disabledAgentTools: options?.disabled ?? [],
			cancellation: {
				stopToken,
				isCancelled: () => stopToken.stopped,
				reason: () => stopToken.reason,
			},
			emitProgress: () => options?.onProgress?.(),
			services: {},
			workflow: {},
		};
	}

	const validHandler: AgentToolHandler = async (_context, input) => ({
		output: { success: true, value: input.value },
	});
	function createDefinition(overrides?: Partial<AgentToolDefinition>): AgentToolDefinition {
		return {
			name: "read_file",
			roles: ["main"],
			workModes: ["code"],
			description: "test",
			inputSchema: () => ({
				type: "object",
				properties: { value: { type: "number" } },
				required: ["value"],
				additionalProperties: false,
			}),
			outputSchema: {
				type: "object",
				properties: { success: { type: "boolean" }, value: { type: "number" } },
				required: ["success"],
			},
			handler: validHandler,
			...overrides,
		};
	}

	const schemaContext = { searchDoraDocLimitMax: 20 };
	const valid = await executeAgentToolDefinition(createDefinition(), { value: 3 }, createContext(), schemaContext);
	check(valid.output.success === true && valid.output.value === 3, "execute valid handler");

	const invalidInput = await executeAgentToolDefinition(createDefinition(), { value: "3" }, createContext(), schemaContext);
	check(invalidInput.output.code === "INVALID_TOOL_INPUT", "reject structurally invalid input");
	const extraInput = await executeAgentToolDefinition(createDefinition(), { value: 3, extra: true }, createContext(), schemaContext);
	check(extraInput.output.code === "INVALID_TOOL_INPUT", "reject additional input property");

	const missingHandlerDefinition = createDefinition();
	delete missingHandlerDefinition.handler;
	const missingHandler = await executeAgentToolDefinition(missingHandlerDefinition, { value: 1 }, createContext(), schemaContext);
	check(missingHandler.output.code === "TOOL_HANDLER_MISSING", "reject missing handler");
	const deniedRole = await executeAgentToolDefinition(createDefinition(), { value: 1 }, createContext({ role: "sub" }), schemaContext);
	check(deniedRole.output.code === "TOOL_ROLE_DENIED", "enforce role guard");
	const deniedMode = await executeAgentToolDefinition(createDefinition(), { value: 1 }, createContext({ workMode: "plan" }), schemaContext);
	check(deniedMode.output.code === "TOOL_MODE_DENIED", "enforce work mode guard");
	const disabled = await executeAgentToolDefinition(createDefinition(), { value: 1 }, createContext({ disabled: ["read_file"] }), schemaContext);
	check(disabled.output.code === "TOOL_DISABLED", "enforce disabled tool guard");

	const editDefinition = createDefinition({
		name: "edit_file",
		roles: ["main"],
		workModes: ["code", "plan"],
		inputSchema: () => ({
			type: "object",
			properties: { path: { type: "string" }, old_str: { type: "string" }, new_str: { type: "string" } },
			required: ["path", "old_str", "new_str"],
		}),
	});
	const deniedPlanPath = await executeAgentToolDefinition(editDefinition, { path: "src/a.ts", old_str: "a", new_str: "b" }, createContext({ workMode: "plan" }), schemaContext);
	check(deniedPlanPath.output.code === "PLAN_PATH_DENIED", "enforce Plan path guard");
	const allowedPlanPath = await executeAgentToolDefinition(editDefinition, { path: ".agent/plan/PLAN.md", old_str: "a", new_str: "b" }, createContext({ workMode: "plan" }), schemaContext);
	check(allowedPlanPath.output.success === true, "allow Plan document edit");

	const deleteDefinition = createDefinition({
		name: "delete_file",
		workModes: ["code", "plan"],
		inputSchema: () => ({
			type: "object",
			properties: { target_file: { type: "string" } },
			required: ["target_file"],
		}),
	});
	const protectedPlan = await executeAgentToolDefinition(deleteDefinition, { target_file: ".agent/plan/PLAN.md" }, createContext({ workMode: "plan" }), schemaContext);
	check(protectedPlan.output.code === "PROTECTED_AGENT_DOCUMENT", "protect fixed Plan document");
	const normalizedPlanDelete = await executeAgentToolDefinition(
		deleteDefinition,
		{ target_file: ".agent\\plan\\notes.md" },
		createContext({ workMode: "plan" }),
		schemaContext
	);
	check(normalizedPlanDelete.output.success === true, "normalize delete path before Plan guard");
	const protectedMemory = await executeAgentToolDefinition(deleteDefinition, { target_file: ".agent/main/MEMORY.md" }, createContext(), schemaContext);
	check(protectedMemory.output.code === "PROTECTED_AGENT_MEMORY", "protect Agent memory deletion");

	const stopped: StopToken = { stopped: true, reason: "user stopped" };
	const cancelled = await executeAgentToolDefinition(createDefinition(), { value: 1 }, createContext({ stopToken: stopped }), schemaContext);
	check(cancelled.output.code === "TOOL_CANCELLED" && cancelled.output.message === "user stopped", "cancel before execution");

	const throwing = await executeAgentToolDefinition(createDefinition({
		handler: async () => { throw new Error("boom"); },
	}), { value: 1 }, createContext(), schemaContext);
	check(throwing.output.code === "TOOL_EXECUTION_FAILED", "normalize handler exception");

	const invalidOutput = await executeAgentToolDefinition(createDefinition({
		handler: async () => ({ output: { success: "yes" } }),
	}), { value: 1 }, createContext(), schemaContext);
	check(invalidOutput.output.code === "INVALID_TOOL_OUTPUT", "reject invalid output schema");
	const nonJsonOutput = await executeAgentToolDefinition(createDefinition({
		handler: async () => ({ output: { success: true, value: math.huge } }),
	}), { value: 1 }, createContext(), schemaContext);
	check(nonJsonOutput.output.code === "INVALID_TOOL_OUTPUT", "reject non-JSON output");

	const semanticReject = await executeAgentToolDefinition(createDefinition({
		validateInput: () => ({ success: false, message: "semantic failure" }),
	}), { value: 1 }, createContext(), schemaContext);
	check(semanticReject.output.code === "INVALID_TOOL_INPUT" && semanticReject.output.message === "semantic failure", "run semantic input validator");
	const semanticNormalize = await executeAgentToolDefinition(createDefinition({
		validateInput: value => ({ success: true, value: { ...value, value: 4 } }),
	}), { value: 1 }, createContext(), schemaContext);
	check(semanticNormalize.output.value === 4, "use semantic normalized input");

	const control = await executeAgentToolDefinition(createDefinition({
		handler: async () => ({ output: { success: true, value: 1 }, control: { concludeTask: true } }),
	}), { value: 1 }, createContext(), schemaContext);
	check(control.control?.concludeTask === true && control.output.concludeTask === undefined, "keep control separate from canonical output");

	let progressCount = 0;
	const progressDefinition = createDefinition({
		handler: async (context, input) => {
			context.emitProgress({ success: false, progress: 0.5 });
			return { output: { success: true, value: input.value } };
		},
	});
	await executeAgentToolDefinition(progressDefinition, { value: 1 }, createContext({ onProgress: () => progressCount++ }), schemaContext);
	check(progressCount === 1, "forward progress without settling result");

	const cancelDuringToken: StopToken = { stopped: false };
	const cancelDuring = await executeAgentToolDefinition(createDefinition({
		handler: async (_context, input) => {
			cancelDuringToken.stopped = true;
			cancelDuringToken.reason = "cancel during handler";
			return { output: { success: true, value: input.value } };
		},
	}), { value: 1 }, createContext({ stopToken: cancelDuringToken }), schemaContext);
	check(cancelDuring.output.code === "TOOL_CANCELLED", "cancel after handler cleanup");

	let afterDenialRan = false;
	const monotonicGuards: AgentToolGuard[] = [
		() => undefined,
		() => ({ denied: true, code: "DENIED", message: "no" }),
		() => { afterDenialRan = true; return undefined; },
	];
	const monotonic = await executeAgentToolDefinition(createDefinition(), { value: 1 }, createContext(), schemaContext, monotonicGuards);
	check(monotonic.output.code === "DENIED" && !afterDenialRan, "guard denial is monotonic");

	const unknown = await executeRegisteredAgentTool({
		tool: "not_a_tool",
		input: {},
		context: createContext(),
		schemaContext,
	});
	check(unknown.output.code === "UNKNOWN_TOOL", "reject unknown registered tool");

	return { success: failures.length === 0, passed, total, failures };
}

export function printAgentToolExecutorTestResult(): void {
	runAgentToolExecutorTests().then(
		result => print(`AGENT_TOOL_EXECUTOR_TEST success=${result.success} passed=${result.passed} total=${result.total} failures=${result.failures.join("|")}`),
		error => print(`AGENT_TOOL_EXECUTOR_TEST rejected=${tostring(error)}`)
	);
}
