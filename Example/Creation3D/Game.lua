local D = require('Dora')
local P=require('Kit.Primitive')
local Config=require('Kit.Config')
local Adapter=require('Kit.Adapter')
local Motion=require('Kit.Motion')
local M = {}
-- Non-blocking application entry. create() is retained for already-prepared resources.
function M.launch(options,onReady)
  local cfg=Config.resolve(options)
  local pending={phase='loading',ready=false}
  local label=assert(D.Label('sarasa-mono-sc-regular',22))
  label.text='Loading scene...'; D.Director.ui:addChild(label)
  local started=D.App.runningTime
  D.thread(function()
    local ok,diagnostics,reports=require('Kit.Loader').prepare(cfg,function(progress)
      label.text=string.format('Loading scene... %d%%',math.floor(progress*100))
    end)
    pending.diagnostics=diagnostics; pending.loadReports=reports
    pending.preparationMs=(D.App.runningTime-started)*1000
    if not ok then
      pending.phase='failed'; pending.diagnostics=diagnostics
      label.text='Scene load failed. See diagnostics.'
      print(assert(require('json').encode(diagnostics)))
      return
    end
    local createStart=D.App.runningTime
    local created,game=pcall(M.create,cfg)
    pending.createMs=(D.App.runningTime-createStart)*1000
    if not created then
      pending.phase='failed'; pending.diagnostics={{severity='error',code='ADAPTATION_FAILED',message=tostring(game)}}
      label.text='Scene adaptation failed. See diagnostics.'
      print(assert(require('json').encode(pending.diagnostics)))
      return
    end
    pending.game=game
    pending.ready=true; pending.phase='ready'
    pending.game.loading={preparationMs=pending.preparationMs,createMs=pending.createMs,diagnostics=diagnostics,loadReports=reports}
    label:removeFromParent()
    if onReady then onReady(pending.game) end
  end)
  return pending
