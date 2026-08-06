#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/MobileRuntimeScene", import.meta.url));
const workflowKey = `__loveMobile_${crypto.randomUUID().replaceAll("-", "")}`;

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
			assert(result.content === expected, `unexpected mobile runtime status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for mobile runtime status at ${path}`);
}

const status = await post("/status");
assert(status.success && ["iOS", "Android", "Linux", "Windows"].includes(status.platform) && status.writablePath,
	`multi-runtime workflow requires iOS, Android, Linux, or Windows Dora, got ${status.platform ?? "unknown"}`);
const platform = status.platform.toLowerCase();
const systemMix = status.platform === "iOS" ? "pass" : "unsupported";
const audio = status.platform === "Linux" ? "not-tested" : "soloud";
const expected = `platform=${platform} graphics=pass pixels=pass audio=${audio} systemmix=${systemMix} system=pass multi=2 input=injected stats=pass content=pass`;
const root = `${status.writablePath}/.download/love-mobile-runtime`;
const statusFile = `${root}/runtime-status.txt`;
const names = ["conf.lua", "common.lua", "first.lua", "second.lua", "host.lua"];
let initialized = false;

await post("/delete", {path: root});
try {
	let result = await post("/new", {path: root, content: "", folder: true});
	assert(result.success, `failed to create mobile workflow directory: ${result.message ?? ""}`);
	for (const name of names) {
		result = await post("/new", {
			path: `${root}/${name}`,
			content: readFileSync(`${fixtureRoot}/${name}`, "utf8"),
			folder: false,
		});
		assert(result.success, `failed to stage ${name} through Dora Content: ${result.message ?? ""}`);
	}

	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue mobile runtime workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(statusFile);
	console.log(`LOVE_MOBILE_RUNTIME_PASS platform=${status.platform} instances=2 input=injected audio=${status.platform === "Linux" ? "not-tested" : "SoLoud-lifecycle"} systemmix=${status.platform === "iOS" ? "AVAudioSession" : "unsupported"} system=vibrate+backgroundMusic`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
