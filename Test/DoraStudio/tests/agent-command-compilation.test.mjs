import test from 'node:test';
import assert from 'node:assert/strict';
import {compileAgentCommand} from './helpers/compile-agent-command.mjs';
test('original Agent command TypeScript emits its cleanup lifecycle through shared TSTL',async()=>{
  const files=await compileAgentCommand();
  assert.ok(files.some(file=>file.path==='Agent/Tool/Command.lua'));
  assert.ok(files.every(file=>!file.path.startsWith('../')));
});