end
function M.create(options)
  local cfg=Config.resolve(options)
  local view=D.Director.entry
  local camera=P.preset(view)
  local function box(x,y,z,sx,sy,sz,color,parent)
    return P.shape('cube',{position={x,y,z},size={sx,sy,sz},color=color},parent or view)
  end
  local floor=box(0,-.2,0,16,.3,13,0xff385b4b)
  local road=P.road({position={0,-.025,0},size={cfg.roadWidth,.08,12},color=P.palette.road},view)
  local houses={}; local obstacles={}
  for _,side in ipairs({-1,1}) do
    for _,z in ipairs({-3.8,0,3.8}) do
      local x=side*(cfg.roadWidth/2+1.5)
      local house=P.house({position={x,0,z},color=cfg.houseColor},view)
      houses[#houses+1]=house
      obstacles[#obstacles+1]={x=x,z=z,hx=.9,hz=1}
    end
  end
  for _,t in ipairs(Config.layout(cfg)) do P.tree({position={t.x,0,t.z}},view) end
  local root=D.Node3D(); view:addChild(root)
  local player,adaptation
  local profile=Config.copy(require('Assets')[cfg.asset])
  if cfg.asset=='cube' then
    player=box(0,.5,0,.65,1,.65,0xff75dce2,root)
    P.shape('sphere',{position={0,1.1,-.2},size={.4,.25,.3},color=0xffe8fbf6},root)
    adaptation={asset='cube',height=1,clips={},collider={radius=.5,height=1.25},diagnostics={}}
  else
    player,adaptation=Adapter.load(profile,root)
    assert(player,require('json').encode(adaptation.diagnostics))
    adaptation.asset=cfg.asset
    for _,d in ipairs(adaptation.diagnostics) do print(d.code..': '..d.message) end
    Adapter.play(adaptation,'idle')
  end
  local radius=adaptation.collider.radius
  local targets={{x=0,z=2.6},{x=-.7,z=-.6},{x=.7,z=-3.7}}
  local gems={}
  for i,p in ipairs(targets) do
    gems[i]=box(p.x,.55,p.z,.42,.65,.42,0xffffd773)
    gems[i].angleZ=35
    gems[i]:getMaterial(0).emissive=D.Color3(0x332000)
  end
  local goal=P.platform({position={0,.08,-5.3},size={2,.15,.65},color=0xffb2d8a9},view)
  local state={x=0,z=5,collected=0,won=false,time=0,restarts=0,started=false,inputEvents=0,collisionHits=0}
  local destination
  local function sync() root.position=D.Vec3(state.x,0,state.z) end
  local function restart()
    state.x=0; state.z=5; state.collected=0; state.won=false; state.time=0
    state.restarts=state.restarts+1; state.started=false; destination=nil
    for _,g in ipairs(gems) do g.visible=true end
    root.angleY=0
    if cfg.asset~='cube' then Adapter.play(adaptation,'idle') end
    sync()
  end
  local function blocked(x,z)
    for _,b in ipairs(obstacles) do
      if math.abs(x-b.x)<b.hx+radius and math.abs(z-b.z)<b.hz+radius then return true end
    end
    return false
  end
  local function move(dx,dz,dt)
    if state.won or not state.started then return end
    local len=math.sqrt(dx*dx+dz*dz)
    if len>0 then
      dx=dx/len; dz=dz/len
      -- Substeps prevent tunnelling through logical colliders on long frames.
      local steps=math.max(1,math.ceil(cfg.speed*dt/.15))
      for _=1,steps do
        local nx=math.max(-7,math.min(7,state.x+dx*cfg.speed*dt/steps))
        if not blocked(nx,state.z) then state.x=nx else state.collisionHits=state.collisionHits+1 end
        local nz=math.max(-5.8,math.min(5.8,state.z+dz*cfg.speed*dt/steps))
        if not blocked(state.x,nz) then state.z=nz else state.collisionHits=state.collisionHits+1 end
      end
      root.angleY=math.deg(math.atan(-dx,-dz))
    end
    if cfg.asset~='cube' then Adapter.play(adaptation,len>0 and (cfg.speed>=4 and 'run' or 'walk') or 'idle') end
    sync()
    for i,p in ipairs(targets) do
      if gems[i].visible and (state.x-p.x)^2+(state.z-p.z)^2 < .7^2 then
        gems[i].visible=false; state.collected=state.collected+1
      end
    end
    if state.collected==3 and state.z< -4.85 and math.abs(state.x)<1 then state.won=true; if cfg.asset~='cube' then Adapter.play(adaptation,'idle') end end
  end
  restart()
  local elapsed=0
  local function update(dt)
    elapsed=elapsed+dt
    if state.started and not state.won then state.time=state.time+dt end
    for i,g in ipairs(gems) do
      Motion.apply(g,'rotate',{from={0,i*20,35},to={0,360+i*20,35},duration=360/70,loop=true},elapsed)
      Motion.apply(g,'bounce',{from={targets[i].x,.55,targets[i].z},amplitude=.12,duration=1.2},elapsed)
    end
    if cfg.asset=='cube' then Motion.apply(player,'bounce',{from={0,.5,0},amplitude=.035,duration=.6},elapsed) end
  end
  local function start() state.started=true end
  local api={start=start,cfg=cfg,view=view,camera=camera,road=road,houses=houses,player=player,root=root,
    state=state,targets=targets,gems=gems,adaptation=adaptation,move=move,restart=restart,update=update,blocked=blocked}
  view:onTapped(function(touch)
    state.inputEvents=state.inputEvents+1; start()
    local o=view:getRayOrigin(touch.viewLocation)
    local d=view:getRayDirection(touch.viewLocation)
    if math.abs(d.y)>.00001 then
      local t=-o.y/d.y
      if t>0 then destination={x=o.x+d.x*t,z=o.z+d.z*t} end
    end
  end)
  local hud=D.Node(); D.Director.ui:addChild(hud)
  local function label(text,size,y,color)
    local l=assert(D.Label('sarasa-mono-sc-regular',size))
    l.text=text; l.y=y; l.color=D.Color(color or 0xffeef5eb)
    hud:addChild(l); return l
  end
  label('COURIER / 3D LAB',28,38,0xffeac98f)
  label('Collect 3 golden parcels, then reach the green gate',18,5)
  label('Enter: start  |  WASD / arrows / click ground  |  R: restart',16,-24)
  local status=label('',22,-56)
  local retry=D.Node(); retry.swallowTouches=true; retry.size=D.Size(180,38); retry.y=-102
  local bg=D.DrawNode()
  bg:drawPolygon({D.Vec2(-90,-19),D.Vec2(90,-19),D.Vec2(90,19),D.Vec2(-90,19)},D.Color(0xff34594f))
  bg.position=D.Vec2(90,19)
  retry:addChild(bg); local retryLabel=D.Label('sarasa-mono-sc-regular',18)
  retryLabel.text='Restart [R]'; retryLabel.position=D.Vec2(90,19); retry:addChild(retryLabel); hud:addChild(retry)
  retry:onTapped(function() state.inputEvents=state.inputEvents+1; restart(); destination=nil end)
  D.threadLoop(function()
    if D.Keyboard:isKeyDown('Return') then state.inputEvents=state.inputEvents+1; start() end
    local dt=math.min(D.App.deltaTime,.05)
    local dx,dz=0,0
    if D.Keyboard:isKeyPressed('A') or D.Keyboard:isKeyPressed('Left') then dx=dx-1 end
    if D.Keyboard:isKeyPressed('D') or D.Keyboard:isKeyPressed('Right') then dx=dx+1 end
    if D.Keyboard:isKeyPressed('W') or D.Keyboard:isKeyPressed('Up') then dz=dz-1 end
    if D.Keyboard:isKeyPressed('S') or D.Keyboard:isKeyPressed('Down') then dz=dz+1 end
    if dx~=0 or dz~=0 then state.inputEvents=state.inputEvents+1; start(); destination=nil end
    if destination then
      dx=destination.x-state.x; dz=destination.z-state.z
      if dx*dx+dz*dz<.08 then destination=nil; dx=0; dz=0 end
    end
    if D.Keyboard:isKeyDown('R') then state.inputEvents=state.inputEvents+1; restart(); destination=nil end
    move(dx,dz,dt); update(dt)
    local pixelScale=D.App.bufferSize.width/D.App.visualSize.width
    hud.scaleX=pixelScale; hud.scaleY=pixelScale
    hud.position=D.Vec2(0,D.App.bufferSize.height/2-65*pixelScale)
    status.text=not state.started and 'Press Enter or move to start' or state.won and 'DELIVERY COMPLETE!' or string.format('Parcels %d / 3  |  %.1fs',state.collected,state.time)
    if M.observe then M.observe(api,dt) end
    return false
  end)
  return api
end
return M
