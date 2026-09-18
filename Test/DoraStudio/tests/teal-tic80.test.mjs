import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import createModule from '../packages/agent-contracts/dist/teal/compiler.mjs';
import {createTealCompiler} from '../packages/agent-contracts/src/teal-compiler.js';

const declarations=JSON.parse(await readFile('apps/web/.generated/teal/declarations.json','utf8'));
async function compile(path,text,action){
  const snapshot={version:1,projectId:'tic80-check',revision:0,entry:path,files:[{path,kind:'text',text}]};
  const compiler=await createTealCompiler(snapshot,declarations,createModule);
  try{return action(compiler);}finally{compiler.dispose();}
}

test('Teal Worker compiled core uses Dora TIC80 source rewrite and restores a leading marker',async()=>{
  const result=await compile('main.tl','-- tic80\ncls(0)\n',compiler=>compiler.compile('tic80-check','main.tl'));
  assert.equal(result.success,true);
  assert.equal(result.tic80,true);
  assert.match(result.code,/^-- tic80\ncls\(0\)/);
});

test('ordinary Teal does not gain a TIC80 marker',async()=>{
  const result=await compile('main.tl','local n: number = 1\nprint(n)\n',compiler=>compiler.compile('tic80-check','main.tl'));
  assert.equal(result.success,true);assert.equal(result.tic80,false);
  assert.doesNotMatch(result.code,/tic80/);
});

test('Lua checker retains Dora TIC80 permissive check and reports invalid source',async()=>{
  const valid=await compile('main.lua','-- tic80\ncls(0)\n',compiler=>compiler.check('tic80-check','main.lua'));
  const invalid=await compile('main.lua','-- tic80\ncls(\n',compiler=>compiler.check('tic80-check','main.lua'));
  assert.equal(valid.success,true);assert.deepEqual(valid.diagnostics,[]);
  assert.equal(invalid.success,false);assert.ok(invalid.diagnostics.some(d=>d.type==='syntax'));
});
