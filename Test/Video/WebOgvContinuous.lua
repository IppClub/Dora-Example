-- Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
-- Run alongside NativeVideoControls.lua for Web acceptance with the original OGV.
local D=require('Dora');local json=require('json')
return function(filename,output)
 local video=assert(D.VideoNode(filename,false))
 local audio=assert(video:getChildByTag('VideoAudio'),'embedded Vorbis missing');audio.volume=0
 local function moveSource(source)
  source:schedule(function()source.x=math.sin(D.App.runningTime)*10;return false end)
 end
 moveSource(audio)
 video.position=D.Vec2(video.width/2,video.height/2);D.Director.entry:addChild(video)
 local target=D.RenderTarget(math.floor(video.width),math.floor(video.height))
 local captures,checks={},{samples={}}
 local function snap(label)
  video:pause();D.sleep(.15)
  local time=video.currentTime;local file=label..'.png'
  target:renderWithClear(video,D.Color(0xff000000));assert(target:saveAsync(output..'/'..file))
  captures[#captures+1]={file=file,time=time}
 end
 D.thread(function()
  local ok,error=xpcall(function()
   local start=D.App.runningTime
   while video.currentTime==0 do assert(D.App.runningTime-start<4,'audio start timeout');D.sleep() end
   start=D.App.runningTime-video.currentTime
   for _,time in ipairs({1,6,20,40,51}) do
    while video.currentTime<time do assert(video.playing,'early EOF');assert(D.App.runningTime-start<video.duration+5,'clock stopped');D.sleep() end
    checks.samples[#checks.samples+1]={video=video.currentTime}
    print('OGV_SYNC '..assert(json.encode({video=video.currentTime})))
    local stamp=video.currentTime;local file='full-'..time..'.png'
    target:renderWithClear(video,D.Color(0xff000000));assert(target:saveAsync(output..'/'..file))
    captures[#captures+1]={file=file,time=stamp}
   end
   while video.playing do assert(D.App.runningTime-start<video.duration+.5,'EOF timeout');D.sleep() end
   checks.naturalEnd={wall=D.App.runningTime-start,time=video.currentTime}
   print('OGV_SYNC '..assert(json.encode({phase='natural-end',video=video.currentTime,wall=checks.naturalEnd.wall})))
   assert(math.abs(checks.naturalEnd.wall-video.duration)<.35,'natural EOF time')
   video:play()
   local deadline=D.App.runningTime+10
   while video.currentTime<6 do assert(video.playing,'replay failed');assert(D.App.runningTime<deadline,'replay clock stopped');D.sleep() end
   snap('replay')
   video:removeFromParent(true)
   video=assert(D.VideoNode(filename,true));audio=assert(video:getChildByTag('VideoAudio'));audio.volume=0
   moveSource(audio)
   video.position=D.Vec2(video.width/2,video.height/2);D.Director.entry:addChild(video)
   video:seek(video.duration-.2)
   deadline=D.App.runningTime+3
   while video.currentTime>1 do assert(D.App.runningTime<deadline,'loop failed');D.sleep() end
   deadline=D.App.runningTime+10
   while video.currentTime<6 do assert(video.playing,'loop did not continue');assert(D.App.runningTime<deadline,'loop clock stopped');D.sleep() end
   snap('loop');checks.loopWrapped=true
  end,debug.traceback)
  video:removeFromParent(true)
  local text=assert(json.encode({success=ok,error=not ok and tostring(error) or nil,
   kind='playback',captures=captures,checks=checks}))
  assert(D.Content:save(output..'/result.json',text));print('OGV_BENCH '..text)
 end)
end
