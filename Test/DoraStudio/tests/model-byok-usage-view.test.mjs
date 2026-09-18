import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';
const bundle=await build({stdin:{contents:`import {createElement} from 'react';import {renderToStaticMarkup} from 'react-dom/server';import {ByokUsageView} from './ByokUsage';export {decodeByokUsage} from './byok-usage-client';export const render=report=>renderToStaticMarkup(createElement(ByokUsageView,{report}));`,resolveDir:resolve('apps/web/src'),loader:'tsx'},bundle:true,write:false,format:'cjs',platform:'node',jsx:'automatic',loader:{'.css':'empty'}});
const mod={exports:{}};new Function('module','exports','require',bundle.outputFiles[0].text)(mod,mod.exports,createRequire(import.meta.url));const {decodeByokUsage,render}=mod.exports;
const fixture=()=>({version:1,funding:'byok',summary:{registeredRequests:'2',knownUsageRequests:'1',pendingUsageRequests:'1',inputTokens:'9007199254740993',outputTokens:'2'},records:[{requestId:'a',projectId:'project',configurationId:'config',model:'<script>model</script>',state:'recorded',usage:{inputTokens:'9007199254740993',outputTokens:'2',cachedInputTokens:'10'},createdAt:0},{requestId:'b',projectId:'project',configurationId:'config',model:'model',state:'pending-usage',usage:null,createdAt:0}],nextCursor:'b'});
test('BYOK usage view preserves precision and distinguishes unknown usage from zero',()=>{
 const report=decodeByokUsage(fixture()),html=render(report);
 assert.match(html,/9,007,199,254,740,993/);assert.match(html,/待补记请求/);assert.match(html,/用量尚未返回/);assert.match(html,/不代表免费/);
 assert.match(html,/&lt;script&gt;/);assert.doesNotMatch(html,/<script>/);
 assert.equal(report.records[1].usage,null);
});
test('usage decoder rejects inconsistent summaries, duplicate rows and invalid cursor or counters',()=>{
 const mutations=[value=>value.summary.pendingUsageRequests='0',value=>value.records[1].usage={inputTokens:'0',outputTokens:'0'},value=>value.records[1].requestId='a',value=>value.nextCursor='foreign',value=>value.records[0].usage.cachedInputTokens=-1,value=>value.summary.inputTokens=9007199254740993];
 for(const mutate of mutations){const value=fixture();mutate(value);assert.throws(()=>decodeByokUsage(value));}
 const original=fixture(),copy=decodeByokUsage(original);original.records[0].usage.inputTokens='0';assert.equal(copy.records[0].usage.inputTokens,'9007199254740993');
 assert.throws(()=>decodeByokUsage({...fixture(),records:[],nextCursor:undefined}));
 assert.equal(decodeByokUsage({...fixture(),nextCursor:null}).nextCursor,null);
});
