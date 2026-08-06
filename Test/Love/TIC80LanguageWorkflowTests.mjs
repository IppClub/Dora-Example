#!/usr/bin/env node

import process from "node:process";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");

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

async function create(path, content, folder = false) {
	const result = await post("/new", {path, content, folder});
	assert(result.success, `failed to create ${path}: ${result.message ?? ""}`);
}

async function read(path) {
	const result = await post("/read", {path});
	assert(result.success, `failed to read ${path}`);
	return result.content;
}

function hasSuggestion(result, name) {
	return result.success && result.suggestions?.some(([candidate]) => candidate === name);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status did not provide writablePath");
const root = `${status.writablePath}/.download/love-tic80-regression`;
const files = {
	lua: `${root}/game-lua.lua`,
	tl: `${root}/game-teal.tl`,
	yue: `${root}/game-yue.yue`,
	ts: `${root}/game-ts.ts`,
};

const luaCode = `-- tic80
TIC = function()
	cls(0)
	spr(1, 0, 0)
end
`;
const tealCode = `-- tic80
TIC = function()
	cls(0)
	spr(1, 0, 0)
end
`;
const yueCode = `-- tic80
TIC = ->
	cls 0
	spr 1, 0, 0
`;
const tsCode = `import {cls, print, _G} from "tic80";

const labels = ["TIC", "80"].map(value => value.toLowerCase());
_G.TIC = () => {
	cls(0);
	print(labels.join("-"), 96, 64, 15);
};
`;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	await create(files.lua, luaCode);
	await create(files.tl, tealCode);
	await create(files.yue, yueCode);
	await create(files.ts, tsCode);

	for (const [lang, file, content] of [
		["lua", files.lua, luaCode],
		["tl", files.tl, tealCode],
		["yue", files.yue, yueCode],
	]) {
		const checked = await post("/check", {file, content});
		assert(checked.success, `${lang} TIC-80 check failed: ${JSON.stringify(checked.info ?? [])}`);
		const completed = await post("/complete", {
			lang,
			file,
			content: "-- tic80\nspr",
			line: "spr",
			row: 2,
		});
		assert(hasSuggestion(completed, "spr"), `${lang} TIC-80 completion lost spr`);
	}

	for (const [lang, file] of [["tl", files.tl], ["yue", files.yue]]) {
		const built = await post("/build", {path: file, projectRoot: root});
		assert(built.success, `${lang} TIC-80 build failed: ${built.message ?? ""}`);
		const lua = await read(file.replace(/\.(tl|yue)$/, ".lua"));
		const lines = lua.split(/\r?\n/);
		assert(lines[0].trim() === "-- tic80", `${lang} build displaced the first-line TIC-80 marker`);
		assert(lines[1].startsWith(`-- [${lang}]: `), `${lang} build lost its source header`);
		assert(!lua.includes('require("tic80")'), `${lang} build leaked the editor-only TIC-80 require`);
		assert(!lua.includes('require("love")'), `${lang} TIC-80 output was affected by Love module handling`);
	}

	const tsBuild = await post("/ts/build", {path: files.ts, projectRoot: root});
	assert(tsBuild.success && tsBuild.messages?.length === 1 && tsBuild.messages[0].success,
		`TypeScript TIC-80 build failed: ${JSON.stringify(tsBuild)}`);
	const tsLua = await read(`${root}/game-ts.lua`);
	assert(tsLua.startsWith(`-- [ts]: ${files.ts}\n`), "TypeScript TIC-80 build lost its source header");
	assert(!tsLua.includes('require("tic80")'), "TypeScript TIC-80 import was not rewritten to _G");
	assert(!tsLua.includes('require("lualib_bundle")'), "TypeScript TIC-80 helpers were not inlined");
	assert(tsLua.includes("__TS__ArrayMap"), "TypeScript TIC-80 Array.map helper was not emitted");
	assert(tsLua.includes("_G.TIC"), "TypeScript TIC-80 callback was not assigned through _G");
	assert(!tsLua.includes('require("love")'), "TypeScript TIC-80 output was affected by Love module handling");

	console.log("PASS: TIC-80 first-line markers, Lua/Teal/Yue definitions, TypeScript import rewrite, and inline helpers");
} finally {
	await post("/delete", {path: root});
}
