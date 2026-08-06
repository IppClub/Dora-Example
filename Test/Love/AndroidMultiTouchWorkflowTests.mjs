#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const adb = process.env.ADB
	?? `${process.env.HOME}/Library/Android/sdk/platform-tools/adb`;
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `loveAndroidMultiTouch_${crypto.randomUUID().replaceAll("-", "")}`;
const files = ["conf.lua", "main.lua", "host.lua"];
const expected = "platform=android touches=2 move=both release=ordered source=inputreader content=pass";

const EV_SYN = 0;
const SYN_REPORT = 0;
const EV_ABS = 3;
const ABS_MT_SLOT = 47;
const ABS_MT_POSITION_X = 53;
const ABS_MT_POSITION_Y = 54;
const ABS_MT_TRACKING_ID = 57;
const ABS_MT_PRESSURE = 58;

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
					`unexpected Android multi-touch status: ${result.content}`);
			return result.content;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Android multi-touch status at ${path}`);
}

function adbRun(...args) {
	return execFileSync(adb, args, {encoding: "utf8", timeout: 10000});
}

function activeMultiTouchDevice() {
	const inputDump = adbRun("shell", "dumpsys", "input");
	const sections = inputDump.split(/(?=^  Device \d+: )/m);
	const section = sections.find(value => value.includes("virtio_input_multi_touch_")
		&& value.includes("Touch Input Mapper (mode - DIRECT)"));
	assert(section, "Android AVD has no active direct multi-touch input device");
	const name = section.match(/^  Device \d+: (virtio_input_multi_touch_\d+)/m)?.[1];
	assert(name, "could not resolve Android direct multi-touch device name");
	const eventDump = adbRun("shell", "getevent", "-lp");
	const eventSections = eventDump.split(/(?=^add device \d+: )/m);
	const eventSection = eventSections.find(value => value.includes(`name:     "${name}"`));
	const device = eventSection?.match(/^add device \d+: (\/dev\/input\/event\d+)/m)?.[1];
	assert(device, `could not resolve event path for ${name}`);
	assert(eventSection.includes("ABS_MT_SLOT") && eventSection.includes("ABS_MT_TRACKING_ID"),
		`${name} does not expose Protocol-B multi-touch slots`);
	assert(adbRun("shell", "id").includes("uid=0(root)"),
		"Android multi-touch workflow requires a root-capable AVD for sendevent");
	return {name, device};
}

function sendEvent(device, type, code, value) {
	adbRun("shell", "sendevent", device, String(type), String(code), String(value));
}

function report(device) {
	sendEvent(device, EV_SYN, SYN_REPORT, 0);
}

function setSlot(device, slot, trackingId, x, y) {
	sendEvent(device, EV_ABS, ABS_MT_SLOT, slot);
	sendEvent(device, EV_ABS, ABS_MT_TRACKING_ID, trackingId);
	sendEvent(device, EV_ABS, ABS_MT_POSITION_X, x);
	sendEvent(device, EV_ABS, ABS_MT_POSITION_Y, y);
	sendEvent(device, EV_ABS, ABS_MT_PRESSURE, 512);
}

function moveSlot(device, slot, x, y) {
	sendEvent(device, EV_ABS, ABS_MT_SLOT, slot);
	sendEvent(device, EV_ABS, ABS_MT_POSITION_X, x);
	sendEvent(device, EV_ABS, ABS_MT_POSITION_Y, y);
}

function releaseSlot(device, slot) {
	sendEvent(device, EV_ABS, ABS_MT_SLOT, slot);
	sendEvent(device, EV_ABS, ABS_MT_TRACKING_ID, -1);
}

function releaseAll(device) {
	for (const slot of [0, 1]) releaseSlot(device, slot);
	report(device);
}

const status = await post("/status");
assert(status.success && status.platform === "Android" && status.writablePath,
	`Android multi-touch workflow requires Android Dora, got ${status.platform ?? "unknown"}`);
assert(adbRun("get-state").trim() === "device", "adb device is not ready");
const touchDevice = activeMultiTouchDevice();

const root = `${status.writablePath}/.download/love-android-multitouch-${workflowKey}`;
const readyFile = `${root}/ready.txt`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	releaseAll(touchDevice.device);
	await create(root, "", true);
	for (const filename of files) {
		await create(`${root}/${filename}`,
			readFileSync(`${testsRoot}/Fixtures/AndroidMultiTouchScene/${filename}`, "utf8"));
	}
	const launcher = `${root}/launcher.lua`;
	await create(launcher,
		`require("host").run(${JSON.stringify(readyFile)}, ${JSON.stringify(statusFile)})\n`);
	const command = await post("/command", {
		code: `Entry = require "Script.Dev.Entry"\nthread -> Entry.enterEntryAsync {entryName: ${JSON.stringify(workflowKey)}, fileName: ${JSON.stringify(launcher)}, workDir: ${JSON.stringify(root)}}`,
		log: true,
	});
	assert(command.success, `failed to queue Android multi-touch workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(readyFile, 15000, "ready");

	setSlot(touchDevice.device, 0, 101, 18200, 15400);
	report(touchDevice.device);
	await new Promise(resolve => setTimeout(resolve, 80));
	setSlot(touchDevice.device, 1, 202, 16000, 17200);
	report(touchDevice.device);
	await new Promise(resolve => setTimeout(resolve, 80));
	moveSlot(touchDevice.device, 0, 18000, 15800);
	moveSlot(touchDevice.device, 1, 16200, 16800);
	report(touchDevice.device);
	await new Promise(resolve => setTimeout(resolve, 120));
	releaseSlot(touchDevice.device, 0);
	report(touchDevice.device);
	await new Promise(resolve => setTimeout(resolve, 120));
	releaseSlot(touchDevice.device, 1);
	report(touchDevice.device);

	await waitForContent(statusFile, 20000, expected);
	console.log(`LOVE_ANDROID_MULTITOUCH_WORKFLOW_PASS touches=2 move=both release=ordered device=${touchDevice.name}`);
} finally {
	releaseAll(touchDevice.device);
	if (initialized) {
		await post("/command", {
			code: `Entry = require "Script.Dev.Entry"\nEntry.stop!\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
