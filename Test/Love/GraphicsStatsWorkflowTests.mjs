#!/usr/bin/env node

import {readFile} from "node:fs/promises";
import {basename, join} from "node:path";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/GraphicsStatsScene", import.meta.url));
const expected = "instances=2 counters=pass spritepair=1draw+1batched resources=isolated texturememory=pass target=pass";

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

async function upload(root, localPath) {
	const form = new FormData();
	form.append("file", new Blob([await readFile(localPath)]), basename(localPath));
	const response = await fetch(`${baseUrl}/upload?path=${encodeURIComponent(root)}`, {
		method: "POST",
		body: form,
	});
	assert(response.ok, `upload ${basename(localPath)} returned HTTP ${response.status}`);
}

async function waitForContent(path, timeoutMs = 30000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected graphics stats status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for graphics stats status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-graphics-stats`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	for (const filename of ["host.lua", "common.lua", "first.lua", "second.lua", "conf.lua"])
		await upload(root, join(fixtureRoot, filename));
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\ngraphicsStatsWorkflow = require "host"\ngraphicsStatsWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue graphics stats workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile);
	console.log(`LOVE_GRAPHICS_STATS_WORKFLOW_PASS ${expected}`);
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(root)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
