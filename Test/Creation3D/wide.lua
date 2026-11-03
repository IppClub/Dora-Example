local Content=require('Dora').Content
local path='Test/Creation3D/Input.lua'
if not Content:exist(path) then path='Input.lua' end
local root=Content:getFullPath(path):match('^(.*)/Test/Creation3D/Input.lua$')
assert(root,'Cannot locate Dora-Example root'); Content:insertSearchPath(1,root)
return require('Test.Creation3D.Verify')('wide',{roadWidth=4.8})
