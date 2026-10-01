import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const engine = process.env.DORA_ENGINE_ROOT;

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
