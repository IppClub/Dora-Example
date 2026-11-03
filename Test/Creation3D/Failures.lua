local D=require('Dora'); local json=require('json')
local source=D.Content:getFullPath('Example/Creation3D/Game.lua'):match('^(.*)/Game.lua$'); D.Content:insertSearchPath(1,source)
local output=D.Content:getFullPath('Test/Creation3D/Failures.lua'):match('^(.*)/Failures.lua$')..'/evidence/'
local A=require('Kit.Adapter'); local C=require('Kit.Config'); local checks={}
local function check(v,msg) assert(v,msg); checks[#checks+1]=msg end
for i,kind in ipairs({'cube','sphere','cylinder','plane'}) do
  local node=require('Kit.Primitive').shape(kind,{position={i*2,0,3},size={1,1,1}},D.Director.entry)
  local lo,hi=node:getLocalBoundsMin(),node:getLocalBoundsMax()
  check(node.materialCount==1 and math.abs(hi.x-lo.x-1)<.001 and math.abs(hi.z-lo.z-1)<.001,'unit primitive bounds/material: '..kind)
end
local p=C.copy(require('Assets').cube)
local m,r=A.load(p,D.Director.entry)
check(m~=nil,'static model loads')
check(#r.diagnostics==3,'all missing semantics diagnosed')
check(A.play(r,'walk')=='static:walk' and not m.playing,'missing animation explicitly static')
p.path='assets/does-not-exist.glb'; local missing,report=A.load(p)
check(not missing and report.diagnostics[1].code=='RESOURCE_NOT_FOUND','missing GLB rejected')
p=C.copy(require('Assets').Fox); p.targetHeight=10
local large,report=A.load(p)
check(not large and not report.ok,'excess footprint and collider mismatch rejected')
p=C.copy(require('Assets').Fox); p.maxSourceExtent=.001
local huge,report=A.load(p)
check(not huge and report.diagnostics[1].code=='MODEL_TOO_LARGE','abnormal source extent rejected')
local raw=assert(D.Content:load('assets/cube.glb'))
local a,b,c,d=raw:byte(13,16); local len=a+b*256+c*65536+d*16777216
local doc=assert(json.decode(raw:sub(21,20+len))); doc.images={{uri='missing-texture.png'}}
local js=assert(json.encode(doc)); js=js..string.rep(' ',(-#js)%4)
local function u32(n) return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256) end
local tail=raw:sub(21+len)
local fixture='Test/Creation3D/evidence/missing-texture.glb'
-- Absolute output keeps generated fixture out of project-relative writable storage.
fixture=output..'missing-texture.glb'
assert(D.Content:save(fixture,'glTF'..u32(2)..u32(20+#js+#tail)..u32(#js)..'JSON'..js..tail))
local doc,ds=A.preflight(fixture)
check(not doc and ds[1].code=='MISSING_TEXTURE','missing texture diagnosed before load')
D.Content:remove(fixture)
-- Validate arbitrary Euler rotation against the owning runtime's world AABB.
p=C.copy(require('Assets').cube); p.rotation={23,47,61}; p.targetHeight=.9; p.maxFootprint={3,3}; p.collider={radius=3,height=3}
local rotated,r=A.load(p,D.Director.entry); check(rotated~=nil,'arbitrary rotation loads')
local mn,mx=rotated:getWorldBoundsMin(),rotated:getWorldBoundsMax()
check(math.abs(mn.y)<.001 and math.abs(mx.x-mn.x-r.size[1])<.001 and math.abs(mx.z-mn.z-r.size[3])<.001,'rotation/foot offset matches engine XYZ bounds')
p=C.copy(require('Assets').Fox)
local fox,r=A.load(p,D.Director.entry); check(fox~=nil,'Fox direction probe loads')
local head,tail=D.Node3D(),D.Node3D()
check(fox:attachToNode('b_Head_05',head) and fox:attachToNode('b_Tail01_012',tail),'Fox facing landmarks attach')
local h,t=head:convertToWorldSpace(D.Vec3(0,0,0)),tail:convertToWorldSpace(D.Vec3(0,0,0))
check(h.z<t.z,'Fox configured face direction is gameplay -Z: head='..h.z..' tail='..t.z)
local cfg=C.resolve(); assert(C.save(output..'saved-scene.json',cfg)); local loaded=C.load(output..'saved-scene.json')
check(loaded.seed==cfg.seed and loaded.speed==cfg.speed,'JSON configuration save/load roundtrip')
assert(D.Content:save(output..'failures.json',assert(json.encode({status='passed',checks=checks,diagnostics=ds}))))
print('CREATION3D_FAILURES PASS '..#checks)
