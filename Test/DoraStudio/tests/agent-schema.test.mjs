import test from 'node:test';
import assert from 'node:assert/strict';
import { buildDecisionToolSchema } from '../packages/agent-contracts/dist/index.js';
import { compileJsonSchema, validateJsonValue } from '../packages/agent-contracts/dist/json-schema.js';

test('shared native schema validator compiles every exposed Agent schema', () => {
  for (const role of ['main', 'sub']) for (const workMode of ['plan', 'code']) {
    for (const tool of buildDecisionToolSchema(role, 20, { workMode })) {
      assert.equal(compileJsonSchema(tool.function.parameters).success, true, tool.function.name);
    }
  }
  const read = buildDecisionToolSchema('main', 20).find(tool => tool.function.name === 'read_file').function.parameters;
  assert.equal(validateJsonValue(read, { reads: [{ path: 'main.ts' }] }).valid, true);
  assert.equal(validateJsonValue(read, { reads: [] }).valid, false);
  assert.equal(validateJsonValue(read, {}).valid, false);
  assert.equal(validateJsonValue(read, { path: 'main.ts', unexpected: true }).valid, false);
});

test('schema platform bindings preserve null, Unicode codepoint length and error limits', () => {
  assert.equal(validateJsonValue({ type: 'null' }, null).valid, true);
  assert.equal(validateJsonValue({ type: 'object' }, null).valid, false);
  assert.equal(validateJsonValue({ type: 'string', minLength: 2, maxLength: 2 }, '中😀').valid, true);
  assert.equal(validateJsonValue({ type: 'integer' }, 1.5).valid, false);
  assert.equal(validateJsonValue({ type: 'number' }, Infinity).valid, false);
  const cyclic = {}; cyclic.self = cyclic;
  assert.equal(validateJsonValue(true, cyclic).valid, false);
  const result = validateJsonValue({ type: 'array', items: { type: 'number' } }, ['a', 'b', 'c'], { maxErrors: 1 });
  assert.equal(result.valid, false);
  assert.equal(result.errors.length, 1);
});
