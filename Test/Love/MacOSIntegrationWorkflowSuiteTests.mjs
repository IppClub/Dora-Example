#!/usr/bin/env node

import {spawn} from "node:child_process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const testsRoot = fileURLToPath(new URL(".", import.meta.url));
const workflows = [
	"LoveDeclarationsTests.mjs",
	"LoveLanguageServiceTests.mjs",
	"TIC80LanguageWorkflowTests.mjs",
	"VisualEvidenceWorkflowTests.mjs",
	"OpenSourceLanguageProjectTests.mjs",
	"LoveHotReloadWorkflowTests.mjs",
	"DoraRegressionWorkflowTests.mjs",
	"DoraSourceRegressionWorkflowTests.mjs",
	"VideoNodeWorkflowTests.mjs",
	"ArrayImageLayerWorkflowTests.mjs",
	"AudioWorkflowTests.mjs",
	"CanvasReadbackWorkflowTests.mjs",
	"ColorMaskWorkflowTests.mjs",
	"CompressedImageWorkflowTests.mjs",
	"EventRestartWorkflowTests.mjs",
	"AsyncLifecycleWorkflowTests.mjs",
	"ThreadWorkflowTests.mjs",
	"FilesystemWorkflowTests.mjs",
	"FontImageRasterizerWorkflowTests.mjs",
	"GraphicsStateWorkflowTests.mjs",
	"GraphicsStatsWorkflowTests.mjs",
	"ImageDataWorkflowTests.mjs",
	"ImageFontWorkflowTests.mjs",
	"JoystickWorkflowTests.mjs",
	"KeyboardWorkflowTests.mjs",
	"LineStyleWorkflowTests.mjs",
	"LuaCompatibilityWorkflowTests.mjs",
	"MouseSettingsWorkflowTests.mjs",
	"PhysicsWorkflowTests.mjs",
	"ShaderCustomAttributeWorkflowTests.mjs",
	"ShaderNon2DTextureWorkflowTests.mjs",
	"ShaderDiagnosticsWorkflowTests.mjs",
	"ShaderInterpolationWorkflowTests.mjs",
	"SpriteBatchWorkflowTests.mjs",
	"WindowUpdateModeWorkflowTests.mjs",
	"WireframeWorkflowTests.mjs",
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

function runWorkflow(filename) {
	return new Promise((resolve, reject) => {
		const environment = {...process.env};
		for (const name of [
			"http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy",
		]) delete environment[name];
		const child = spawn(process.execPath, [`${testsRoot}/${filename}`, baseUrl], {
			cwd: testsRoot,
			env: environment,
			stdio: "inherit",
		});
		child.once("error", reject);
		child.once("exit", (code, signal) => {
			if (code === 0) resolve();
			else reject(new Error(`${filename} failed with ${signal ?? `exit ${code}`}`));
		});
	});
}

const status = await post("/status");
assert(status.success && status.platform === "macOS",
	`macOS integration workflow suite requires macOS Dora, got ${status.platform ?? "unknown"}`);
assert(status.wsConnectionCount === 1,
	`macOS integration workflow suite requires exactly one Web IDE compiler, got ${status.wsConnectionCount}`);
console.log("LOVE_MACOS_INTEGRATION_PREREQUISITES web-ide=awake DORA_VIRTUAL_CONTROLLER=1");

for (const [index, workflow] of workflows.entries()) {
	console.log(`LOVE_MACOS_INTEGRATION_STEP ${index + 1}/${workflows.length} ${workflow}`);
	await runWorkflow(workflow);
}

console.log(`LOVE_MACOS_INTEGRATION_WORKFLOW_SUITE_PASS workflows=${workflows.length} platform=macOS`);
