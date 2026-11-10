// Log text/severity must be copied between independent heaps, including teardown.
import assert from 'node:assert/strict';import {pathToFileURL} from 'node:url';import path from 'node:path';
const root=process.env.DORA_ENGINE_ROOT||process.env.DORA_SSR_ROOT;
const {GodotWebBridge}=await import(pathToFileURL(path.join(root,'Tools/Godot/web/runtime_bridge.js')));
const hostBytes=new Uint8Array(16384),godotBytes=new Uint8Array(16384),encoder=new TextEncoder();
let enabled=false,pops=0,freed=0;
const host={HEAPU8:hostBytes};
const godot={HEAPU8:godotBytes,HEAPU32:new Uint32Array(godotBytes.buffer),_malloc:n=>{assert.equal(n,4);return 4;},_free:p=>{assert.equal(p,4);freed++;},
 _dora_web_log_enable:value=>{enabled=!!value;},_dora_web_log_pop:level=>{if(pops++)return 0;godot.HEAPU32[level/4]=2;return 128;},UTF8ToString:p=>{assert.equal(p,128);return 'res://游戏.gd:7: 故意错误 [_ready]';}};
const bridge=new GodotWebBridge(host,godot,{});bridge.scratch=0; // shutdown frees graphics scratch first
assert.equal(bridge.dispatch(23,0,1,0,0,0),1);assert(enabled);
assert.equal(bridge.dispatch(24,100,8193,0,0,0),1);
assert.equal(new DataView(hostBytes.buffer).getUint32(100,true),2);
const expected=encoder.encode('res://游戏.gd:7: 故意错误 [_ready]');assert.deepEqual(hostBytes.subarray(104,104+expected.length),expected);assert.equal(hostBytes[104+expected.length],0);
assert.equal(bridge.dispatch(24,100,8193,0,0,0),0);assert.equal(freed,2);
bridge.dispatch(23,0,0,0,0,0);assert(!enabled);
delete godot._dora_web_log_pop;assert.equal(bridge.dispatch(24,100,8193,0,0,0),0);
console.log('PASS: Web Godot log text/severity copied across heaps, UTF-8, empty queue, teardown without graphics scratch and legacy fallback');
