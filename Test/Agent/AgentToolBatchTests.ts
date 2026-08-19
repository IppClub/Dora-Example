// @preview-file off clear
import { areAgentToolParamsEqual, cloneAgentToolParams, coalesceCompatibleAgentToolCalls, partitionAgentToolCalls } from 'Agent/Tool/Batch';
import type { AgentToolBatchItem } from 'Agent/Tool/Batch';
import type { AgentToolName } from 'Agent/Tool/Types';
import { planTruncatedEditRecovery } from 'Agent/Tools';

export interface AgentToolBatchTestResult { success: boolean; passed: number; total: number; failures: string[] }

export function runAgentToolBatchTests(): AgentToolBatchTestResult {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];
	function check(condition: boolean, name: string): void { total++; if (condition) passed++; else failures.push(name); }
	function item(tool: AgentToolName, id: string, params: Record<string, unknown> = {}): AgentToolBatchItem { return { tool, toolCallId: id, params }; }
	const safe = (tool: AgentToolName) => tool === "read_file" || tool === "grep_files" || tool === "glob_files";
	const actions = [item("read_file", "1"), item("grep_files", "2"), item("edit_file", "3"), item("glob_files", "4"), item("build", "5"), item("read_file", "6")];
	const batches = partitionAgentToolCalls(actions, safe);
	check(batches.length === 5, "partition count");
	check(batches[0].isConcurrencySafe && batches[0].actions.map(row => row.toolCallId).join(",") === "1,2", "adjacent safe calls share parallel batch");
	check(!batches[1].isConcurrencySafe && batches[1].actions[0].tool === "edit_file", "side effect is serial");
	check(batches.map(batch => batch.actions.map(row => row.toolCallId).join("")).join("") === "123456", "partition preserves order");
	const original = { path: "a", nested: { values: [1, "x", true] } };
	const cloned = cloneAgentToolParams(original);
	check(areAgentToolParamsEqual(original, cloned), "cloned params match exactly");
	(cloned.nested as Record<string, unknown>).values = [1, "changed", true];
	check(!areAgentToolParamsEqual(original, cloned), "stale nested params do not match");
	check(!areAgentToolParamsEqual({ a: 1 }, { a: 1, b: 2 }), "extra key does not match");
	check(!areAgentToolParamsEqual([1, 2], [1, 2, 3]), "different array length does not match");
	const coalescedReads = coalesceCompatibleAgentToolCalls([
		item("read_file", "r1", { reads: [{ path: "a.ts", startLine: 1, endLine: 2 }] }),
		item("read_file", "r2", { reads: [{ path: "b.ts" }] }),
		item("read_file", "r3", { reads: [{ path: "c.ts" }, { path: "d.ts", startLine: -2, endLine: -1 }] }),
	]);
	check(coalescedReads.length === 1 && coalescedReads[0].toolCallId === "r1" && (coalescedReads[0].params.reads as unknown[]).length === 4, "coalesce consecutive read arrays");
	const separatedReads = coalesceCompatibleAgentToolCalls([
		item("read_file", "r1", { reads: [{ path: "a.ts" }] }),
		item("grep_files", "g1", { pattern: "x" }),
		item("read_file", "r2", { reads: [{ path: "b.ts" }] }),
	]);
	check(separatedReads.length === 3 && separatedReads.map(row => row.toolCallId).join(",") === "r1,g1,r2", "do not coalesce across another tool");
	const coalescedBuilds = coalesceCompatibleAgentToolCalls([
		item("build", "b1", { paths: ["a.ts"] }),
		item("build", "b2", { paths: ["b.ts", "c.ts"] }),
	]);
	check(coalescedBuilds.length === 1 && (coalescedBuilds[0].params.paths as string[]).join(",") === "a.ts,b.ts,c.ts", "coalesce consecutive build targets in order");
	const malformedArrayRecovery = planTruncatedEditRecovery([{
		function: {
			name: "edit_file",
			arguments: '[{"path":"game/Core.ts","old_str":"","new_str":"export const value = 1;"}, ["unattributed", "tail"]',
		},
	}]);
	const malformedEdits = malformedArrayRecovery?.params.edits as Record<string, unknown>[] | undefined;
	check(
		malformedArrayRecovery?.operationCount === 1
		&& malformedArrayRecovery.targets[0] === "game/Core.ts"
		&& malformedEdits?.[0]?.new_str === "export const value = 1;",
		"recover a complete edit object before malformed trailing fragments"
	);
	const partialBatchRecovery = planTruncatedEditRecovery([{
		function: {
			name: "edit_file",
			arguments: '{"edits":[{"path":"a.ts","old_str":"","new_str":"alpha"},{"path":"b.ts","old_str":"beta","new_str":"partial\\nline',
		},
	}]);
	const partialEdits = partialBatchRecovery?.params.edits as Record<string, unknown>[] | undefined;
	check(
		partialBatchRecovery?.operationCount === 2
		&& partialBatchRecovery.incompleteStringCount === 1
		&& partialEdits?.[1]?.new_str === "partial\nline",
		"recover closed batch entries and a decodable current new_str prefix"
	);
	check(planTruncatedEditRecovery([{ function: { name: "edit_file", arguments: '{"new_str":"orphan' } }]) === undefined, "do not guess a truncated edit target");
	check(planTruncatedEditRecovery([{ function: { name: "delete_file", arguments: '{"target_file":"a.ts"' } }]) === undefined, "do not recover other side-effect tools");
	return { success: failures.length === 0, passed, total, failures };
}

export function printAgentToolBatchTestResult(): void {
	const result = runAgentToolBatchTests();
	print(`AGENT_TOOL_BATCH_TEST success=${result.success} passed=${result.passed} total=${result.total} failures=${result.failures.join("|")}`);
}
