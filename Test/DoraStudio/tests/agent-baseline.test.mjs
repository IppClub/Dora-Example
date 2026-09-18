import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import ts from 'typescript';
import { loadAgentContracts, loadAgentRegistry } from '../scripts/agent-contracts.mjs';

test('built Agent contracts match source schemas for every role and mode', async () => {
  const built = await import('../packages/agent-contracts/dist/index.js');
  const upstream = await loadAgentRegistry();
  for (const role of ['main', 'sub']) for (const workMode of ['code', 'plan']) {
    const options = { workMode, disabledAgentTools: ['fetch_url'] };
    assert.deepEqual(built.buildDecisionToolSchema(role, 7, options), upstream.buildDecisionToolSchema(role, 7, options));
  }
});

// This is a migration drift gate, not proof that Studio implements these tools.
const registry = new URL('../../Assets/Script/Lib/Agent/Tool/Registry.ts', import.meta.url);
const source = ts.createSourceFile(registry.pathname, await readFile(registry, 'utf8'), ts.ScriptTarget.Latest, true);
let definitions;
function visit(node) {
  if (ts.isVariableDeclaration(node) && node.name.getText(source) === 'AGENT_TOOL_DEFINITION_SOURCES') definitions = node.initializer;
  ts.forEachChild(node, visit);
}
visit(source);
test('Agent migration baseline includes every upstream registered tool, not parameter names', () => {
  assert.ok(definitions && ts.isArrayLiteralExpression(definitions));
  const names = definitions.elements.map(element => {
    assert.ok(ts.isObjectLiteralExpression(element));
    const name = element.properties.find(property => property.name?.getText(source) === 'name');
    assert.ok(name && ts.isPropertyAssignment(name) && ts.isStringLiteral(name.initializer));
    return name.initializer.text;
  });
  assert.deepEqual(names, ['read_file', 'edit_file', 'delete_file', 'grep_files', 'glob_files',
    'search_dora_doc', 'build', 'fetch_url', 'analyze_image', 'execute_command', 'finish',
    'list_sub_agents', 'spawn_sub_agent', 'ask_user'],
  'Upstream Agent registry changed: review the Studio parity inventory before accepting the new baseline');
});
test('upstream tool declarations produce JSON contracts without loading native handlers', async () => {
  const contracts = await loadAgentContracts();
  assert.equal(contracts.length, 14);
  assert.deepEqual(JSON.parse(JSON.stringify(contracts)), contracts);
  for (const contract of contracts) {
    assert.ok(contract.roles.length && contract.workModes.length);
    assert.equal(contract.inputSchema.type, 'object');
    assert.equal(contract.handler, undefined);
  }
  const read = contracts.find(tool => tool.name === 'read_file');
  assert.equal(read.parallelSafe, true);
  assert.deepEqual(read.inputSchema.anyOf, [{ required: ['path'] }, { required: ['reads'] }]);
  assert.ok(contracts.find(tool => tool.name === 'ask_user').rules.some(rule => rule.includes('only tool call')));
});
test('original Agent selectors retain mode restrictions, disabled tools and sub-agent completion schema', async () => {
  const registry = await loadAgentRegistry();
  const names = (role, options) => registry.buildDecisionToolSchema(role, 20, options).map(tool => tool.function.name);
  const mainCode = names('main', { workMode: 'code' });
  const mainPlan = names('main', { workMode: 'plan' });
  assert.ok(mainCode.includes('spawn_sub_agent'));
  assert.ok(!mainCode.includes('ask_user'));
  assert.ok(mainPlan.includes('ask_user'));
  assert.ok(!mainPlan.includes('spawn_sub_agent'));
  for (const role of ['main', 'sub']) for (const workMode of ['code', 'plan']) {
    const tools = names(role, { workMode, disabledAgentTools: ['read_file', 'analyze_image'] });
    assert.ok(!tools.includes('read_file') && !tools.includes('analyze_image'));
    if (role === 'sub') assert.ok(!tools.includes('ask_user') && !tools.includes('spawn_sub_agent'));
  }
  const finish = registry.buildDecisionToolSchema('sub', 20).find(tool => tool.function.name === 'finish');
  assert.deepEqual(finish.function.parameters.required, ['message', 'outcome', 'validation', 'knownIssues', 'assumptions', 'learningCandidates']);
});
