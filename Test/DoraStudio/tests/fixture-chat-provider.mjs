import {createServer} from 'node:https';
import {readFileSync} from 'node:fs';

// Local-only end-to-end fixture, never a real model or credential store.
const key=readFileSync(process.env.STUDIO_FIXTURE_TLS_KEY),cert=readFileSync(process.env.STUDIO_FIXTURE_TLS_CERT);
let calls=0;
let buildSucceeded=false,buildReport='';
let commandSucceeded=false,commandReport='';
let previewSucceeded=false,previewFrameCount=0,previewReport='';
let latestToolResults=[];
const gameMode=process.env.STUDIO_FIXTURE_GAME==='1';
const buildMode=process.env.STUDIO_FIXTURE_BUILD==='1';
const commandMode=process.env.STUDIO_FIXTURE_COMMAND==='1';
const previewMode=process.env.STUDIO_FIXTURE_PREVIEW==='1';
const scriptBuildKind=['tl','lua','yarn','yue','xml'].includes(process.env.STUDIO_FIXTURE_SCRIPT_BUILD)?process.env.STUDIO_FIXTURE_SCRIPT_BUILD:undefined;
const xmlPlay=process.env.STUDIO_FIXTURE_XML_PLAY==='1'&&scriptBuildKind==='xml';
const invalidScript=process.env.STUDIO_FIXTURE_SCRIPT_INVALID==='1';
const tic80Mode=process.env.STUDIO_FIXTURE_TIC80==='1';
const seed='// Dora Studio · TypeScript\nimport { Vec2 } from "Dora";\n\nexport const start = Vec2(0, 0);\n';
const game='import { DrawNode, Director, Vec2, Color, Size } from "Dora";\nconst node = DrawNode();\nnode.size = Size(360, 180);\nnode.drawPolygon([Vec2(-180,-90), Vec2(180,-90), Vec2(180,90), Vec2(-180,90)], Color(0xff4cc38a));\nnode.onTapBegan(() => { print("STUDIO_FIXTURE_GAME_TAPPED"); });\nDirector.ui.addChild(node);\nprint("STUDIO_FIXTURE_GAME_READY");\n';
const rainGame=game.replace('0xff4cc38a','0xff3b82f6')+'print("STUDIO_FIXTURE_RAIN_READY");\n';
const starGame=rainGame.replace('0xff3b82f6','0xffffc857')+'print("STUDIO_FIXTURE_STAR_READY");\n';
const scriptSource=invalidScript?scriptBuildKind==='xml'?'<Dora><Node Name="STUDIO_FIXTURE_INVALID"></Dora>\n':'print("STUDIO_FIXTURE_INVALID"\n':tic80Mode?'-- tic80\ncls(0)\n':scriptBuildKind==='tl'?'local message: string = "STUDIO_FIXTURE_TEAL_READY"\nprint(message)\n':scriptBuildKind==='yarn'?'title: Start\n---\nSTUDIO_FIXTURE_YARN_READY\n===\n':scriptBuildKind==='yue'?"print 'STUDIO_FIXTURE_YUE_READY'\n":scriptBuildKind==='xml'?'<Dora><Node Name="STUDIO_FIXTURE_XML_READY"/></Dora>\n':'print("STUDIO_FIXTURE_LUA_READY")\n';
const xmlPlaySource='<Dora><DrawNode Name="STUDIO_FIXTURE_XML_READY"><Polygon FillColor="0xff4cc38a"><Vec2 X="-180" Y="-90"/><Vec2 X="180" Y="-90"/><Vec2 X="180" Y="90"/><Vec2 X="-180" Y="90"/></Polygon></DrawNode></Dora>\n';
const xmlPlayEntry='local Dora = require("Dora")\nlocal create = require("main")\nlocal node = create()\nnode.size = Dora.Size(360, 180)\nnode:onTapBegan(function() print("STUDIO_FIXTURE_XML_TAPPED") end)\nDora.Director.ui:addChild(node)\nprint("STUDIO_FIXTURE_XML_GAME_READY")\n';
const server=createServer({key,cert},async(req,res)=>{
  if(req.method==='GET'&&req.url==='/stats'){
    res.setHeader('Content-Type','application/json');res.end(JSON.stringify({calls,buildSucceeded,buildReport,latestToolResults,commandSucceeded,commandReport,previewSucceeded,previewFrameCount,previewReport}));return;
  }
  if(req.method!=='POST'||req.url!=='/v1/chat/completions'){res.statusCode=404;res.end();return;}
  if(req.headers.authorization!=='Bearer test-only-browser-provider-key'){res.statusCode=401;res.end();return;}
  let size=0,raw='';for await(const part of req){size+=part.length;if(size>1024*1024){res.statusCode=413;res.end();return;}raw+=part;}
  let body;try{body=JSON.parse(raw);}catch{res.statusCode=400;res.end();return;}
  if(body.model!=='fixture-model'||!Array.isArray(body.messages)||!body.messages.length){res.statusCode=400;res.end();return;}
  calls++;
  const usage={prompt_tokens:16,completion_tokens:9,total_tokens:25};
  const lastUserIndex=body.messages.findLastIndex(message=>message?.role==='user'),currentPrompt=String(body.messages[lastUserIndex]?.content??'');
  const toolResults=body.messages.slice(lastUserIndex+1).filter(message=>message?.role==='tool');
  latestToolResults=toolResults.slice(-3).map(message=>({id:String(message.tool_call_id??'').slice(0,100),content:String(message.content??'').slice(0,2048)}));
  if(buildMode&&toolResults.length===(xmlPlay?3:2)){
    try{const result=JSON.parse(toolResults[toolResults.length-1].content);buildSucceeded=result.success===true;buildReport=JSON.stringify(result).slice(0,2048);}catch{buildReport='unreadable tool result';}
  }
  if(commandMode&&toolResults.length===3){
    try{const result=JSON.parse(toolResults[toolResults.length-1].content);commandSucceeded=result.success===true;commandReport=String(result.output??result.message??'').slice(0,256);}catch{commandReport='unreadable tool result';}
  }
  if(previewMode&&toolResults.length>=(xmlPlay?4:commandMode?4:3)){
    try{const result=JSON.parse(toolResults[toolResults.length-1].content);previewSucceeded=result.success===true&&result.previewGame?.success===true;previewFrameCount=Number(result.previewGame?.frameCount??0);previewReport=String(result.previewGame?.files?.join(',')??result.output??result.message??'').slice(0,256);}catch{previewReport='unreadable tool result';}
  }
  const hasToolResult=toolResults.length>0;
  const target=scriptBuildKind?`main.${scriptBuildKind}`:'main.ts';
  const continuation=currentPrompt.includes('再增加星光效果')?'star':currentPrompt.includes('增加雨滴效果')?'rain':'initial';
  const oldGame=continuation==='star'?rainGame:continuation==='rain'?game:seed,newGame=continuation==='star'?starGame:continuation==='rain'?rainGame:game;
  const toolCall={index:0,id:`studio_fixture_game_edit_${continuation}`,type:'function',function:{name:'edit_file',arguments:JSON.stringify({path:target,old_str:scriptBuildKind?'':oldGame,new_str:xmlPlay?xmlPlaySource:scriptBuildKind?scriptSource:newGame})}};
  const xmlEntryCall={index:0,id:'studio_fixture_xml_entry_edit',type:'function',function:{name:'edit_file',arguments:JSON.stringify({path:'init.lua',old_str:'',new_str:xmlPlayEntry})}};
  const buildCall={index:0,id:'studio_fixture_game_build',type:'function',function:{name:'build',arguments:JSON.stringify({paths:[target]})}};
  const commandCall={index:0,id:'studio_fixture_game_command',type:'function',function:{name:'execute_command',arguments:JSON.stringify({mode:'lua',code:'print("STUDIO_FIXTURE_COMMAND_OK")',timeoutSeconds:10})}};
  const previewCall={index:0,id:'studio_fixture_game_preview',type:'function',function:{name:'execute_command',arguments:JSON.stringify({mode:'lua',code:xmlPlay?'previewGame({entry="init.lua",captureAtSeconds={0.5}})':'previewGame({entry="main.ts",captureAtSeconds={0.5}})',timeoutSeconds:40})}};
  const nextTool=gameMode&&!hasToolResult?toolCall:gameMode&&xmlPlay&&toolResults.length===1?xmlEntryCall:gameMode&&buildMode&&toolResults.length===(xmlPlay?2:1)?buildCall
    :gameMode&&commandMode&&toolResults.length===2?commandCall
    :gameMode&&previewMode&&toolResults.length===(xmlPlay?3:commandMode?3:2)?previewCall:undefined;
  const choice=nextTool?{index:0,delta:{tool_calls:[nextTool]},finish_reason:'tool_calls'}:
    {index:0,delta:{role:'assistant',content:invalidScript?'构建诊断已收到，需要修复脚本。':gameMode?'游戏已创建，可以试玩。':'我会先创建一个小游戏。'},finish_reason:'stop'};
  if(body.stream){
    res.setHeader('Content-Type','text/event-stream');res.setHeader('Cache-Control','no-store');
    res.write('data: '+JSON.stringify({choices:[choice]})+'\n\n');
    res.write('data: '+JSON.stringify({choices:[],usage})+'\n\n');
    res.end('data: [DONE]\n\n');return;
  }
  res.setHeader('Content-Type','application/json');
  res.end(JSON.stringify({choices:[nextTool?{index:0,message:{role:'assistant',content:null,tool_calls:[nextTool]},finish_reason:'tool_calls'}:
    {index:0,message:{role:'assistant',content:invalidScript?'构建诊断已收到，需要修复脚本。':gameMode?'游戏已创建，可以试玩。':'我会先创建一个小游戏。'},finish_reason:'stop'}],usage}));
});
const port=Number(process.env.STUDIO_FIXTURE_PORT??8962);
if(!Number.isSafeInteger(port)||port<1||port>65535)throw new Error('Invalid fixture port');
server.listen(port,'127.0.0.1',()=>process.stdout.write(`Studio fixture provider listening on https://127.0.0.1:${port}\n`));
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>server.close(()=>process.exit(0)));
