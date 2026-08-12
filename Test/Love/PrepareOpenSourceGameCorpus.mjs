#!/usr/bin/env node

import {access, mkdir, readFile, rm} from "node:fs/promises";
import {dirname, join} from "node:path";
import {spawn} from "node:child_process";
import {fileURLToPath} from "node:url";

const testRoot = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await readFile(join(testRoot, "OpenSourceGames.json"), "utf8"));
const corpusRoot = process.argv[2];
const verifyOnly = process.argv.includes("--verify-only");

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function run(command, args, cwd) {
	await new Promise((resolve, reject) => {
		const child = spawn(command, args, {cwd, stdio: "inherit"});
		child.on("error", reject);
		child.on("exit", code => code === 0
			? resolve()
			: reject(new Error(`${command} ${args.join(" ")} exited with ${code}`)));
	});
}

async function exists(path) {
	try {
		await access(path);
		return true;
	} catch {
		return false;
	}
}

assert(corpusRoot, "usage: node PrepareOpenSourceGameCorpus.mjs CORPUS_ROOT [--verify-only]");
assert(manifest.length === 100, `expected exactly 100 games, got ${manifest.length}`);
await mkdir(corpusRoot, {recursive: true});

for (const [index, game] of manifest.entries()) {
	const checkoutName = game.entry.split("/")[0];
	const checkout = join(corpusRoot, checkoutName);
	const entry = join(corpusRoot, game.entry);
	process.stdout.write(`[${index + 1}/100] ${game.repository}@${game.commit}\n`);
	if (!await exists(join(checkout, ".git"))) {
		assert(!verifyOnly, `missing checkout ${checkout}`);
		await rm(checkout, {recursive: true, force: true});
		await run("git", ["init", checkout]);
		await run("git", ["-C", checkout, "remote", "add", "origin", `https://github.com/${game.repository}.git`]);
	}
	if (!verifyOnly) {
		await run("git", ["-C", checkout, "fetch", "--depth", "1", "origin", game.commit]);
		await run("git", ["-C", checkout, "checkout", "--detach", "--force", game.commit]);
		await run("git", ["-C", checkout, "clean", "-ffd"]);
	}
	const head = await new Promise((resolve, reject) => {
		let output = "";
		const child = spawn("git", ["-C", checkout, "rev-parse", "HEAD"], {stdio: ["ignore", "pipe", "inherit"]});
		child.stdout.on("data", chunk => output += chunk);
		child.on("error", reject);
		child.on("exit", code => code === 0 ? resolve(output.trim()) : reject(new Error(`failed to read HEAD for ${game.repository}`)));
	});
	assert(head === game.commit, `${game.repository} resolved to ${head}, expected ${game.commit}`);
	assert(await exists(entry), `${game.repository} is missing ${game.entry}`);
}

console.log(`LOVE_OPEN_SOURCE_CORPUS_PREPARED total=${manifest.length} root=${corpusRoot}`);
