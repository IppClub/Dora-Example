local D=require('Dora')
local request=assert(require('json').decode(assert(D.Content:load('Test/Creation3D/evidence/profile-request.json'))))
return require('Test.Creation3D.Profile')(request.name,'Fox',request.mode)
