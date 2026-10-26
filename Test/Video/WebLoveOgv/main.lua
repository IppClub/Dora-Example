-- Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
-- Stage an unmodified multiplexed sample.ogv and settings.lua beside this file.
local cfg=require('settings')
local encode=require('encode')
local video,source,phase,at,started,pausedAt,request,pending,captureTime
local activeWall,lastWall=cfg.startAt or 0,0
local captures,checks={},{}
local checkpoints={1,6,20,40,51}
if cfg.startAt then checkpoints={cfg.startAt} end
local nextCheckpoint=1
local function now()return love.timer.getTime()end
local function enter(p)phase=p;at=now()end
local function snap(name,time)request=name;captureTime=time;pending=true end
local function report(ok,error)
 love.filesystem.write('result.json',encode({success=ok,error=error,kind='playback',
  duration=cfg.duration,startAt=cfg.startAt,captures=captures,checks=checks,activeWall=activeWall}))
 print('OGV_BENCH '..love.filesystem.read('result.json'))
 love.event.quit()
end
function love.load()
 video=love.graphics.newVideo('sample.ogv')
 source=assert(video:getSource(),'embedded Vorbis Source missing')
 source:setVolume(0)
 if cfg.startAt then video:seek(cfg.startAt) end
 video:play();lastWall=now();enter('full')
end
local function update()
 local t=video:tell();local elapsed=now()-at
 local dt=now()-lastWall;lastWall=now()
 if phase=='full' then
  if t>0 and not started then started=now() end
  if started then activeWall=activeWall+dt end
  if checkpoints[nextCheckpoint] and t>=checkpoints[nextCheckpoint] then
   checks[#checks+1]={video=t,audio=source:tell()}
   assert(math.abs(t-source:tell())<.045,'audio clock mismatch')
   video:pause();pausedAt=video:tell();enter('full-pause')
  elseif not video:isPlaying() then
   assert(started and math.abs(activeWall-cfg.duration)<.35,'natural EOF wall time')
   checks.naturalEnd={video=t,activeWall=activeWall}
   snap('ended',cfg.duration-.001);enter('ended-capture')
  end
 elseif phase=='ended-capture' and not pending then video:rewind();video:play();enter('replay')
 elseif phase=='full-pause' and elapsed>.15 then
  assert(math.abs(video:tell()-pausedAt)<.045,'paused audio clock advanced')
  snap('full-'..nextCheckpoint);enter('full-capture')
 elseif phase=='full-capture' and not pending then
  nextCheckpoint=nextCheckpoint+1;video:play();enter('full')
 elseif phase=='replay' and t>=6 then
  video:pause();enter('replay-pause')
 elseif phase=='replay-pause' and elapsed>.15 then snap('replay');enter('replay-capture')
 elseif phase=='replay-capture' and not pending then video:seek(20.75);enter('seek-pause')
 elseif phase=='seek-pause' and elapsed>.2 then
  assert(not video:isPlaying() and math.abs(t-20.75)<.045,'paused seek state')
  snap('paused-seek');enter('seek-capture')
 elseif phase=='seek-capture' and not pending then
  video:play();video:seek(8);enter('playing-seek')
 elseif phase=='playing-seek' and t>=8.5 then video:pause();enter('playing-pause')
 elseif phase=='playing-pause' and elapsed>.15 then snap('playing-seek');enter('playing-capture')
 elseif phase=='playing-capture' and not pending then
  source:setLooping(true);video:seek(cfg.duration-.2);video:play();enter('loop')
 elseif phase=='loop' then
  if t<1 then checks.loopWrapped=true;enter('loop-running')
  else assert(elapsed<3,'loop did not wrap') end
 elseif phase=='loop-running' and t>=6 then video:pause();enter('loop-pause')
 elseif phase=='loop-pause' and elapsed>.15 then snap('loop');enter('loop-capture')
 elseif phase=='loop-capture' and not pending then report(true) end
 assert(now()-at<cfg.duration+5,'phase timeout: '..phase)
end
function love.update()
 if not video then return end
 local ok,error=xpcall(update,debug.traceback)
 if not ok then report(false,tostring(error));video=nil end
end
function love.draw()
 if not video then return end
 love.graphics.setColor(1,1,1,1);love.graphics.draw(video)
 if request then
  local file=request..'.png';request=nil;local time=captureTime or video:tell();captureTime=nil
  love.graphics.captureScreenshot(function(image)
   image:encode('png',file);captures[#captures+1]={file=file,time=time};pending=false
  end)
 end
end
