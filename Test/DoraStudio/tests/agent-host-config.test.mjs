import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:['apps/web/src/agent-host-config.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const {decodeAgentHostConfig:decode}=await import('data:text/javascript;base64,'+Buffer.from(result.outputFiles[0].text).toString('base64'));
const config={version:1,parentOrigin:'https://studio.example',accountId:'a',projectId:'p',generation:'g',projectRoot:'/game',title:'中文游戏'};
test('host configuration copies trusted identity without accepting secrets or path aliases',()=>{
  const input={...config},output=decode(input);input.projectId='other';
  assert.equal(output.projectId,'p');assert.ok(Object.isFrozen(output));
  for(const value of [null,[],{...config,apiKey:'must not be here'},{...config,parentOrigin:'https://studio.example/path'},
    {...config,projectRoot:'/game/../other'},{...config,projectRoot:'/'},{...config,generation:''},{...config,accountId:'\ud800'},
    {...config,projectRoot:'/game/'},{...config,projectRoot:'/game\\other'},{...config,title:'bad\0title'}])assert.throws(()=>decode(value));
});
