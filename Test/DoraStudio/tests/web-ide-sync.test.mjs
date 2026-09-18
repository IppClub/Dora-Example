import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { transform } from 'esbuild';

const source = await readFile(new URL('../../Assets/Script/Lib/Agent/Tool/WebIDESync.ts', import.meta.url), 'utf8');
const {code} = await transform(source, {loader:'ts',format:'cjs',target:'es2022'});
function load(server) {
  const sent = [];
  const module = {exports:{}};
  const dependencies = {
    Dora: {HttpServer:server,Content:{},emit:(...event)=>sent.push(event)},
    'Agent/Utils': {safeJsonEncode:value=>[JSON.stringify(value)],Log:()=>{}},
    'Agent/Tool/Workspace': {resolveWorkspaceFilePath:()=>undefined},
  };
  new Function('require','module','exports',code)(name=>{
    assert.ok(Object.hasOwn(dependencies,name),name);
    return dependencies[name];
  },module,module.exports);
  return {api:module.exports,sent};
}
for (const [name,server] of [['Web host',undefined],['disconnected native IDE',{wsConnectionCount:0}]]) {
  test(`${name} does not require a WebSocket receiver`,()=>{
    const {api,sent} = load(server);
    assert.equal(api.sendWebIDERefreshTree(),true);
    assert.equal(api.sendWebIDEFileUpdate('/game/init.lua',true,'print(42)'),true);
    assert.deepEqual(sent,[]);
  });
}
test('connected native IDE retains the original refresh and file payloads',()=>{
  const {api,sent} = load({wsConnectionCount:1});
  assert.equal(api.sendWebIDERefreshTree(),true);
  assert.equal(api.sendWebIDEFileUpdate('/game/init.lua',true,'print(42)'),true);
  assert.deepEqual(sent.map(([event,action,payload])=>[event,action,JSON.parse(payload)]),[
    ['AppWS','Send',{name:'RefreshTree'}],
    ['AppWS','Send',{name:'UpdateFile',file:'/game/init.lua',exists:true,content:'print(42)'}],
  ]);
});
