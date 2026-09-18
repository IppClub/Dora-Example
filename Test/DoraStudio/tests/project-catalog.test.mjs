import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const output=await build({entryPoints:[new URL('../apps/web/src/project-catalog.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {mergeProjectCatalog}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);

test('project catalog presents local and synchronized projects as one deduplicated list',()=>{
 const local=[
  {projectId:'same-project',name:'俄罗斯方块',updatedAt:100,createdAt:1,revision:2,entry:'main.ts'},
  {projectId:'local-only',name:'离线草稿',updatedAt:300,createdAt:2,revision:0,entry:'main.ts'},
 ];
 const remote=[
  {projectId:'same-project',name:'跨设备新名称',cloudRevision:4,updatedAt:400},
  {projectId:'remote-only-project',name:'云端原名',cloudRevision:1,updatedAt:200},
 ];
 const result=mergeProjectCatalog(local,remote);
 assert.deepEqual(result.map(item=>[item.projectId,item.name,item.updatedAt]),[
  ['same-project','跨设备新名称',400],
  ['local-only','离线草稿',300],
  ['remote-only-project','云端原名',200],
 ]);
 assert.equal(result[0].local,local[0]);
 assert.equal(result[0].remote,remote[0]);
 assert.equal(result[2].local,undefined);
});

test('project catalog order is stable when timestamps match',()=>{
 const result=mergeProjectCatalog([],[
  {projectId:'b',name:'B',cloudRevision:1,updatedAt:10},
  {projectId:'a',name:'A',cloudRevision:1,updatedAt:10},
 ]);
 assert.deepEqual(result.map(item=>item.projectId),['a','b']);
});
