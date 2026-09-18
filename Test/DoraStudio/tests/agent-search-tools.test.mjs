import test from 'node:test';
import assert from 'node:assert/strict';
import { validateSearchInput, createSearchHandlers } from '../packages/agent-contracts/dist/search-tools.js';

test('original search semantics retain required pattern, pagination and document kinds', () => {
  assert.equal(validateSearchInput('grep_files', { pattern: '  ' }).success, false);
  const input = { pattern: ' foo ', offset: -1, limit: 2.9 };
  assert.deepEqual(validateSearchInput('grep_files', input).value, { pattern: 'foo', offset: 0, limit: 2 });
  assert.equal(input.pattern, ' foo ');
  assert.equal(validateSearchInput('search_dora_doc', { pattern: 'Node', docType: 'unknown' }).success, false);
  assert.equal(validateSearchInput('search_dora_doc', { pattern: 'Node' }).value.docType, 'dora-api');
  assert.equal(validateSearchInput('glob_files', { maxEntries: -5 }).value.maxEntries, 1);
});

test('original search handlers retain language, source variants and workflow updates', async () => {
  const calls = [];
  const reply = { success: true };
  const handlers = createSearchHandlers({
    searchFiles: async request => { calls.push(request); return reply; },
    listFiles: request => { calls.push(request); return reply; },
    searchDoraDoc: async request => { calls.push(request); return reply; },
  });
  const context = { workingDir: 'A', useChineseResponse: true, workflow: {} };
  assert.equal((await handlers.grep_files(context, { pattern: 'Node', groupByFile: true })).output, reply);
  await handlers.glob_files(context, {});
  await handlers.search_dora_doc(context, { pattern: 'Node' });
  assert.equal(calls[0].docLanguage, 'zh');
  assert.equal(calls[0].includeContent, true);
  assert.equal(calls[0].groupByFile, true);
  assert.equal(calls[1].preferSourceVariants, false);
  assert.equal(calls[2].programmingLanguage, 'ts');
  assert.equal(calls[2].caseSensitive, false);
  assert.equal(context.workflow.apiSearchesSinceBuild, 1);
});
