import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundled=await build({entryPoints:[new URL('../apps/web/src/project-compatibility.ts',import.meta.url).pathname],bundle:true,write:false,format:'esm',platform:'browser'});
const {inspectProjectCompatibility}=await import(`data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`);
test('compatibility observations distinguish supported entry types from unverified execution',()=>{
 const project={entry:'init.ts',files:[{path:'init.ts',kind:'text',text:'invalid code'}]};
 assert.deepEqual(inspectProjectCompatibility(project),{entrySupported:true,declaredEngine:undefined,warnings:[]});
 const mixed={...project,files:[...project.files,{path:'extra.yue',kind:'text',text:''},{path:'extra.wasm',kind:'binary',bytes:new Uint8Array()},{path:'dora-package.json',kind:'text',text:'{"engineVersion":"99.0.0"}'}]};
 const before=structuredClone(mixed),report=inspectProjectCompatibility(mixed);assert.equal(report.declaredEngine,'99.0.0');assert.equal(report.warnings.length,2);assert.deepEqual(mixed,before);
 assert.equal(inspectProjectCompatibility({...mixed,entry:'init.xml'}).entrySupported,false);
 for(const text of ['broken','null','[]','{"engineVersion":3}',' '.repeat(65537)])assert.match(inspectProjectCompatibility({...project,files:[{path:'dora-package.json',kind:'text',text}]}).warnings[0],/元数据无法识别/);
});
