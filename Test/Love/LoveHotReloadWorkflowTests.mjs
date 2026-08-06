#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/HotReloadWorkflow", import.meta.url));

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

async function write(path, content, create = false) {
	const result = await post(create ? "/new" : "/write",
		create ? {path, content, folder: false} : {path, content});
	assert(result.success, `${create ? "create" : "write"} failed for ${path}: ${result.message ?? ""}`);
}

async function read(path) {
	const result = await post("/read", {path});
	assert(result.success, `read failed for ${path}`);
	return result.content;
}

async function waitForStatus(path, expected) {
	const deadline = Date.now() + 5000;
	while (Date.now() < deadline) {
		const result = await post("/read", {path});
		if (result.success && result.content === expected) return;
		await new Promise(resolve => setTimeout(resolve, 50));
	}
	throw new Error(`timed out waiting for hot reload status ${expected}`);
}

async function command(code) {
	const result = await post("/command", {code, log: true});
	assert(result.success, `Dora command failed: ${code}`);
}

async function build(root, path = root) {
	const result = await post("/ts/build", {path, projectRoot: root});
	assert(result.success, `TypeScript build request failed: ${result.message ?? ""}`);
	return result.messages ?? [];
}

const mainV1 = `import "love";
import {version} from "hot-module";

declare global {
	var p6OldLoveClosure: (() => string) | undefined;
}

let source: Love.Source | undefined;
globalThis.p6OldLoveClosure = () => "old-state";

love.load = () => {
	assert(version === "v1");
	const sound = love.sound.newSoundData(2205, 44100, 16, 1);
	source = love.audio.newSource(sound);
	source.setLooping(true);
	assert(source.play());
	print("LOVE_HOT_RELOAD_V1_LOAD", version);
};

love.update = () => {
	assert(source !== undefined);
};

love.draw = () => {
	love.graphics.clear(0.8, 0.1, 0.1, 1);
};
`;

const moduleV1 = `export const version = "v1";\n`;

const mainV2 = `import "love";
import {version} from "hot-module";

declare global {
	var p6OldLoveClosure: (() => string) | undefined;
}

love.load = () => {
	assert(version === "v2");
	assert(globalThis.p6OldLoveClosure === undefined, "old Love global survived restart");
	print("LOVE_HOT_RELOAD_V2_LOAD", version);
};

love.draw = () => {
	love.graphics.clear(0.1, 0.8, 0.1, 1);
};
`;

const moduleV2 = `export const version = "v2";\n`;
const invalidTs = `import "love";\nlove.load = () => { const broken: = 1; };\n`;

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status did not provide writablePath");
const activeRoot = `${status.writablePath}/.download/love-hot-reload-workflow`;
const statusFile = `${activeRoot}/status.txt`;
const mainTs = `${activeRoot}/main.ts`;
const moduleTs = `${activeRoot}/hot-module.ts`;
const mainLua = `${activeRoot}/main.lua`;

await post("/delete", {path: activeRoot});
const created = await post("/new", {path: activeRoot, content: "", folder: true});
assert(created.success, `failed to create active hot reload root: ${created.message ?? ""}`);
let workflowStarted = false;
try {
	await write(mainTs, mainV1, true);
	await write(moduleTs, moduleV1, true);
	let messages = await build(activeRoot);
	assert(messages.length === 2 && messages.every(message => message.success),
		`generation 1 build failed: ${JSON.stringify(messages)}`);

	await command(`Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nhotWorkflow = require "host"\nhotWorkflow.start ${JSON.stringify(activeRoot)}`);
	workflowStarted = true;
	await waitForStatus(statusFile, "v1");

	await write(mainTs, mainV2);
	await write(moduleTs, moduleV2);
	messages = await build(activeRoot);
	assert(messages.length === 2 && messages.every(message => message.success),
		`generation 2 build failed: ${JSON.stringify(messages)}`);
	await command("hotWorkflow.reloadV2!");
	await waitForStatus(statusFile, "v2");

	const acceptedLua = await read(mainLua);
	await write(mainTs, invalidTs);
	messages = await build(activeRoot, mainTs);
	assert(messages.length === 1 && !messages[0].success,
		`invalid TypeScript unexpectedly compiled: ${JSON.stringify(messages)}`);
	assert(await read(mainLua) === acceptedLua, "failed TypeScript build overwrote the last accepted Lua");
	await command("hotWorkflow.verifyRejectedBuild!");
	await waitForStatus(statusFile, "rejected");

	await write(mainLua, `-- [ts]: ${mainTs}\nlocal broken = -- 2\n`);
	await command("hotWorkflow.expectFailedRestart!");
	await waitForStatus(statusFile, "failed");

	await write(mainTs, mainV2);
	await write(moduleTs, moduleV2);
	messages = await build(activeRoot);
	assert(messages.length === 2 && messages.every(message => message.success),
		`recovery build failed: ${JSON.stringify(messages)}`);
	await command("hotWorkflow.recover!");
	await waitForStatus(statusFile, "recovered");
	await command("hotWorkflow.finish!");
	workflowStarted = false;

	console.log("PASS: Content-built TS hot reload, state replacement, rejected build preservation, failure cleanup, recovery, and LoveNode isolation");
} finally {
	if (workflowStarted) {
		try {
			await command("hotWorkflow.finish!");
		} catch {
			// Preserve the original assertion or transport failure.
		}
	}
	await post("/delete", {path: activeRoot}).catch(() => undefined);
}
