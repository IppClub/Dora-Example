import test from 'node:test';
import assert from 'node:assert/strict';
import {agentProviderCatalog,createAgentProviderIds,getAgentProviderProfile} from '../apps/server/agent-provider-profiles.mjs';

test('Agent provider catalog exposes the supported trusted profiles',()=>{
  assert.deepEqual(agentProviderCatalog,[
    {id:'deepseek',label:'DeepSeek'},
    {id:'zai',label:'ZAI'},
    {id:'openai',label:'OpenAI'},
  ]);
  assert.deepEqual([...createAgentProviderIds()],['deepseek','zai','openai']);
  assert.equal(getAgentProviderProfile('unknown'),undefined);
});

test('Agent provider profiles match the original Dora Agent presets',()=>{
  assert.deepEqual(getAgentProviderProfile('deepseek'),{
    id:'deepseek',label:'DeepSeek',contextWindow:1000000,temperature:0.1,maxTokens:64000,supportsFunctionCalling:true,
    auxiliaryOptions:{max_tokens:8192,reasoning_effort:null,thinking:{type:'disabled'}},
    vision:{provider:'deepseek',model:'deepseek-flash'},
  });
  assert.deepEqual(getAgentProviderProfile('zai'),{
    id:'zai',label:'ZAI',contextWindow:128000,temperature:0.1,maxTokens:8192,supportsFunctionCalling:true,
    auxiliaryOptions:{max_tokens:8192,reasoning_effort:null,thinking:{type:'disabled'}},
    vision:{provider:'glm-coding-cn',model:'glm-5.3-flash'},
  });
  assert.deepEqual(getAgentProviderProfile('openai'),{
    id:'openai',label:'OpenAI',contextWindow:128000,temperature:0.1,maxTokens:8192,supportsFunctionCalling:true,
    auxiliaryOptions:{max_tokens:null,max_completion_tokens:8192,reasoning_effort:'none'},
  });
});
