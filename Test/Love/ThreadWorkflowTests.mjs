#!/usr/bin/env node

import process from "node:process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/ThreadWorkflow", import.meta.url));
const workflowKey = `__loveThreadWorkflow_${crypto.randomUUID().replaceAll("-", "")}`;
const files = ["host.lua", "main.lua", "worker.lua"];

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
			assert(result.content === expected, `unexpected Thread workflow status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Thread workflow status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-thread-workflow-${workflowKey}`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create Thread workflow directory: ${created.message ?? ""}`);
	for (const filename of files) {
		const staged = await post("/new", {
			path: `${root}/${filename}`,
			content: readFileSync(`${fixtureRoot}/${filename}`, "utf8"),
			folder: false,
		});
		assert(staged.success,
			`failed to stage ${filename} through Dora Content: ${staged.message ?? ""}`);
	}
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue Thread workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(statusFile,
		"thread=pass generations=2 source=content error=pass isolation=pass");
	console.log(`LOVE_THREAD_WORKFLOW_PASS platform=${status.platform} generations=2 source=content error=pass isolation=pass`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\npackage.loaded.host = nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
