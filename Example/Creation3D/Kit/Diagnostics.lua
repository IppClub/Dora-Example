-- Versioned engine data, never text-log matching. JSON keeps the contract portable to other bindings.
local D=require('Dora'); local json=require('json')
local M={}
function M.read(path)
  assert(D.Cache.getLoadDiagnostics,'This toolkit requires an engine with Cache.getLoadDiagnostics')
  local report=assert(json.decode(D.Cache:getLoadDiagnostics(path)))
  assert(report.version==1 and type(report.diagnostics)=='table','Unsupported model diagnostic schema')
  return report
end
function M.append(target,report)
  for _,diagnostic in ipairs(report.diagnostics) do target[#target+1]=diagnostic end
end
return M
