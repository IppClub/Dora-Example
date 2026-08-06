#!/usr/bin/env node

import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/AsyncLifecycleScene", import.meta.url));
const workflowKey = `__loveAsyncLifecycle_${crypto.randomUUID().replaceAll("-", "")}`;

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
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for async lifecycle status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.platform === "macOS" && status.writablePath,
	`async lifecycle workflow requires the macOS Dora app, got ${status.platform ?? "unknown"}`);
const root = `${status.writablePath}/.download/async-lifecycle-${workflowKey}`;
const statusFile = `${root}/status.txt`;
let initialized = false;
await post("/delete", {path: root});

try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create async lifecycle directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue async lifecycle workflow: ${command.message ?? ""}`);
	initialized = true;
	const result = (await waitForContent(statusFile)).trim();
	assert(result === "generation=pass destroy=pass stale-callback=dropped stale-file=dropped current=pass cleanup=pass",
		`async lifecycle workflow failed: ${result}`);
	console.log("LOVE_ASYNC_LIFECYCLE_WORKFLOW_PASS generation=pass destroy=pass stale-callback=dropped stale-file=dropped current=pass cleanup=pass");
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\npackage.loaded.host = nil\nContent\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
