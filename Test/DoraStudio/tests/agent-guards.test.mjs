import test from 'node:test';
import assert from 'node:assert/strict';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { runAgentToolGuards, getAgentFileEditPlanGuardDenial } from '../packages/agent-contracts/dist/guards.js';

test('original guard chain retains roles, modes, disabled tools and protected paths', () => {
  const check = (name, input, patch = {}) => runAgentToolGuards({ definition: getToolDefinition(name), input,
    context: { role: 'main', workMode: 'code', disabledAgentTools: [], ...patch } });
  assert.equal(check('spawn_sub_agent', {}, { role: 'sub' }).code, 'TOOL_ROLE_DENIED');
  assert.equal(check('ask_user', {}).code, 'TOOL_MODE_DENIED');
  assert.equal(check('read_file', {}, { disabledAgentTools: ['read_file'] }).code, 'TOOL_DISABLED');
  assert.equal(check('edit_file', { path: 'main.ts' }, { workMode: 'plan' }).code, 'PLAN_PATH_DENIED');
  assert.equal(check('edit_file', { path: ' ./\\.agent\\plan\\PLAN.md ' }, { workMode: 'plan' })?.code, 'PLAN_PATH_DENIED');
  assert.equal(check('edit_file', { path: './.agent/plan/PLAN.md' }, { workMode: 'plan' }), undefined);
  assert.equal(check('delete_file', { target_file: '.agent/plan/PLAN.md' }).code, 'PROTECTED_AGENT_DOCUMENT');
  assert.equal(check('delete_file', { target_file: '.agent/main/memory.md' }).code, 'PROTECTED_AGENT_MEMORY');
  assert.equal(check('read_file', { path: 'main.ts' }), undefined);
  // Batch edits are checked individually by the handler, not denied as a whole here.
  assert.equal(check('edit_file', { edits: [{ path: 'main.ts' }] }, { workMode: 'plan' }), undefined);
  assert.equal(getAgentFileEditPlanGuardDenial({ workMode: 'plan' }, { index: 1, path: 'main.ts' }).code, 'PLAN_PATH_DENIED');
});
