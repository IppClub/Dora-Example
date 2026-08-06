#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `__loveMobilePhysics_${crypto.randomUUID().replaceAll("-", "")}`;
const files = [
	["host.lua", "Fixtures/MobilePhysicsScene/host.lua"],
	["conf.lua", "Fixtures/MobilePhysicsScene/conf.lua"],
	["main.lua", "Fixtures/PhysicsScene/main.lua"],
	["boot.lua", "Fixtures/PhysicsScene/boot.lua"],
];

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
			assert(result.content === expected, `mobile physics workflow failed: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for mobile physics status at ${path}`);
}

const status = await post("/status");
assert(status.success && ["iOS", "Android"].includes(status.platform) && status.writablePath,
	`mobile physics workflow requires mobile Dora, got ${status.platform ?? "unknown"}`);
const expected = `platform=${status.platform.toLowerCase()} physics=playrho callbacks=pass joints=11 ccd=pass pixels=pass content=pass`;
const root = `${status.writablePath}/.download/love-mobile-physics`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	let result = await post("/new", {path: root, content: "", folder: true});
	assert(result.success, `failed to create mobile physics directory: ${result.message ?? ""}`);
	for (const [target, source] of files) {
		result = await post("/new", {
			path: `${root}/${target}`,
			content: readFileSync(`${testsRoot}/${source}`, "utf8"),
			folder: false,
		});
		assert(result.success, `failed to stage ${target} through Dora Content: ${result.message ?? ""}`);
	}

	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue mobile physics workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(statusFile);
	console.log(`LOVE_MOBILE_PHYSICS_PASS platform=${status.platform} backend=PlayRho callbacks=pass joints=11 ccd=pass pixels=pass`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
