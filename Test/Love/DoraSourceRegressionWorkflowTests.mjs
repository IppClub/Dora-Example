#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {doraSSRRoot} from "./TestPaths.mjs";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const assetsRoot = path.join(doraSSRRoot, "Assets");
const scriptRoot = path.join(assetsRoot, "Script");
const warningBaseline = Object.freeze({
	"Dev/cli.lua": 7,
	"Dev/Entry.lua": 1,
	"Dev/Entry.yue": 1,
	"Lib/Agent/Skills.lua": 3,
	"Lib/Agent/Gen/BlocklyGen.lua": 9,
	"Lib/Agent/DoraAgent.lua": 119,
	"Lib/Agent/JsonSchema.lua": 15,
	"Lib/Agent/flow.lua": 19,
	"Lib/Agent/Memory.lua": 25,
	"Lib/Agent/Runtime/StepDebugLog.lua": 1,
	"Lib/Agent/Storage/Support.lua": 1,
	"Lib/Agent/Tool/Command.lua": 1,
	"Lib/Agent/Tool/Executor.lua": 1,
	"Lib/Agent/Tool/Guards.lua": 1,
	"Lib/Agent/Tool/Registry.lua": 12,
	"Lib/Agent/Tool/Validation.lua": 5,
	"Lib/Agent/Tool/Workspace.lua": 3,
	"Lib/Agent/Tools.lua": 13,
	"Lib/Agent/Utils.lua": 8,
	"Lib/DoraX.lua": 77,
	"Lib/InputManager.lua": 6,
	"Lib/lualib_bundle.lua": 66,
	"Lib/lualib/ArrayEntries.lua": 2,
	"Lib/lualib/ArrayFrom.lua": 1,
	"Lib/lualib/Await.lua": 5,
	"Lib/lualib/Class.lua": 1,
	"Lib/lualib/DescriptorGet.lua": 1,
	"Lib/lualib/DescriptorSet.lua": 1,
	"Lib/lualib/Error.lua": 4,
	"Lib/lualib/Generator.lua": 2,
	"Lib/lualib/Iterator.lua": 1,
	"Lib/lualib/Map.lua": 9,
	"Lib/lualib/NumberToString.lua": 1,
	"Lib/lualib/ParseInt.lua": 1,
	"Lib/lualib/Promise.lua": 3,
	"Lib/lualib/Set.lua": 9,
	"Lib/lualib/SetDescriptor.lua": 1,
	"Lib/lualib/SourceMapTraceBack.lua": 2,
	"Lib/lualib/StringReplace.lua": 1,
	"Lib/lualib/StringReplaceAll.lua": 1,
	"Lib/lualib/StringSplit.lua": 1,
	"Lib/lualib/Symbol.lua": 1,
	"Lib/lualib/SymbolRegistry.lua": 2,
	"Lib/lualib/Using.lua": 1,
	"Lib/lualib/UsingAsync.lua": 1,
	"Lib/luaminify.lua": 73,
	"Lib/PlatformerX.lua": 4,
	"Lib/utf-8.lua": 39,
	"Lib/Utils.lua": 1,
	"Tools/BlocklyCoder.lua": 11,
	"Tools/ResourceDownloader.lua": 5,
	"Tools/ResourceDownloader/Catalog.lua": 1,
	"Tools/TexturePacker.lua": 3,
	"Tools/TexturePacker/Packer.lua": 1,
	"Tools/YarnTester.lua": 4,
});

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function post(endpoint, body = {}) {
	const response = await fetch(`${baseUrl}${endpoint}`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify(body),
	});
	assert(response.ok, `${endpoint} returned HTTP ${response.status}`);
	return response.json();
}

function collectFiles(root, predicate) {
	const files = [];
	const visit = directory => {
		for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
			if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
			const filename = path.join(directory, entry.name);
			if (entry.isDirectory()) visit(filename);
			else if (entry.isFile() && predicate(filename)) files.push(filename);
		}
	};
	visit(root);
	return files.sort();
}

function relative(filename) {
	return path.relative(scriptRoot, filename).split(path.sep).join("/");
}

function assertWarningBaseline() {
	for (const [filename, count] of warningsByFile) {
		assert(Object.hasOwn(warningBaseline, filename),
			`source check introduced warnings in ${filename}: ${count}`);
		assert(count <= warningBaseline[filename],
			`source check warning count increased for ${filename}: ${count} > ${warningBaseline[filename]}`);
	}
	const baselineCount = Object.values(warningBaseline)
		.reduce((total, count) => total + count, 0);
	assert(warningCount <= baselineCount,
		`source check warning total increased: ${warningCount} > ${baselineCount}`);
}

async function create(filename, content = "", folder = false) {
	const result = await post("/new", {path: filename, content, folder});
	assert(result.success, `failed to create ${filename}: ${result.message ?? ""}`);
}

async function write(filename, content) {
	const result = await post("/write", {path: filename, content});
	assert(result.success, `failed to write ${filename}: ${result.message ?? ""}`);
}

