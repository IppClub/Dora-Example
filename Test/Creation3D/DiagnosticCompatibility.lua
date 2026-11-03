-- Existing model/PBR/morph/skin fixtures must still import through the stricter guard.
local D=require('Dora');local json=require('json')
local entry='Test/Creation3D/DiagnosticCompatibility.lua'
if not D.Content:exist(entry) then entry='DiagnosticCompatibility.lua' end
local root=D.Content:getFullPath(entry):match('^(.*)/Test/Creation3D/DiagnosticCompatibility.lua$')
local base=root..'/Test/Model3D/Assets/Model/'
local output=root..'/Test/Creation3D/evidence/'
D.thread(function()
  local results={}
  for _,file in ipairs(D.Content:getAllFiles(base)) do
    if file:lower():match('%.glb$') or file:lower():match('%.gltf$') then
      local path=base..file
      local ok=D.Cache:loadAsync(path)
      local report=assert(json.decode(D.Cache:getLoadDiagnostics(path)))
      results[#results+1]={file=file,success=ok,report=report}
      D.Content:save(output..'compatibility-progress.json',assert(json.encode(results)))
      assert(ok,'Existing fixture failed: '..file..' '..json.encode(report))
      D.Cache:unload(path)
    end
  end
  assert(#results>=15,'Expected existing model corpus')
  D.Content:save(output..'diagnosticcompatibility.json',assert(json.encode({status='passed',checks=results})))
  print('MODEL_DIAGNOSTIC_COMPATIBILITY PASS '..#results)
end)
