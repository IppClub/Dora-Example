import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

test('current Go backend passes real HTTP, SQLite, quota, model, queue and static-host contracts with race detection', () => {
  const engine = process.env.DORA_SSR_ROOT;
  assert.ok(engine, 'DORA_SSR_ROOT is required');
  const contract = JSON.parse(fs.readFileSync(new URL('../backend-contract.json', import.meta.url), 'utf8'));
  const result = spawnSync(process.env.DORA_GO || 'go', ['test', '-race', '-count=1', '-json', './...'],
    {cwd:path.join(engine,'Studio'), encoding:'utf8', maxBuffer:16*1024*1024, timeout:180000});
  assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
  const events = result.stdout.trim().split('\n').map(line => JSON.parse(line));
  const passed = new Set(events.filter(e => e.Action === 'pass' && e.Test).map(e => e.Test));
  for (const name of contract.requiredGoTests) assert.ok(passed.has(name), `Go contract did not execute: ${name}`);
  assert.ok(contract.requiredGoTests.length >= 15, 'backend coverage registry must not be empty');
  console.log(`Go backend: ${passed.size} contracts passed with race detection.`);
});
