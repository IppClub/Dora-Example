-- Execute production xmake task callbacks with captured child invocations.
local root=assert(os.getenv('DORA_ENGINE_ROOT') or arg[1], 'Set DORA_ENGINE_ROOT')
local oldStartsWith=string.startswith
string.startswith=function(value,prefix)return value:sub(1,#prefix)==prefix end
local function run(name,options,host)
 local callbacks,calls,writes={},{},{}
 local current
 local path={join=function(...)return table.concat({...},'/')end,
  absolute=function(value,base)return value:sub(1,1)=='/' and value or base..'/'..value end,filename=function(v)return v:match("[^/]+$")end}
 local tables=setmetatable({join=function(...)
  local result={};for _,values in ipairs({...})do for _,value in ipairs(values)do result[#result+1]=value end end;return result
 end},{__index=table})
 local function exec(program,args,settings)calls[#calls+1]={program=program,args=args,settings=settings}end
 local fakeOS={host=function()return host or 'macosx' end,arch=function()return 'arm64' end,
  getenv=function()return nil end,projectdir=function()return '/engine' end,programfile=function()return 'xmake' end,
  execv=function(binary,args)calls.binary=binary;calls.arguments=args end,
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
local ok,err,calls=run('project-gen',{kind='compile_commands'},'windows')
assert(ok,err);assert(has(calls[1].args,'x64'))
ok,err,calls=run('project-gen',{kind='compile_commands',arch='x86_64'},'windows')
assert(ok,err);assert(has(calls[1].args,'x64'))
ok,err,calls=run('project-gen',{kind='compile_commands'});assert(ok,err)
assert(calls[1].settings.envs.XMAKE_IN_PROJECT_GENERATOR=='1')
assert(has(calls[2].args,'compile_commands'))
for _,case in ipairs({{platform='macosx',kind='xcode'},{platform='ios',kind='xcode',appledev='device'}, {platform='ios',kind='xcode',appledev='simulator'}})do
 local passed,reason,_,writes=run('project-gen',case)
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
-- Run the real before_run module with a captured component staging service.
local function prepare(arguments,debug)
 local calls={};local options={arguments=arguments,debug=debug}
 local path={join=function(...)return table.concat({...},'/')end,
  absolute=function(value,base)return value:sub(1,1)=='/' and value or base..'/'..value end,filename=function(v)return v:match("[^/]+$")end}
 local tables=setmetatable({join=function(values)local r={};for _,v in ipairs(values)do r[#r+1]=v end;return r end},{__index=table})
 -- table.join also accepts the default argument prefix.
 tables.join=function(...)local r={};for _,values in ipairs({...})do for _,v in ipairs(values)do r[#r+1]=v end end;return r end
 local target={plat=function()return 'macosx' end,is_plat=function(_,name)return name=='macosx' end,
  get=function()end,set=function(_,name,...)calls[name]={...}end,
  targetfile=function()return '/engine/build/Dora' end,data=function()return '/engine/build/Dora.app/Contents' end}
 local env=setmetatable({path=path,table=tables,
  os={host=function()return 'macosx' end,projectdir=function()return '/engine' end,
      execv=function(binary,args)calls.binary=binary;calls.arguments=args end,
      isdir=function(value)return value~='/missing' end,getenv=function()end},
  option={get=function(key)return options[key]end},
  debugger={run=function(binary,args)calls.debug=true;calls.binary=binary;calls.arguments=args end},
  runenvs={make=function()return {},{} end,join=function()return {} end},
  config={get=function()return true end},import=function(name)
   if name=='Projects.xmake.godot.component' then
    return function(t,staging,assets)assert(t==target and staging);calls.assets=assets end
   end
   assert(name=='core.base.option' or name=='core.project.config' or name=='devel.debugger' or name=='private.action.run.runenvs')
  end},{__index=_G})
 assert(loadfile(root..'/Projects/xmake/tools/native_run.lua','t',env))()
 local ok,err=pcall(env.main,target);return ok,err,calls.arguments,calls
end
for _,args in ipairs({{}, {'--asset','custom assets','--other'}, {'--asset=/custom assets','--other'}})do
 local ok,err,actual,calls=prepare(args);assert(ok,err)
 local expected=#args==0 and '/engine/Assets' or (args[1]=='--asset' and '/engine/custom assets' or '/custom assets')
 assert(calls.assets==expected)
 assert(calls.runenv[1]=='DORA_GODOT_LIBRARY' and calls.runenv[2]==expected..'/libdora_godot.dylib')
 assert((actual[1]=='--asset' and actual[2]==expected) or actual[1]=='--asset='..expected)
 local count=0;for _,v in ipairs(actual)do if v=='--asset' or v:match('^%-%-asset=')then count=count+1 end end
 assert(count==1)
end
do
 local ok,err,args,calls=prepare({'--','--asset','/custom assets'})
 assert(ok,err);assert(args[1]=='--asset' and args[2]=='/custom assets')
 assert(calls.assets=='/custom assets')
end
do
 local ok,err,args,calls=prepare({},true)
 assert(ok,err);assert(calls.debug and args[1]=='--asset')
 assert(calls.binary=='/engine/build/Dora.app/Contents/MacOS/Dora')
end
for _,args in ipairs({{'--asset'},{'--asset='},{'--asset','--other'},{'--asset','/one','--asset=/two'},{'--asset','/missing'}})do
 local ok,_,_,calls=prepare(args);assert(not ok and not calls.assets)
end
local engine=assert(io.open(root..'/Projects/xmake/engine.lua')):read('a')
assert(engine:find('set_default(true)',1,true))
local main=assert(io.open(root..'/xmake.lua')):read('a')
assert(main:find('set_policy("run.autobuild", true)',1,true))
string.startswith=oldStartsWith
print('PASS: project generation selects supported architectures/output paths; built-in run hook handles default/custom assets and runtime staging; Dora is the default target with run.autobuild')
