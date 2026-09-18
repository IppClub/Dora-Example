import {readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {runInNewContext} from 'node:vm';

const output=process.argv[2];
if(!output||!output.endsWith('.dora'))throw new Error('Expected absolute .dora output path');
const backupOutput=process.argv[3];
if(backupOutput&&!backupOutput.endsWith('.zip'))throw new Error('Expected .zip backup output path');
const source=await readFile(resolve(import.meta.dirname,'../../Projects/Web/web-package.js'),'utf8');
const scope={TextDecoder,TextEncoder,Uint8Array,ArrayBuffer,DataView,Promise,Blob};
runInNewContext(source,scope,{filename:'web-package.js'});
const encode=text=>new TextEncoder().encode(text);
const archive=scope.DoraWebPackage.createArchive([
 {path:'Imported/dora-package.json',data:encode(JSON.stringify({format:'dora-game',version:1,entry:'init',title:'人工验收 Dora 导入',engineVersion:'1.9.2'}))},
 {path:'Imported/init.lua',data:encode('print("人工验收：导入游戏已启动")\n')},
 {path:'Imported/Resources/check.bin',data:new Uint8Array([0,255,128,7])},
]);
await writeFile(output,archive);
process.stdout.write(`Created ${output} (${archive.length} bytes)\n`);
if(backupOutput){
 const backup=scope.DoraWebPackage.createArchive([
  {path:'init.lua',data:encode('print("人工验收：Studio 备份恢复成功")\n')},
  {path:'Resources/backup.bin',data:new Uint8Array([1,2,255])},
  {path:'.studio/project.json',data:encode(JSON.stringify({format:'dora-studio-project',version:1,name:'人工验收 ZIP 恢复',entry:'init.lua',files:[{path:'init.lua',kind:'text'},{path:'Resources/backup.bin',kind:'binary'}]}))},
 ]);
 await writeFile(backupOutput,backup);
 process.stdout.write(`Created ${backupOutput} (${backup.length} bytes)\n`);
}
