import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';
const bundle=await build({stdin:{contents:`import {createElement} from 'react';import {renderToStaticMarkup} from 'react-dom/server';import {ModelAllowanceView,ModelAllowanceCompactView,decodeAllowance,formatNanoCny} from './ModelAllowance';export {decodeAllowance,formatNanoCny};export const render=data=>renderToStaticMarkup(createElement(ModelAllowanceView,{data}));export const renderCompact=data=>renderToStaticMarkup(createElement(ModelAllowanceCompactView,{data}));`,resolveDir:resolve('apps/web/src'),loader:'tsx'},bundle:true,write:false,format:'cjs',platform:'node',jsx:'automatic',loader:{'.css':'empty'}});
const mod={exports:{}};new Function('module','exports','require',bundle.outputFiles[0].text)(mod,mod.exports,createRequire(import.meta.url));
const {decodeAllowance,formatNanoCny,render,renderCompact}=mod.exports;
const fixture=()=>({api:{spent:'0',reserved:'0',limit:'0'},version:1,currency:'CNY',unit:'nano-CNY',funding:'platform',grantId:'g',state:'available',available:'5000000000',account:{spent:'1',reserved:'2000000000',limit:'10000000000'},grant:{spent:'1',reserved:'2000000000',limit:'7000000001'}});
test('CNY display retains tiny consumption and does not use floating point rounding',()=>{
 assert.equal(formatNanoCny('0'),'¥0.00');assert.equal(formatNanoCny('1'),'< ¥0.01');assert.equal(formatNanoCny('10000000'),'¥0.01');
 assert.equal(formatNanoCny('1234567890'),'≈ ¥1.23');assert.equal(formatNanoCny('9007199254740993000000000'),'¥9007199254740993.00');
 assert.equal(formatNanoCny('4999999999'),'≈ ¥5.00');assert.equal(formatNanoCny('19999999'),'≈ ¥0.02');
 for(const value of ['-1','1.2','01',1])assert.throws(()=>formatNanoCny(value));
});
test('allowance decoding binds grant, currency and availability state',()=>{
 const source=fixture(),copy=decodeAllowance(source,'g');source.account.spent='999';assert.equal(copy.account.spent,'1');
 for(const patch of [{grantId:'foreign'},{currency:'USD'},{available:5},{available:null},{state:'unavailable'},{unit:'cent'}])assert.throws(()=>decodeAllowance({...fixture(),...patch},'g'));
 assert.equal(decodeAllowance({...fixture(),state:'unavailable',available:null},'g').available,null);
});
test('view separates platform usage, reservation and unavailable balances',()=>{
 const html=render(decodeAllowance(fixture(),'g'));assert.match(html,/¥5.00/);assert.match(html,/&lt; ¥0.01/);assert.match(html,/本次请求暂时预留/);assert.match(html,/不是供应商余额/);
 const disabled=render(decodeAllowance({...fixture(),state:'unavailable',available:null},'g'));assert.match(disabled,/不可用/);assert.doesNotMatch(disabled,/¥5.00/);
});
test('compact view keeps only allowance and actionable state',()=>{
 const available=renderCompact(decodeAllowance(fixture(),'g'));assert.match(available,/可用额度/);assert.match(available,/¥5.00/);assert.doesNotMatch(available,/使用明细|账号已使用/);
 const blocked=renderCompact(decodeAllowance({...fixture(),state:'concurrency'},'g'));assert.match(blocked,/并发已满/);
});
