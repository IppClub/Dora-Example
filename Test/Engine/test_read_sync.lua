-- Exercise the generated production GET/POST compiler-read handler unchanged.
local root = assert(os.getenv('DORA_ENGINE_ROOT') or arg[1], 'Set DORA_ENGINE_ROOT')
local file = assert(io.open(root .. '/Assets/Script/Dev/WebServer.lua'))
local source = file:read('a'); file:close()
local first = assert(source:find('local readSyncFile', 1, true))
local last = assert(source:find('local addGeneratedSourceHeader', first, true))
local fallback = assert(source:find('local projectFallbackPaths', 1, true))
local fallbackEnd = assert(source:find('local withProjectSearchPaths', fallback, true))
local files = {['/game/types/support.d.ts']='declare const value: number;', ['/game/main.ts']='export const ready = true;',
 ['/game/entry.lua']='return "root"', ['/game/Script/entry.lua']='return "Script"'}
local dirs = {['/game']=true,['/game/types']=true,['/game/Script']=true}
local function join(...)return table.concat({...},'/'):gsub('//+','/')end
local path = setmetatable({getPath=function(_,p)return p:match('^(.*)/') or '' end},{__call=function(_,...)return join(...)end})
local content = {
 exist=function(_,p)return files[p]~=nil or dirs[p]==true end,
 isdir=function(_,p)return dirs[p]==true end,
 isAbsolutePath=function(_,p)return p:sub(1,1)=='/' end,
 load=function(_,p)return files[p]end,
 getFullPath=function(_,p)return p end,
}
local get,post
local env=setmetatable({Content=content,Path=path,getProjectDirFromFile=function()return nil end,HttpServer={
 get=function(_,url,handler)assert(url=='/read-sync');get=handler end,
 post=function(_,url,handler)assert(url=='/read-sync');post=handler end,
}},{__index=_G})
local dora = setmetatable({Content=content, Path=path}, {__index=_G})
local utils = assert(loadfile(root .. '/Assets/Script/Lib/Utils.lua', 't', setmetatable({Dora=dora}, {__index=_G})))()
env.GetProjectSearchPaths = utils.GetProjectSearchPaths
assert(load(source:sub(fallback,fallbackEnd-1) .. source:sub(first,last-1),'production read-sync','t',env))()
for _,params in ipairs({
 {path='/game/main.ts'},
 {path='types/support',exts='.ts|.d.ts',projectRoot='/game',projFile='/game/init.ts'},
 {path='types/support.d.ts',projFile='/game/init.ts'},
 {path='entry.lua',projectRoot='/game'},
 {path='missing',projectRoot='/game'},
 {path=''},
 {path=42},
})do
 local old,new=get({params=params}),post({body=params})
 assert(old.success==new.success and old.content==new.content and old.fullPath==new.fullPath)
 if params.path=='entry.lua' then assert(new.fullPath=='/game/Script/entry.lua') end
 if params.path=='missing' or params.path=='' or params.path==42 then assert(not new.success) else assert(new.success and new.content)end
end
assert(not post({}).success)
assert(not post({body={}}).success)
print('PASS: production sync GET and JSON POST resolve identical files, extensions and project roots; invalid/missing targets fail')
