import assert from 'node:assert/strict';
import { cp, mkdir, mkdtemp, rm, access } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const temp = await mkdtemp(join(tmpdir(), 'studio-native-install-'));
const ide = join(temp, 'Tools/dora-dora');
try {
  await mkdir(ide, { recursive: true });
  for (const name of ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'patches', 'scripts', 'src', 'public', 'config',
    'index.html', 'compiler.html', 'vite.config.ts', 'tsconfig.json']) {
    await cp(join(repo, 'Tools/dora-dora', name), join(ide, name), { recursive: true });
  }
  for (const name of ['compiler', 'tstl']) {
    await cp(join(repo, 'Studio/packages', name), join(temp, 'Studio/packages', name), {
      recursive: true, filter: path => !path.split('/').some(part => part === 'node_modules' || part === 'dist'),
    });
  }
  await assert.rejects(access(join(temp, 'Studio/node_modules')));
  execFileSync('pnpm', ['install', '--offline', '--frozen-lockfile', '--ignore-scripts'], { cwd: ide, stdio: 'inherit' });
  execFileSync(process.execPath, ['scripts/copy-typescript.js'], { cwd: ide, stdio: 'inherit' });
  execFileSync(process.execPath, ['scripts/build-studio-compiler.cjs'], { cwd: ide, stdio: 'inherit' });
  execFileSync(process.execPath, ['scripts/test-tstl-truthiness.mjs'], { cwd: ide, stdio: 'inherit' });
  execFileSync(process.execPath, ['node_modules/vite/bin/vite.js', 'build'], { cwd: ide, stdio: 'inherit' });
  console.log('PASS: native IDE installs and builds without a Studio workspace install or prebuilt shared artifacts.');
} finally { await rm(temp, { recursive: true, force: true }); }
