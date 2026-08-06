#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/ShaderNon2DTextureScene", import.meta.url));
const expected = "single=array+cube+volume arrays=array+cube+volume dynamic-index=pass type-guard=pass pixels=pass";

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
			assert(!result.content.startsWith("failed:"), result.content);
			assert(result.content === expected, `unexpected non-2D Shader status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for non-2D Shader status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-shader-non2d-workflow`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create non-2D Shader workflow directory: ${created.message ?? ""}`);
	for (const filename of ["host.lua", "main.lua"]) {
		const staged = await post("/new", {
			path: `${root}/${filename}`,
			content: readFileSync(`${fixtureRoot}/${filename}`, "utf8"),
			folder: false,
		});
		assert(staged.success,
			`failed to stage ${filename} through Dora Content: ${staged.message ?? ""}`);
	}
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nshaderNon2DWorkflow = require "host"\nshaderNon2DWorkflow.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue non-2D Shader workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile);
	console.log(`LOVE_SHADER_NON2D_WORKFLOW_PASS platform=${status.platform} ${expected}`);
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(root)}`,
		log: false,
	});
	await post("/delete", {path: root});
}
