#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `loveMacOSPhysicalMouse_${crypto.randomUUID().replaceAll("-", "")}`;
const files = ["boot.lua", "conf.lua", "main.lua", "host.lua"];
const expected = "platform=macOS move=pass buttons=left+right+middle doubleclick=pass wheel=pass content=pass";

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

async function create(path, content = "", folder = false) {
	const result = await post("/new", {path, content, folder});
	assert(result.success, `failed to stage ${path} through Dora Content: ${result.message ?? ""}`);
}

async function waitForContent(path, timeoutMs, expectedContent) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			if (expectedContent !== undefined)
				assert(result.content === expectedContent,
					`unexpected macOS physical mouse status: ${result.content}`);
			return result.content;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for macOS physical mouse status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.platform === "macOS" && status.writablePath,
	`physical mouse workflow requires macOS Dora, got ${status.platform ?? "unknown"}`);

const root = `${status.writablePath}/.download/love-macos-physical-mouse-${workflowKey}`;
const readyFile = `${root}/ready.txt`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	for (const filename of files) {
		await create(`${root}/${filename}`,
			readFileSync(`${testsRoot}/Fixtures/PhysicalMouseScene/${filename}`, "utf8"));
	}
	const launcher = `${root}/launcher.lua`;
	await create(launcher,
		`require("host").run(${JSON.stringify(readyFile)}, ${JSON.stringify(statusFile)})\n`);
	const command = await post("/command", {
		code: `Entry = require "Script.Dev.Entry"\nthread -> Entry.enterEntryAsync {entryName: ${JSON.stringify(workflowKey)}, fileName: ${JSON.stringify(launcher)}, workDir: ${JSON.stringify(root)}}`,
		log: true,
	});
	assert(command.success, `failed to queue physical mouse workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(readyFile, 15000, "ready");
	console.log("LOVE_MACOS_PHYSICAL_MOUSE_READY interact-with-dora-window");
	await waitForContent(statusFile, 90000, expected);
	console.log("LOVE_MACOS_PHYSICAL_MOUSE_WORKFLOW_PASS move=pass buttons=left+right+middle doubleclick=pass wheel=pass");
} finally {
	if (initialized) {
		await post("/command", {
			code: `Entry = require "Script.Dev.Entry"\nEntry.stop!\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
