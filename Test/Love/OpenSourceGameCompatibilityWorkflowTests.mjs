#!/usr/bin/env node

import {access, readFile} from "node:fs/promises";
import {join} from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const corpusRoot = process.argv[3] ?? process.env.DORA_LOVE_CORPUS_ROOT;
const selectedNames = process.argv[4]
	? new Set(process.argv[4].split(",").map(name => name.trim()).filter(Boolean))
	: null;
const testRoot = fileURLToPath(new URL(".", import.meta.url));
const fixtureRoot = join(testRoot, "Fixtures/OpenSourceGameCorpusScene");
const manifest = JSON.parse(await readFile(join(testRoot, "OpenSourceGames.json"), "utf8"));

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

async function waitForContent(path, timeoutMs) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) return result.content;
		await new Promise(resolve => setTimeout(resolve, 100));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for corpus status at ${path}`);
}

assert(corpusRoot, "pass the corpus root as argv[3] or DORA_LOVE_CORPUS_ROOT");
assert(manifest.length === 100, `expected exactly 100 games, got ${manifest.length}`);
const cases = [];
for (const game of manifest) {
	assert(/^[0-9a-f]{40}$/.test(game.commit), `${game.name} does not pin a full commit`);
	assert(game.license, `${game.name} does not declare a license`);
	const path = join(corpusRoot, game.entry);
	await access(path);
	if (selectedNames && !selectedNames.has(game.name)) continue;
	cases.push({name: game.name, path});
}
assert(cases.length > 0, "the requested corpus selection is empty");
if (selectedNames)
	assert(cases.length === selectedNames.size, "one or more requested game names are absent from the manifest");

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
assert(status.wsConnectionCount >= 1,
	`open-source corpus workflow requires a connected Web IDE compiler, got ${status.wsConnectionCount}`);
const root = `${status.writablePath}/.download/love-open-source-game-corpus`;
const statusFile = `${root}/runtime-status.tsv`;
await post("/delete", {path: root});
const created = await post("/new", {path: root, content: "", folder: true});
assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);

try {
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nopenSourceGameCorpusWorkflow = require "host"\nopenSourceGameCorpusWorkflow.run ${JSON.stringify(JSON.stringify(cases))}, ${JSON.stringify(statusFile)}, 120`,
		log: true,
	});
	assert(command.success, `failed to queue corpus workflow: ${command.message ?? ""}`);
	// Shader-heavy games can spend tens of seconds compiling their first frame
	// on Debug builds. Scale the deadline with the selected corpus instead of
	// making the full 20-game run race a fixed three-minute timeout.
	const content = await waitForContent(statusFile, 60000 + cases.length * 30000);
	const results = content.split("\n").filter(Boolean).map(line => {
		const [name, result, error = ""] = line.split("\t");
		return {name, result, error};
	});
	assert(results.length === cases.length,
		`expected ${cases.length} corpus results, got ${results.length}`);
	for (const result of results)
		console.log(`LOVE_GAME_RESULT ${result.result} ${result.name}${result.error ? ` :: ${result.error}` : ""}`);
	const passed = results.filter(result => result.result === "pass").length;
	console.log(`LOVE_OPEN_SOURCE_GAME_CORPUS_RESULT passed=${passed} failed=${results.length - passed} total=${results.length}`);
	if (passed !== results.length) process.exitCode = 1;
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
}
