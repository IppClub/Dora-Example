import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeModelUsage} from '../apps/server/model-usage.mjs';
import {tokenCharge} from '../apps/server/model-amount.mjs';
test('normalized usage preserves overlapping detail without adding it to billing totals',()=>{
 const source={inputTokens:100n,outputTokens:20n,totalTokens:120n,cachedInputTokens:80n,cacheMissInputTokens:20n,reasoningOutputTokens:15n,cacheCreationInputTokens:10n,inputAudioTokens:5n,outputAudioTokens:3n,unrelated:'not retained'};
 const result=normalizeModelUsage(source);assert.equal(result.unrelated,undefined);
 assert.equal(result.cachedInputTokens,80n);assert.equal(result.reasoningOutputTokens,15n);assert.equal(result.cacheCreationInputTokens,10n);assert.equal(result.inputAudioTokens,5n);
 assert.equal(tokenCharge(result,{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:1000000n}),120n);
 source.cachedInputTokens=99n;assert.equal(result.cachedInputTokens,80n);
});
test('missing breakdowns stay unknown rather than zero and invalid counts fail closed',()=>{
 const result=normalizeModelUsage({inputTokens:0n,outputTokens:0n});assert.deepEqual(Object.keys(result),['inputTokens','outputTokens']);
 for(const value of [-1n,1,NaN,null,'1'])assert.throws(()=>normalizeModelUsage({inputTokens:0n,outputTokens:0n,cachedInputTokens:value}),/bigint/);
 assert.throws(()=>normalizeModelUsage({inputTokens:0n}),/bigint/);
});
