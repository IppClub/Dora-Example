#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const hostRoot = fileURLToPath(new URL("./Fixtures/VideoNodeScene", import.meta.url));
const mediaRoot = fileURLToPath(new URL("./Fixtures/RuntimeScene/resources", import.meta.url));
const workflowKey = `__videoNodeWorkflow_${crypto.randomUUID().replaceAll("-", "")}`;

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

async function upload(directory, filename, source) {
	const form = new FormData();
	form.append("file", new Blob([readFileSync(source)]), filename);
	const response = await fetch(`${baseUrl}/upload?path=${encodeURIComponent(directory)}`, {
		method: "POST",
		body: form,
	});
	assert(response.ok,
		`failed to upload ${directory}/${filename} through Dora Content: HTTP ${response.status}`);
}

async function waitForContent(path, timeoutMs = 30000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) return result.content;
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for VideoNode status at ${path}`);
}

const status = await post("/status");
assert(status.success && ["macOS", "Windows", "Linux", "iOS", "Android"].includes(status.platform)
	&& status.writablePath,
	`VideoNode workflow requires a supported Dora app, got ${status.platform ?? "unknown"}`);
const root = `${status.writablePath}/.download/video-node-workflow-${workflowKey}`;
const statusFile = `${root}/status.txt`;
const outputRoot = `${root}/screenshots`;
let initialized = false;
await post("/delete", {path: root});

try {
	await create(root, "", true);
	await create(`${root}/host.lua`, readFileSync(`${hostRoot}/host.lua`, "utf8"));
	await upload(root, "sample.ogv", `${mediaRoot}/sample.ogv`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}, ${JSON.stringify(outputRoot)}`,
		log: true,
	});
	assert(command.success, `failed to queue VideoNode workflow: ${command.message ?? ""}`);
	initialized = true;
	const result = (await waitForContent(statusFile, status.platform === "Android" ? 90000 : 30000)).trim();
	assert(result === "content=pass dimensions=496x502 pause=pixel-stable loop=pixel-changing cleanup=pass",
		`VideoNode runtime failed: ${result}`);
	console.log(`DORA_VIDEO_NODE_WORKFLOW_PASS platform=${status.platform} content=pass dimensions=496x502 pause=pixel-stable loop=pixel-changing cleanup=pass`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\npackage.loaded.host = nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
