local D=require('Dora')
local M={palette={grass=0xff385b4b,road=0xff71818b,wall=0xffe2ac76,roof=0xff9e605c,leaf=0xff75a56b}}
-- All dimensions are full extents, angles are degrees; plane lies in XZ.
function M.shape(kind,o,parent)
  o=o or {}; assert(kind=='cube' or kind=='sphere' or kind=='cylinder' or kind=='plane','unknown primitive')
  local m=assert(D.Model3D('assets/'..kind..'.glb'),'primitive resource missing: '..kind)
  local p,s,a=o.position or {0,0,0},o.size or {1,1,1},o.rotation or {0,0,0}
  for _,v in ipairs(s) do assert(v>0 and v<10000,'invalid primitive size') end
  m.position=D.Vec3(table.unpack(p)); m.scale=D.Vec3(table.unpack(s)); m.angles=D.Vec3(table.unpack(a))
  for i=0,m.materialCount-1 do
    local mat=m:getMaterial(i); mat.baseColor=D.Color(o.color or 0xffffffff)
    mat.roughness=o.roughness or .85; mat.metallic=o.metallic or 0
  end
  if parent then parent:addChild(m) end; return m
end
function M.group(o,parent)
  local n=D.Node3D(); o=o or {}
  n.position=D.Vec3(table.unpack(o.position or {0,0,0})); n.angles=D.Vec3(table.unpack(o.rotation or {0,0,0}))
  n.scale=D.Vec3(table.unpack(o.size or {1,1,1})); if parent then parent:addChild(n) end; return n
end
function M.tree(o,parent)
  local n=M.group(o,parent)
  M.shape('cylinder',{position={0,.6,0},size={.24,1.2,.24},color=0xff795544},n)
  M.shape('sphere',{position={0,1.5,0},size={1.2,1.6,1.2},color=o.color or M.palette.leaf},n)
  return n
end
function M.house(o,parent)
  local n=M.group(o,parent)
  local wall=M.shape('cube',{position={0,.85,0},size={1.8,1.7,2},color=o.color or M.palette.wall},n)
  local roof=M.shape('cube',{position={0,1.85,0},size={2.05,.35,2.2},color=M.palette.roof},n)
  return {group=n,wall=wall,roof=roof}
end
function M.road(o,parent) return M.shape('cube',o,parent) end
function M.platform(o,parent) return M.shape('cube',o,parent) end
function M.preset(view)
  local camera=D.Camera3D(); camera:lookAt(D.Vec3(11,15,17),D.Vec3(0,0,0)); D.Director:pushCamera(camera)
  view:setEnvironmentMap(''); view:setEnvironmentIntensity(.25,0,1)
  local sun=D.DirectionalLight3D(); sun.angleX=-60; sun.angleY=30; sun.intensity=3.2
  sun.castShadow=true; view:addChild(sun); view.shadowMapSize=1024; return camera
end
return M
