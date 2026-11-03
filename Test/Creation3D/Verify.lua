local D=require('Dora')
local json=require('json')
return function(name,cfg)
  local source=D.Content:getFullPath('Example/Creation3D/Game.lua'):match('^(.*)/Game.lua$')
  assert(source,'Run with Dora-Example as project root')
  local output=D.Content:getFullPath('Test/Creation3D/Verify.lua'):match('^(.*)/Verify.lua$')..'/evidence/'
  D.Content:insertSearchPath(1,source)
  return require('Game').launch(cfg,function(g)
  g.start()
  local checks={}
  local function check(v,msg) assert(v,msg); checks[#checks+1]=msg end
  local function near(a,b) return math.abs(a-b)<.002 end
  local function go(x,z)
    for _=1,1000 do
      local dx,dz=x-g.state.x,z-g.state.z
      if g.state.won or dx*dx+dz*dz<.001 then return end
      local dt=math.min(.02,math.sqrt(dx*dx+dz*dz)/g.cfg.speed)
      g.move(dx,dz,dt)
    end
    error('route could not reach '..x..','..z)
  end
  check(#g.houses==6,'six parameterized buildings')
  check(near(g.road.scaleX,g.cfg.roadWidth),'road width applied')
  check(near(g.houses[1].group.x,-g.cfg.roadWidth/2-1.5),'building setback follows road')
  local original=g.houses[2].wall:getMaterial(0).baseColor:toARGB()
  local roadColor=g.road:getMaterial(0).baseColor:toARGB()
  g.houses[1].wall:getMaterial(0).baseColor=D.Color(0xff803080)
  check(g.houses[2].wall:getMaterial(0).baseColor:toARGB()==original,'material change isolated across shared cube asset')
  check(g.road:getMaterial(0).baseColor:toARGB()==roadColor,'recolor preserves road material')
  g.houses[1].wall:getMaterial(0).baseColor=D.Color(g.cfg.houseColor)
  local z=g.state.z; g.move(0,-1,.1)
  local displacement=z-g.state.z
  check(near(displacement,g.cfg.speed*.1),'speed controls actual displacement')
  g.restart(); g.start()
  -- Shared logical collider must survive replacing visuals.
  go(0,3.8)
  g.move(1,0,2)
  check(g.state.x<g.cfg.roadWidth/2+.3,'house collision blocks long movement with substeps')
  g.restart(); g.start()
  for _,p in ipairs(g.targets) do go(p.x,p.z) end
  check(g.state.collected==3,'all three parcels collectible')
  g.move(0,0,.1)
  check(g.state.collected==3,'collected parcel cannot count twice')
  go(0,-5.3)
  check(g.state.won,'goal enters success state')
  local winZ=g.state.z; g.move(0,1,1)
  check(g.state.z==winZ,'success freezes movement')
  check(near(g.root.z,g.state.z),'render node follows gameplay state')
  if g.cfg.asset~='cube' then
    local a,b=g.player:getWorldBoundsMin(),g.player:getWorldBoundsMax()
    check(near(b.y-a.y,g.adaptation.size[2]),'replacement world height matches adaptation')
    check(near(a.y,0),'replacement feet at world ground after rotation')
    check(g.adaptation.collider.radius>=math.sqrt(g.adaptation.size[1]^2+g.adaptation.size[3]^2)/2,'collider encloses visual footprint at all headings')
    check(g.player.materialCount>0,'replacement materials available')
    check(g.player.animationCount==3,'Fox imports three animation clips')
    require('Kit.Adapter').play(g.adaptation,'run')
    check(g.player.playing,'Fox semantic run playback started')
  end
  D.thread(function()
    local frames,collect,submit={}, {}, {}
    for i=1,90 do
      D.sleep()
      frames[i]=D.App.deltaTime*1000; collect[i]=g.view.stats.collectMicros; submit[i]=g.view.stats.submitMicros
    end
    local function percentiles(a) table.sort(a); return {p50=a[math.ceil(#a*.5)],p95=a[math.ceil(#a*.95)],max=a[#a]} end
    local perf={framesMs=percentiles(frames),collectMicros=percentiles(collect),submitMicros=percentiles(submit),samples=#frames}
    D.sleep(.35)
    local stats=g.view.stats
    check(stats.visibleVisuals>0 and stats.drawCalls>0 and stats.triangles>0,'actual renderer submits geometry')
    if g.cfg.asset=='Fox' then check(g.player.elapsed>0,'Fox animation advances across rendered frames') end
    local report={loading=g.loading,actual={roadWidth=g.road.scaleX,houseColor=g.houses[1].wall:getMaterial(0).baseColor:toARGB(),movementSeconds=.1,movementDistance=displacement},config=g.cfg,layout=require('Kit.Config').layout(g.cfg),name=name,status='passed',checks=checks,adaptation={asset=g.cfg.asset,scale=g.adaptation.scale,size=g.adaptation.size,offset=g.adaptation.offset,collider=g.adaptation.collider,diagnostics=g.adaptation.diagnostics},
      performance=perf,stats={visible=stats.visibleVisuals,draws=stats.drawCalls,triangles=stats.triangles,
      modelInstances=stats.modelInstanceCount,meshes=stats.meshCount,modelResidentBytes=stats.modelResidentBytes,
      meshResidentBytes=stats.meshResidentBytes,textureResidentBytes=stats.textureResidentBytes}}
    D.sleep(.6)
    g.restart(); g.start()
    check(g.state.collected==0 and not g.state.won and near(g.state.z,5),'restart resets gameplay')
    for _,gem in ipairs(g.gems) do check(gem.visible,'restart restores parcel visibility') end
    for _,p in ipairs(g.targets) do go(p.x,p.z) end
    go(0,-5.3)
    check(g.state.won and g.state.collected==3,'second logic round completes')
    report.checks=checks; report.restartVerified=true; report.inputMethod='direct logic calls; NOT real input'
    assert(D.Content:save(output..name..'.json',assert(json.encode(report))))
    print('AI_3D_VERIFIED '..name..' checks='..#checks..' triangles='..stats.triangles)
  end)
  end)
end
