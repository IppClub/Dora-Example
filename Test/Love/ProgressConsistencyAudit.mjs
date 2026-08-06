#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {doraSSRRoot} from "./TestPaths.mjs";

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

const runtimeTests = readFileSync(new URL("LoveRuntimeTests.cpp", import.meta.url), "utf8");
const progress = readFileSync(path.join(doraSSRRoot, "Docs/design/love2d-integration-progress.md"), "utf8");
const design = readFileSync(path.join(doraSSRRoot, "Docs/design/love2d-integration.md"), "utf8");
const parityPath = new URL("LoveApiParityTests.mjs", import.meta.url);
const parityOutput = execFileSync(process.execPath, [fileURLToPath(parityPath)], {encoding: "utf8"}).trim();

const modules = new Map();
for (const match of runtimeTests.matchAll(
	/official_modules\.([a-z]+)\.passed == (\d+) and official_modules\.\1\.failed == (\d+) and official_modules\.\1\.skipped == (\d+)/g)) {
	modules.set(match[1], {
		passed: Number(match[2]),
		failed: Number(match[3]),
		skipped: Number(match[4]),
	});
}
assert(modules.size === 15,
	`expected 15 official module assertions in LoveRuntimeTests.cpp, found ${modules.size}`);

const totals = [...modules.values()].reduce((result, value) => ({
	passed: result.passed + value.passed,
	failed: result.failed + value.failed,
	skipped: result.skipped + value.skipped,
}), {passed: 0, failed: 0, skipped: 0});
for (const [field, sourceName] of [
	["passed", "official_passed"],
	["failed", "#official_failed"],
	["skipped", "#official_skipped"],
]) {
	const match = runtimeTests.match(new RegExp(`assert\\(${sourceName} == (\\d+)(?:[,\\)])`));
	assert(match, `missing ${sourceName} total assertion in LoveRuntimeTests.cpp`);
	assert(Number(match[1]) === totals[field],
		`${sourceName} assertion ${match[1]} does not match module sum ${totals[field]}`);
}

const parity = parityOutput.match(
	/\((\d+) Graphics \+ (\d+) core method checks\).*\((\d+) method checks\)/);
assert(parity, `could not parse LoveApiParityTests.mjs output: ${parityOutput}`);
const graphicsMethods = Number(parity[1]);
const coreMethods = Number(parity[2]);
const declarationMethods = Number(parity[3]);

function row(firstColumn) {
	const prefix = `| ${firstColumn} |`;
	const result = progress.split(/\r?\n/).find(line => line.startsWith(prefix));
	assert(result, `progress tracker row ${firstColumn} was not found`);
	return result;
}

function requireText(line, text, label) {
	assert(line.includes(text), `${label} must contain current value: ${text}`);
}

function requireCounts(line, counts, label) {
	const expression = new RegExp(
		`${counts.passed} pass/${counts.failed} fail/${counts.skipped}(?: [^;|。]*)? skip`);
	assert(expression.test(line),
		`${label} must contain current counts: ${counts.passed}/${counts.failed}/${counts.skipped}`);
}

const totalText = `${totals.passed} pass/${totals.failed} fail/${totals.skipped} skip`;
requireText(row("P6"), totalText, "P6 summary");
requireText(row("P6-17"), totalText, "P6-17 official test task");

for (const phase of ["P0", "P1", "P2", "P3", "P4", "P5"]) {
	const phaseRow = row(phase);
	requireText(phaseRow, "已完成", `${phase} phase status`);
	requireText(phaseRow, "100%", `${phase} phase completion`);
}
for (const task of ["P3-06", "P3-09", "P4-19", "P4-20", "P5-17", "P5-37"]) {
	requireText(row(task), "已完成", `${task} implementation/device-gate separation`);
}
requireText(row("P6"), "进行中", "P6 release certification status");
requireText(row("P6-24"), "进行中", "P6-24 physical-device certification status");

for (const [name, counts] of modules) {
	const moduleRow = row(`\`love.${name}\``);
	requireCounts(moduleRow, counts, `love.${name} support matrix row`);
}

