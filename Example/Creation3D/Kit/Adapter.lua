local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function diagnostic(list,code,message,severity)
  list[#list+1]={code=code,message=message,severity=severity or 'warning'}
end
-- Node3D uses intrinsic XYZ; transform all eight corners before fitting.
function M.measure(mn,mx,p)
  local out={diagnostics={}}; local ds=out.diagnostics
  for i=1,3 do
    if not finite(mn[i]) or not finite(mx[i]) or mx[i]<=mn[i] then
      diagnostic(ds,'INVALID_BOUNDS','Non-finite or degenerate bounds','error'); return out
    end
  end
  local unit=p.unitsToMeters or 1
  if not finite(unit) or unit<=0 or not finite(p.targetHeight) or p.targetHeight<=0 then
    diagnostic(ds,'INVALID_SCALE','Unit/height must be finite and positive','error'); return out
  end
  for i=1,3 do if (mx[i]-mn[i])>(p.maxSourceExtent or 10000) then
    diagnostic(ds,'MODEL_TOO_LARGE','Source extent exceeds profile budget','error'); return out end end
  local angles=p.rotation or {0,0,0}
  for i=1,3 do
    if not finite(angles[i]) then diagnostic(ds,'INVALID_ROTATION','Euler angles must be finite','error'); return out end
  end
  local lo={math.huge,math.huge,math.huge}; local hi={-math.huge,-math.huge,-math.huge}
  local function rotate(x,y,z)
    -- Intrinsic XYZ: apply Z, then Y, then X to column vectors.
    local a,b,c=math.rad(angles[1]),math.rad(angles[2]),math.rad(angles[3])
    x,y=x*math.cos(c)-y*math.sin(c),x*math.sin(c)+y*math.cos(c)
    x,z=x*math.cos(b)+z*math.sin(b),-x*math.sin(b)+z*math.cos(b)
    y,z=y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
    return {x,y,z}
  end
  for _,x in ipairs({mn[1],mx[1]}) do for _,y in ipairs({mn[2],mx[2]}) do for _,z in ipairs({mn[3],mx[3]}) do
    local v=rotate(x*unit,y*unit,z*unit)
    for i=1,3 do lo[i]=math.min(lo[i],v[i]); hi[i]=math.max(hi[i],v[i]) end
  end end end
  local fit=p.targetHeight/(hi[2]-lo[2]); local scale=(p.scaleOverride or fit)*unit
  if not finite(scale) or scale<=0 then diagnostic(ds,'INVALID_SCALE','Invalid scale override','error'); return out end
  local factor=scale/unit
  out.scale=scale; out.size={}; out.offset={}
  for i=1,3 do out.size[i]=(hi[i]-lo[i])*factor end
  out.offset={-(lo[1]+hi[1])/2*factor,-lo[2]*factor,-(lo[3]+hi[3])/2*factor}
  if p.offsetOverride then out.offset=p.offsetOverride end
  for i=1,3 do
    if not finite(out.offset[i]) then diagnostic(ds,'INVALID_OFFSET','Offset must be finite','error'); return out end
  end
  out.boundsMin={}; out.boundsMax={}
  for i=1,3 do out.boundsMin[i]=lo[i]*factor+out.offset[i]; out.boundsMax[i]=hi[i]*factor+out.offset[i] end
  local footprint=assert(p.maxFootprint,'explicit footprint required')
  if out.size[1]>footprint[1] or out.size[3]>footprint[2] then
    diagnostic(ds,'FOOTPRINT_EXCEEDED','Adjust scale, target height or allowed footprint; replacement rejected','error')
  end
  local c=assert(p.collider,'explicit collider required')
  -- Game turns freely: enclosing circle stays conservative under gameplay yaw.
  local rx=math.max(math.abs(out.boundsMin[1]),math.abs(out.boundsMax[1]))
  local rz=math.max(math.abs(out.boundsMin[3]),math.abs(out.boundsMax[3]))
  local needed=math.sqrt(rx*rx+rz*rz)
  if not finite(c.radius) or not finite(c.height) or c.radius<needed or c.height+1e-6<out.boundsMax[2] or out.boundsMin[2]<-(p.groundTolerance or 1e-6) then
    diagnostic(ds,'COLLIDER_MISMATCH',string.format('Needs radius %.4f, top %.4f, bottom %.4f; configured radius %.4f, height %.4f. Adjust collision/profile explicitly.',needed,out.boundsMax[2],out.boundsMin[2],c.radius or 0,c.height or 0),'error')
  end
  out.collider=c; out.ok=true
  for _,v in ipairs(ds) do if v.severity=='error' then out.ok=false end end
  return out
end
-- Preflight local GLB image references before loading (no network fetch).
function M.preflight(path)
  local D=require('Dora'); local ds={}; local raw=D.Content:load(path)
  if not raw then diagnostic(ds,'MISSING_RESOURCE',path,'error'); return nil,ds end
  if raw:sub(1,4)~='glTF' then diagnostic(ds,'INVALID_GLB','Expected local GLB','error'); return nil,ds end
  local a,b,c,d=raw:byte(13,16); if not d then diagnostic(ds,'INVALID_GLB','Truncated header','error'); return nil,ds end
  local len=a+b*256+c*65536+d*16777216
  local doc=require('json').decode(raw:sub(21,20+len))
  if not doc then diagnostic(ds,'INVALID_GLB','Invalid JSON chunk','error'); return nil,ds end
  for _,im in ipairs(doc.images or {}) do
    if im.uri then
      if not im.uri:match('^data:') then
        local base=path:match('^(.*[/\\])') or ''
        if im.uri:match('^%a+://') or not D.Content:exist(base..im.uri) then
          diagnostic(ds,'MISSING_TEXTURE',im.uri,'error')
        end
      end
    elseif not im.bufferView or not (doc.bufferViews or {})[im.bufferView+1] then
      diagnostic(ds,'MISSING_TEXTURE','Invalid embedded image bufferView','error')
    end
  end
  for _,v in ipairs(ds) do if v.severity=='error' then return nil,ds end end
  return doc,ds
end
function M.load(profile,parent)
  local D=require('Dora')
  local loaded=D.Cache:load(profile.path)
  local loadReport=require('Kit.Diagnostics').read(profile.path)
  local ds={}; require('Kit.Diagnostics').append(ds,loadReport)
  if not loaded then return nil,{diagnostics=ds,loadReport=loadReport} end
  local instantiated,model=pcall(D.Model3D,profile.path)
  if not instantiated or not model then
    ds[#ds+1]={code='INSTANCE_CREATION_FAILED',severity='error',stage='instantiate',resourcePath=profile.path,
      message=instantiated and 'Model resource loaded but instance creation failed' or tostring(model)}
    return nil,{diagnostics=ds,loadReport=loadReport}
  end
  local a,b=model:getLocalBoundsMin(),model:getLocalBoundsMax()
  local report=M.measure({a.x,a.y,a.z},{b.x,b.y,b.z},profile)
  report.loadReport=loadReport
  for _,d in ipairs(ds) do report.diagnostics[#report.diagnostics+1]=d end
  report.profile=profile; report.path=profile.path; report.animations={}; report.mapping=profile.animations or {}
  for i=0,model.animationCount-1 do report.animations[#report.animations+1]=model:getAnimationName(i) end
  if not report.ok then model:cleanup(); return nil,report end
  local root=D.Node3D(); local pivot=D.Node3D(); root:addChild(pivot); pivot:addChild(model)
  model.scale=D.Vec3(report.scale,report.scale,report.scale)
  model.angles=D.Vec3(table.unpack(profile.rotation or {0,0,0}))
  pivot.position=D.Vec3(table.unpack(report.offset))
  if parent then parent:addChild(root) end
  report.root=root; report.pivot=pivot; report.model=model
  for _,semantic in ipairs({'idle','walk','run'}) do
    local found=false; for _,name in ipairs(report.animations) do if name==report.mapping[semantic] then found=true end end
    if not found then diagnostic(report.diagnostics,'MISSING_ANIMATION',semantic..': static fallback') end
  end
  return model,report
end
-- Check a moving clip at its current pose using the original scale and foot pivot.
-- Does not silently refit or change the collider when animation expands the bounds.
function M.checkEnvelope(report)
  local p={}; for k,v in pairs(report.profile) do p[k]=v end
  p.scaleOverride=report.scale/(p.unitsToMeters or 1); p.offsetOverride=report.offset
  local a,b=report.model:getLocalBoundsMin(),report.model:getLocalBoundsMax()
  return M.measure({a.x,a.y,a.z},{b.x,b.y,b.z},p)
end
function M.play(report,semantic)
  if report.semantic==semantic then return report.animationStatus end
  report.semantic=semantic
  local name=report.mapping[semantic]; local found=false
  for _,clip in ipairs(report.animations) do if clip==name then found=true end end
  if found and report.model:play(name,true)>0 then report.animationStatus='playing:'..name
  else report.model:stop(); report.animationStatus='static:'..semantic end
  return report.animationStatus
end
return M
