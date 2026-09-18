import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {buildAgentSessionSchema} from '../scripts/agent-session-schema.mjs';
test('generated patch schema preserves required fields, enums and optional union semantics',async()=>{
  const schema=JSON.parse(await readFile('packages/agent-contracts/dist/session-patch-schema.json','utf8'));
  assert.deepEqual(schema.$defs.AgentSessionPatch.required,['name','sessionId']);
  assert.equal(schema.$defs.AgentSessionPatch.properties.name.const,'AgentSessionPatch');
  assert.deepEqual(schema.$defs.AgentSessionMessage.properties.role.anyOf,[{const:'user'},{const:'assistant'}]);
  assert.deepEqual(schema.$defs.AgentSessionPatch.properties.pendingQuestionnaire.anyOf,[{$ref:'#/$defs/AgentQuestionnaire'},{const:false}]);
  assert.ok(schema.$defs.AgentSessionStep.required.includes('sessionId'));
});
test('unsupported upstream declarations fail instead of silently weakening validation',()=>{
  for(const text of ['export interface AgentSessionPatch {value: any}', 'export interface AgentSessionPatch extends Base {}', 'export interface AgentSessionPatch {value: Missing}', 'export interface AgentSessionPatch {call(): void}'])assert.throws(()=>buildAgentSessionSchema(text));
});
