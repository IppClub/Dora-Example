// Native macOS regression: actual SDL event pump, WKWebView and Monaco.
// Requires a built Dora SDL2 library. No engine restart or saved config changes.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join,extname} from 'node:path';
const root=process.env.DORA_SSR_ROOT;if(process.platform!=='darwin'||!root)throw new Error('Set DORA_SSR_ROOT on macOS.');
const require=createRequire(join(root,'Studio/package.json')),{build}=require('esbuild');
const output=join(root,'build/webview-command-qa');await mkdir(output,{recursive:true});
await build({stdin:{contents:`import * as monaco from 'monaco-editor/esm/vs/editor/editor.api.js';window.MonacoEnvironment={getWorker(){return new Worker(URL.createObjectURL(new Blob(['self.onmessage=()=>{}'])));}};window.editor=monaco.editor.create(document.getElementById('editor'),{value:'first\\nsecond\\nthird',language:'plaintext',automaticLayout:true});`,resolveDir:join(root,'Tools/dora-dora'),loader:'js'},bundle:true,format:'iife',outfile:join(output,'fixture.js'),loader:{'.ttf':'file'}});
const html=`<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/fixture.css"><textarea id="t">hello</textarea><div id="editor" style="height:400px"></div><script>window.saves=0;window.savesShift=0;window.finds=0;document.addEventListener('keydown',e=>{if(!e.isTrusted||!e.metaKey)return;if(e.key==='s'){e.shiftKey?savesShift++:saves++;e.preventDefault();}if(e.key==='f'){finds++;e.preventDefault();}});</script><script src="/fixture.js"></script>`;
const server=createServer(async(req,res)=>{try{if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end(html);return;}const file=join(output,new URL(req.url,'http://localhost').pathname.split('/').at(-1));res.setHeader('Content-Type',extname(file)==='.css'?'text/css':extname(file)==='.js'?'text/javascript':'application/octet-stream');res.end(await readFile(file));}catch{res.statusCode=404;res.end();}});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
try{
 const source=await readFile(join(root,'Source/Basic/Application.mm'),'utf8');
 const scriptSource=source.slice(source.indexOf('static NSString* ideEditingShortcutScript()'),source.indexOf('@interface DoraIDEHost'));
 const script=[...scriptSource.matchAll(/@?("(?:\\.|[^"\\])*")/g)].map(match=>JSON.parse(match[1])).join('');
 let listener;const posted=[];
 vm.runInNewContext(script,{window:{addEventListener(name,handler){assert.equal(name,'keydown');listener=handler;},webkit:{messageHandlers:{doraIDEEdit:{postMessage(action){posted.push(action);}}}}}});
 const base={isTrusted:true,defaultPrevented:false,isComposing:false,keyCode:65,metaKey:true,ctrlKey:false,altKey:false,shiftKey:false,key:'a'};
 for(const patch of [{isTrusted:false},{defaultPrevented:true},{isComposing:true},{keyCode:229},{metaKey:false},{ctrlKey:true},{altKey:true},{shiftKey:true},{key:'s'},{key:'q'},{key:'w'},{key:'v'}]){
  const count=posted.length;let prevented=false;listener({...base,...patch,preventDefault(){prevented=true;}});assert.equal(posted.length,count);assert.equal(prevented,false);
 }
 for(const [key,shiftKey,action] of [['a',false,'selectAll'],['x',false,'cut'],['c',false,'copy'],['z',false,'undo'],['Z',true,'redo']]){
  let prevented=false;listener({...base,key,shiftKey,preventDefault(){prevented=true;}});assert.equal(posted.at(-1),action);assert.equal(prevented,true);
 }
 console.log('PASS: production shortcut policy preserves IME, page handlers, other modifiers and unrelated commands.');
 const webview=source.slice(source.indexOf('@interface DoraIDEWebView'),source.indexOf('@interface DoraIDEHost'));
 const menu=source.slice(source.indexOf('\tif (![NSApp.mainMenu itemWithTitle:@"Edit"]'),source.indexOf('\n\n [NSNotificationCenter'));
 const methodStart=source.indexOf('- (void)userContentController:',source.indexOf('@implementation DoraIDEHost'));
 const method=source.slice(methodStart,source.indexOf(' NSArray<NSString*>* parts =',methodStart));assert.match(method,/doraIDEEdit/);
 const port=server.address().port;
 await writeFile(join(output,'WebViewShortcutProduction.inc'),`${webview}\n@interface DoraIDEHost:NSObject<WKScriptMessageHandler>\n@property(weak) NSWindow* window;\n@property(strong) WKWebView* view;\n@property BOOL visible;\n@end\n@implementation DoraIDEHost\n${method.replace('url.port.intValue != 8866',`url.port.intValue != ${port}`)}\n}\n@end\nstatic void installEditMenu(BOOL zh){${menu}}\n`);
 await writeFile(join(output,'clipboard-document.txt'),'Native clipboard document 中文');
 const cli=join(output,'webview-command-test'),frameworks=['Cocoa','WebKit','IOKit','Carbon','CoreAudio','AudioToolbox','CoreVideo','ForceFeedback','GameController','CoreHaptics','Metal','AVFoundation'];
 await promisify(execFile)('clang++',['-std=c++20','-fobjc-arc','-DSDL_MAIN_HANDLED',`-I${join(root,'Source/3rdParty/SDL2/include')}`,`-I${output}`,new URL('./WebViewCommandShortcuts.mm',import.meta.url).pathname,process.env.DORA_SDL_LIBRARY||join(root,'build/macosx/arm64/release/libSDL2.a'),...frameworks.flatMap(x=>['-framework',x]),'-o',cli]);
 const {stdout,stderr}=await promisify(execFile)(cli,[`http://localhost:${port}/`,join(root,'Assets/Image/banner.jpg'),join(output,'clipboard-document.txt')],{timeout:60000});console.log(stdout+stderr);await writeFile(join(output,process.env.DORA_CLIPBOARD_ONLY?'clipboard-regression.log':'regression.log'),stdout+stderr);
}finally{await new Promise(done=>server.close(done));}
