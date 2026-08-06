import fs from "node:fs";
import path from "node:path";
import {doraSSRRoot, testRoot} from "./TestPaths.mjs";

function read(relativePath) {
	const filename = path.join(doraSSRRoot, relativePath);
	if (!fs.existsSync(filename)) {
		throw new Error(`missing required license artifact: ${relativePath}`);
	}
	return fs.readFileSync(filename, "utf8");
}

function requireText(relativePath, needles) {
	const content = read(relativePath);
	for (const needle of needles) {
		if (!content.includes(needle)) {
			throw new Error(`${relativePath} is missing required notice: ${needle}`);
		}
	}
}

requireText("Source/3rdParty/Love/DORA_SOURCE.md", [
	"Tag: `11.5`",
	"6eb8d546736d5915a8b5af30b2cf33456dfdcb1a",
	"The complete upstream licensing notice is retained in `license.txt`.",
]);
requireText("Source/3rdParty/Love/license.txt", [
	"Copyright (c) 2006-2023 LOVE Development Team",
	"Copyright (C) 2011-2015, Yann Collet",
	"zlib license",
	"2-Clause BSD",
]);
requireText("LICENSES.3rdparty.md", [
	"[LOVE](https://github.com/love2d/love)",
	"Source/3rdParty/Love/license.txt",
	"[libogg](https://gitlab.xiph.org/xiph/ogg)",
	"Source/3rdParty/ogg/COPYING",
	"[libtheora](https://gitlab.xiph.org/xiph/theora)",
	"Source/3rdParty/theora/COPYING",
]);
requireText("Source/3rdParty/ogg/COPYING", [
	"Copyright (c) 2002, Xiph.org Foundation",
	"Redistribution and use in source and binary forms",
]);
requireText("Source/3rdParty/theora/COPYING", [
	"Copyright (C) 2002-2009 Xiph.org Foundation",
	"Redistribution and use in source and binary forms",
]);
requireText("NOTICE.txt", [
	"libogg: 3-clause BSD License",
	"libtheora: 3-clause BSD License",
]);
requireText("Assets/LICENSES", [
	"LOVE: zlib License",
	"Copyright (c) 2006-2023 LOVE Development Team",
	"LZ4 (bundled by LOVE): BSD-2-Clause License",
	"Copyright (C) 2011-2017, Yann Collet",
	"libogg and aoTuV/libvorbis: BSD-3-Clause License",
	"libtheora: BSD-3-Clause License",
]);
requireText("Source/Love/LoveDataAlgorithms.cpp", [
	"3rdParty/Love/src/modules/data/HashFunction.cpp",
]);
requireText("Source/Love/LoveLZ4.c", [
	"3rdParty/Love/src/libraries/lz4/lz4.c",
]);
requireText("Source/Love/LoveLZ4HC.c", [
	"3rdParty/Love/src/libraries/lz4/lz4hc.c",
]);
requireText("Assets/Shader/Love/varying.def.sc", [
	"v_color0 : COLOR0",
	"a_position : POSITION",
]);

function auditSamples(relativeDirectory) {
	const openSourceRoot = path.join(testRoot, "Fixtures", relativeDirectory);
	const sampleDirectories = fs.readdirSync(openSourceRoot, {withFileTypes: true})
		.filter((entry) => entry.isDirectory())
		.map((entry) => entry.name)
		.sort();
	if (sampleDirectories.length === 0) {
		throw new Error(`${relativeDirectory} compatibility fixtures have no licensed samples`);
	}
	for (const sample of sampleDirectories) {
		const relativeRoot = `Fixtures/${relativeDirectory}/${sample}`;
		const upstream = fs.readFileSync(path.join(testRoot, relativeRoot, "UPSTREAM.md"), "utf8");
		for (const needle of ["repository:", "commit:", "license:"])
			if (!upstream.includes(needle)) throw new Error(`${relativeRoot}/UPSTREAM.md is missing ${needle}`);
		const licensePath = path.join(testRoot, relativeRoot, "LICENSE");
		if (!fs.existsSync(licensePath) || fs.statSync(licensePath).size === 0) {
			throw new Error(`${relativeRoot} must retain a non-empty upstream LICENSE`);
		}
	}
	return sampleDirectories.length;
}

const runtimeSamples = auditSamples("OpenSource");
const languageSamples = auditSamples("OpenSourceLanguage");

for (const project of [
	"Projects/macOS/Dora.xcodeproj/project.pbxproj",
	"Projects/iOS/Dora.xcodeproj/project.pbxproj",
]) {
	requireText(project, ["LICENSES in Resources", "Shader in Resources"]);
}

console.log(`LOVE_LICENSE_AUDIT_PASS ${runtimeSamples} runtime sample(s), ${languageSamples} language sample(s)`);
