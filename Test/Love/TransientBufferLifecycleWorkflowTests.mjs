#!/usr/bin/env node

import {readFile} from "node:fs/promises";
import {basename, dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = join(dirname(fileURLToPath(import.meta.url)), "Fixtures/TransientBufferLifecycleScene");
const marker = `LOVE_TRANSIENT_BEGIN_${crypto.randomUUID().replaceAll("-", "")}`;
const expected = "cycles=3 frames=120 points=840";

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

async function waitForContent(path, timeoutMs = 600000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) return result.content;
		await new Promise(resolve => setTimeout(resolve, 100));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-transient-buffer-lifecycle`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
const created = await post("/new", {path: root, content: "", folder: true});
assert(created.success, `failed to create transient workflow directory: ${created.message ?? ""}`);

try {
	await upload(root, join(fixtureRoot, "host.lua"));
	await upload(root, join(fixtureRoot, "main.lua"));
	const command = await post("/command", {
		code: `print ${JSON.stringify(marker)}\nContent\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\ntransientBufferWorkflow = require "host"\ntransientBufferWorkflow.run ${JSON.stringify(statusFile)}, 3, 120`,
		log: true,
	});
	assert(command.success, "failed to queue transient-buffer lifecycle workflow");
	assert(await waitForContent(statusFile) === expected, "unexpected transient-buffer workflow result");
	await new Promise(resolve => setTimeout(resolve, 500));
	const logResult = await post("/log", {count: 5000});
	assert(logResult.success && typeof logResult.log === "string", "failed to snapshot Dora logs");
	const combined = logResult.log;
	const markerIndex = combined.indexOf(marker);
	assert(markerIndex >= 0, "transient-buffer log marker was not persisted");
	const testLog = combined.slice(markerIndex);
	assert(!/not enough (?:space in )?transient|transient buffer for/i.test(testLog),
		"transient-buffer exhaustion was logged during lifecycle stress");
	console.log(`LOVE_TRANSIENT_BUFFER_LIFECYCLE_PASS ${expected}`);
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(root)}\ntransientBufferWorkflow = nil`,
		log: false,
	});
	await post("/delete", {path: root});
}
