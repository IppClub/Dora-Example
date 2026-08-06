#!/usr/bin/env node

import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/MouseSettingsScene", import.meta.url));
const expected = "position=pass visibility=pass grab=pass relative=pass cursor=pass restart=pass reset=pass";

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
		if (result.success) {
			assert(result.content === expected, `unexpected mouse settings status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for mouse settings status at ${path}`);
}

const status = await post("/status");
assert(status.success && ["macOS", "Linux"].includes(status.platform) && status.writablePath,
	`mouse settings workflow requires desktop Dora on macOS or Linux, got ${status.platform ?? "unknown"}`);
const root = `${status.writablePath}/.download/love-mouse-settings`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create mouse settings workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nmouseSettingsWorkflow = require "host"\nmouseSettingsWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue mouse settings workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile);
	console.log(`LOVE_MOUSE_SETTINGS_WORKFLOW_PASS ${expected}`);
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
