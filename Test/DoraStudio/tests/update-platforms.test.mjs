import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

test('generated updater Lua accepts old/new releases and selects only the installed desktop architecture', async()=>{
 const dir=await mkdtemp(join(tmpdir(),'dora-update-platform-'));
 try{
  const program=join(dir,'check.lua');
  await writeFile(program,`local root=assert(arg[1])
package.path=root.."/Assets/Script/Lib/?.lua;"..package.path
local decoded,architectures,exists
local app={platform="Windows"}
package.preload.Dora=function()return{App=app,Content={exist=function()return exists end,load=function(_,p)return p end},json={decode=function(s)if s=="manifest" then return decoded else return{architectures=architectures}end end},Path={getFilename=function(_,s)return s:match("[^/]+$")end},PlatformType={Android="Android",Windows="Windows",macOS="macOS"}}end
local function module()return dofile(root.."/Assets/Script/Tools/SelfUpdater/Manifest.lua")end
local m=module()
local function release(version,platforms)
 local packages={}
 for _,p in ipairs(platforms)do local file="dora-ssr-"..version.."-"..p..".zip";packages[p]={ref="refs/tags/"..version.."-0-"..p,commit=string.rep("a",40),file=file,size=42,sha256=string.rep("b",64),github="https://github.com/IppClub/Dora-SSR/releases/download/"..version.."/"..file}end
 return{["$schema"]="./schema/stable-v1.schema.json",schemaVersion=1,channel="stable",version=version,revision=0,publishedAt="2026-11-05T00:00:00Z",packages=packages}
end
local old={"android","windows-x86","macos-universal"};local new={"android","windows-x64","macos-arm64"}
assert(table.concat(m.updatePlatformsForVersion("v1.9.4"),",")==table.concat(old,","))
assert(table.concat(m.updatePlatformsForVersion("v1.10.0"),",")==table.concat(new,","))
decoded=release("v1.9.4",old);assert(m.parseUpdateManifest("manifest").manifest)
decoded=release("v1.10.0",new);assert(m.parseUpdateManifest("manifest").manifest)
decoded=release("v1.10.0",old);assert(not m.parseUpdateManifest("manifest").manifest)
exists=true;architectures={"x86_64"};app.platform="Windows";assert(module().updatePlatformForApp()=="windows-x64")
architectures={"arm64"};app.platform="macOS";assert(module().updatePlatformForApp()=="macos-arm64")
architectures={"x86_64"};assert(module().updatePlatformForApp()==nil)
exists=false;assert(module().updatePlatformForApp()==nil)
app.platform="Android";assert(module().updatePlatformForApp()=="android")
print("PASS legacy/new manifests, filenames, architecture selection and slim-build rejection")
`);
  const engine=resolve(process.env.DORA_STUDIO_ROOT,'..');
  const result=spawnSync(process.env.DORA_LUA||'lua',[program,engine],{encoding:'utf8'});
  assert.equal(result.status,0,result.stdout+result.stderr);
 }finally{await rm(dir,{recursive:true,force:true});}
});
