import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const root = process.env.DORA_ENGINE_ROOT;
assert(root, 'DORA_ENGINE_ROOT is required');
const require = createRequire(path.join(root, 'Tools/dora-dora/package.json'));
const ts = require('typescript');
const blocklyRequire = createRequire(require.resolve('blockly'));
const { JSDOM } = blocklyRequire('jsdom');
const dom = new JSDOM('<div id="root"></div>');
for (const name of ['window', 'document', 'HTMLElement', 'Element']) globalThis[name] = dom.window[name];
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const React = require('react');
const { createRoot } = require('react-dom/client');
const antdRequire = createRequire(require.resolve('antd'));
const tourRequire = createRequire(antdRequire.resolve('@rc-component/tour'));
const useTarget = tourRequire('./hooks/useTarget.js').default;

// Evaluate the actual application target resolvers; do not copy their behavior.
const file = path.join(root, 'Tools/dora-dora/src/FirstProjectTour.tsx');
const source = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
const names = new Set(['target', 'playControlTarget']);
const declarations = source.statements.filter(s => ts.isVariableStatement(s)
  && s.declarationList.declarations.some(d => names.has(d.name.getText(source))));
assert.equal(declarations.length, 2);
const code = ts.transpileModule(declarations.map(s => s.getText(source)).join('\n')
  + '\nmodule.exports={target,playControlTarget};', {compilerOptions: {target: ts.ScriptTarget.ES2020}}).outputText;
const context = {module: {exports: {}}, document};
vm.runInNewContext(code, context);
const {target, playControlTarget} = context.module.exports;
const visible = element => {
  element.getBoundingClientRect = () => ({x: 10, y: 10, left: 10, top: 10, right: 30, bottom: 30, width: 20, height: 20});
  return element;
};
let latest;
function Probe({resolve}) {
  latest = useTarget(resolve, true, undefined, false, false, {current: null});
  return null;
}
const reactRoot = createRoot(document.getElementById('root'));
try {
  const resolve = target('[data-tour-fixture="true"]');
  await React.act(async () => reactRoot.render(React.createElement(Probe, {resolve})));
  assert.equal(latest[0], null);
  assert.equal(latest[1], null, 'actual Tour hook must accept a null target');
  const element = visible(document.createElement('button'));
  element.dataset.tourFixture = 'true';document.body.append(element);
  await React.act(async () => reactRoot.render(React.createElement(Probe, {resolve})));
  assert.equal(latest[1], element, 'lazy target must find a newly mounted element');
  assert.equal(latest[0].width, 32);
  element.remove();
  await React.act(async () => reactRoot.render(React.createElement(Probe, {resolve})));
  assert.equal(latest[0], null);
  assert.equal(latest[1], null, 'removing a target must restore centered mode');

  const outside = visible(document.createElement('button'));
  outside.dataset.playControlMode = 'Run';document.body.append(outside);
  assert.equal(playControlTarget('Run')(), null, 'controls outside a strip must not be selected');
  const strip = document.createElement('div');strip.dataset.playControlStrip = 'true';
  const hidden = document.createElement('button');hidden.dataset.playControlMode = 'Run';strip.append(hidden);
  const inside = visible(document.createElement('button'));inside.dataset.playControlMode = 'Run';strip.append(inside);
  document.body.append(strip);
  assert.equal(playControlTarget('Run')(), inside, 'visible strip control must win over hidden/outside controls');
  console.log('PASS: actual Tour target hook supports null, lazy mount, removal and centered mode; play target selects visible strip controls.');
} finally {
  await React.act(async () => reactRoot.unmount());
  dom.window.close();
}
