-- Absolute-time samplers: no accumulating drift, no hidden scheduler.
local M={}
function M.sample(kind,o,t)
  local a,b=o.from or {0,0,0},o.to or {0,0,0}
  local d=o.duration or 1; assert(d>0,'duration must be positive')
  local u=o.loop and (t/d)%1 or math.max(0,math.min(1,t/d))
  if kind=='move' or kind=='rotate' then
    return {a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u}
  elseif kind=='swing' or kind=='bounce' then
    local v=(kind=='bounce' and math.abs(math.sin(t/d*math.pi)) or math.sin(t/d*2*math.pi))*(o.amplitude or 1)
    local r={a[1],a[2],a[3]}; local axis=o.axis or 2; r[axis]=r[axis]+v; return r
  elseif kind=='path' then
    local points=assert(o.points); assert(#points>=2,'path needs two points')
    local s=u*(#points-1); local i=math.min(#points-1,math.floor(s)+1); local f=s-(i-1)
    return {points[i][1]*(1-f)+points[i+1][1]*f,points[i][2]*(1-f)+points[i+1][2]*f,points[i][3]*(1-f)+points[i+1][3]*f}
  end
  error('unknown motion: '..tostring(kind))
end
function M.apply(node,kind,o,t)
  local v=require('Dora').Vec3(table.unpack(M.sample(kind,o,t)))
  if kind=='rotate' or kind=='swing' then node.angles=v else node.position=v end
end
return M
