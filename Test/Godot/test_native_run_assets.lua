-- Run with: lua Test/Godot/test_native_run_assets.lua /path/to/Dora-SSR
table.join2=function(target,values) for _,value in ipairs(values) do target[#target+1]=value end end
local root = assert(arg[1])
local function join(...)
    return table.concat({...}, '/'):gsub('//+', '/')
end
local calls, removed, invalidated, receipt
local configValues, environment
local target = {
    plat=function() return configValues.platform end,
    arch=function() return configValues.arch end,
    targetdir=function() return '/output' end,
    data=function(_,key)
        if configValues.platform ~= 'macosx' then return nil end
        return key=='xcode.bundle.rootdir' and '/bundle' or '/bundle/Resources'
    end,
    dependfile=function() return '/signature-dependency' end,
}
local env = setmetatable({
    path={join=join,absolute=function(p)return p end},
    os={projectdir=function()return root end,getenv=function(key)return environment[key] end,
        programfile=function()return '/xmake' end,
        exists=function()return true end,rm=function(p)removed[#removed+1]=p end,
        tryrm=function(p)invalidated[#invalidated+1]=p end,
        vrunv=function(program,args,opts)calls[#calls+1]={program=program,args=args,opts=opts} end},
}, {__index=_G})
env.import=function(name)
    if name=='lib.detect.find_tool' then env.find_tool=function()return {program='/python'}end
    elseif name=='core.base.json' then env.json={loadfile=function()return receipt end}
    elseif name=='core.project.config' then env.config={get=function(key)return configValues[key]end,mode=function()return configValues.mode end}
    else error(name) end
end
local function setup(platform,mode,enabled,backend)
    calls,removed,invalidated={},{},{}
    receipt={staged_changed=true}
    configValues={platform=platform,mode=mode,arch='arm64',dora_godot_runtime=enabled,dora_godot_windows_backend=backend}
    environment={}
end
assert(loadfile(root..'/Projects/xmake/godot/component.lua','t',env))()
for _, platform in ipairs({'macosx','linux','windows'}) do
    for _,mode in ipairs({'debug','release'}) do
        setup(platform,mode,true,'d3d12')
        env.main(target,true,'/source/Assets')
        assert(#calls==1 and #invalidated==0)
        local args=calls[1].args
        local options={}
        for i=2,#args do if args[i]:sub(1,2)=='--' then options[args[i]]=args[i+1] end end
        assert(options['--stage']=='/source/Assets')
        assert(options['--mode']==mode and options['--arch']=='arm64' and options['--platform']==platform)
        assert(options['--output']:match('/run%-assets.json$'))
        assert(options['--stage-only'])
        if platform=='windows' then assert(options['--windows-backend']=='d3d12') end
    end
end
setup('windows','debug',true,'wgl')
environment.DORA_GODOT_RUNTIME_DIR='/custom/runtime'
env.main(target,true,'/source/Assets')
local text=table.concat(calls[1].args,' ')
assert(text:find('/custom/runtime',1,true) and text:find('wgl',1,true))
setup('macosx','debug',true)
env.main(target,true)
assert(#invalidated==1, 'Bundle staging must still invalidate its signature')
setup('macosx','debug',false)
env.main(target,true,'/source/Assets')
assert(#calls==0 and #invalidated==0 and #removed==5)
for _,p in ipairs(removed) do assert(p:sub(1,15)=='/source/Assets/') end
-- Exercise the production rule: always stage the bundle, and stage run assets
-- only when the launcher supplied its dedicated subprocess environment.
local before,componentCalls
local rules=setmetatable({
    is_plat=function()return true end,
    os={getenv=function(key)return environment[key] end,projectdir=function()return root end},
    target=function()end,target_end=function()end,set_kind=function()end,set_default=function()end,set_group=function()end,
    on_build=function()end,rule=function()end,rule_end=function()end,on_config=function()end,
    before_build=function(fn)before=fn end,
    import=function()return function(...)componentCalls[#componentCalls+1]={...}end end,
}, {__index=_G})
setup('macosx','debug',true)
assert(loadfile(root..'/Projects/xmake/godot/component_targets.lua','t',rules))()
componentCalls={};before(target);assert(#componentCalls==1)
environment.DORA_NATIVE_RUN_ASSET_DIR='/source/Assets'
componentCalls={};before(target);assert(#componentCalls==2 and componentCalls[2][3]=='/source/Assets')
print('PASS: native run asset staging: platforms/modes/backends, custom package, disabled cleanup, signature isolation and rule routing')
