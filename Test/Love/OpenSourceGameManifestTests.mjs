#!/usr/bin/env node

import {access, readFile} from "node:fs/promises";
import {dirname, isAbsolute, join, normalize, sep} from "node:path";
import {fileURLToPath} from "node:url";

const testRoot = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await readFile(join(testRoot, "OpenSourceGames.json"), "utf8"));
const corpusRoot = process.argv[2];
const supportedLicenses = new Set(["AGPL-3.0", "Apache-2.0", "GPL-3.0", "MIT", "MPL-2.0"]);

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

function assertUnique(values, label) {
	const seen = new Set();
	for (const value of values) {
		assert(!seen.has(value), `duplicate ${label}: ${value}`);
		seen.add(value);
	}
}

assert(Array.isArray(manifest), "open-source game manifest must be an array");
assert(manifest.length === 100, `expected exactly 100 games, got ${manifest.length}`);
for (const [index, game] of manifest.entries()) {
	const label = `game ${index + 1}`;
	assert(typeof game.name === "string" && game.name.length > 0, `${label} has no name`);
	assert(/^[^/\s]+\/[^/\s]+$/.test(game.repository), `${label} has invalid repository ${game.repository}`);
	assert(/^[0-9a-f]{40}$/.test(game.commit), `${label} does not pin a full commit`);
	assert(supportedLicenses.has(game.license), `${label} has unsupported SPDX license ${game.license}`);
	assert(typeof game.entry === "string" && game.entry.endsWith("main.lua"), `${label} has invalid entry`);
	assert(!isAbsolute(game.entry) && !normalize(game.entry).split(sep).includes(".."), `${label} entry escapes its corpus root`);
}
assertUnique(manifest.map(game => game.name), "name");
assertUnique(manifest.map(game => game.repository.toLowerCase()), "repository");
assertUnique(manifest.map(game => game.entry.split("/")[0]), "checkout directory");

if (corpusRoot) {
	for (const game of manifest) await access(join(corpusRoot, game.entry));
}

console.log(`LOVE_OPEN_SOURCE_MANIFEST_PASS total=${manifest.length}${corpusRoot ? " entries=verified" : ""}`);
