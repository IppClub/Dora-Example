import test from 'node:test';
import assert from 'node:assert/strict';
import { getAgentFileEditInputs } from '../packages/agent-contracts/dist/file-edits.js';
import { validateJsonValue } from '../packages/agent-contracts/dist/json-schema.js';
import { buildDecisionToolSchema } from '../packages/agent-contracts/dist/index.js';

test('native edit parsing preserves batch order and shared/per-item paths after schema validation', () => {
  const schema = buildDecisionToolSchema('main', 20).find(tool => tool.function.name === 'edit_file').function.parameters;
  const input = { path: ' main.ts ', edits: [
    { old_str: 'a', new_str: 'b' },
    { path: ' other.ts ', old_str: '', new_str: 'new' },
    { path: ' ', old_str: 'b', new_str: 'c' }
  ] };
  const before = structuredClone(input);
  assert.equal(validateJsonValue(schema, input).valid, true);
  assert.deepEqual(getAgentFileEditInputs(input), [
    { index: 0, path: 'main.ts', oldStr: 'a', newStr: 'b' },
    { index: 1, path: 'other.ts', oldStr: '', newStr: 'new' },
    { index: 2, path: 'main.ts', oldStr: 'b', newStr: 'c' }
  ]);
  assert.deepEqual(input, before);
  assert.deepEqual(getAgentFileEditInputs({ path: ' init.lua ', old_str: '', new_str: 'print(1)' }),
    [{ index: 0, path: 'init.lua', oldStr: '', newStr: 'print(1)' }]);
  assert.equal(validateJsonValue(schema, { edits: [null] }).valid, false);
});
