#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/ShaderInterpolationScene", import.meta.url));
const expected = "flat=pass smooth=pass noperspective=compile centroid=compile combined=pass interface-block=pass matrices=pass arrays=pass block-arrays=pass nested-structs=pass multi-declarators=pass integer-varyings=pass inline-structs=pass diagnostics=pass";

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

async function waitForContent(path, timeoutMs = 20000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected Shader interpolation status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Shader interpolation status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
assert(status.wsConnectionCount === 1,
	`Shader interpolation workflow requires exactly one Web IDE compiler, got ${status.wsConnectionCount}`);
const root = `${status.writablePath}/.download/love-shader-interpolation`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nshaderInterpolationWorkflow = require "host"\nshaderInterpolationWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue Shader interpolation workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile);
	console.log(`LOVE_SHADER_INTERPOLATION_WORKFLOW_PASS ${expected}`);
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
