import test from 'node:test';
import assert from 'node:assert/strict';
import {tokenCharge,availableModelAmount,settleModelReservation} from '../apps/server/model-amount.mjs';
const rates={inputNanoCnyPerMillion:2000000000n,outputNanoCnyPerMillion:8000000000n};
test('token amounts use exact integer arithmetic and one total rounding',()=>{
 assert.equal(tokenCharge({inputTokens:1000000n,outputTokens:1000000n},rates),10000000000n);
 assert.equal(tokenCharge({inputTokens:1n,outputTokens:1n},{inputNanoCnyPerMillion:1n,outputNanoCnyPerMillion:1n}),1n);
 assert.equal(tokenCharge({inputTokens:0n,outputTokens:0n},rates),0n);
 assert.throws(()=>tokenCharge({inputTokens:1,outputTokens:0n},rates));
 assert.throws(()=>tokenCharge({inputTokens:-1n,outputTokens:0n},rates));
});
test('available amount takes the smaller remaining bound without adding balances',()=>{
 const values={accountLimit:100n,accountSpent:20n,accountReserved:10n,grantLimit:60n,grantSpent:10n,grantReserved:5n};
 assert.equal(availableModelAmount(values),45n);
 assert.equal(availableModelAmount({...values,accountReserved:100n}),0n);
 assert.equal(availableModelAmount({...values,grantSpent:100n}),0n);
});
test('settlement retains missing usage and records overage without hiding consumption',()=>{
 assert.deepEqual(settleModelReservation(100n,null,rates),{state:'pending-usage',reserved:100n});
 assert.deepEqual(settleModelReservation(10000n,{inputTokens:1n,outputTokens:0n},rates),{state:'settled',charged:2000n,released:8000n,overage:0n});
 assert.deepEqual(settleModelReservation(1000n,{inputTokens:1n,outputTokens:0n},rates),{state:'settled',charged:2000n,released:0n,overage:1000n});
 assert.throws(()=>settleModelReservation(100n,{},rates));
});
