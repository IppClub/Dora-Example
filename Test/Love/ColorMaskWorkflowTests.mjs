#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/ColorMaskScene", import.meta.url));

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

async function waitForContent(path, expected, timeoutMs = 20000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected color-mask status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for color-mask status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-color-mask`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\ncolorMaskWorkflow = require "host"\ncolorMaskWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue color-mask workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile, "independent-rgba=pass masked-clear=pass scoped-clear=pass mrt-clear=pass custom-depth-stencil=pass subtract=pass");
	console.log("LOVE_COLOR_MASK_WORKFLOW_PASS independent-rgba=pass masked-clear=pass scoped-clear=pass mrt-clear=pass custom-depth-stencil=pass subtract=pass");
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