async function read(filename) {
	const result = await post("/read", {path: filename});
	assert(result.success, `failed to read ${filename}: ${result.message ?? ""}`);
	return result.content;
}

async function removeIfExists(filename) {
	const result = await post("/exist", {file: filename});
	if (result.success) await post("/delete", {path: filename});
}

let warningCount = 0;
const warningFiles = new Set();
const warningsByFile = new Map();
let emptyGeneratedCount = 0;

async function check(filename) {
	const content = fs.readFileSync(filename, "utf8");
	const result = await post("/check", {file: filename, content});
	if (result.success) return;
	const diagnostics = Array.isArray(result.info) ? result.info : [];
	const nonWarnings = diagnostics.filter(diagnostic => diagnostic?.[0] !== "warning");
	assert(diagnostics.length > 0 && nonWarnings.length === 0,
		`source check failed for ${relative(filename)}: ${JSON.stringify(result.info ?? result)}`);
	warningCount += diagnostics.length;
	const source = relative(filename);
	warningFiles.add(source);
	warningsByFile.set(source, (warningsByFile.get(source) ?? 0) + diagnostics.length);
}

async function makeMirror(root, entries) {
	const directories = new Set();
	for (const {target} of entries) {
		let directory = path.posix.dirname(target);
		while (directory !== ".") {
			directories.add(directory);
			directory = path.posix.dirname(directory);
		}
	}
	await create(root, "", true);
	for (const directory of [...directories].sort((a, b) => {
		const depth = value => value.split("/").length;
		return depth(a) - depth(b) || a.localeCompare(b);
	})) await create(`${root}/${directory}`, "", true);
	for (const {source, target} of entries) {
		await write(`${root}/${target}`, fs.readFileSync(source, "utf8"));
	}
}

async function buildScript(root, filename, marker) {
	const target = `${root}/Script/${relative(filename)}`;
	const result = await post("/build", {path: target, projectRoot: root});
	assert(result.success,
		`source build failed for ${relative(filename)}: ${JSON.stringify(result)}`);
	const output = result.resultCodes ?? await read(target.replace(/\.(?:tl|yue)$/, ".lua"));
	if (output === "") {
		emptyGeneratedCount += 1;
		return;
	}
	assert(output.startsWith(`-- [${marker}]: `),
		`generated ${relative(filename)} lost its ${marker} source header`);
}

const luaFiles = collectFiles(scriptRoot, filename => filename.endsWith(".lua"));
const yueFiles = collectFiles(scriptRoot, filename => filename.endsWith(".yue"));
const tealFiles = collectFiles(scriptRoot,
	filename => filename.endsWith(".tl") && !filename.endsWith(".d.tl"));
const typeScriptFiles = collectFiles(scriptRoot,
	filename => filename.endsWith(".ts") || filename.endsWith(".tsx"));
const typeScriptSources = typeScriptFiles.filter(filename => !filename.endsWith(".d.ts"));

for (const filename of [...luaFiles, ...yueFiles, ...tealFiles]) await check(filename);

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status did not provide writablePath");
const root = `${status.writablePath}/.download/dora-source-regression`;

await removeIfExists(root);
try {
	const mirrorEntries = new Map();
	for (const source of [...luaFiles, ...typeScriptFiles, ...yueFiles, ...tealFiles]) {
		mirrorEntries.set(`Script/${relative(source)}`, {source, target: `Script/${relative(source)}`});
	}
	for (const source of luaFiles) {
		const sourceRelative = relative(source);
		if (sourceRelative.startsWith("Lib/")) {
			const target = sourceRelative.slice("Lib/".length);
			mirrorEntries.set(target, {source, target});
		}
	}
	await makeMirror(root, [...mirrorEntries.values()]);
	const tsBuild = await post("/ts/build", {path: `${root}/Script`, projectRoot: root});
	assert(tsBuild.success, `TypeScript project build request failed: ${JSON.stringify(tsBuild)}`);
	const messages = tsBuild.messages ?? [];
	assert(messages.length === typeScriptSources.length,
		`TypeScript project built ${messages.length} files, expected ${typeScriptSources.length}`);
	const failed = messages.filter(message => !message.success);
	assert(failed.length === 0, `TypeScript project build failures: ${JSON.stringify(failed)}`);
	for (const filename of typeScriptSources) {
		const output = await read(`${root}/Script/${relative(filename).replace(/\.tsx?$/, ".lua")}`);
		const marker = filename.endsWith(".tsx") ? "tsx" : "ts";
		assert(output.startsWith(`-- [${marker}]: `),
			`generated ${relative(filename)} lost its ${marker} source header`);
	}
	for (const filename of yueFiles) await buildScript(root, filename, "yue");
	for (const filename of tealFiles) await buildScript(root, filename, "tl");
	assertWarningBaseline();

	console.log(`DORA_SOURCE_REGRESSION_PASS lua=${luaFiles.length} yue=${yueFiles.length} teal=${tealFiles.length} ts=${typeScriptSources.length} warnings=${warningCount} warning-files=${warningFiles.size} empty-generated=${emptyGeneratedCount}`);
} finally {
	await removeIfExists(root);
}
