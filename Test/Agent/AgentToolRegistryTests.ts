// @preview-file off clear
import * as Registry from 'Agent/Tool/Registry';
import { compileJsonSchema } from 'Agent/JsonSchema';
import type { AgentRole, AgentToolName, AgentWorkMode } from 'Agent/Tool/Types';

export interface AgentToolRegistryTestResult {
	success: boolean;
	passed: number;
	total: number;
	failures: string[];
}

export function runAgentToolRegistryTests(): AgentToolRegistryTestResult {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];
	function check(condition: boolean, name: string): void {
		total++;
		if (condition) passed++;
		else failures.push(name);
	}

	const expectedNames: AgentToolName[] = [
		"read_file", "edit_file", "delete_file", "grep_files", "glob_files", "search_dora_doc",
		"build", "fetch_url", "execute_command", "finish", "list_sub_agents", "spawn_sub_agent", "ask_user",
	];
	check(Registry.AGENT_TOOL_DEFINITIONS.length === expectedNames.length, "registry contains 13 tools");
	for (const name of expectedNames) {
		check(Registry.isKnownToolName(name), `known tool ${name}`);
		check(Registry.getToolDefinition(name)?.name === name, `definition lookup ${name}`);
	}

	const seen: string[] = [];
	let schemasValid = true;
	for (const definition of Registry.AGENT_TOOL_DEFINITIONS) {
		if (seen.indexOf(definition.name) >= 0) schemasValid = false;
		seen.push(definition.name);
		if (!compileJsonSchema(definition.inputSchema({ searchDoraDocLimitMax: 20 })).success) schemasValid = false;
		if (!compileJsonSchema(definition.outputSchema).success) schemasValid = false;
	}
	check(schemasValid, "definitions are unique with valid input and output schemas");

	function names(role: AgentRole, workMode: AgentWorkMode): string {
		return Registry.getAllowedToolsForRole(role, { workMode }).join(",");
	}
	check(names("main", "code") === "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,list_sub_agents,spawn_sub_agent", "main code matrix");
	check(names("main", "plan") === "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,ask_user", "main plan matrix");
	check(names("sub", "code") === "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,build,fetch_url,execute_command,finish", "sub code matrix");
	check(names("sub", "plan") === "read_file,edit_file,delete_file,grep_files,glob_files,search_dora_doc,finish", "sub plan matrix");
	check(Registry.getAllowedToolsForRole("main", { workMode: "code", disabledAgentTools: ["build"] }).indexOf("build") < 0, "disabled tool removed");
	check(expectedNames.filter(name => Registry.getToolDefinition(name)?.handler !== undefined).join(",") === expectedNames.join(","), "all tools have one registered handler");
	const globValidator = Registry.getToolDefinition("glob_files")?.validateInput;
	const normalizedGlob = globValidator?.({ path: "Assets/Script/Lib/Agent", maxEntries: 5 });
	check(normalizedGlob?.success === true && normalizedGlob.value.path === "Assets/Script/Lib/Agent" && normalizedGlob.value.maxEntries === 5, "semantic validator receives tool input without method self injection");

	const parallel = expectedNames.filter(name => Registry.canRunToolInParallel(name));
	check(parallel.join(",") === "read_file,grep_files,glob_files,search_dora_doc,list_sub_agents", "parallel-safe matrix");
	check(expectedNames.filter(name => Registry.canPreExecuteTool(name)).length === 0, "pre-executable baseline");

	const mainSchemas = Registry.buildDecisionToolSchema("main", 20, { workMode: "code" });
	check(mainSchemas.length === 11, "main code function schema count");
	const readSchema = mainSchemas.find(item => item.function.name === "read_file");
	const readParams = readSchema?.function.parameters as Record<string, unknown> | undefined;
	const readProperties = readParams?.properties as Record<string, unknown> | undefined;
	const readBatchSchema = readProperties?.reads as Record<string, unknown> | undefined;
	check(Array.isArray(readParams?.required) && (readParams.required as string[]).join(",") === "reads" && readBatchSchema?.minItems === 1 && readBatchSchema.maxItems === undefined, "read_file requires an unbounded reads array");
	const readValidator = Registry.getToolDefinition("read_file")?.validateInput;
	const batchRead = readValidator?.({ reads: [{ path: "a.ts", startLine: 1, endLine: 2 }, { path: "b.ts", startLine: -2 }] });
	const legacyRead = readValidator?.({ path: "a.ts", startLine: 1, endLine: 2 });
	const emptyRead = readValidator?.({ reads: [] });
	check(batchRead?.success === true && (batchRead.value.reads as unknown[]).length === 2, "read_file validator accepts and normalizes reads");
	check(legacyRead?.success === false && emptyRead?.success === false, "read_file validator rejects legacy and empty forms");
	const buildSchema = mainSchemas.find(item => item.function.name === "build")?.function.parameters as Record<string, unknown> | undefined;
	const buildValidator = Registry.getToolDefinition("build")?.validateInput;
	check(Array.isArray(buildSchema?.required) && (buildSchema.required as string[]).join(",") === "paths", "build schema requires paths");
	check(buildValidator?.({ paths: ["a.ts", "b.ts"] }).success === true, "build validator accepts paths");
	check(buildValidator?.({ path: "a.ts" }).success === false && buildValidator?.({ paths: [] }).success === false, "build validator rejects legacy and empty forms");
	const editSchema = mainSchemas.find(item => item.function.name === "edit_file")?.function.parameters as Record<string, unknown> | undefined;
	const editProperties = editSchema?.properties as Record<string, unknown> | undefined;
	const editBatchSchema = editProperties?.edits as Record<string, unknown> | undefined;
	check(editBatchSchema?.minItems === 1 && editBatchSchema.maxItems === undefined, "edit_file batch is non-empty without an artificial upper bound");
	const editValidator = Registry.getToolDefinition("edit_file")?.validateInput;
	const legacyEdit = editValidator?.({ path: "a.ts", old_str: "a", new_str: "b" });
	const batchEdit = editValidator?.({ edits: [{ path: "a.ts", old_str: "a", new_str: "b" }, { path: "b.ts", old_str: "", new_str: "x" }] });
	const commonPathBatchEdit = editValidator?.({ path: "a.ts", edits: [{ old_str: "a", new_str: "b" }, { old_str: "b", new_str: "c" }] });
	const mixedEdit = editValidator?.({ path: "a.ts", old_str: "a", new_str: "b", edits: [{ path: "b.ts", old_str: "b", new_str: "c" }] });
	const emptyBatchEdit = editValidator?.({ edits: [] });
	const commonPathEdits = commonPathBatchEdit?.success === true ? commonPathBatchEdit.value.edits as Record<string, unknown>[] : [];
	check(legacyEdit?.success === true && batchEdit?.success === true, "edit_file validator preserves legacy form and accepts batch form");
	check(commonPathEdits.length === 2 && commonPathEdits[0].path === "a.ts" && commonPathEdits[1].path === "a.ts", "edit_file batch applies top-level default path");
	check(mixedEdit?.success === false && emptyBatchEdit?.success === false, "edit_file validator rejects mixed and empty forms");

	const mainFinish = Registry.buildDecisionToolSchema("main", 20, { workMode: "code" })
		.find(item => item.function.name === "finish")?.function.parameters as Record<string, unknown> | undefined;
	const subFinish = Registry.buildDecisionToolSchema("sub", 20, { workMode: "code" })
		.find(item => item.function.name === "finish")?.function.parameters as Record<string, unknown> | undefined;
	check(mainFinish === undefined, "finish is hidden from main agents");
	check(Array.isArray(subFinish?.required) && (subFinish?.required as string[]).join(",") === "message,outcome,validation,knownIssues,assumptions,learningCandidates", "sub finish strict requirements");

	return { success: failures.length === 0, passed, total, failures };
}
