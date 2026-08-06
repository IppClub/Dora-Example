#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/CompressedImageScene", import.meta.url));

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

async function waitForContent(path, expected, timeoutMs = 30000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `unexpected compressed image status: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for compressed image status at ${path}`);
}

const status = await post("/status");
assert(status.success && status.writablePath, "Dora status is incomplete");
const workflowKey = `__loveCompressedImage_${crypto.randomUUID().replaceAll("-", "")}`;
const root = `${status.writablePath}/.download/love-compressed-image-${workflowKey}`;
const statusFile = `${root}/runtime-status.txt`;
const layeredStatus = ["macOS", "iOS"].includes(status.platform)
	? "layered-metal-reject"
	: "layered-nonmetal-pass";
const readbackStatus = "pixels";
const astcStatus = status.platform === "macOS" ? "all14-pass" : "capability";
const etc2Status = status.platform === "macOS"
	? "ktx+pvr-rgb+rgba-pass+rgba1-emulation-reject"
	: "capability";
const pvrtcStatus = ["macOS", "Linux"].includes(status.platform)
	? "ktx+pvr-rgb4+rgba4-pass+2bpp-reject"
	: "capability";
const eacStatus = ["macOS", "iOS", "Android", "Linux"].includes(status.platform) ? "ktx+pvr-all4-pass" : "capability";
const expected = `formats=DDS-DXT1+DXT3+DXT5+KTX-DXT1+ASTC4x4+PVR-DXT1+KTX-ETC1+PVR-ETC1+KTX-ETC2rgb+ETC2rgba+ETC2rgba1+PVR-ETC2rgb+ETC2rgba+ETC2rgba1+KTX/PVR-PVRTC1-rgb2+rgb4+rgba2+rgba4+KTX-ASTC5x4+5x5+6x5+6x6+8x5+8x6+8x8+10x5+10x6+10x8+10x10+12x10+12x12+KTX/PVR-EACr+EACrs+EACrg+EACrgs width=4 height=4 bytes=24+48+48+24+48+24+24+24+24+48+24+24+48+24+4x192+4x128+4x48+9x64+4x24+4x48 astc-gpu=${astcStatus} etc2-gpu=${etc2Status} pvrtc-gpu=${pvrtcStatus} eac-gpu=${eacStatus} gpu=pass mipmaps=3 ${layeredStatus}=pass auto-mips=pass non2d-mip=pass cube-volume-replace=pass readback=${readbackStatus}`;
let initialized = false;
await post("/delete", {path: root});
try {
	const created = await post("/new", {path: root, content: "", folder: true});
	assert(created.success, `failed to create workflow directory: ${created.message ?? ""}`);
	for (const filename of ["host.lua", "main.lua"]) {
		const staged = await post("/new", {
			path: `${root}/${filename}`,
			content: readFileSync(`${fixtureRoot}/${filename}`, "utf8"),
			folder: false,
		});
		assert(staged.success, `failed to stage ${filename} through Dora Content: ${staged.message ?? ""}`);
	}
	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue compressed-image workflow: ${command.message ?? ""}`);
	initialized = true;
	await waitForContent(statusFile, expected);
	console.log(`LOVE_COMPRESSED_IMAGE_WORKFLOW_PASS platform=${status.platform} formats=DDS-DXT1+DXT3+DXT5+KTX-DXT1+ASTC4x4+PVR-DXT1+KTX-ETC1+PVR-ETC1+KTX-ETC2rgb+ETC2rgba+ETC2rgba1+PVR-ETC2rgb+ETC2rgba+ETC2rgba1+KTX/PVR-PVRTC1-rgb2+rgb4+rgba2+rgba4+KTX-ASTC5x4+5x5+6x5+6x6+8x5+8x6+8x8+10x5+10x6+10x8+10x10+12x10+12x12+KTX/PVR-EACr+EACrs+EACrg+EACrgs size=4x4 bytes=24+48+48+24+48+24+24+24+24+48+24+24+48+24+4x192+4x128+4x48+9x64+4x24+4x48 astc-gpu=${astcStatus} etc2-gpu=${etc2Status} pvrtc-gpu=${pvrtcStatus} eac-gpu=${eacStatus} gpu=pass mipmaps=3 ${layeredStatus}=pass auto-mips=pass non2d-mip=pass cube-volume-replace=pass readback=${readbackStatus}`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
