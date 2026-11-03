-- Real native importer contract tests, without log parsing or mocked loading.
local D=require('Dora'); local json=require('json')
local root=D.Content:getFullPath('Test/Creation3D/Diagnostics.lua'):match('^(.*)/Test/Creation3D/Diagnostics.lua$')
D.Content:insertSearchPath(1,root..'/Example/Creation3D')
local dir=root..'/Test/Creation3D/Fixtures/Diagnostics/'
local output=root..'/Test/Creation3D/evidence/'
local function read(file) return assert(json.decode(D.Cache:getLoadDiagnostics(file))) end
local checks,reports={},{}
local function check(value,message) assert(value,message); checks[#checks+1]=message end
local cases={
  {'absent.glb',false,'RESOURCE_NOT_FOUND','read'},
  {'parse.glb',false,'GLTF_PARSE_FAILED','parse'},
  {'invalid-index.glb',false,'GLTF_VALIDATION_FAILED','parse'},
  {'missing-buffer.glb',false,'RESOURCE_READ_FAILED','buffers'},
  {'short-buffer.glb',false,'BUFFER_TOO_SHORT','buffers'},
  {'missing-image.glb',false,'RESOURCE_READ_FAILED','images','pbrMetallicRoughness.baseColorTexture'},
  {'decode-image.glb',false,'IMAGE_DECODE_FAILED','images','pbrMetallicRoughness.baseColorTexture'},
  {'embedded-decode.glb',false,'IMAGE_DECODE_FAILED','images','pbrMetallicRoughness.baseColorTexture'},
  {'shared-image.glb',false,'RESOURCE_READ_FAILED','images','normalTexture'},
  {'uri.glb',false,'RESOURCE_URI_INVALID','images','pbrMetallicRoughness.baseColorTexture'},
  {'empty.glb',true,'NO_RENDERABLE_GEOMETRY','prepare'},
  {'warning.glb',true,'EXTENSION_VALIDATION_RELAXED','parse'},
  {'wide-texture.glb',true,'TEXTURE_DIMENSIONS_UNSUPPORTED','prepare','pbrMetallicRoughness.baseColorTexture'},
  {'valid.glb',true},
}
local function verify(file,success,case,mode)
  local report=read(file)
  check(report.version==1 and type(report.diagnostics)=='table',mode..' schema '..case[1])
  check(success==case[2] and report.state==(case[2] and 'ready' or 'failed'),mode..' result '..case[1])
  check(report.modelPath==file,mode..' model path '..case[1])
  if case[3] then
    local found
    for _,d in ipairs(report.diagnostics) do if d.code==case[3] and d.stage==case[4] and (not case[5] or d.textureSlot==case[5]) then found=d end end
    check(found~=nil,mode..' code/stage/slot '..case[1])
    check(found.severity==(case[2] and 'warning' or 'error') and #found.message>0 and #found.resourcePath>0,mode..' severity/reason/resource '..case[1])
    if case[5] then check(found.imageIndex==0 and found.materialIndex==0,mode..' material/image '..case[1]) end
  else check(#report.diagnostics==0,mode..' clean success') end
  local hasError=false;for _,d in ipairs(report.diagnostics) do if d.severity=='error' then hasError=true end end
  check(hasError~=case[2],mode..' report errors match result '..case[1])
  return report
end
D.thread(function()
  check(type(D.Cache.getLoadDiagnostics)=='function' and D.Cache.getLoadError==nil,'only the unified diagnostic getter is exported')
  check(read(dir..'never-requested.glb').state=='none','query is read-only before any attempt')
  for _,case in ipairs(cases) do
    local file=dir..case[1]; D.Cache:unload(file)
    local loaded=D.Cache:load(file)
    local sync=verify(file,loaded,case,'sync')
    D.Cache:unload(file)
    local success=D.Cache:loadAsync(file)
    local async=verify(file,success,case,'async')
    check(json.encode(sync)==json.encode(async),'same sync/async structured result '..case[1])
    reports[#reports+1]={fixture=case[1],sync=sync,async=async}
    if case[2] then
      local snapshot=D.Cache:getLoadDiagnostics(file)
      check(D.Cache:load(file) and D.Cache:loadAsync(file),'cache hit succeeds '..case[1])
      check(D.Cache:getLoadDiagnostics(file)==snapshot,'cache hit preserves warnings '..case[1])
    end
  end
  -- Retry without unloading the failed report: success must replace every old error.
  local retry=dir..'retry.glb'; D.Cache:unload(retry)
  assert(D.Content:save(retry,assert(D.Content:load(dir..'parse.glb'))))
  check(not D.Cache:loadAsync(retry),'retry starts with a real failed import')
  local old=D.Cache:getLoadDiagnostics(retry)
  assert(D.Content:save(retry,assert(D.Content:load(dir..'valid.glb'))))
  check(D.Cache:load(retry),'sync retry succeeds')
  check(read(retry).state=='ready' and #read(retry).diagnostics==0,'success clears old diagnostics')
  check(json.decode(old).state=='failed','prior returned snapshot remains immutable')
  -- Concurrent imports + coalesced requests must not read a shared last-error slot.
  local done=0; local parallel={}
  for i,name in ipairs({'decode-image.glb','missing-image.glb','decode-image.glb'}) do
    local file=dir..name; if i<3 then D.Cache:unload(file) end
    D.thread(function()
      local ok=D.Cache:loadAsync(file);parallel[i]=read(file);done=done+1
      check(not ok and parallel[i].modelPath==file,'concurrent failure scoped to its path '..i)
    end)
  end
  repeat D.sleep() until done==3
  check(parallel[1].diagnostics[1].code=='IMAGE_DECODE_FAILED' and parallel[2].diagnostics[1].code=='RESOURCE_READ_FAILED','concurrent errors remain distinct')
  check(json.encode(parallel[1])==json.encode(parallel[3]),'coalesced handlers receive equivalent snapshots')
  local cancel=dir..'cancel.glb';D.Cache:unload(cancel)
  local settled=false;local cancelledReport
  D.thread(function()
    local ok=D.Cache:loadAsync(cancel);cancelledReport=read(cancel);settled=true
    check(not ok,'cancelled handler reports failure')
  end)
  repeat D.sleep() until D.Cache:getLoadState(cancel)=='loading' or settled
  check(D.Cache:cancelLoad(cancel),'cancel a pending actual model import')
  repeat D.sleep() until settled
  check(cancelledReport.state=='cancelled' and cancelledReport.diagnostics[1].code=='LOAD_CANCELLED','cancel state visible inside completion handler')
  D.sleep(.4)
  check(read(cancel).state=='cancelled','late worker result cannot overwrite cancellation')
  check(D.Cache:loadAsync(cancel) and read(cancel).state=='ready' and #read(cancel).diagnostics==0,'retry after cancellation clears cancelled report')
  -- Toolkit must consume authoritative engine records and retain slot context.
  local Config=require('Kit.Config');local p=Config.copy(require('Assets').cube)
  p.path=dir..'decode-image.glb'
  local model,adaptation=require('Kit.Adapter').load(p)
  check(not model and adaptation.loadReport.state=='failed' and adaptation.diagnostics[1].code=='IMAGE_DECODE_FAILED','sync toolkit consumes engine report')
  local Assets=require('Assets');Assets.diagnostic=p
  local ok,diagnostics,loads=require('Kit.Loader').prepare({asset='diagnostic'})
  check(not ok and #loads==4,'async toolkit returns all per-resource reports')
  local found=false;for _,d in ipairs(diagnostics) do if d.code=='IMAGE_DECODE_FAILED' and d.textureSlot=='pbrMetallicRoughness.baseColorTexture' then found=true end end
  check(found,'async toolkit retains engine texture context');Assets.diagnostic=nil
  local environment=dir..'absent.hdr'
  D.Director.entry:setEnvironmentMap(environment)
  repeat D.sleep() until D.Cache:getLoadState(environment)~='loading'
  local environmentReport=read(environment)
  check(environmentReport.state=='failed' and #environmentReport.diagnostics>0 and #environmentReport.diagnostics[1].message>0,'unified API also retains environment failure reason')
  D.Director.entry:setEnvironmentMap('')
  assert(D.Content:save(output..'diagnostics.json',assert(json.encode({status='passed',checks=checks,reports=reports,parallel=parallel,cancelled=cancelledReport,environment=environmentReport}))))
  print('CREATION3D_DIAGNOSTICS PASS '..#checks)
end)
