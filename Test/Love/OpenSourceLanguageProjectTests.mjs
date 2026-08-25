#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/OpenSourceLanguage", import.meta.url));

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

async function create(filename, content = "", folder = false) {
	const result = await post("/new", {path: filename, content, folder});
	assert(result.success, `failed to create ${filename}: ${result.message ?? ""}`);
}

async function read(filename) {
	const result = await post("/read", {path: filename});
	assert(result.success, `failed to read ${filename}`);
	return result.content;
}

function fixture(relativePath) {
	return fs.readFileSync(path.join(fixtureRoot, relativePath), "utf8");
}

async function makeDirectories(root, directories) {
	await create(root, "", true);
	for (const directory of directories) await create(`${root}/${directory}`, "", true);
}

async function writeFixture(root, target, source) {
	await create(`${root}/${target}`, fixture(source));
}

async function checkSource(filename) {
	const content = await read(filename);
	const result = await post("/check", {file: filename, content});
	assert(result.success,
		`source check failed for ${filename}: ${JSON.stringify(result.info ?? result)}`);
}

async function buildSource(root, filename) {
	const result = await post("/build", {path: filename, projectRoot: root});
	assert(result.success, `source build failed for ${filename}: ${JSON.stringify(result)}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status did not provide writablePath");
const root = `${status.writablePath}/.download/love-open-source-language-workflow`;

await post("/delete", {path: root});
try {
	const tsRoot = `${root}/typescript`;
	await makeDirectories(tsRoot, ["src", "res"]);
	const upstreamMain = fixture("LoveTypeScriptTemplate/upstream/src/main.ts");
	const upstreamConf = fixture("LoveTypeScriptTemplate/upstream/src/conf.ts");
	const portMain = fixture("LoveTypeScriptTemplate/dora-port/src/main.ts");
	const portConf = fixture("LoveTypeScriptTemplate/dora-port/src/conf.ts");
	assert(portMain === `import "love";\n${upstreamMain}`,
		"TypeScript main port contains changes beyond explicit Love import");
	assert(portConf === `import "love";\n${upstreamConf}`,
		"TypeScript conf port contains changes beyond explicit Love import");
	await create(`${tsRoot}/src/main.ts`, portMain);
	await create(`${tsRoot}/src/conf.ts`, portConf);
	await writeFixture(tsRoot, "res/index.txt",
		"LoveTypeScriptTemplate/upstream/res/index.txt");
	const tsBuild = await post("/ts/build", {path: tsRoot, projectRoot: tsRoot});
	assert(tsBuild.success && tsBuild.messages?.length === 2 &&
		tsBuild.messages.every(({success}) => success),
		`TypeScript project build failed: ${JSON.stringify(tsBuild)}`);
	for (const filename of ["src/main.lua", "src/conf.lua"]) {
		const lua = await read(`${tsRoot}/${filename}`);
		assert(lua.startsWith(`-- [ts]: ${path.basename(filename).replace(/\.lua$/, ".ts")}\n`),
			`TypeScript output lost source header: ${filename}: ${JSON.stringify(lua.slice(0, 160))}`);
		assert(lua.includes('require("love")'),
			`TypeScript output lost standard Love module import: ${filename}`);
	}

	const tealRoot = `${root}/teal`;
	await makeDirectories(tealRoot, ["src", "src/game"]);
	await create(`${tealRoot}/init.lua`, "return {}\n");
	await writeFixture(tealRoot, "src/game/card.d.tl",
		"OSSUnoCardModule/upstream/src/game/card.d.tl");
	await writeFixture(tealRoot, "src/game/card.tl",
		"OSSUnoCardModule/upstream/src/game/card.tl");
	const tealEntry = `${tealRoot}/src/game/card.tl`;
	await checkSource(tealEntry);
	await buildSource(tealRoot, tealEntry);
	const tealLua = await read(`${tealRoot}/src/game/card.lua`);
	assert(tealLua.startsWith("-- [tl]: src/game/card.tl\n"), "Teal output lost source header");
	assert(tealLua.includes('require("love")'), "Teal output lost standard Love module require");
	assert(tealLua.includes('require("src.game.card")'), "Teal output lost project module require");

	const yueRoot = `${root}/yue`;
	await makeDirectories(yueRoot, ["src", "src/util"]);
	await create(`${yueRoot}/init.lua`, "return {}\n");
	for (const filename of ["Math.yue", "Vector2.yue"]) {
		await writeFixture(yueRoot, `src/util/${filename}`,
			`Tsuki/upstream/src/util/${filename}`);
	}
	for (const filename of ["Main.yue", "Game.yue", "Player.yue"]) {
		const upstream = fixture(`Tsuki/upstream/src/${filename}`);
		const port = fixture(`Tsuki/dora-port/src/${filename}`);
		assert(!upstream.includes('require "love"') && port.startsWith('love = require "love"\n'),
			`Yue ${filename} does not preserve the explicit port boundary`);
		await create(`${yueRoot}/src/${filename}`, port);
	}
	const yueFiles = [
		"src/util/Math.yue",
		"src/util/Vector2.yue",
		"src/Player.yue",
		"src/Game.yue",
		"src/Main.yue",
	];
	for (const relative of yueFiles) {
		const filename = `${yueRoot}/${relative}`;
		await checkSource(filename);
		await buildSource(yueRoot, filename);
		const lua = await read(filename.replace(/\.yue$/, ".lua"));
		assert(lua.startsWith(`-- [yue]: ${relative}\n`),
			`Yue output lost project-relative source header: ${relative}`);
		if (!relative.startsWith("src/util/")) {
			assert(lua.includes('require("love")'),
				`Yue output lost standard Love module require: ${relative}`);
		}
	}

	console.log("LOVE_OPEN_SOURCE_LANGUAGE_PASS ts=2 teal=1 yue=5");
} finally {
	await post("/delete", {path: root});
}
