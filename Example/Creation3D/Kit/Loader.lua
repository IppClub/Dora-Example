local D=require('Dora')
local M={}
-- Must run in a Dora thread. Decode on workers, use the existing per-frame upload budget.
-- Failure leaves the game uncreated; this never falls back to a blocking load.
function M.prepare(config,progress)
  local profile=assert(require('Assets')[config.asset],'asset profile missing')
  local paths={'assets/cube.glb','assets/sphere.glb','assets/cylinder.glb'}
  if config.asset~='cube' then paths[#paths+1]=profile.path end
  local success=D.Cache:loadAsync(paths,progress)
  local diagnostics,reports={},{}
  local Diagnostics=require('Kit.Diagnostics')
  for _,path in ipairs(paths) do
    local report=Diagnostics.read(path); reports[#reports+1]=report
    Diagnostics.append(diagnostics,report)
  end
  if not success and #diagnostics==0 then
    diagnostics[1]={severity='error',code='LOAD_FAILED',stage='load',resourcePath=profile.path,message='Resource preparation failed without a model report'}
  end
  return success,diagnostics,reports
end
return M
