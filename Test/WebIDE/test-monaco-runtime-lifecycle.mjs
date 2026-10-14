import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const root = process.env.DORA_ENGINE_ROOT;
assert(root, 'DORA_ENGINE_ROOT must target the current engine');
const require = createRequire(path.join(root, 'Tools/dora-dora/package.json'));
const { build } = require('esbuild');
// Blockly already uses jsdom; reuse the installed dependency without another install.
const blocklyRequire = createRequire(require.resolve('blockly'));
const { JSDOM } = blocklyRequire('jsdom');
const dom = new JSDOM('<div id="root"></div>');
for (const name of ['window', 'document', 'HTMLElement']) globalThis[name] = dom.window[name];
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const React = require('react');
const { createRoot } = require('react-dom/client');
const temp = mkdtempSync(path.join(tmpdir(), 'dora-monaco-lifecycle-'));

try {
  const output = path.join(temp, 'runtime.cjs');
  await build({
    entryPoints: [path.join(root, 'Tools/dora-dora/src/MonacoEditorRuntime.tsx')],
    outfile: output, bundle: true, platform: 'node', format: 'cjs', logLevel: 'silent',
    plugins: [{ name: 'editor-fixture', setup(builder) {
      builder.onResolve({filter: /^react(?:\/.*)?$/}, args => ({path: require.resolve(args.path), external: true}));
      builder.onResolve({filter: /^(@monaco-editor\/react|\.\/monacoBase|\.\/Editor|\.\/MonacoRuntimeAccess)$/}, args => ({path: args.path, namespace: 'fixture'}));
      builder.onLoad({filter: /.*/, namespace: 'fixture'}, args => ({contents: args.path === '@monaco-editor/react' ? `
        import {useEffect} from 'react';
        export const loader={config(){}};
        export default function Editor(props){
          const f=globalThis.__editorFixture;f.props=props;
          useEffect(()=>{
            f.disposed=false;f.events.push('mount');props.onMount(f.editor,{});
            return ()=>{f.disposed=true;f.events.push('dispose')};
          },[]);
          return null;
        }
      ` : args.path === './monacoBase' ? `
        export default {Uri:{file:path=>({toString:()=> 'file://'+path})}};
        export const monacoTypescript={};
      ` : args.path === './MonacoRuntimeAccess' ? 'export function setMonacoRuntime(){}' : '', loader: 'js'}));
    }}],
  });
  const Runtime = require(output).default;
  for (const strict of [false, true]) {
    const fixture = {events: [], disposed: false, props: null};
    fixture.editor = {saveViewState() {
      assert.equal(fixture.disposed, false, 'view state must be saved before disposal');
      fixture.events.push('save');return {cursor: 7};
    }};
    globalThis.__editorFixture = fixture;
    let initialCalls = 0, latestCalls = 0;
    const onUnmount = label => editor => {
      assert.equal(editor, fixture.editor);
      assert.deepEqual(editor.saveViewState(), {cursor: 7});
      fixture.events.push('unmount');
      if (label === 'initial') initialCalls++; else latestCalls++;
    };
    const render = callback => {
      const element = React.createElement(Runtime, {filePath: '/project/init.ts', onUnmount: callback});
      return strict ? React.createElement(React.StrictMode, null, element) : element;
    };
    const reactRoot = createRoot(document.getElementById('root'));
    await React.act(async () => reactRoot.render(render(onUnmount('initial'))));
    const initialBeforeUpdate = initialCalls;
    await React.act(async () => reactRoot.render(render(onUnmount('latest'))));
    assert.equal(fixture.props.path, 'file:///project/init.ts');
    assert.equal(Object.hasOwn(fixture.props, 'onUnmount'), false, 'unsupported callback must not leak into Monaco props');
    await React.act(async () => reactRoot.unmount());
    assert.equal(initialCalls, initialBeforeUpdate, 'unmount must use the latest callback');
    assert.equal(latestCalls, 1);
    for (let i = 0; i < fixture.events.length; i++) {
      if (fixture.events[i] === 'dispose') assert.equal(fixture.events[i - 1], 'unmount');
    }
    assert.equal(fixture.events.filter(e => e === 'dispose').length, strict ? 2 : 1);
  }
  console.log('PASS: real React layout cleanup saves view state before Monaco disposal; latest callback, URI, no unsupported prop, StrictMode.');
} finally {
  delete globalThis.__editorFixture;
  dom.window.close();
  rmSync(temp, {recursive: true, force: true});
}
