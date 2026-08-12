#!/usr/bin/env node

import {readFile} from "node:fs/promises";
import {basename, dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const packageRoot = process.argv[3];
const index = Number(process.argv[4]);
const frameBudget = Number(process.argv[5] ?? 120);
const testRoot = dirname(fileURLToPath(import.meta.url));

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function post(path, body = {}, timeoutMs = 5000) {
	const response = await fetch(`${baseUrl}${path}`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify(body),
		signal: AbortSignal.timeout(timeoutMs),
	});
	assert(response.ok, `${path} returned HTTP ${response.status}`);
	return response.json();
}

async function upload(root, localPath) {
	const form = new FormData();
	form.append("file", new Blob([await readFile(localPath)]), basename(localPath));
	const response = await fetch(`${baseUrl}/upload?path=${encodeURIComponent(root)}`, {
		method: "POST",
		body: form,
		// Large source games in the reproducible corpus exceed 60 MiB and an
		// Android emulator can take several minutes to persist the multipart upload.
		signal: AbortSignal.timeout(300000),
	});
	assert(response.ok, `upload ${basename(localPath)} returned HTTP ${response.status}`);
}

async function waitForContent(path, timeoutMs = 60000) {
	const deadline = Date.now() + timeoutMs;
	do {
		try {
			const result = await post("/read", {path}, 2000);
			if (result.success) return result.content;
		} catch (error) {
			if (Date.now() >= deadline) throw error;
		}
		await new Promise(resolve => setTimeout(resolve, 250));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for ${path}`);
}

assert(packageRoot && Number.isInteger(index) && index >= 1 && index <= 100,
	"usage: node AndroidOpenSourceGameCase.mjs BASE_URL PACKAGE_ROOT INDEX [FRAME_BUDGET]");
const cases = JSON.parse(await readFile(join(packageRoot, "AndroidCases.json"), "utf8"));
assert(cases.length === 100, `expected exactly 100 packaged cases, got ${cases.length}`);
const game = cases[index - 1];
assert(game.index === index, `case index mismatch at ${index}`);
const root = `/data/data/org.ippclub.dorassr/files/.download/love-corpus-100-${String(index).padStart(3, "0")}`;
const statusFile = `${root}/runtime-status.tsv`;
await post("/delete", {path: root});
const created = await post("/new", {path: root, content: "", folder: true});
assert(created.success, `failed to create ${root}: ${created.message ?? ""}`);

try {
	await upload(root, join(testRoot, "Fixtures/OpenSourceGameCorpusScene/host.lua"));
	const packagePath = join(packageRoot, game.package);
	await upload(root, packagePath);
	const remoteCases = JSON.stringify([{name: game.name, path: `${root}/${game.package}`}]);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nopenSourceGameCorpusWorkflow = require "host"\nopenSourceGameCorpusWorkflow.run ${JSON.stringify(remoteCases)}, ${JSON.stringify(statusFile)}, ${frameBudget}`,
		log: true,
	});
	assert(command.success, `failed to queue ${game.name}`);
	const content = await waitForContent(statusFile);
	const lines = content.split("\n").filter(Boolean);
	assert(lines.length === 1, `expected one result for ${game.name}, got ${lines.length}`);
	process.stdout.write(`${lines[0]}\n`);
} finally {
	try {
		await post("/command", {code: `Content\\removeSearchPath ${JSON.stringify(root)}`, log: false});
	} catch {}
	try {
		await post("/delete", {path: root});
	} catch {}
}
