#!/usr/bin/env node

import {mkdtemp, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/LegacyZipFilenameScene", import.meta.url));

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

function crc32(data) {
	let crc = 0xffffffff;
	for (const byte of data) {
		crc ^= byte;
		for (let bit = 0; bit < 8; bit++) {
			crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
		}
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function makeStoredZip(entries) {
	const localRecords = [];
	const centralRecords = [];
	let offset = 0;
	for (const entry of entries) {
		const checksum = crc32(entry.data);
		const local = Buffer.alloc(30);
		local.writeUInt32LE(0x04034b50, 0);
		local.writeUInt16LE(20, 4);
		local.writeUInt16LE(0, 6); // Deliberately leave the UTF-8 filename flag unset.
		local.writeUInt16LE(0, 8);
		local.writeUInt32LE(checksum, 14);
		local.writeUInt32LE(entry.data.length, 18);
		local.writeUInt32LE(entry.data.length, 22);
		local.writeUInt16LE(entry.name.length, 26);
		localRecords.push(local, entry.name, entry.data);

		const central = Buffer.alloc(46);
		central.writeUInt32LE(0x02014b50, 0);
		central.writeUInt16LE(20, 4);
		central.writeUInt16LE(20, 6);
		central.writeUInt16LE(0, 8);
		central.writeUInt16LE(0, 10);
		central.writeUInt32LE(checksum, 16);
		central.writeUInt32LE(entry.data.length, 20);
		central.writeUInt32LE(entry.data.length, 24);
		central.writeUInt16LE(entry.name.length, 28);
		central.writeUInt32LE(offset, 42);
		centralRecords.push(central, entry.name);
		offset += local.length + entry.name.length + entry.data.length;
	}
	const centralSize = centralRecords.reduce((size, part) => size + part.length, 0);
	const end = Buffer.alloc(22);
	end.writeUInt32LE(0x06054b50, 0);
	end.writeUInt16LE(entries.length, 8);
	end.writeUInt16LE(entries.length, 10);
	end.writeUInt32LE(centralSize, 12);
	end.writeUInt32LE(offset, 16);
	return Buffer.concat([...localRecords, ...centralRecords, end]);
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

async function waitForContent(path, expected, timeoutMs = 20000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected legacy filename status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for legacy filename status at ${path}`);
}

const temporaryRoot = await mkdtemp(join(tmpdir(), "dora-love-non-utf8-"));
const packagePath = join(temporaryRoot, "non-utf8-filename.love");
const mainLua = Buffer.from([
	'function love.load()\n',
	'  love.event.quit()\n',
	'end\n',
].join(""));
const archive = makeStoredZip([
	{name: Buffer.from("main.lua"), data: mainLua},
	{name: Buffer.from("cbabbcfdcdb7b2e2cad42e6c7561", "hex"), data: Buffer.from('return "legacy-gbk-ok"\n')},
]);
await writeFile(packagePath, archive);

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
assert(status.wsConnectionCount === 1,
	`legacy filename workflow requires exactly one Web IDE compiler, got ${status.wsConnectionCount}`);
const root = `${status.writablePath}/.download/love-legacy-zip-filename`;
const statusFile = `${root}/runtime-status.txt`;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(fixtureRoot)}\npackage.loaded.host = nil\nlegacyZipFilenameWorkflow = require "host"\nlegacyZipFilenameWorkflow.run ${JSON.stringify(packagePath)}, ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue legacy filename workflow: ${command.message ?? ""}`);
	await waitForContent(statusFile, "non-utf8-tolerance=pass");
	console.log("LOVE_LEGACY_ZIP_FILENAME_WORKFLOW_PASS non-utf8-tolerance=pass");
} finally {
	await post("/command", {
		code: `Content\\removeSearchPath ${JSON.stringify(fixtureRoot)}`,
		log: false,
	});
	await post("/delete", {path: root});
	await rm(temporaryRoot, {recursive: true, force: true});
}
