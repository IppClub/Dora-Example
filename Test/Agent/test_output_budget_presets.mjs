import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createRequire } from 'node:module';

const root = process.env.DORA_ENGINE_ROOT ?? '/Users/Jin/Workspace/Dora-SSR';
const require = createRequire(path.join(root, 'Tools/dora-dora/package.json'));
const ts = require('typescript');
const file = path.join(root, 'Tools/dora-dora/src/LLMConfigDialog.tsx');
const source = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
// Evaluate the actual preset declarations, without importing the React UI.
const names = new Set(['DEFAULT_CONTEXT_WINDOW', 'DEFAULT_TEMPERATURE', 'DEFAULT_MAX_TOKENS', 'DEEPSEEK_CONTEXT_WINDOW', 'customOptionsWithAuxiliary', 'BUILTIN_TEMPLATES']);
const declarations = source.statements.filter(statement => ts.isVariableStatement(statement)
  && statement.declarationList.declarations.some(declaration => names.has(declaration.name.getText(source))));
assert.equal(declarations.length, names.size, 'preset declarations changed; update the fixture extraction');
const code = ts.transpileModule(declarations.map(statement => statement.getText(source)).join('\n')
  + '\nmodule.exports = {presets: BUILTIN_TEMPLATES, maxTokens: DEFAULT_MAX_TOKENS};', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const context = { module: { exports: undefined } };
vm.runInNewContext(code, context, { timeout: 1000 });
const {presets, maxTokens} = context.module.exports;
assert.equal(maxTokens, 64000);
assert(presets.length > 10);
for (const preset of presets) {
  const options = JSON.parse(preset.customOptions);
  const auxiliary = options.auxiliaryOptions;
  assert(Object.keys(auxiliary).length > 0, `${preset.id}: independent reasoning configuration missing`);
  assert(!Object.hasOwn(auxiliary, 'max_tokens'), `${preset.id}: auxiliary max_tokens remains`);
  assert(!Object.hasOwn(auxiliary, 'max_completion_tokens'), `${preset.id}: auxiliary completion budget remains`);
}
for (const preset of presets) assert.equal(preset.maxTokens ?? maxTokens, 64000, preset.id);
assert.equal(JSON.parse(presets.find(preset => preset.id === 'mimo').customOptions).max_completion_tokens, 64000,
  'shared provider field selection must remain available');
console.log(`PASS: ${presets.length} Web IDE presets retain independent reasoning without auxiliary output budgets; shared defaults/provider fields preserved.`);
