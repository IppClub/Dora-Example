-- Serializable scene parameters. No global RNG or executable config serialization.
local M={defaults={roadWidth=3.4,houseColor=0xffe2ac76,speed=3,asset='cube',seed=12345}}
function M.copy(t)
  if type(t)~='table' then return t end
  local r={}; for k,v in pairs(t) do r[k]=M.copy(v) end; return r
end
function M.resolve(options)
  local c=M.copy(M.defaults)
  for k,v in pairs(options or {}) do assert(c[k]~=nil,'unknown scene parameter: '..k); c[k]=v end
  for _,entry in ipairs({{'roadWidth',2.5,6},{'speed',.5,8},{'seed',1,2147483646},{'houseColor',0,4294967295}}) do
    local v=c[entry[1]]; assert(type(v)=='number' and v==v and v>=entry[2] and v<=entry[3], 'invalid '..entry[1])
  end
  assert(c.seed%1==0 and c.houseColor%1==0,'integer seed/color required')
  assert(type(c.asset)=='string' and require('Assets')[c.asset]~=nil,'asset profile missing: '..tostring(c.asset))
  return c
end
function M.edit(config,key,value)
  assert(M.defaults[key]~=nil,'unknown parameter'); local c=M.copy(config); c[key]=value; return M.resolve(c)
end
function M.save(path,config)
  return require('Dora').Content:save(path,assert(require('json').encode(M.resolve(config))))
end
function M.load(path)
  local text=assert(require('Dora').Content:load(path),'configuration missing')
  return M.resolve(assert(require('json').decode(text)))
end
function M.random(seed)
  local state=seed
  return function() state=(state*16807)%2147483647; return (state-1)/2147483646 end
end
function M.layout(config)
  local r=M.random(config.seed); local trees={}
  for i=1,8 do trees[i]={x=(i%2==0 and 1 or -1)*(6+r()*.7),z=-5+(i-1)*1.4+r()*.3} end
  return trees
end
return M