const p329 = row("P3-29");
requireText(p329, `${graphicsMethods}`, "P3-29 Graphics wrapper audit");
requireText(p329, `${coreMethods}`, "P3-29 core wrapper audit");
requireText(p329, `${declarationMethods}`, "P3-29 declaration audit");

const p536 = row("P5-36");
requireText(p536, `${graphicsMethods}`, "P5-36 Graphics wrapper audit");
requireText(p536, `${declarationMethods}`, "P5-36 declaration audit");
const p535 = row("P5-35");
requireText(p535, `${graphicsMethods}`, "P5-35 Graphics wrapper audit");
requireText(p535, `${declarationMethods}`, "P5-35 declaration audit");

const audio = modules.get("audio");
requireText(row("P4-19"),
	`${audio.passed}/${audio.failed}/${audio.skipped}`,
	"P4-19 Audio official result");

const platformMarkers = ["macOS", "Windows", "Linux", "iOS Simulator", "Android"];
for (const [text, label] of [
	[row("P5-16"), "P5-16 Thread progress"],
	[row("P5-15"), "P5-15 Video progress"],
	[design.match(/P5-16 已从可行性结论进入实现[^\n]+/)?.[0] ?? "", "Thread integration design"],
	[design.match(/固定 VideoNode workflow 已在[^\n]+/)?.[0] ?? "", "VideoNode integration design"],
]) {
	for (const platform of platformMarkers) {
		assert(text.includes(platform), `${label} must retain ${platform} runtime evidence`);
	}
}
for (const stale of [
	"Windows 的实际 native-thread 运行仍是阶段验收余项",
	"Windows renderer 的运行矩阵仍待补齐",
	"非 macOS 平台 backend 仍需逐项补齐",
	"跨平台 backend 待补",
	"下一步补齐 Windows Direct3D/Vulkan",
	"Windows renderer 验证归 P6-24",
	"下一步加入 Windows renderer",
	"下一步扩展 Windows renderer",
	"Direct3D 非二维 sampler array",
	"完整十一 Joint 的 Windows 场景仍",
	"后续补 Windows 十一 Joint",
	"完成 Windows 宿主与 Linux",
]) {
	assert(!design.includes(stale) && !progress.includes(stale),
		`design/progress still contains stale completed-platform claim: ${stale}`);
}

const p537 = row("P5-37");
requireText(p537, "Windows Direct3D", "P5-37 renderer matrix");
requireText(p537, "能力查询、创建/拒绝与 Canvas 像素读回", "P5-37 Direct3D evidence");
requireText(p537, "Vulkan 当前不是 Dora Linux 可选择 renderer", "P5-37 current Dora renderer boundary");

const p624 = row("P6-24");
requireText(p624, "十三场景高级图形", "P6-24 Direct3D advanced graphics evidence");
requireText(p624, "非二维 sampler", "P6-24 Direct3D non-2D sampler evidence");
requireText(p624, "明确拒绝 Noop", "P6-24 interactive renderer evidence");
requireText(p624, "十一 Joint PhysicsScene", "P6-24 Windows full Physics evidence");
requireText(p624, "双 LoveNode", "P6-24 Windows multi-runtime evidence");
requireText(p624, "剪贴板/供电/URL policy", "P6-24 Windows system evidence");

const p513 = row("P5-13");
requireText(p513, "Windows Direct3D", "P5-13 Windows renderer evidence");
requireText(p513, "11 Joint", "P5-13 Windows full Joint evidence");
const p517 = row("P5-17");
requireText(p517, "Windows 交互桌面", "P5-17 Windows system evidence");
requireText(p517, "剪贴板保存→写入→读回→恢复", "P5-17 Windows clipboard evidence");

const windowsPlatform = row("Windows");
requireText(windowsPlatform, "双 LoveNode", "Windows platform multi-runtime evidence");
requireText(windowsPlatform, "完整十一 Joint PhysicsScene", "Windows platform Physics evidence");

console.log(`LOVE_PROGRESS_CONSISTENCY_AUDIT_PASS official=${totals.passed}/${totals.failed}/${totals.skipped} modules=${modules.size} wrappers=${graphicsMethods}+${coreMethods} declarations=${declarationMethods}`);
