import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { resolve, dirname, join } from 'node:path';
import { mkdtemp, mkdir, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const ide = resolve(repo, 'Tools/dora-dora');
const require = createRequire(resolve(ide, 'package.json'));
const ts = require('typescript');
const temp = await mkdtemp(join(tmpdir(), 'studio-ide-types-'));
try {
  // Extract a real HEAD baseline without touching the current checkout. Dependencies
  // are identical, so this isolates source migration from unrelated package upgrades.
  const archive = execFileSync('git', ['archive', 'HEAD', 'Tools/dora-dora/src', 'Tools/dora-dora/tsconfig.json'],
    { cwd: repo, maxBuffer: 150 * 1024 * 1024 });
  execFileSync('tar', ['-x', '-C', temp], { input: archive });
  const baselineIde = resolve(temp, 'Tools/dora-dora');
  await mkdir(baselineIde, { recursive: true });
  await symlink(resolve(ide, 'node_modules'), resolve(baselineIde, 'node_modules'), 'dir');
  const installedTstl = dirname(require.resolve('@dora-studio/tstl'));
  function normalize(value) {
    return value.replaceAll(temp, repo.replace(/\/$/, ''))
      .replaceAll(installedTstl, resolve(ide, 'src/3rdParty/tstl'));
  }
  function diagnostics(directory) {
    const config = ts.readConfigFile(resolve(directory, 'tsconfig.json'), ts.sys.readFile);
    if (config.error) throw new Error(ts.flattenDiagnosticMessageText(config.error.messageText, '\n'));
    const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, directory);
    // Existing 6.0 setting is incompatible with the locked TS 5.9.3. Override only
    // for the comparison; neither source configuration is changed.
    parsed.options.ignoreDeprecations = '5.0';
    const program = ts.createProgram(parsed.fileNames, parsed.options);
    return [...parsed.errors, ...ts.getPreEmitDiagnostics(program)].map(d => normalize(
      `${d.file?.fileName ?? '<config>'}:${d.code}:${ts.flattenDiagnosticMessageText(d.messageText, '\n')}`
    )).sort();
  }
  const before = diagnostics(baselineIde);
  const after = diagnostics(ide);
  const remaining = [...before];
  const added = [];
  for (const diagnostic of after) {
    const index = remaining.indexOf(diagnostic);
    if (index < 0) added.push(diagnostic); else remaining.splice(index, 1);
  }
  assert.deepEqual(added, [], 'shared package migration must not introduce IDE type diagnostics');
  console.log(`PASS: IDE type diagnostics ${before.length} baseline / ${after.length} current; no additions. This is not a clean typecheck.`);
} finally { await rm(temp, { recursive: true, force: true }); }
