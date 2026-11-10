-- Execute production xmake task callbacks with captured child invocations.
local root=assert(os.getenv('DORA_ENGINE_ROOT') or arg[1], 'Set DORA_ENGINE_ROOT')
local oldStartsWith=string.startswith
string.startswith=function(value,prefix)return value:sub(1,#prefix)==prefix end
local function run(name,options,host)
 local callbacks,calls,writes={},{},{}
 local current
 local path={join=function(...)return table.concat({...},'/')end,
  absolute=function(value,base)return value:sub(1,1)=='/' and value or base..'/'..value end}
 local tables=setmetatable({join=function(...)
  local result={};for _,values in ipairs({...})do for _,value in ipairs(values)do result[#result+1]=value end end;return result
 end},{__index=table})
 local function exec(program,args,settings)calls[#calls+1]={program=program,args=args,settings=settings}end
 local fakeOS={host=function()return host or 'macosx' end,arch=function()return 'arm64' end,
  getenv=function()return nil end,projectdir=function()return '/engine' end,programfile=function()return 'xmake' end,
  isdir=function(value)return value~='/missing' end,isfile=function()return true end,execv=exec,vrunv=exec}
 local env=setmetatable({os=fakeOS,path=path,table=tables,
  io={readfile=function()return 'XMAKE_BUILD_DIR=${BUILD_DIR}/${PLATFORM_NAME}/${NATIVE_ARCH}/${CONFIGURATION}\n-p ${PLATFORM_NAME}\nSUPPORTED_PLATFORMS = "macosx iphoneos";' end,
      writefile=function(file,text)writes[file]=text end},
  task=function(value)current=value end,task_end=function()end,set_category=function()end,set_menu=function()end,
  on_run=function(fn)callbacks[current]=fn end,cprint=function()end,
  option={get=function(key)return options[key]end},import=function(name)assert(name=='core.base.option')end}, {__index=_G})
 assert(loadfile(root..'/Projects/xmake/tasks/native.lua','t',env))()
 local ok,err=pcall(callbacks[name]);return ok,err,calls,writes
end
local function has(args,value)for _,arg in ipairs(args)do if arg==value then return true end end;return false end
local ok,err,calls=run('dora-build',{jobs='6',mode='debug'},'windows')
assert(ok,err);assert(has(calls[1].args,'x64'),'Windows default must match the supported Godot runtime')
ok,err,calls=run('dora-build',{jobs='6',arch='x86_64'},'windows');assert(ok,err);assert(has(calls[1].args,'x64'))
for _,arguments in ipairs({{}, {'--asset','custom assets','--other'}, {'--asset=/custom assets','--other'}})do
 ok,err,calls=run('dora-run',{jobs='6',arguments=arguments})
 assert(ok,err);assert(#calls==3)
 local expected=#arguments==0 and '/engine/Assets' or (arguments[1]=='--asset' and '/engine/custom assets' or '/custom assets')
 assert(calls[1].settings.envs.DORA_NATIVE_RUN_ASSET_DIR==expected)
 assert(calls[2].settings.envs.DORA_NATIVE_RUN_ASSET_DIR==expected)
 local args=calls[3].args
 assert((args[1]=='--asset' and args[2]==expected) or args[1]=='--asset='..expected)
 local count=0;for _,a in ipairs(args)do if a=='--asset' or a:match('^%-%-asset=')then count=count+1 end end
 assert(count==1,'must not insert an earlier default --asset')
end
for _,arguments in ipairs({{'--asset'},{'--asset='},{'--asset','--other'},{'--asset','/one','--asset=/two'},{'--asset','/missing'}})do
 ok,err,calls=run('dora-run',{jobs='6',arguments=arguments})
 assert(not ok and #calls==0,'invalid asset args must fail before building')
end
ok,err,calls=run('dora-run',{jobs='0'});assert(not ok and #calls==0)
ok,err,calls=run('dora-ide',{kind='compile_commands'});assert(ok,err)
assert(calls[1].settings.envs.XMAKE_IN_PROJECT_GENERATOR=='1')
assert(has(calls[2].args,'compile_commands'))
for _,case in ipairs({{platform='macosx',kind='xcode'},{platform='ios',kind='xcode',appledev='device'}, {platform='ios',kind='xcode',appledev='simulator'}})do
 local passed,reason,_,writes=run('dora-ide',case)
 assert(passed,reason)
 local count=0
 for _,text in pairs(writes)do
  count=count+1
  local expected=case.platform=='macosx' and '/engine/build/macosx/' or '/engine/build/iphoneos/'..case.appledev..'/'
  assert(text:find(expected,1,true),'Xcode must copy from the actual application output')
  assert(not text:find('XMAKE_BUILD_DIR=${BUILD_DIR}',1,true))
 end
 assert(count==1)
end
string.startswith=oldStartsWith
print('PASS: native tasks select supported Windows architecture; stage the effective custom/default --asset; reject invalid arguments before build; preserve generator invocation')
