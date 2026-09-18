import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-text-merge.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {mergeCloudText:merge}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
test('text merge combines separate and adjacent edits preserving newline and BOM bytes',()=>{
 assert.equal(merge('\ufeffa\r\nb\r\nc','\ufeffA\r\nb\r\nc','\ufeffa\r\nb\r\nC'),'\ufeffA\r\nb\r\nC');
 assert.equal(merge('a\nb\nc\n','A\nb\nc\n','a\nB\nc\n'),'A\nB\nc\n');
 assert.equal(merge('a\nb\nc\nd\n','a\nc\nd\n','a\nb\nc\nD\n'),'a\nc\nD\n');
 assert.equal(merge('a\nb\nc','x\na\nb\nc','a\nb\nc\ny'),'x\na\nb\nc\ny');
});
test('text merge leaves overlapping edits and competing insertions unresolved',()=>{
 assert.equal(merge('a\nb','A\nb','B\nb'),null);
 assert.equal(merge('a\nb','x\na\nb','y\na\nb'),null);
 assert.equal(merge('a\nb','a\nb\nx','a\nb\ny'),null);
 assert.equal(merge('a','same','same'),'same');
 assert.equal(merge('a','a',''), '');
 assert.equal(merge('a\n'.repeat(1100),'b\n'.repeat(1100),'c\n'.repeat(1100)),null);
});
