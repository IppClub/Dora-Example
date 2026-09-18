import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
const result = await build({ entryPoints: [new URL('../apps/web/src/project-import.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm' });
const { restoreStudioArchive, restoreDoraPackage, restoreDoraArchive } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
const encoder = new TextEncoder();
test('source import and backup restoration preserve UTF-8 BOM and CRLF bytes',()=>{
 const source='\ufeffprint "你好"\r\n';
 const imported=restoreDoraArchive([{path:'init.yue',data:encoder.encode(source)}],'source.dora');
 assert.equal(imported.snapshot.files[0].text,source);
 const metadata=encoder.encode(JSON.stringify({format:'dora-studio-project',version:1,name:'BOM',entry:'init.yue',files:[{path:'init.yue',kind:'text'}]}));
 const restored=restoreStudioArchive([{path:'.studio/project.json',data:metadata},{path:'init.yue',data:encoder.encode(source)}]);
 assert.deepEqual(encoder.encode(restored.snapshot.files[0].text),encoder.encode(source));
});
test('ordinary source archives import without a player manifest and preserve future metadata',()=>{
 const files=[{path:'game/init.ts',data:encoder.encode('export const value = 1;')},{path:'game/art.bin',data:new Uint8Array([0,255])},{path:'game/dora-package.json',data:encoder.encode('{"engineVersion":"99.0.0"}')}];
 const imported=restoreDoraArchive(files,'game.zip');assert.equal(imported.name,'game');assert.equal(imported.snapshot.entry,'init.ts');assert.equal(imported.snapshot.files[2].text,'{"engineVersion":"99.0.0"}');
 files[1].data[0]=9;assert.deepEqual([...imported.snapshot.files[1].bytes],[0,255]);
 assert.equal(restoreDoraArchive([{path:'init.lua',data:encoder.encode('print(1)')}],'simple.dora').snapshot.entry,'init.lua');
 const titled=restoreDoraArchive([{path:'wrapper/init.lua',data:encoder.encode('print(1)')},{path:'wrapper/dora-package.json',data:encoder.encode(JSON.stringify({format:'dora-game',version:1,title:'Dora 导入验收'}))}],'import-test.dora');
 assert.equal(titled.name,'Dora 导入验收');assert.equal(titled.snapshot.files.find(file=>file.path==='dora-package.json').text,JSON.stringify({format:'dora-game',version:1,title:'Dora 导入验收'}));
 assert.equal(restoreDoraArchive([{path:'init.lua',data:encoder.encode('')},{path:'dora-package.json',data:encoder.encode('{broken')}],'fallback.dora').name,'fallback');
 assert.throws(()=>restoreDoraArchive([{path:'one/init.lua',data:encoder.encode('')},{path:'two/init.lua',data:encoder.encode('')}],'multi.zip'),/明确的源码入口/);
 assert.throws(()=>restoreDoraArchive([{path:'init.ts',data:encoder.encode('')},{path:'../escape',data:new Uint8Array()}],'bad.zip'));
 const deep=restoreDoraArchive([{path:'download/repo/game/init.ts',data:encoder.encode('export {};')},{path:'download/repo/game/assets/a.bin',data:new Uint8Array([5])}],'deep.zip');
 assert.deepEqual(deep.snapshot.files.map(file=>file.path),['init.ts','assets/a.bin']);
 assert.throws(()=>restoreDoraArchive([{path:'../init.ts',data:encoder.encode('')}],'unsafe.zip'),/非法路径/);
 assert.throws(()=>restoreDoraArchive([{path:'repo/README.md',data:encoder.encode('keep me')},{path:'repo/game/init.ts',data:encoder.encode('')}],'siblings.zip'),/明确的源码入口/);
 assert.throws(()=>restoreDoraArchive([],'empty.zip'),/为空/);
});
test('source import prefers authored entry over its generated Lua sibling',()=>{
 const pair=[{path:'init.lua',data:encoder.encode('generated')},{path:'init.ts',data:encoder.encode('export {};')}];
 assert.equal(restoreDoraArchive(pair,'pair.zip').snapshot.entry,'init.ts');
 assert.equal(restoreDoraPackage({manifest:{title:'pair'},files:pair}).snapshot.entry,'init.ts');
});
function files(patch = {}) {
  return [{ path: '.studio/project.json', data: encoder.encode(JSON.stringify({
    format: 'dora-studio-project', version: 1, name: '备份', entry: 'main.ts',
    files: [{ path: 'main.ts', kind: 'text' }, { path: 'a.bin', kind: 'binary' }], ...patch })) },
  { path: 'main.ts', data: encoder.encode('print("你好")') }, { path: 'a.bin', data: new Uint8Array([0, 255]) }];
}
test('backup restoration preserves types and bytes but creates independent project identities', () => {
  const a = restoreStudioArchive(files()), b = restoreStudioArchive(files());
  assert.notEqual(a.snapshot.projectId, b.snapshot.projectId);
  assert.equal(a.snapshot.files[0].text, 'print("你好")');
  assert.deepEqual([...a.snapshot.files[1].bytes], [0, 255]);
  for (const patch of [{ version: 2 }, { entry: 'missing' }, { name: '' }, { files: [] }]) {
    assert.throws(() => restoreStudioArchive(files(patch)));
  }
  const bad = files(); bad[1].data = new Uint8Array([255]);
  assert.throws(() => restoreStudioArchive(bad));
});
test('validated Dora packages preserve sources and binary assets with an independent identity', () => {
  const pack = { manifest: { title: '导入游戏' }, files: [
    { path: 'init.lua', data: encoder.encode('print("hello")') },
    { path: 'a.png', data: new Uint8Array([0, 255, 128]) }
  ] };
  const a = restoreDoraPackage(pack), b = restoreDoraPackage(pack);
  assert.equal(a.name, '导入游戏');
  assert.equal(a.snapshot.entry, 'init.lua');
  assert.equal(a.snapshot.files[0].text, 'print("hello")');
  assert.deepEqual([...a.snapshot.files[1].bytes], [0, 255, 128]);
  assert.notEqual(a.snapshot.projectId, b.snapshot.projectId);
  pack.files[1].data[0] = 99;
  assert.equal(a.snapshot.files[1].bytes[0], 0);
  assert.throws(() => restoreDoraPackage({ ...pack, files: [] }), /Wasm/);
});
