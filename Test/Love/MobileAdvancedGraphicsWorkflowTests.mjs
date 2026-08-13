#!/usr/bin/env node

import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflowKey = `__loveMobileGraphics_${crypto.randomUUID().replaceAll("-", "")}`;
const files = [
	["host.lua", "Fixtures/MobileAdvancedGraphicsScene/host.lua"],
	["ShaderMRT/conf.lua", "Fixtures/ShaderMRTScene/conf.lua"],
	["ShaderMRT/main.lua", "Fixtures/ShaderMRTScene/main.lua"],
	["ShaderMRT/mrt.frag", "Fixtures/ShaderMRTScene/mrt.frag"],
	["ShaderGLSL3/main.lua", "Fixtures/ShaderGLSL3Scene/main.lua"],
	["ShaderInterpolation/main.lua", "Fixtures/ShaderInterpolationScene/main.lua"],
	["ShaderCustomAttribute/main.lua", "Fixtures/ShaderCustomAttributeScene/main.lua"],
	["MeshDepth/conf.lua", "Fixtures/MeshDepthScene/conf.lua"],
	["MeshDepth/main.lua", "Fixtures/MeshDepthScene/main.lua"],
	["MeshDepth/tint.frag", "Fixtures/MeshDepthScene/tint.frag"],
	["CanvasReadback/conf.lua", "Fixtures/CanvasReadbackScene/conf.lua"],
	["CanvasReadback/main.lua", "Fixtures/CanvasReadbackScene/main.lua"],
	["CompressedImage/main.lua", "Fixtures/CompressedImageScene/main.lua"],
	["SpriteBatch/main.lua", "Fixtures/SpriteBatchScene/main.lua"],
	["ParticleSystem/main.lua", "Fixtures/ParticleSystemScene/main.lua"],
	["TextBatch/conf.lua", "Fixtures/TextBatchScene/conf.lua"],
	["TextBatch/main.lua", "Fixtures/TextBatchScene/main.lua"],
	["ImageFont/conf.lua", "Fixtures/ImageFontScene/conf.lua"],
	["ImageFont/main.lua", "Fixtures/ImageFontScene/main.lua"],
	["ArrayImageLayer/conf.lua", "Fixtures/ArrayImageLayerScene/conf.lua"],
	["ArrayImageLayer/main.lua", "Fixtures/ArrayImageLayerScene/main.lua"],
	["WindowSettings/conf.lua", "Fixtures/WindowSettingsScene/conf.lua"],
	["WindowSettings/main.lua", "Fixtures/WindowSettingsScene/main.lua"],
];
const binaryFiles = [
	["SpriteBatch", "atlas.png", "Fixtures/SpriteBatchScene/atlas.png"],
	["ParticleSystem", "atlas.png", "Fixtures/ParticleSystemScene/atlas.png"],
];

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

async function create(path, content = "", folder = false) {
	const result = await post("/new", {path, content, folder});
	assert(result.success, `failed to stage ${path} through Dora Content: ${result.message ?? ""}`);
	if (!folder) {
		const deadline = Date.now() + 10000;
		do {
			const staged = await post("/read", {path});
			if (staged.success && staged.content === content) return;
			await new Promise(resolve => setTimeout(resolve, 25));
		} while (Date.now() < deadline);
		throw new Error(`timed out waiting for staged text file ${path}`);
	}
}

async function upload(directory, filename, source) {
	const form = new FormData();
	form.append("file", new Blob([readFileSync(`${testsRoot}/${source}`)]), filename);
	const response = await fetch(`${baseUrl}/upload?path=${encodeURIComponent(directory)}`, {
		method: "POST",
		body: form,
	});
	assert(response.ok, `failed to upload ${directory}/${filename} through Dora Content: HTTP ${response.status}`);
}

async function waitForContent(path, timeoutMs = 600000) {
	const deadline = Date.now() + timeoutMs;
	do {
		const result = await post("/read", {path});
		if (result.success) {
			assert(result.content === expected, `advanced graphics workflow failed: ${result.content}`);
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 25));
	} while (Date.now() < deadline);
	throw new Error(`timed out waiting for advanced graphics status at ${path}`);
}

const status = await post("/status");
assert(status.success && ["macOS", "iOS", "Android", "Linux", "Windows"].includes(status.platform) && status.writablePath,
	`advanced graphics workflow requires macOS, iOS, Android, Linux, or Windows Dora, got ${status.platform ?? "unknown"}`);
const platform = status.platform.toLowerCase();
const renderer = ["macOS", "iOS"].includes(status.platform)
	? "metal"
	: status.platform === "Windows" ? "direct3d" : "opengles";
const expected = `platform=${platform} renderer=${renderer} shaders=glsl3-interpolation-layout-matrix mrt=2 depth=pass mesh=pass msaa=4 formats=pass compressed=dxt1-layered-capability batch=sprite-array-particle text=retained-imagefont array=maintex-layers window=virtual-queries pixels=pass scenes=13 content=pass`;
const root = `${status.writablePath}/.download/love-mobile-advanced-graphics-${workflowKey}`;
const statusFile = `${root}/runtime-status.txt`;
let initialized = false;

await post("/delete", {path: root});
try {
	await create(root, "", true);
	for (const folder of ["ShaderMRT", "ShaderGLSL3", "ShaderInterpolation", "ShaderCustomAttribute", "MeshDepth", "CanvasReadback", "CompressedImage",
		"SpriteBatch", "ParticleSystem", "TextBatch", "ImageFont", "ArrayImageLayer", "WindowSettings"]) {
		await create(`${root}/${folder}`, "", true);
	}
	for (const [target, source] of files) {
		await create(`${root}/${target}`, readFileSync(`${testsRoot}/${source}`, "utf8"));
	}
	for (const [folder, filename, source] of binaryFiles) {
		await upload(`${root}/${folder}`, filename, source);
	}

	const command = await post("/command", {
		code: `Content\\insertSearchPath 1, ${JSON.stringify(root)}\npackage.loaded.host = nil\nrawset _G, ${JSON.stringify(workflowKey)}, require "host"\n(rawget _G, ${JSON.stringify(workflowKey)}).run ${JSON.stringify(statusFile)}`,
		log: true,
	});
	assert(command.success, `failed to queue advanced graphics workflow: ${command.message ?? ""}`);
	initialized = true;
	console.log(`LOVE_MOBILE_ADVANCED_GRAPHICS_QUEUED platform=${status.platform} scenes=13`);
	await waitForContent(statusFile);
	console.log(`LOVE_MOBILE_ADVANCED_GRAPHICS_PASS platform=${status.platform} renderer=${renderer} shaders=GLSL3+interpolation+layout+matrix mrt=2 depth=pass mesh=pass msaa=4 formats=pass compressed=DXT1+DXT3+DXT5+layered-capability batch=SpriteBatch+ArrayImage+attachedAttribute+ParticleSystem text=Text+ImageFont array=MainTex+layers window=virtual-queries scenes=13`);
} finally {
	if (initialized) {
		await post("/command", {
			code: `rawset _G, ${JSON.stringify(workflowKey)}, nil\nContent\\removeSearchPath ${JSON.stringify(root)}`,
			log: false,
		});
	}
	await post("/delete", {path: root});
}
