import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import path from 'node:path';
import ts from 'typescript';
const root=path.resolve(process.env.DORA_ENGINE_ROOT || process.env.DORA_SSR_ROOT || '../..');
const read=relative=>readFileSync(path.join(root,relative),'utf8');
const compile=(source,scope={})=>new Function(...Object.keys(scope),ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText)(...Object.values(scope));
const exports={};
compile(read('Studio/packages/agent-ui/src/InputEvents.ts'),{exports});
const {isImeKeyEvent,preventImeSubmit}=exports;
function handler(relative,name){
 const source=ts.createSourceFile(relative,read(relative),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
 let result;
 const visit=node=>{
  if(ts.isVariableDeclaration(node)&&node.name.getText(source)===name)result=node.initializer;
  if(ts.isJsxAttribute(node)&&node.name.getText(source)===name&&node.initializer&&ts.isJsxExpression(node.initializer))result=node.initializer.expression;
  ts.forEachChild(node,visit);
 };
 visit(source);assert.ok(result,`${relative}: ${name}`);return result.getText(source);
}
let passed=0;
const cases=[
 ['Studio/packages/agent-ui/src/AgentComposer.tsx','onKeyDown',{}],
 ['Studio/packages/agent-ui/src/AgentFollowup.tsx','onKeyDown',{ctrlKey:true}],
 ['Tools/dora-dora/src/AgentMessageList.tsx','handleEditKeyDown',{}],
 ['Tools/dora-dora/src/LogFixPanel.tsx','onKeyDown',{}],
 ['Tools/dora-dora/src/FileFilter.tsx','onInputKeyDown',{}],
 ['Tools/dora-dora/src/FileSearch.tsx','onKeyDown',{}],
 // This component has another root keyboard handler: select the input callback below.
 ['Tools/dora-dora/src/ParticleEditor/ParticleEditorCanvas.tsx','onKeyDown',{}],
];
for(const [file,name,modifiers] of cases){
 let callback=handler(file,name);
 if(file.includes('ParticleEditor')){
  const source=ts.createSourceFile(file,read(file),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
  const visit=node=>{if(ts.isJsxAttribute(node)&&node.name.getText(source)==='onKeyDown'&&node.initializer&&ts.isJsxExpression(node.initializer)&&node.initializer.expression?.getText(source).includes('commitHex'))callback=node.initializer.expression.getText(source);ts.forEachChild(node,visit);};visit(source);
 }
 let actions=0,prevented=false;
 const act=()=>{actions++;};
 const scope={isImeKeyEvent,isComposingRef:{current:false},running:false,canStop:true,stopping:false,isMac:false,submit:act,finishEdit:act,cancelEdit:act,sendEdit:act,onSend:act,sendPrompt:act,runSearch:act,commitHex:act,selectOption:act,results:['result'],selectedIndex:0,props:{onStop:act,onClose:act}};
 const invoke=compile(`return (${callback});`,scope);
 const event=native=>({key:'Enter',shiftKey:false,altKey:false,...modifiers,nativeEvent:native,preventDefault(){prevented=true;},stopPropagation(){},currentTarget:{blur(){}}});
 for(const native of [{isComposing:true,keyCode:13},{isComposing:false,keyCode:229}]){
  actions=0;prevented=false;invoke(event(native),{});assert.equal(actions,0,`${file}: IME Enter must not submit`);assert.equal(prevented,false,`${file}: preserve IME default`);passed++;
 }
 actions=0;invoke(event({isComposing:false,keyCode:13}),{});assert.equal(actions,1,`${file}: ordinary Enter still submits`);passed++;
}
for(const native of [{isComposing:true,keyCode:13},{isComposing:false,keyCode:229},{isComposing:false,keyCode:13}]){
 let prevented=false;preventImeSubmit({key:'Enter',nativeEvent:native,preventDefault(){prevented=true;}});assert.equal(prevented,isImeKeyEvent(native));passed++;
}
for(const key of ['a','Escape','ArrowDown']){
 let prevented=false;preventImeSubmit({key,nativeEvent:{isComposing:true,keyCode:229},preventDefault(){prevented=true;}});assert.equal(prevented,false);passed++;
}
// Cover every native form, including implicit Enter submits without a key handler.
for(const file of ['Tools/dora-dora/src/LogView.tsx',...['App','LoginDialog','AdminModels','ByokCreateConfiguration','ByokEditConfiguration','ByokSecretSettings'].map(name=>`Studio/apps/web/src/${name}.tsx`)]){
 const source=ts.createSourceFile(file,read(file),ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
 const visit=node=>{
  if((ts.isJsxOpeningElement(node)||ts.isJsxSelfClosingElement(node))&&node.tagName.getText(source)==='form'){
   assert.ok(node.attributes.properties.some(attr=>ts.isJsxAttribute(attr)&&attr.name.getText(source)==='onKeyDownCapture'&&attr.initializer?.getText(source)==='{preventImeSubmit}'),`${file}: native form needs IME guard`);passed++;
  }
  ts.forEachChild(node,visit);
 };visit(source);
}
// A resend must close immediately, before its response resolves, including failures.
for(const result of [true,false]){
 let closed=0,payload,resolveRequest,sending=false;
 const invoke=compile(`return (${handler('Tools/dora-dora/src/AgentMessageList.tsx','sendEdit')});`,{
  editingPrompt:' 修改后的消息 ',sending:false,
  setSending:value=>{sending=value;},cancelEdit:()=>{closed++;},
  replaceAgentMessageText:(content,prompt)=>`${content}:${prompt}`,
  props:{onResendPrompt:(message,prompt)=>{payload=prompt;return new Promise(resolve=>{resolveRequest=resolve;});}},
 });
 const pending=invoke({content:'原始消息'});
 assert.equal(closed,1,'resend closes editor while request is pending');
 assert.equal(sending,true);assert.equal(payload,'原始消息:修改后的消息');passed++;
 resolveRequest(result);await pending;
 assert.equal(closed,1,'resend result must not close a newer editor');assert.equal(sending,false);passed++;
}
console.log(`Passed ${passed} IME keyboard, native-form and resend checks.`);
