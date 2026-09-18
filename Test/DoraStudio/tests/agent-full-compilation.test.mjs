import test from 'node:test';
import assert from 'node:assert/strict';
import {compileAgentCommand} from './helpers/compile-agent-command.mjs';
import {readFile} from 'node:fs/promises';
test('all original Agent TypeScript sources compile with real engine declarations',async()=>{
  const files=await compileAgentCommand({fullAgent:true});
  assert.ok(files.some(file=>file.path==='Agent/Session.lua'));
  assert.ok(files.some(file=>file.path==='Agent/DoraAgent.lua'));
});
test('native Agent generated files retain IDE source line annotations',async()=>{
  const files=await compileAgentCommand({fullAgent:true,lineComments:true});
  for(const path of ['Agent/Session.lua','Agent/Runtime/TaskAdmission.lua']) {
    const generated=files.find(file=>file.path===path).text;
    assert.match(generated,/^-- \[ts\]:/);
    assert.match(generated,/ -- \d+/);
    assert.equal(await readFile('../Assets/Script/Lib/'+path,'utf8'),generated);
  }
});
