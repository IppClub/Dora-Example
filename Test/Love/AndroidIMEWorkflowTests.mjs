#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const adb = process.env.ADB
	?? `${process.env.HOME}/Library/Android/sdk/platform-tools/adb`;
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `loveAndroidIME_${crypto.randomUUID().replaceAll("-", "")}`;
const files = ["conf.lua", "main.lua", "host.lua"];
const expected = "platform=android default=true ime=explicit key=single text=a closed=true content=pass";

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
					`unexpected Android IME status: ${result.content}`);
			return result.content;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Android IME status at ${path}`);
}

function adbRun(...args) {
	return execFileSync(adb, args, {encoding: "utf8", timeout: 10000});
}

function servedView() {
	const output = adbRun("shell", "dumpsys", "input_method");
	const lines = output.split("\n").filter(line => line.includes("mServedView="));
	return lines.find(line => line.includes("org.libsdl.app.DummyEdit"))
		?? lines.find(line => line.includes("org.libsdl.app.SDLSurface"))
		?? lines.join("\n");
}

async function waitForServedView(className, timeoutMs) {
	const deadline = Date.now() + timeoutMs;
	do {
		const current = servedView();
		if (current.includes(className)) return current;
		await new Promise(resolve => setTimeout(resolve, 50));
	} while (Date.now() < deadline);
	throw new Error(`Android input focus did not reach ${className}; current served view: ${servedView()}`);
}

const status = await post("/status");
assert(status.success && status.platform === "Android" && status.writablePath,
	`Android IME workflow requires Android Dora, got ${status.platform ?? "unknown"}`);
assert(adbRun("get-state").trim() === "device", "adb device is not ready");

const root = `${status.writablePath}/.download/love-android-ime-${workflowKey}`;
const readyFile = `${root}/ready.txt`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	for (const filename of files) {
		await create(`${root}/${filename}`,
			readFileSync(`${testsRoot}/Fixtures/AndroidIMEScene/${filename}`, "utf8"));
	}
	const launcher = `${root}/launcher.lua`;
	await create(launcher,
		`require("host").run(${JSON.stringify(readyFile)}, ${JSON.stringify(statusFile)})\n`);
	const command = await post("/command", {
		code: `Entry = require "Script.Dev.Entry"\nthread -> Entry.enterEntryAsync {entryName: ${JSON.stringify(workflowKey)}, fileName: ${JSON.stringify(launcher)}, workDir: ${JSON.stringify(root)}}`,
		log: true,
	});
	assert(command.success, `failed to queue Android IME workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(readyFile, 15000, "ready");
	await waitForServedView("org.libsdl.app.DummyEdit", 5000);

	adbRun("shell", "input", "keyevent", "KEYCODE_A");
	await waitForContent(statusFile, 20000, expected);
	await waitForServedView("org.libsdl.app.SDLSurface", 5000);
	console.log("LOVE_ANDROID_IME_WORKFLOW_PASS default=true ime=DummyEdit key=single text=a close=SDLSurface");
} finally {
	if (initialized) {
		await post("/command", {
			code: `Entry = require "Script.Dev.Entry"\nEntry.stop!\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
