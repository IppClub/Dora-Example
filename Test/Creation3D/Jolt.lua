-- Isolated adapter/Jolt box integration; town keeps its script collision implementation.
local D=require('Dora'); local json=require('json')
local source=D.Content:getFullPath('Example/Creation3D/Game.lua'):match('^(.*)/Game.lua$'); D.Content:insertSearchPath(1,source)
local output=D.Content:getFullPath('Test/Creation3D/Jolt.lua'):match('^(.*)/Jolt.lua$')..'/evidence/'
local view=D.Director.entry; local P=require('Kit.Primitive'); P.preset(view)
local world=D.PhysicsWorld3D(); world.gravity=D.Vec3(0,-9.81,0); view:addChild(world)
local function body(half,pos,kind)
  local def=D.BodyDef3D(); def.type=kind
  assert(def:attach(D.FixtureDef3D:box(D.Vec3(table.unpack(half)))))
  local b=assert(D.Body3D(def,world,D.Vec3(table.unpack(pos)))); view:addChild(b); return b
end
body({5,.25,5},{0,-.25,0},D.PhysicsWorld3D.Static)
P.platform({position={0,-.25,0},size={10,.5,10},color=P.palette.grass},view)
local results={}; local bodies={}
for i,name in ipairs({'cube','Fox'}) do
  local model,r=require('Kit.Adapter').load(require('Assets')[name]); assert(model)
  local c=r.collider; local b=body({c.radius,c.height/2,c.radius},{(i-1)*3,3,0},D.PhysicsWorld3D.Dynamic)
  r.root.position=D.Vec3(0,-c.height/2,0); b:addChild(r.root)
  local contacts=0; b:onContactEnter(function() contacts=contacts+1 end)
  bodies[i]={body=b,model=model,report=r,name=name,contacts=function() return contacts end}
end
D.thread(function()
  D.sleep(3)
  for _,v in ipairs(bodies) do
    local b,r=v.body,v.report; local c=r.collider
    local mn,mx=v.model:getWorldBoundsMin(),v.model:getWorldBoundsMax()
    assert(math.abs(b.position.y-c.height/2)<.06,'Jolt did not settle at collider half-height')
    assert(math.abs(mn.y)<.06,'adapted visual feet not aligned after Jolt landing')
    assert(mn.x>=b.position.x-c.radius-.01 and mx.x<=b.position.x+c.radius+.01,'visual outside collider X')
    assert(mn.z>=b.position.z-c.radius-.01 and mx.z<=b.position.z+c.radius+.01,'visual outside collider Z')
    local inside=false; local outside=false
    world:raycast(D.Vec3(b.position.x+c.radius-.02,2,0),D.Vec3(b.position.x+c.radius-.02,.05,0),function(hit) if hit==b then inside=true end; return false end)
    world:raycast(D.Vec3(b.position.x+c.radius+.02,2,0),D.Vec3(b.position.x+c.radius+.02,.05,0),function(hit) if hit==b then outside=true end; return false end)
    assert(inside and not outside,'Jolt actual shape boundary mismatches adapter collider')
    assert(v.contacts()>0,'no floor contact observed')
    results[#results+1]={asset=v.name,bodyY=b.position.y,visualFootY=mn.y,insideHit=inside,outsideHit=outside,contacts=v.contacts(),collider=c}
  end
  assert(D.Content:save(output..'jolt.json',assert(json.encode({status='passed',checks=results,scope='box boundary, visual enclosure, gravity landing, floor contact; isolated from game'}))))
  print('CREATION3D_JOLT PASS')
end)
