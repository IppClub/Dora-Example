import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const repo=process.env.DORA_TEST_REPO||resolve(process.env.DORA_SSR_ROOT,'../Dora-Example');
const {hasHostBuildPaths,hasCredentialMaterial}=await import(pathToFileURL(resolve(repo,'Test/BuildScripts/web_artifact_policy.mjs')));
test('Godot virtual filesystem roots do not exempt actual host build paths',()=>{
 for(const root of ['.cache','.config','.local/share']){
  assert.equal(hasHostBuildPaths('\0/home/web_user/'+root+'\0','godot/dora-godot.wasm'),false);
  assert.equal(hasHostBuildPaths('\0/home/web_user/'+root+'/source.cpp\0','godot/dora-godot.wasm'),true);
  assert.equal(hasHostBuildPaths('\0/home/web_user/'+root+'\0','dora-player-runtime.wasm'),true);
 }
 for(const path of ['/home/runner/work/repo/','/Users/Jin/Workspace/source.cpp','C:\\Users\\runner\\work\\source.cpp','/home/web_user/project/']){
  assert.equal(hasHostBuildPaths(path,'godot/dora-godot.wasm'),true);
 }
});
test('Mbed TLS parser labels never exempt a PEM payload',()=>{
 for(const kind of ['','RSA ','EC ']){
  const marker='-----BEGIN '+kind+'PRIVATE KEY-----';
  for(const ending of ['','\n']) assert.equal(hasCredentialMaterial('\0'+marker+ending+'\0','godot/dora-godot.wasm'),false);
  assert.equal(hasCredentialMaterial('\0'+marker+'\ntest-only-payload\n','godot/dora-godot.wasm'),true);
  assert.equal(hasCredentialMaterial('\0'+marker+'\0','unrelated.wasm'),true);
 }
});
