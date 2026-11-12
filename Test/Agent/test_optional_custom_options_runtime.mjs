// Opt-in persistence regression against an explicitly supplied running engine.
// Uses inactive fixture rows and removes them; selected user config is untouched.
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdir,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const root=process.env.DORA_SSR_ROOT,cli=process.env.DORA_CLI;
if(!root||!cli)throw new Error('Set DORA_SSR_ROOT and DORA_CLI for the running native engine.');
const output=resolve(root,'build/agent-optional-custom-options-20261112');await mkdir(output,{recursive:true});
const code=`local D=require('Dora');local U=require('Agent.Utils')
local cases={'','   ','{}','{"temperature":0.4}','{"visionModel":"fixture-vision"}','{"auxiliaryOptions":{}}','{"auxiliaryOptions":false}'}
local checked=0
for index,text in ipairs(cases) do
 assert(D.DB:exec('INSERT INTO LLMConfig(name,url,model,api_key,context_window,temperature,max_tokens,reasoning_effort,custom_options,active) VALUES(?,?,?,?,?,?,?,?,?,0)',{'__optional_custom_fixture','http://localhost/fixture','fixture-text','fixture-only',64000,0.1,8000,'',text})>0)
 local id=D.DB:query('SELECT last_insert_rowid()')[1][1]
 local ok,err=pcall(function()
  local stored=D.DB:query('SELECT custom_options FROM LLMConfig WHERE id=?',{id})[1][1];assert(stored==text,'stored options changed')
  local loaded=U.getLLMConfig(id);assert(loaded.success,loaded.message)
  local valid=U.validateAgentLLMConfig(loaded.config);assert(valid.success==(index~=7),'wrong optional configuration validation at '..index..': '..tostring(valid.message))
  local options=U.applyCustomLLMOptions({model='fixture-text',temperature=0.1,max_tokens=8000},loaded.config.customOptions)
  assert(options.model=='fixture-text' and options.max_tokens==8000 and options.auxiliaryOptions==nil and options.visionModel==nil)
  assert(options.temperature==(index==4 and 0.4 or 0.1),'request defaults changed')
 end)
 D.DB:exec('DELETE FROM LLMConfig WHERE id=?',{id});assert(ok,tostring(err));checked=checked+1
end
print('PASS: '..checked..' persisted optional custom configurations; defaults and explicit overrides verified; fixture rows removed.')`;
const path=join(output,'persistence-command.json');await writeFile(path,JSON.stringify({mode:'lua',code,timeoutSeconds:30}));
const {stdout}=await promisify(execFile)(cli,['--asset',join(root,'Assets'),'cli','agent','command','-p',output,'--input',path]);
const result=JSON.parse(stdout);assert.equal(result.success,true,stdout);assert.match(result.output,/PASS: 7 persisted/);console.log(result.output);
