import test from 'node:test';
import assert from 'node:assert/strict';
import { compileTealProject } from '../packages/agent-contracts/dist/teal-project.js';
const project = () => ({version:1, projectId:'A', revision:3, entry:'main.tl', files:[
  {path:'main.tl',kind:'text',text:'local x: number = 1\nreturn x'},
  {path:'dep.tl',kind:'text',text:'return 2'},
  {path:'image.bin',kind:'binary',bytes:new Uint8Array([0,255])},
]});
test('Teal diagnostics select complete UTF-16 source lines without assuming byte columns', async () => {
  const source = project();
  source.files[0].text = '-- 中文 😀\r\nlocal x: number = "wrong"';
  const result = await compileTealProject(source, async () => ({success:false, message:'type error', diagnostics:[
    {type:'type',path:'main.tl',line:2,column:19,message:'wrong type'},
  ]}));
  assert.equal(result.diagnostics[0].start, '-- 中文 😀\r\n'.length);
  assert.equal(result.diagnostics[0].length, 'local x: number = "wrong"'.length);
  assert.equal(result.diagnostics[0].path, 'main.tl');
  assert.match(result.diagnostics[0].message, /行 2，列 19/);
  assert.equal(result.snapshot, undefined);
});
test('Teal project builds all sources into an independent runtime snapshot', async () => {
  const source = project();
  const result = await compileTealProject(source, async request => {
    assert.equal(request.snapshot.revision, 3);
    request.snapshot.files[0].text = 'mutated callback';
    return {success:true,code:'return 1'};
  });
  assert.equal(result.snapshot.entry, 'main.lua');
  assert.equal(result.snapshot.files[1].path, 'dep.lua');
  assert.equal(source.entry, 'main.tl');
  assert.match(source.files[0].text, /number/);
  result.snapshot.files[2].bytes[0] = 9;
  assert.equal(source.files[2].bytes[0], 0);
});
test('Lua checking preserves sources and blocks invalid runtime inputs without requiring generated code', async () => {
  const source = {version:1,projectId:'Lua',revision:0,entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'return 1'}]};
  let checked = 0;
  const result = await compileTealProject(source, async request => {
    checked++; assert.equal(request.path, 'main.lua'); return {success:true};
  }, {checkLua:true});
  assert.equal(checked, 1);
  assert.deepEqual(result.snapshot, source);
  const failed = await compileTealProject(source, async () => ({success:false,message:'syntax error',diagnostics:[
    {type:'syntax',path:'main.lua',line:1,column:0,message:'unexpected symbol'},
  ]}), {checkLua:true});
  assert.equal(failed.snapshot, undefined);
  assert.equal(failed.diagnostics[0].code, 'lua-syntax');
  assert.equal(failed.diagnostics[0].message, 'unexpected symbol（行 1）');
});
test('Teal project never returns partial output after failure, cancellation or source collision', async () => {
  let count = 0;
  const failed = await compileTealProject(project(), async () => (++count === 1 ? {success:true,code:'return 1'} : {success:false,message:'type error'}));
  assert.equal(failed.success, false); assert.equal(failed.snapshot, undefined);
  const controller = new AbortController(); count = 0;
  const cancelled = await compileTealProject(project(), async () => {count++; controller.abort(); return {success:true,code:'return 1'};}, {signal:controller.signal});
  assert.equal(cancelled.interrupted, true); assert.equal(count, 1); assert.equal(cancelled.snapshot, undefined);
  const source = project(); source.files.push({path:'main.lua',kind:'text',text:'return "original"'});
  const collision = await compileTealProject(source, async () => assert.fail('collision must fail before compile'));
  assert.equal(collision.success, false);
});
