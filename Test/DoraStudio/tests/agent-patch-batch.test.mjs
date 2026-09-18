import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import ts from 'typescript';
import path from 'node:path';

// Exercise the original IDE implementation, not a Studio copy.
const bundle = await build({entryPoints: ['../Tools/dora-dora/src/AgentPatchBatch.ts'], bundle: true, write: false, format: 'esm', platform: 'node'});
const {applyStepPatches} = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const packaged = await import('../packages/agent-contracts/dist/session-patches.js');
const step = (id, position = id) => ({id, taskId: 1, step: position});
const patch = fields => ({name: 'AgentSessionPatch', sessionId: 1, ...fields});

test('a later removal wins over an earlier step update in a batch', () => {
  const initial = [step(1)];
  assert.deepEqual(applyStepPatches(initial, [patch({step: step(2)}), patch({removedStepIds: [2]})]), initial);
  assert.deepEqual(initial, [step(1)]);
});

test('later reinsertions and same-patch replacements preserve existing semantics', () => {
  const initial = [step(1)];
  assert.deepEqual(applyStepPatches(initial, [patch({removedStepIds: [1]}), patch({step: step(1, 3)})]), [step(1, 3)]);
  assert.deepEqual(applyStepPatches(initial, [patch({removedStepIds: [1], step: step(1, 4)})]), [step(1, 4)]);
});

test('batching step events is equivalent to applying events individually', () => {
  const events = [patch({step: step(2)}), patch({step: step(1, 5)}), patch({removedStepIds: [1, 2]}), patch({step: step(2, 3)}), patch({removedStepIds: [2]}), patch({step: step(3)})];
  for (let length = 0; length <= events.length; length++) {
    const prefix = events.slice(0, length);
    const initial = [step(1)];
    assert.deepEqual(applyStepPatches(initial, prefix), prefix.reduce((state, event) => applyStepPatches(state, [event]), initial));
  }
});

test('Studio build shares original message, step and checkpoint behavior', () => {
  const events = [
    patch({message: {id: 2, content: 'partial'}, step: step(1)}),
    patch({message: {id: 2, content: 'complete'}, removedStepIds: [1]}),
    patch({message: {id: 1, content: 'first'}, checkpoint: {id: 1, taskId: 1, seq: 1}}),
    patch({checkpoints: [{id: 2, taskId: 2, seq: 1}]}),
    patch({checkpoint: {id: 3, taskId: 2, seq: 2}}),
  ];
  assert.deepEqual(packaged.applyMessagePatches([], events).map(({id, content}) => [id, content]), [[1, 'first'], [2, 'complete']]);
  assert.deepEqual(packaged.applyStepPatches([], events), []);
  assert.deepEqual(packaged.applyCheckpointPatches([], events).map(item => item.id), [3, 2]);
  assert.deepEqual(packaged.applyStepPatches([], events), applyStepPatches([], events));
});

test('Studio consumers resolve generated original types and reject invalid patch fields', () => {
  const file = path.resolve('apps/web/src/session-types-check.ts');
  const source = `
import {applyStepPatches, type AgentSessionPatch, type AgentSessionStep} from '@dora-studio/agent-contracts/session-patches';
const patch: AgentSessionPatch = {name: 'AgentSessionPatch', sessionId: 1, removedStepIds: [2]};
const steps: AgentSessionStep[] = applyStepPatches([], [patch]);
// @ts-expect-error Session identifiers must be numeric.
const badId: AgentSessionPatch = {name: 'AgentSessionPatch', sessionId: '1'};
// @ts-expect-error A step requires the full original step shape.
applyStepPatches([], [{name: 'AgentSessionPatch', sessionId: 1, step: {id: 1}}]);
// @ts-expect-error The result is typed, not any.
const invalid: string = steps[0].id;
`;
  const options = {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext, moduleResolution: ts.ModuleResolutionKind.Bundler, strict: true, noEmit: true, types: []};
  const host = ts.createCompilerHost(options);
  const original = host.getSourceFile.bind(host);
  host.getSourceFile = (name, ...args) => name === file ? ts.createSourceFile(file, source, options.target, true) : original(name, ...args);
  const program = ts.createProgram([file], options, host);
  assert.deepEqual(ts.getPreEmitDiagnostics(program).map(item => ts.flattenDiagnosticMessageText(item.messageText, '\n')), []);
});
