#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/DoraRegressionWorkflow", import.meta.url));

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

async function waitForContent(path, expected, timeoutMs = 5000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected,
				`unexpected Dora runtime status: ${result.content}`);
			return result.content;
		}
		await new Promise((resolve) => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for Dora runtime status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath && status.assetPath, "Dora status is incomplete");
assert(status.wsConnectionCount === 1,
	`Dora regression requires exactly one Web IDE compiler, got ${status.wsConnectionCount}`);

const root = `${status.writablePath}/.download/love-dora-regression`;
const files = {
	lua: `${root}/ordinary-lua.lua`,
	tl: `${root}/ordinary-teal.tl`,
	yue: `${root}/ordinary-yue.yue`,
	ts: `${root}/ordinary-ts.ts`,
	tsx: `${root}/ordinary-tsx.tsx`,
};
const statusFile = `${root}/runtime-status.txt`;

const luaCode = `local Dora = require("Dora")
local node = Dora.Node()
assert(node ~= nil)
`;
const tealCode = `local node = Dora.Node()
assert(node ~= nil)
`;
const yueCode = `node = Dora.Node!
assert node
`;
const tsCode = `import {DrawNode, Node, Vec2} from "Dora";

const root = Node();
const draw = DrawNode();
draw.drawDot(Vec2(4, 8), 2);
root.addChild(draw);
export default root;
`;
const tsxCode = `import {Node} from "Dora";

export const createOrdinaryNode = () => Node();
`;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	for (const [file, content] of [
		[files.lua, luaCode],
		[files.tl, tealCode],
		[files.yue, yueCode],
		[files.ts, tsCode],
		[files.tsx, tsxCode],
	]) {
		await create(file, content);
	}

	for (const [lang, file, content] of [
		["lua", files.lua, luaCode],
		["tl", files.tl, tealCode],
		["yue", files.yue, yueCode],
	]) {
		const checked = await post("/check", {file, content});
		assert(checked.success, `${lang} ordinary Dora check failed: ${JSON.stringify(checked.info ?? [])}`);
	}

	for (const [lang, file] of [["tl", files.tl], ["yue", files.yue]]) {
		const built = await post("/build", {path: file, projectRoot: root});
		assert(built.success, `${lang} ordinary Dora build failed: ${built.message ?? ""}`);
		const output = await read(file.replace(/\.(tl|yue)$/, ".lua"));
		assert(output.includes("Dora.Node"), `${lang} ordinary Dora build lost its global API call`);
		assert(!output.includes('require("love")'), `${lang} ordinary Dora build was polluted by Love`);
	}

	for (const file of [files.ts, files.tsx]) {
		const built = await post("/ts/build", {path: file, projectRoot: root});
		assert(built.success && built.messages?.length === 1 && built.messages[0].success,
			`${file} ordinary Dora build failed: ${JSON.stringify(built)}`);
		const output = await read(file.replace(/\.tsx?$/, ".lua"));
		assert(output.includes('require("Dora")'), `${file} output lost its standard Dora import`);
		assert(!output.includes('require("love")'), `${file} output was polluted by Love`);
	}

	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\ndoraRegression = require "host"\ndoraRegression.run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue Dora runtime regression: ${command.message ?? ""}`);
	await waitForContent(statusFile, "2d=1 3d=1 tic80=1 nvg=1 imgui=1 love=1");

	console.log("DORA_EXISTING_FEATURE_REGRESSION_PASS scripts=5 runtime=2d,3d,tic80,nvg,imgui,love");
} finally {
	await post("/delete", {path: root});
}
