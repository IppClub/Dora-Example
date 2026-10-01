import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const engine = process.env.DORA_ENGINE_ROOT;

// The UI workflow runs on Linux; its pnpm spawn contract is POSIX-specific.
test('Studio runner builds trusted host before mirroring a clean checkout', {skip: process.platform === 'win32'}, () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dora-studio-entrypoint-'));
  try {
    const root = path.join(temporary, 'engine');
    const suite = path.join(temporary, 'suite');
    const bin = path.join(temporary, 'bin');
    for (const directory of [path.join(root, 'Studio/apps/web/src'), path.join(suite, 'tests'), bin]) {
      fs.mkdirSync(directory, {recursive: true});
    }
    fs.writeFileSync(path.join(root, 'Studio/package.json'), '{}');
    fs.writeFileSync(path.join(root, 'Studio/apps/web/src/App.tsx'), '');
    fs.copyFileSync(path.join(process.env.DORA_TEST_REPO, 'Test/DoraStudio/run.mjs'), path.join(suite, 'run.mjs'));
    fs.writeFileSync(path.join(suite, 'backend-contract.json'), '{}');
    fs.writeFileSync(path.join(bin, 'pnpm'), `#!/usr/bin/env node
const fs=require('node:fs');
const args=process.argv.slice(2);
if(args.join(' ')==='-r build')fs.writeFileSync('workspace-built','yes');
else if(args.join(' ')==='build:agent-host'){
  if(!fs.existsSync('workspace-built'))throw Error('Workspace must build first');
  fs.mkdirSync('dist/agent-host',{recursive:true});
  fs.writeFileSync('dist/agent-host/manifest.json','{}');
}else throw Error('Unexpected build command');
`);
    fs.chmodSync(path.join(bin, 'pnpm'), 0o755);
    fs.writeFileSync(path.join(suite, 'tests/artifact.test.mjs'), `
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
test('artifact is visible through the test mirror',()=>{
  assert.deepEqual(JSON.parse(fs.readFileSync(new URL('../dist/agent-host/manifest.json',import.meta.url))),{});
});
`);
    const env = {...process.env, DORA_SSR_ROOT: root, PATH: bin + path.delimiter + process.env.PATH};
    // This fixture launches its own test runner, not an outer worker.
    delete env.NODE_TEST_CONTEXT;
    const result = spawnSync(process.execPath, [path.join(suite, 'run.mjs')], {
      encoding: 'utf8', timeout: 30000,
      env,
    });
    assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
    assert.match(result.stdout, /artifact is visible through the test mirror/);
  } finally {
    fs.rmSync(temporary, {recursive: true, force: true});
  }
});

test('canonical tutorial generator prepares bilingual docs in a clean checkout', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dora-studio-docs-'));
  try {
    const script = path.join(temporary, 'Docs/scripts/generate-language-docs.js');
    fs.mkdirSync(path.dirname(script), {recursive: true});
    fs.copyFileSync(path.join(engine, 'Docs/scripts/generate-language-docs.js'), script);
    for (const directory of ['docs/tutorial', 'i18n/zh-Hans/docusaurus-plugin-content-docs/current/tutorial']) {
      const source = path.join(temporary, 'Docs', directory);
      fs.mkdirSync(source, {recursive: true});
      fs.writeFileSync(path.join(source, '001.ci-fixture.md'), '# CI fixture\n\n```lua\nprint("hello")\n```\n');
    }
    assert.equal(fs.existsSync(path.join(temporary, 'Assets/Doc')), false);
    const result = spawnSync(process.execPath, [script], {encoding: 'utf8', timeout: 30000});
    assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
    for (const language of ['en', 'zh-Hans']) {
      const tutorial = path.join(temporary, 'Assets/Doc', language, 'Tutorial/lua/ci-fixture.md');
      assert.match(fs.readFileSync(tutorial, 'utf8'), /print\("hello"\)/);
    }
  } finally {
    fs.rmSync(temporary, {recursive: true, force: true});
  }
});

test('nested package and CI commands put the xmake task before project options', () => {
  for (const name of ['Tools/dora-dora/package.json', 'Docs/package.json', '.github/workflows/ui.yml']) {
    const source = fs.readFileSync(path.join(engine, name), 'utf8');
    assert.doesNotMatch(source, /xmake\s+-P\s+\S+\s+dora-/, name);
    assert.match(source, /xmake\s+dora-[\w-]+\s+-P\s+/, name);
  }
});

test('test listing from a nested directory needs no engine configuration or toolchain install', () => {
  const config = fs.mkdtempSync(path.join(os.tmpdir(), 'dora-test-entrypoint-'));
  try {
    const result = spawnSync(process.env.DORA_XMAKE || 'xmake', ['dora-test', '-P', '../..', '--list'], {
      cwd: path.join(engine, 'Tools/dora-dora'), encoding: 'utf8', timeout: 30000,
      env: {...process.env, XMAKE_CONFIGDIR: config},
    });
    assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
    assert.match(result.stdout, /check_touch_input_sources/);
    assert.doesNotMatch(result.stdout + result.stderr, /checking for platform|must be installed|wayland-scanner/);
  } finally {
    fs.rmSync(config, {recursive: true, force: true});
  }
});
