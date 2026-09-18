import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorkspaceList } from '../packages/agent-contracts/dist/workspace-list.js';
import { createSearchHandlers, validateSearchInput } from '../packages/agent-contracts/dist/search-tools.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('original listing adds safe exclusions, preserves variants and reports truncation through executor', async () => {
  const calls = [];
  const listFiles = createWorkspaceList({
    resolveWorkspaceSearchPath: (workDir, path) => workDir === 'A' ? `/project/${path}` : undefined,
    toWorkspaceRelativePath: (_workDir, path) => path.replace(/^\/project\//, ''),
    Content: { glob: (path, globs, levels) => { calls.push({ path, globs, levels }); return ['/project/a.lua', '/project/a.ts']; } },
  });
  const handler = createSearchHandlers({ listFiles }).glob_files;
  const definition = { ...getToolDefinition('glob_files'), validateInput: value => validateSearchInput('glob_files', value), handler };
  const context = { workingDir: 'A', role: 'main', workMode: 'code', disabledAgentTools: [],
    cancellation: { isCancelled: () => false, reason: () => undefined } };
  const globs = ['**/*.ts'];
  const result = await executeAgentToolDefinition(definition, { globs, maxEntries: 1 }, context, { searchDoraDocLimitMax: 20 });
  assert.equal(result.output.success, true);
  assert.equal(result.output.truncated, true);
  assert.equal(result.output.totalEntries, 2);
  assert.deepEqual(result.output.files, ['a.lua']);
  assert.deepEqual(calls[0].globs, ['**/*.ts', '!**/.*/**', '!**/node_modules/**']);
  assert.deepEqual(calls[0].levels, {});
  assert.deepEqual(globs, ['**/*.ts']);
  listFiles({ workDir: 'A', path: '' });
  assert.deepEqual(calls[1].levels, { vs: 2, bl: 2, ts: 1, tsx: 1, tl: 1, yue: 1, xml: 1, lua: 0 });
  assert.equal(listFiles({ workDir: 'B', path: '' }).success, false);
});

test('listing backend exceptions become tool failures without fabricated empty success', () => {
  const list = createWorkspaceList({ resolveWorkspaceSearchPath: () => '/project', toWorkspaceRelativePath: (_, path) => path,
    Content: { glob() { throw new Error('invalid pattern'); } } });
  const result = list({ workDir: 'A', path: '' });
  assert.equal(result.success, false);
  assert.match(result.message, /invalid pattern/);
});
