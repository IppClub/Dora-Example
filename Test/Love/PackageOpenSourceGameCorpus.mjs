#!/usr/bin/env node

import {execFile} from "node:child_process";
import {mkdir, readFile, rm, stat, writeFile} from "node:fs/promises";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const testRoot = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await readFile(join(testRoot, "OpenSourceGames.json"), "utf8"));
const corpusRoot = process.argv[2];
const packageRoot = process.argv[3];

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function run(command, args, cwd) {
	await new Promise((resolve, reject) => {
		const child = execFile(command, args, {cwd}, error => error ? reject(error) : resolve());
		child.stdout?.pipe(process.stdout);
		child.stderr?.pipe(process.stderr);
	});
}

assert(corpusRoot && packageRoot,
	"usage: node PackageOpenSourceGameCorpus.mjs CORPUS_ROOT PACKAGE_ROOT");
assert(manifest.length === 100, `expected exactly 100 games, got ${manifest.length}`);
await mkdir(packageRoot, {recursive: true});

const cases = [];
for (const [index, game] of manifest.entries()) {
	const sequence = String(index + 1).padStart(3, "0");
	const output = join(packageRoot, `${sequence}.love`);
	const gameRoot = dirname(join(corpusRoot, game.entry));
	await rm(output, {force: true});
	process.stdout.write(`[${index + 1}/100] package ${game.name}\n`);
	await run("zip", ["-q", "-r", "-6", output, ".", "-x", ".git/*", ".github/*", "*.love"], gameRoot);
	assert((await stat(output)).size > 0, `empty package for ${game.name}`);
	cases.push({index: index + 1, name: game.name, package: `${sequence}.love`});
}

await writeFile(join(packageRoot, "AndroidCases.json"), `${JSON.stringify(cases, null, "\t")}\n`);
console.log(`LOVE_OPEN_SOURCE_CORPUS_PACKAGED total=${cases.length} root=${packageRoot}`);
