#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/AudioScene", import.meta.url));

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
		assert(result.content === expected, `unexpected audio status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for audio status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
assert(status.wsConnectionCount === 1,
	`audio workflow requires exactly one Web IDE compiler, got ${status.wsConnectionCount}`);
const root = `${status.writablePath}/.download/love-audio`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\naudioWorkflow = require "host"\naudioWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue audio workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile, "pause-list=pass source-table=pass active-count=pass channels=pass aliases=pass spatial-shared=pass doppler-shared=pass distance-model-shared=pass source-spatial=pass source-cone=pass source-hf=pass volume-limits=pass queue=pass effects=pass effect-isolation=pass dora-coexist=pass soloud=pass");
	console.log("LOVE_AUDIO_WORKFLOW_PASS pause-list=pass source-table=pass active-count=pass channels=pass aliases=pass spatial-shared=pass doppler-shared=pass distance-model-shared=pass source-spatial=pass source-cone=pass source-hf=pass volume-limits=pass queue=pass effects=pass effect-isolation=pass dora-coexist=pass soloud=pass");
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
