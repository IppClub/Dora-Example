#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const adb = process.env.ADB
	?? `${process.env.HOME}/Library/Android/sdk/platform-tools/adb`;
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `loveAndroidSystemInput_${crypto.randomUUID().replaceAll("-", "")}`;
const files = ["conf.lua", "main.lua", "host.lua"];
const expected = "platform=android touch=press+move+release key=a source=os content=pass";

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
					`unexpected Android system-input status: ${result.content}`);
			return result.content;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Android system-input status at ${path}`);
}

function adbRun(...args) {
	return execFileSync(adb, args, {encoding: "utf8", timeout: 10000});
}

function currentAppBounds() {
	const output = adbRun("shell", "dumpsys", "window", "displays");
	const match = output.match(/mAppBounds=Rect\(0, 0 - (\d+), (\d+)\)/);
	assert(match, "could not determine the current Android app bounds");
	return {width: Number(match[1]), height: Number(match[2])};
}

const status = await post("/status");
assert(status.success && status.platform === "Android" && status.writablePath,
	`Android system-input workflow requires Android Dora, got ${status.platform ?? "unknown"}`);
assert(adbRun("get-state").trim() === "device", "adb device is not ready");

const root = `${status.writablePath}/.download/love-android-system-input-${workflowKey}`;
const readyFile = `${root}/ready.txt`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	for (const filename of files) {
		await create(`${root}/${filename}`,
			readFileSync(`${testsRoot}/Fixtures/AndroidSystemInputScene/${filename}`, "utf8"));
	}
	const launcher = `${root}/launcher.lua`;
	await create(launcher,
		`require("host").run(${JSON.stringify(readyFile)}, ${JSON.stringify(statusFile)})\n`);
	const command = await post("/command", {
		code: `Entry = require "Script.Dev.Entry"\nthread -> Entry.enterEntryAsync {entryName: ${JSON.stringify(workflowKey)}, fileName: ${JSON.stringify(launcher)}, workDir: ${JSON.stringify(root)}}`,
		log: true,
	});
	assert(command.success, `failed to queue Android system-input workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(readyFile, 15000, "ready");

	const bounds = currentAppBounds();
	const centerX = Math.round(bounds.width / 2);
	const centerY = Math.round(bounds.height / 2);
	const travel = Math.max(60, Math.round(Math.min(bounds.width, bounds.height) * 0.08));
	adbRun("shell", "input", "touchscreen", "swipe",
		String(centerX - travel), String(centerY),
		String(centerX + travel), String(centerY + Math.round(travel / 2)), "500");
	await new Promise(resolve => setTimeout(resolve, 150));
	adbRun("shell", "input", "keyevent", "KEYCODE_A");

	await waitForContent(statusFile, 20000, expected);
	console.log(`LOVE_ANDROID_SYSTEM_INPUT_WORKFLOW_PASS touch=press+move+release key=a source=os bounds=${bounds.width}x${bounds.height}`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `Entry = require "Script.Dev.Entry"\nEntry.stop!\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
