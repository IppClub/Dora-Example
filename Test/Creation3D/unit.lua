-- Run from Example/Creation3D: lua ../../Test/Creation3D/unit.lua
local C=require('Kit.Config'); local A=require('Kit.Adapter'); local M=require('Kit.Motion')
local n=0
local function check(ok,msg) assert(ok,msg); n=n+1 end
local function near(a,b) return math.abs(a-b)<1e-6 end
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not same(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
for _,change in ipairs({{'roadWidth',4.8},{'houseColor',0xff9ab4d4},{'speed',4.5}}) do
  local original=C.resolve(); local modified=C.edit(original,table.unpack(change))
  for k,v in pairs(original) do check(k==change[1] or modified[k]==v,'edit preserves '..k) end
  check(same(C.edit(modified,change[1],original[change[1]]),original),'restore exact configuration')
end
check(same(C.layout(C.resolve()),C.layout(C.resolve())),'same seed reproduces')
check(not same(C.layout(C.resolve()),C.layout(C.resolve({seed=2}))),'different seed changes layout')
for _,o in ipairs({{speed=0},{roadWidth=0},{seed=.1},{houseColor=-1},{surprise=true},{asset='remote'}}) do
  check(not pcall(C.resolve,o),'invalid config rejected')
end
local profile={unitsToMeters=.01,rotation={0,90,0},targetHeight=1,maxFootprint={3,3},collider={radius=2,height=1.1}}
local r=A.measure({-50,0,-100},{50,100,100},profile)
check(r.ok and near(r.size[1],2) and near(r.size[3],1),'rotated footprint, cm to meter')
check(near(r.scale,.01) and near(r.offset[2],0),'scale/feet')
profile.rotation={0,0,0}; profile.targetHeight=2
r=A.measure({10,20,30},{110,120,130},profile)
check(not r.ok,'collider height mismatch rejected')
profile.collider.height=3; profile.maxFootprint={1,1}
check(not A.measure({0,0,0},{100,100,100},profile).ok,'footprint mismatch rejected')
profile.maxFootprint={4,4}; profile.maxSourceExtent=10
check(not A.measure({0,0,0},{100,100,100},profile).ok,'oversize rejected')
check(not A.measure({0,0,0},{0,0,0},profile).ok,'degenerate rejected')
check(not A.measure({0,0,0},{0/0,1,1},profile).ok,'NaN rejected')
check(near(M.sample('move',{from={0,0,0},to={2,4,6},duration=2},1)[3],3),'linear move')
check(near(M.sample('rotate',{to={0,90,0},duration=2},2)[2],90),'rotate')
check(near(M.sample('swing',{amplitude=30,duration=1},.25)[2],30),'swing')
check(near(M.sample('bounce',{amplitude=2,duration=1},.5)[2],2),'bounce')
check(near(M.sample('path',{points={{0,0,0},{1,0,0},{1,0,2}},duration=2},1.5)[3],1),'piecewise path')
check(M.sample('path',{points={{0,0,0},{1,0,2}},duration=2},20)[3]==2,'path endpoint clamps')
profile.maxSourceExtent=1000; profile.targetHeight=1; profile.offsetOverride={5,0,0}
check(not A.measure({-.5,0,-.5},{.5,1,.5},profile).ok,'manual pivot cannot bypass collider enclosure')
profile.offsetOverride=nil; profile.rotation={0,0/0,0}
check(not A.measure({0,0,0},{1,1,1},profile).ok,'nonfinite rotation rejected')
print('CREATION3D_UNIT PASS assertions='..n)
return n
