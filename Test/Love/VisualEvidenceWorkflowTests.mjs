#!/usr/bin/env node

import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixturesRoot = fileURLToPath(new URL("./Fixtures", import.meta.url));
const hostRoot = fileURLToPath(new URL("./Fixtures/VisualEvidenceWorkflow", import.meta.url));
const requestedOutput = process.argv[3];
const workflowKey = `__loveVisualEvidence_${crypto.randomUUID().replaceAll("-", "")}`;

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function post(path, body = {}) {
	const response = await fetch(`${baseUrl}${path}`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify(body),
	});
	assert(response.ok, `${path} returned HTTP ${response.status}`);
	return response.json();
}

async function waitForContent(path, timeoutMs = 30000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) return result.content;
		await new Promise(resolve => setTimeout(resolve, 50));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for visual evidence at ${path}`);
}

const status = await post("/status");
assert(status.success && status.platform === "macOS", "visual evidence workflow requires macOS Dora");
const temporaryOutput = `${status.writablePath}/.download/love-visual-evidence`;
const outputRoot = requestedOutput ?? temporaryOutput;
const statusRoot = `${status.writablePath}/.download/love-visual-evidence-status`;
const statusFile = `${statusRoot}/result.txt`;
await post("/delete", {path: statusRoot});
if (!requestedOutput) await post("/delete", {path: outputRoot});

try {
	assert((await post("/new", {path: statusRoot, content: "", folder: true})).success,
		"failed to create visual evidence status directory");
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(hostRoot)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}, ${JSON.stringify(fixturesRoot)}, ${JSON.stringify(outputRoot)}`,
		log: false,
	});
	assert(command.success, "failed to queue visual evidence workflow");
	const result = await waitForContent(statusFile);
	assert(result === "visual=canvas,stencil,mesh screenshots=3 renderer=metal content=pass cleanup=pass",
		`visual evidence workflow failed: ${result}`);
	console.log("LOVE_VISUAL_EVIDENCE_WORKFLOW_PASS screenshots=3 renderer=Metal content=pass cleanup=pass");
} finally {
	await post("/command", {
		code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\npackage.loaded.host = nil\nContent\\removeSearchPath ${JSON.stringify(hostRoot)}`,
		log: false,
	});
	await post("/delete", {path: statusRoot});
	if (!requestedOutput) await post("/delete", {path: outputRoot});
}
