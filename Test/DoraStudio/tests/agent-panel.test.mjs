import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';
const reactRoot = createRequire(resolve('apps/web/package.json')).resolve('react/package.json').replace(/\/package.json$/, '');
const bundle = await build({stdin:{contents:`import {createElement} from 'react'; import {renderToStaticMarkup} from 'react-dom/server'; import {AgentPanel,isAgentTranscriptAtBottom} from './AgentPanel'; export const render = props => renderToStaticMarkup(createElement(AgentPanel,props)); export {isAgentTranscriptAtBottom};`,resolveDir:resolve('apps/web/src'),loader:'tsx'},bundle:true,alias:{react:reactRoot},write:false,format:'cjs',platform:'node',jsx:'automatic',loader:{'.css':'empty'}});
const mod={exports:{}};
new Function('module','exports','require',bundle.outputFiles[0].text)(mod,mod.exports,createRequire(import.meta.url));
const {render,isAgentTranscriptAtBottom}=mod.exports;
function assertSendDisabled(html,disabled=true){
  const button=html.match(/<button\b[^>]*aria-label="发送[^"]*"[^>]*>/)?.[0];
  assert.ok(button,'the accessible send action must be rendered');
  assert.equal(button.includes('disabled=""'),disabled);
}
const collection = items => ({orderedIds:items.map(item=>item.id),byId:new Map(items.map(item=>[item.id,item]))});
test('Agent transcript follows only while the viewport remains near the latest message',()=>{
  assert.equal(isAgentTranscriptAtBottom({scrollHeight:1000,scrollTop:552,clientHeight:400}),false);
  assert.equal(isAgentTranscriptAtBottom({scrollHeight:1000,scrollTop:553,clientHeight:400}),true);
});
test('unconnected panel keeps the existing honest disabled creation state', () => {
  const html=render({});
  assert.match(html,/待接入/);
  assert.match(html,/不会调用模型或产生模型费用/);
  assert.doesNotMatch(html,/<textarea[^>]* disabled=""/);
  assertSendDisabled(html);
});
test('read-only session view renders messages safely, history and actual execution status', () => {
  const html=render({state:{session:{title:'示例',status:'DONE',workMode:'code',metrics:{usage:{totalTokens:3}}},messages:collection([{id:1,role:'assistant',content:'<script>alert(1)</script>'}]),steps:collection([{id:1,tool:'edit_file',status:'DONE',reason:'保存脚本'}]),checkpoints:collection([]),hasEarlierMessages:true,pendingQuestionnaire:null,deleted:false}});
  assert.match(html,/&lt;script&gt;/);
  assert.doesNotMatch(html,/<script>/);
  assert.match(html,/加载更早的消息/);
  assert.match(html,/编辑文件/);
  assert.match(html,/已完成/);
  assert.match(html,/累计 Token 3/);
  assert.doesNotMatch(html,/Token 用量不等于已结算金额/);
});
test('step list exposes the original Agent execution details instead of a tool-only row',()=>{
  const state={session:{title:'示例',status:'RUNNING',workMode:'code',currentTaskId:2,currentTaskStatus:'RUNNING'},messages:collection([]),steps:collection([{id:8,sessionId:1,taskId:2,step:3,tool:'execute_command',status:'FAILED',reason:'运行检查脚本',reasoningContent:'',params:{mode:'lua',code:'print("check")',cwd:'Script'},result:{success:false,message:'脚本执行失败',output:'line 1: error'},files:[{op:'write',path:'main.ts'}],createdAt:1,updatedAt:1}]),checkpoints:collection([]),hasEarlierMessages:false,pendingQuestionnaire:null,deleted:false};
  const html=render({state});
  assert.match(html,/执行命令/);assert.match(html,/运行检查脚本/);assert.match(html,/工作目录/);assert.match(html,/Script/);
  assert.match(html,/脚本代码/);assert.match(html,/输出结果/);assert.match(html,/脚本执行失败/);assert.match(html,/main.ts/);
});
test('running task shows an explicit automatic shared-model queue state',()=>{
  const state={session:{title:'示例',status:'RUNNING',workMode:'code',currentTaskId:2,currentTaskStatus:'RUNNING'},messages:collection([{id:1,taskId:2,role:'user',content:'继续完善'}]),steps:collection([]),checkpoints:collection([]),hasEarlierMessages:false,pendingQuestionnaire:null,deleted:false};
  const queued=render({state,modelQueue:{version:1,state:'queued',queuedAt:123,position:3}});
  assert.match(queued,/共享模型繁忙，正在自动排队等待/);assert.match(queued,/前方 2 个请求/);
  assert.doesNotMatch(queued,/正在准备上下文并请求模型/);
  const idle=render({state,modelQueue:{version:1,state:'idle'}});
  assert.match(idle,/正在准备上下文并请求模型/);assert.doesNotMatch(idle,/共享模型繁忙/);
});
test('messages and step reasoning render safe GitHub-flavored markdown',()=>{
  const state={session:{title:'示例',status:'DONE',workMode:'code'},messages:collection([{id:1,role:'assistant',content:'## 完成\n\n- 项目一\n- `main.ts`\n\n<script>alert(1)</script>'}]),steps:collection([{id:2,sessionId:1,taskId:1,step:1,tool:'message',status:'DONE',reason:'**重点**：已修复\n\n| 文件 | 状态 |\n| --- | --- |\n| main.ts | 完成 |',reasoningContent:'',createdAt:1,updatedAt:1}]),checkpoints:collection([]),hasEarlierMessages:false,pendingQuestionnaire:null,deleted:false};
  const html=render({state});
  assert.match(html,/<h2>完成<\/h2>/);assert.match(html,/<li>项目一<\/li>/);assert.match(html,/<code>main.ts<\/code>/);
  assert.match(html,/<strong>重点<\/strong>/);assert.match(html,/<table>/);assert.match(html,/&lt;script&gt;alert\(1\)&lt;\/script&gt;/);assert.doesNotMatch(html,/<script>/);
});
test('each task keeps the user request first, execution steps in the middle and Agent summary last',()=>{
  const state={session:{title:'示例',status:'DONE',workMode:'code',currentTaskId:7,currentTaskStatus:'DONE'},messages:collection([{id:1,taskId:7,role:'user',content:'需求在前'},{id:2,taskId:7,role:'assistant',content:'总结在后'}]),steps:collection([{id:3,sessionId:1,taskId:7,step:1,tool:'edit_file',status:'DONE',reason:'执行步骤居中',reasoningContent:'',createdAt:1,updatedAt:1}]),checkpoints:collection([]),hasEarlierMessages:false,pendingQuestionnaire:null,deleted:false};
  const html=render({state});
  assert.ok(html.indexOf('需求在前')<html.indexOf('执行步骤居中'));
  assert.ok(html.indexOf('执行步骤居中')<html.indexOf('总结在后'));
});
test('connected session exposes the continuation composer only when the project gate allows it',()=>{
  const state={session:{title:'示例',status:'DONE',workMode:'code'},messages:collection([]),steps:collection([]),checkpoints:collection([]),hasEarlierMessages:false,pendingQuestionnaire:null,deleted:false};
  const enabled=render({state,composer:{value:'增加雨滴',onChange(){},onSubmit(){},disabled:false,busy:false,status:'可继续第 2 轮创作，不限制轮次',planMode:false,fetchUrlEnabled:false,executeCommandEnabled:true,models:[{id:'grant-a',name:'DeepSeek · deepseek-chat'}],modelId:'grant-a',onPlanModeChange(){},onFetchUrlEnabledChange(){},onExecuteCommandEnabledChange(){},onModelChange(){}}});
  assert.match(enabled,/继续描述你希望修改的玩法/);assert.match(enabled,/增加雨滴/);assert.match(enabled,/不限制轮次/);
  assert.match(enabled,/计划/);assert.match(enabled,/网络/);assert.match(enabled,/命令/);assert.match(enabled,/DeepSeek/);
  assert.doesNotMatch(enabled,/<textarea[^>]* disabled=""/);
  assertSendDisabled(enabled,false);
  const uncertain=render({state,composer:{value:'',onChange(){},onSubmit(){},disabled:true,busy:false,status:'上轮投递结果待核对，不能自动重发'}});
  assert.match(uncertain,/上轮投递结果待核对/);assert.doesNotMatch(uncertain,/<textarea[^>]* disabled=""/);
  assertSendDisabled(uncertain);
});
test('pending questionnaire reuses the interactive Agent UI and blocks the normal composer',()=>{
  const state={
    session:{title:'示例',status:'RUNNING',workMode:'plan'},
    messages:collection([]),steps:collection([]),checkpoints:collection([]),hasEarlierMessages:false,deleted:false,
    pendingQuestionnaire:{
      id:1,sessionId:1,taskId:1,step:1,status:'PENDING',createdAt:1,
      schema:{title:'确认玩法',questions:[{id:'pace',prompt:'你喜欢哪种节奏？',type:'single_choice',required:true,allowOther:false,options:[{id:'calm',label:'轻松',description:'节奏舒缓'},{id:'tense',label:'紧张',description:'持续挑战'}]}]}
    }
  };
  const html=render({
    state,
    composer:{value:'这段内容不应显示',onChange(){},onSubmit(){},disabled:false,busy:false,status:'可继续'},
    questionnaire:{submitting:false,onSubmit(){},onCancel(){}}
  });
  assert.match(html,/确认玩法/);
  assert.match(html,/你喜欢哪种节奏/);
  assert.match(html,/轻松/);
  assert.match(html,/提交回答/);
  assert.doesNotMatch(html,/继续描述你希望修改的玩法/);
  assert.doesNotMatch(html,/这段内容不应显示/);
});
