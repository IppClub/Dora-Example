import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {inflateSync} from 'node:zlib';

const root = process.env.DORA_ENGINE_ROOT || process.cwd();
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dora-lua-codegen-'));
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/codegen-4.7.2.json', import.meta.url)));
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
try {
  const guard = path.join(temporary, 'guard'); fs.mkdirSync(guard);
  const marker = path.join(temporary, 'python-called');
  for (const name of ['python', 'python3']) {
    fs.writeFileSync(path.join(guard, name + (process.platform === 'win32' ? '.cmd' : '')),
      process.platform === 'win32' ? '@echo off\necho python>>"%DORA_PYTHON_GUARD_LOG%"\nexit /b 99\n'
        : '#!/bin/sh\nprintf "python\\n" >> "$DORA_PYTHON_GUARD_LOG"\nexit 99\n', {mode: 0o755});
  }
  const output = path.join(temporary, 'generated');
  const env = {...process.env, LC_ALL: 'C', PATH: guard + path.delimiter + process.env.PATH, DORA_PYTHON_GUARD_LOG: marker};
  function run(extra = [], environment = {}) {
    return spawnSync(process.env.DORA_XMAKE || 'xmake', ['lua', path.join(root, 'Tools/Godot/generate_xmake_sources.lua'), '--output', output, ...extra],
      {cwd: root, env: {...env, ...environment}, encoding: 'utf8', timeout: 60000});
  }
  let result = run(); assert.equal(result.status, 0, result.stdout + result.stderr);
  const state = JSON.parse(fs.readFileSync(path.join(output, '.xmake-codegen.json')));
  assert.equal(state.outputs.length, 147);
  for (const [name, expected] of Object.entries(fixture.files)) assert.equal(hash(fs.readFileSync(path.join(output, name))), expected, name);
  for (const [name, input, symbol] of [
    ['core/io/certs_compressed.gen.h', 'thirdparty/certs/ca-bundle.crt', '_certs_compressed'],
    ['core/extension/gdextension_interface_dump.gen.h', 'core/extension/gdextension_interface.json', '_gdextension_interface_data_compressed'],
  ]) {
    const header = fs.readFileSync(path.join(output, name), 'utf8');
    const bytes = header.match(new RegExp(symbol + '\\[\\] = \\{([^}]+)\\}'))[1].match(/\d+/g).map(Number);
    assert.deepEqual(inflateSync(Buffer.from(bytes)), fs.readFileSync(path.join(root, 'Source/3rdParty/Godot', input)));
  }
  // Reproduce macOS CI's locale-dependent icon ordering. Keep the same golden
  // hashes: accepting a second baseline would hide nondeterministic builds.
  if (process.platform === 'darwin') {
    fs.rmSync(output, {recursive: true});
    result = run([], {LC_ALL: 'en_US.UTF-8'});
    assert.equal(result.status, 0, result.stdout + result.stderr);
    for (const [name, expected] of Object.entries(fixture.files)) assert.equal(hash(fs.readFileSync(path.join(output, name))), expected, 'en_US.UTF-8: ' + name);
  }
  const mtimes = Object.fromEntries(state.outputs.map(name => [name, fs.statSync(path.join(output, name)).mtimeMs]));
  result = run(); assert.equal(result.status, 0, result.stdout + result.stderr); assert.match(result.stdout, /unchanged/);
  for (const [name, value] of Object.entries(mtimes)) assert.equal(fs.statSync(path.join(output, name)).mtimeMs, value);
  result = run(['--disable-module', 'unknown-fixture-module']); assert.notEqual(result.status, 0);
  if (process.platform !== 'win32') {
    const target = path.join(output, 'core/disabled_classes.gen.h'), outside = path.join(temporary, 'outside');
    fs.writeFileSync(outside, 'preserve'); fs.unlinkSync(target); fs.symlinkSync(outside, target);
    result = run(); assert.notEqual(result.status, 0); assert.equal(fs.readFileSync(outside, 'utf8'), 'preserve');
  }
  assert.equal(fs.existsSync(marker), false, 'Lua codegen invoked Python');
  console.log('PASS: 147 Lua outputs; 145 baseline hashes, two decompressed payloads, locale independence, incremental behavior, invalid modules/symlinks and Python exclusion');
} finally {fs.rmSync(temporary, {recursive: true, force: true});}
