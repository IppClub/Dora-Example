import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const root = process.env.DORA_SSR_ROOT;
if (!root) throw new Error('Set DORA_SSR_ROOT to the Dora-SSR checkout.');
const require = createRequire(join(root, 'Tools/dora-dora/package.json'));
const { loadAgentTsModule } = await import(join(root, 'Tools/dora-dora/scripts/load-agent-ts-module.mjs'));
const ts = require('typescript');
const { build } = require('esbuild');
const { promoteCompilerWarnings } = await loadAgentTsModule(
	join(root, 'Tools/dora-dora/src/TranspileDiagnostics.ts'),
);
const temp = await mkdtemp(join(tmpdir(), 'dora-warning-errors-'));
try {
	const bundled = join(temp, 'tstl.cjs');
	await build({ entryPoints: [require.resolve('@dora-studio/tstl')], outfile: bundled,
		bundle: true, format: 'cjs', platform: 'node', logLevel: 'silent' });
	const tstl = require(bundled);
	const source = join(temp, 'warning.ts');
	await writeFile(source, 'export function fallback(value: number): number { return value || 1; }\n');
	const output = new Map();
	const result = tstl.transpileFiles([source, require.resolve('typescript/lib/lib.es5.d.ts')], {
		noLib: true, strict: true, skipLibCheck: true, target: ts.ScriptTarget.ESNext,
		module: ts.ModuleKind.CommonJS, moduleResolution: ts.ModuleResolutionKind.NodeJs,
		luaTarget: '5.4', luaLibImport: 'inline', noHeader: true, noImplicitSelf: true,
	}, (path, text) => output.set(path, text));
	assert.equal(result.emitSkipped, false);
	assert.ok([...output.keys()].some(path => path.endsWith('/warning.lua')));
	assert.equal(result.diagnostics.length, 1);
	assert.equal(result.diagnostics[0].category, ts.DiagnosticCategory.Warning);
	const promoted = promoteCompilerWarnings(result.diagnostics, ts.DiagnosticCategory);
	assert.equal(promoted[0].category, ts.DiagnosticCategory.Error);
	assert.equal(promoted[0].code, 100037);
	assert.equal(promoted[0].file, result.diagnostics[0].file);
	assert.equal(result.diagnostics[0].category, ts.DiagnosticCategory.Warning);
	const formatted = ts.formatDiagnostics(promoted, {
		getCurrentDirectory: () => temp, getCanonicalFileName: name => name, getNewLine: () => '\n',
	});
	assert.match(formatted, /error TS100037/);
	assert.doesNotMatch(formatted, /warning TS100037/);
	assert.deepEqual(promoteCompilerWarnings([], ts.DiagnosticCategory), []);
	assert.equal(promoteCompilerWarnings(promoted, ts.DiagnosticCategory)[0], promoted[0]);
	console.log('Warning-only TSTL output is reported as error TS100037; original diagnostic and source location preserved.');
} finally {
	await rm(temp, { recursive: true, force: true });
}
