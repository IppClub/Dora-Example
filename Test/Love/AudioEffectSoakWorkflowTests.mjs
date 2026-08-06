#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const durationSeconds = Number(process.argv[3] ?? 1800);
const fixtureRoot = fileURLToPath(new URL("./Fixtures/AudioEffectSoakScene", import.meta.url));
const workflowKey = `__loveAudioSoak_${crypto.randomUUID().replaceAll("-", "")}`;

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

async function read(path) {
	return post("/read", {path});
}

const profilerSamples = [];
let profilerWaiter;
const socket = new WebSocket("ws://127.0.0.1:8868");
socket.onmessage = async event => {
	const data = typeof event.data === "string" ? event.data : await event.data.text();
	const message = JSON.parse(data);
	if (message.name === "Profiler") {
		profilerSamples.push(message.info);
		if (profilerWaiter) {
			profilerWaiter();
			profilerWaiter = undefined;
		}
	}
};
await new Promise((resolve, reject) => {
	socket.onopen = resolve;
	socket.onerror = () => reject(new Error("failed to connect to Dora profiler WebSocket"));
});

async function waitForProfilerCount(count, timeoutMs = 5000) {
	const deadline = Date.now() + timeoutMs;
	while (profilerSamples.length < count) {
		await new Promise((resolve, reject) => {
			const timeout = setTimeout(() => {
				profilerWaiter = undefined;
				reject(new Error(`timed out waiting for ${count} profiler samples`));
			}, Math.max(1, deadline - Date.now()));
			profilerWaiter = () => {
				clearTimeout(timeout);
				resolve();
			};
		});
	}
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
// This runner opens the profiler socket before querying status, so the Web IDE
// compiler plus this observer normally report as two live connections.
assert(status.wsConnectionCount >= 1,
	`audio soak requires a live Web IDE compiler, got ${status.wsConnectionCount}`);
assert(Number.isFinite(durationSeconds) && durationSeconds >= 1,
	"audio soak duration must be at least one second");
const root = `${status.writablePath}/.download/love-audio-effect-soak`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;
const started = Date.now();
let nextProgress = started + 60000;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create audio soak directory: ${created.message ?? ""}`);
	const initialize = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).prepare!`,
		log: false,
	});
	assert(initialize.success, "failed to initialize audio effect soak workflow");
	initialized = true;
	await waitForProfilerCount(2);
	const baseline = profilerSamples.at(-1);
	const workloadSampleStart = profilerSamples.length;
	const command = await post("/command", {
		code: `(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}, ${durationSeconds}`,
		log: false,
	});
	assert(command.success, "failed to start audio effect soak workflow");

	const timeout = started + (durationSeconds + 30) * 1000;
	let result;
	do {
		result = await read(statusFile);
		if (result.success) break;
		if (Date.now() >= nextProgress) {
			console.log("LOVE_AUDIO_EFFECT_SOAK_PROGRESS",
				`elapsed=${Math.round((Date.now() - started) / 1000)}s`,
				`profilerSamples=${profilerSamples.length}`);
			nextProgress += 60000;
		}
		await new Promise(resolve => setTimeout(resolve, 250));
	} while (Date.now() < timeout);
	assert(result?.success, "timed out waiting for audio effect soak completion");
	assert(result.content.startsWith("pass "), `audio effect soak failed: ${result.content}`);
	await waitForProfilerCount(profilerSamples.length + 2);
	const workloadSamples = profilerSamples.slice(workloadSampleStart);
	assert(workloadSamples.length >= Math.max(2, Math.floor(durationSeconds / 3)),
		`audio effect soak collected only ${workloadSamples.length} workload samples`);
	for (const sample of workloadSamples) {
		assert(Number.isFinite(sample.avgCPU) && sample.avgCPU >= 0,
			"audio effect soak received an invalid profiler CPU sample");
	}
	const peakAudios = Math.max(...workloadSamples.map(sample => sample.audios));
	const peakAudioMemory = Math.max(...workloadSamples.map(sample => sample.audioMemory));
	const cleaned = profilerSamples.at(-1);
	assert(peakAudios >= baseline.audios + 120,
		`audio effect soak observed only ${peakAudios - baseline.audios} concurrent AudioFiles`);
	assert(cleaned.audios === baseline.audios,
		`audio effect soak retained ${cleaned.audios - baseline.audios} AudioFiles after cleanup`);
	assert(cleaned.audioMemory === baseline.audioMemory,
		`audio effect soak retained ${cleaned.audioMemory - baseline.audioMemory} audio bytes after cleanup`);
	console.log("LOVE_AUDIO_EFFECT_SOAK_PASS", result.content,
		`profilerSamples=${workloadSamples.length}`,
		`peakAudios=${peakAudios}`,
		`peakAudioMemory=${peakAudioMemory}`,
		`cleanupAudios=${cleaned.audios}`,
		`cleanupAudioMemory=${cleaned.audioMemory}`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `workflow = rawget _G, ${JSON.stringify(workflowKey)}\nif workflow\n\tworkflow.finish!\nrawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
	socket.close();
}
