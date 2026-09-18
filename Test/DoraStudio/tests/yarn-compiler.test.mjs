import test from 'node:test';
import assert from 'node:assert/strict';
import createModule from '../packages/agent-contracts/dist/yarn/compiler.mjs';

const module=await createModule(),encoder=new TextEncoder();
const check=module.cwrap('yarn_check_file','number',['number','number']);
const message=module.cwrap('yarn_error_message','string',[]);
const line=module.cwrap('yarn_error_line','number',[]);
function run(text){
  const bytes=encoder.encode(text),pointer=module._malloc(Math.max(1,bytes.length));
  assert.ok(pointer);
  try{module.HEAPU8.set(bytes,pointer);const failed=check(pointer,bytes.length);return {failed,message:failed?message():undefined,line:failed?line():undefined};}
  finally{module._free(pointer);}
}

test('isolated WebAssembly Yarn checker reuses original yarnflow::compileFile for a complete node',()=>{
  assert.deepEqual(run('title: Start\n---\nHello world\n===\n'),{failed:0,message:undefined,line:undefined});
});

test('Yarn checker preserves original file-format diagnostic for empty content',()=>{
  const result=run('title: Start\n---\n===\n');
  assert.equal(result.failed,1);assert.equal(result.line,3);
  assert.match(result.message,/node content cannot be empty/);
});
