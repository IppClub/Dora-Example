local D=require('Dora'); local json=require('json')
local root=D.Content:getFullPath('Test/Creation3D/LoaderFailure.lua'):match('^(.*)/Test/Creation3D/LoaderFailure.lua$')
D.Content:insertSearchPath(1,root..'/Example/Creation3D')
local Assets=require('Assets'); local Config=require('Kit.Config'); local Game=require('Game')
local output=root..'/Test/Creation3D/evidence/'
D.thread(function()
  local checks={}
  Assets.missing=Config.copy(Assets.Fox); Assets.missing.path='assets/missing-loader.glb'
  local pending=Game.launch({asset='missing'})
  repeat D.sleep() until pending.phase~='loading'
  assert(pending.phase=='failed' and not pending.game and pending.diagnostics[1].code=='RESOURCE_NOT_FOUND')
  checks[#checks+1]='missing local asset rejects before async loading and creates no game'
  local js='{"asset":"invalid"}'; js=js..string.rep(' ',(-#js)%4)
  local function u32(n) return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256) end
  local file=output..'invalid-loader.glb'
  assert(D.Content:save(file,'glTF'..u32(2)..u32(20+#js)..u32(#js)..'JSON'..js))
  Assets.invalid=Config.copy(Assets.Fox); Assets.invalid.path=file
  pending=Game.launch({asset='invalid'})
  repeat D.sleep() until pending.phase~='loading'
  assert(pending.phase=='failed' and not pending.game and pending.diagnostics[1].code=='GLTF_PARSE_FAILED')
  checks[#checks+1]='async decoder failure reports LOAD_FAILED with no synchronous fallback'
  D.Cache:unload(file)
  js='{"asset":{"version":"2.0"}}'; js=js..string.rep(' ',(-#js)%4)
  assert(D.Content:save(file,'glTF'..u32(2)..u32(20+#js)..u32(#js)..'JSON'..js))
  pending=Game.launch({asset='invalid'})
  repeat D.sleep() until pending.phase~='loading'
  assert(pending.phase=='failed' and not pending.game and pending.diagnostics[1].code=='ADAPTATION_FAILED')
  checks[#checks+1]='loaded but degenerate model fails adaptation without stuck loading or ready success'
  D.Cache:unload(file);D.Content:remove(file);Assets.missing=nil;Assets.invalid=nil
  assert(D.Content:save(output..'loaderfailure.json',assert(json.encode({status='passed',checks=checks}))))
end)
