#!/usr/bin/env node

import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/PerformanceBaselineScene", import.meta.url));
const workflowKey = `__lovePerformance_${crypto.randomUUID().replaceAll("-", "")}`;

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

async function waitForContent(path, expected, timeoutMs = 5000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected performance phase: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for performance phase at ${path}`);
}

function median(values) {
	const sorted = [...values].sort((a, b) => a - b);
	return sorted[Math.floor(sorted.length / 2)];
}

const profilerQueue = [];
let profilerWaiter;
const socket = new WebSocket("ws://127.0.0.1:8868");
socket.onmessage = async event => {
	const data = typeof event.data === "string" ? event.data : await event.data.text();
	const message = JSON.parse(data);
	if (message.name !== "Profiler") return;
	profilerQueue.push(message.info);
	if (profilerWaiter) {
		profilerWaiter();
		profilerWaiter = undefined;
	}
};
await new Promise((resolve, reject) => {
	socket.onopen = resolve;
	socket.onerror = () => reject(new Error("failed to connect to Dora profiler WebSocket"));
});

async function nextProfiler(timeoutMs = 3000) {
	if (profilerQueue.length > 0) return profilerQueue.shift();
	await new Promise((resolve, reject) => {
		const timeout = setTimeout(() => {
			profilerWaiter = undefined;
			reject(new Error("timed out waiting for Dora profiler sample"));
		}, timeoutMs);
		profilerWaiter = () => {
			clearTimeout(timeout);
			resolve();
		};
	});
	return profilerQueue.shift();
}

async function samplePhase(count, statusFile) {
	await post("/delete", {path: statusFile});
	const command = await post("/command", {
		code: `(rawget _G, ${JSON.stringify(workflowKey)}).setCount ${count}, ${JSON.stringify(statusFile)}`,
		log: false,
	});
	assert(command.success, `failed to queue performance phase ${count}`);
	await waitForContent(statusFile, `count=${count}`);
	profilerQueue.length = 0;
	await nextProfiler();
	await nextProfiler();
	const samples = [];
	for (let index = 0; index < 5; ++index) samples.push(await nextProfiler());
	for (const sample of samples) {
		assert(sample.renderer === "Metal", `unexpected renderer ${sample.renderer}`);
		assert(Number.isFinite(sample.avgCPU) && sample.avgCPU >= 0, "invalid avgCPU sample");
		assert(sample.avgCPU < 1000 / sample.targetFPS,
			`avgCPU ${sample.avgCPU}ms exceeded the ${sample.targetFPS} FPS frame budget`);
	}
	return {
		cpu: median(samples.map(sample => sample.avgCPU)),
		textures: median(samples.map(sample => sample.textures)),
		textureMemory: median(samples.map(sample => sample.textureMemory)),
	};
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const root = `${status.writablePath}/.download/love-performance-baseline`;
const statusFile = `${root}/runtime-status.txt`;
const cleanupFile = `${root}/cleanup-status.txt`;
const finishFile = `${root}/finish-status.txt`;
let baseline;
let initialized = false;
let report;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create performance workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"`,
		log: false,
	});
	assert(command.success, "failed to initialize performance workflow");
	initialized = true;

	baseline = await samplePhase(0, statusFile);
	const one = await samplePhase(1, statusFile);
	const two = await samplePhase(2, statusFile);
	assert(one.textures - baseline.textures === 2,
		`one LoveNode added ${one.textures - baseline.textures} textures instead of 2`);
	assert(two.textures - baseline.textures === 4,
		`two LoveNodes added ${two.textures - baseline.textures} textures instead of 4`);
	assert(one.textureMemory - baseline.textureMemory === 32768,
		`one 64x64 LoveNode used ${one.textureMemory - baseline.textureMemory} texture bytes instead of 32768`);
	assert(two.textureMemory - baseline.textureMemory === 65536,
		`two 64x64 LoveNodes used ${two.textureMemory - baseline.textureMemory} texture bytes instead of 65536`);
	report = {baseline, one, two};
} finally {
	if (initialized) {
		await post("/delete", {path: cleanupFile});
		await post("/command", {
			code: `workflow = rawget _G, ${JSON.stringify(workflowKey)}\nif workflow\n\tworkflow.cleanup ${JSON.stringify(cleanupFile)}`,
			log: false,
		});
		await waitForContent(cleanupFile, "cleanup=pass", 5000);
		if (baseline) {
			profilerQueue.length = 0;
			await nextProfiler();
			await nextProfiler();
			const cleaned = await nextProfiler();
			assert(cleaned.textures === baseline.textures,
				`cleanup left ${cleaned.textures - baseline.textures} Love textures alive`);
			assert(cleaned.textureMemory === baseline.textureMemory,
				`cleanup left ${cleaned.textureMemory - baseline.textureMemory} Love texture bytes alive`);
		}
		await post("/delete", {path: finishFile});
		await post("/command", {
			code: `workflow = rawget _G, ${JSON.stringify(workflowKey)}\nif workflow\n\tworkflow.finish ${JSON.stringify(finishFile)}\nrawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
			log: false,
		});
		await waitForContent(finishFile, "finish=pass", 5000);
	}
	await post("/delete", {path: root});
	socket.close();
}

console.log("LOVE_PERFORMANCE_BASELINE_PASS", JSON.stringify(report));
