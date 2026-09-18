import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:[new URL('../apps/web/src/archive-project.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {archiveEntryCandidates,createArchiveProject}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('explicit archive promotion preserves all paths and bytes under a new identity',()=>{
 const encoder=new TextEncoder(),archive={version:1,kind:'project-archive',projectId:'original',revision:0,entry:null,files:[{path:'one/init.ts',kind:'binary',bytes:encoder.encode('\ufeffexport {};\r\n')},{path:'two/init.lua',kind:'binary',bytes:encoder.encode('return 1')},{path:'README.txt',kind:'binary',bytes:new Uint8Array([255])}]};
 const before=structuredClone(archive);assert.deepEqual(archiveEntryCandidates(archive),['one/init.ts','two/init.lua']);
 const project=createArchiveProject(archive,'one/init.ts');assert.notEqual(project.projectId,archive.projectId);assert.equal(project.entry,'one/init.ts');assert.deepEqual(project.files.map(file=>file.path),archive.files.map(file=>file.path));assert.deepEqual(encoder.encode(project.files[0].text),archive.files[0].bytes);assert.deepEqual(project.files[2].bytes,new Uint8Array([255]));assert.deepEqual(archive,before);
 project.files[2].bytes[0]=0;assert.equal(archive.files[2].bytes[0],255);
 assert.throws(()=>createArchiveProject(archive,'absent.lua'));assert.throws(()=>createArchiveProject({...archive,files:[{path:'bad.lua',kind:'binary',bytes:new Uint8Array([255])}]},'bad.lua'),/UTF-8/);
});
