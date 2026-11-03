local Content=require('Dora').Content
local entry='Test/Creation3D/CacheLifecycle.lua'
if not Content:exist(entry) then entry='CacheLifecycle.lua' end
local root=Content:getFullPath(entry):match('^(.*)/Test/Creation3D/CacheLifecycle.lua$')
Content:insertSearchPath(1,root)
return require('Test.Model3D.CacheLifecycleRegression')
