import assert from 'node:assert/strict';
import { cp, mkdir, mkdtemp, rm, access, readdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const temp = await mkdtemp(join(tmpdir(), 'studio-standalone-'));
const target = join(temp, 'Studio');
try {
  await mkdir(target);
  for (const name of ['package.json', 'pnpm-workspace.yaml', 'pnpm-lock.yaml', 'packages', 'apps', 'tests']) {
    await cp(join(repo, 'Studio', name), join(target, name), {
      recursive: true,
      filter: path => !path.split('/').some(part => ['node_modules', 'dist', '.generated', 'artifacts'].includes(part)),
    });
  }
  const assets = join(temp, 'Assets/Script/Lib');
  await mkdir(join(assets, 'Dora'), { recursive: true });
  await cp(join(repo, 'Assets/Script/Lib/Dora/en'), join(assets, 'Dora/en'), { recursive: true });
  await cp(join(repo, 'Assets/Script/Lib/lualib_bundle.lua'), join(assets, 'lualib_bundle.lua'));
  await mkdir(join(temp, 'Docs/static/img/site'), { recursive: true });
  await cp(join(repo, 'Docs/static/img/site/logo.svg'), join(temp, 'Docs/static/img/site/logo.svg'));
  await assert.rejects(access(join(temp, 'Tools')), 'test fixture must not contain the old IDE');
  execFileSync('pnpm', ['install', '--offline', '--frozen-lockfile', '--ignore-scripts'], { cwd: target, stdio: 'inherit' });
  execFileSync('pnpm', ['build'], { cwd: target, stdio: 'inherit' });
  const tests=(await readdir(join(target,'tests'))).filter(name=>name.endsWith('.test.mjs')).map(name=>join(target,'tests',name));
  execFileSync(process.execPath, ['--test',...tests], { cwd: target, stdio: 'inherit' });
  console.log('PASS: standalone Studio installs and tests offline without any Tools/dora-dora directory or prebuilt shared artifacts.');
} finally { await rm(temp, { recursive: true, force: true }); }
