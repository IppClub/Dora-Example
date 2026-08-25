import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
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

function requireSha256(relativePath, expected) {
	const filename = path.join(doraSSRRoot, relativePath);
	if (!fs.existsSync(filename)) {
		throw new Error(`missing required upstream source: ${relativePath}`);
	}
	const actual = crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex");
	if (actual !== expected) {
		throw new Error(`${relativePath} differs from the pinned upstream source: ${actual}`);
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
	"[libopenmpt](https://lib.openmpt.org/libopenmpt/)",
	"Source/3rdParty/libopenmpt/LICENSE",
]);
requireText("Source/3rdParty/ogg/COPYING", [
	"Copyright (c) 2002, Xiph.org Foundation",
	"Redistribution and use in source and binary forms",
]);
requireText("Source/3rdParty/theora/COPYING", [
	"Copyright (C) 2002-2009 Xiph.org Foundation",
	"Redistribution and use in source and binary forms",
]);
requireText("Source/3rdParty/libopenmpt/README.dora.md", [
	"libopenmpt 0.4.11",
	"a5c90100dcbb95cfee1ebe90bb5a74f9ce562e3c4da848386c2001ef567ecba6",
	"<stdexcept>",
	"current MSVC",
	"canonical `miniz.h`",
]);
requireText("Source/3rdParty/libopenmpt/LICENSE", [
	"Copyright (c) 2004-2019, OpenMPT contributors",
	"Copyright (c) 1997-2003, Olivier Lapicque",
	"Redistribution and use in source and binary forms",
]);
requireText("Source/3rdParty/soloud/README.dora.md", [
	"RELEASE_20200207",
	"c8e339fdce5c7107bdb3e64bbf707c8fd3449beb",
	"engine-side `AudioFile` wrapper",
]);
requireSha256("Source/3rdParty/soloud/audiosource/openmpt/soloud_openmpt.cpp",
	"6e9bae78a3b3c7715d625159357e40d4237b19d19962bcac89428dbfeab6fe2d");
requireSha256("Source/3rdParty/libopenmpt/libopenmpt/libopenmpt_impl.cpp",
	"83d7be464643d11b79b965b2ec3b68faf273f47696ed922b3c1459e6e7c71e7f");
requireSha256("Source/3rdParty/Zip/miniz.c",
	"0fcdc9888cb3a29ca8f176bac087e5fe6c7258a6ab06b1c271c1e109a11d3740");
requireText("Source/3rdParty/Zip/README-miniz.dora.md", [
	"single canonical miniz source copy",
	"final Dora application target compiles `miniz.c` exactly once",
	"libopenmpt",
	"TinyEXR",
]);
requireText("NOTICE.txt", [
	"libogg: 3-clause BSD License",
	"libtheora: 3-clause BSD License",
	"libopenmpt: BSD 3-Clause License",
]);
requireText("Assets/LICENSES", [
	"LOVE: zlib License",
	"Copyright (c) 2006-2023 LOVE Development Team",
	"LZ4 (bundled by LOVE): BSD-2-Clause License",
	"Copyright (C) 2011-2017, Yann Collet",
	"libogg and aoTuV/libvorbis: BSD-3-Clause License",
	"libtheora: BSD-3-Clause License",
	"libopenmpt: BSD 3-Clause License",
]);
requireText("Source/3rdParty/Love/xmake.lua", [
	"src/modules/data/HashFunction.cpp",
	"src/libraries/lz4/lz4.c",
	"src/libraries/lz4/lz4hc.c",
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
