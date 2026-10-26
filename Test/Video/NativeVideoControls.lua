-- Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
-- Run inside Dora: dofile(thisFile)(originalOgvPath, existingOutputDirectory).
-- The original multiplexed OGV is used directly. Audio is muted during checks.
local D = require('Dora')
local json = require('json')
return function(filename, output)
 local records, nodes = {}, {}
 local function make(looped)
  local video = assert(D.VideoNode(filename, looped))
  local audio = assert(video:getChildByTag('VideoAudio'), 'fixture needs embedded Vorbis')
  audio.volume = 0
  video:pause()
  D.Director.entry:addChild(video)
  nodes[#nodes+1] = video
  return video
 end
 local video = make(false)
 local duration = video.duration
 assert(duration > 1, 'fixture needs at least one second')
 video.position = D.Vec2(video.width/2, video.height/2)
 local target = D.RenderTarget(math.floor(video.width), math.floor(video.height))
 local function capture(label)
  assert(video.paused or not video.playing, 'capture must hold the target image')
  local time = video.currentTime
  local file = label..'.png'
  target:renderWithClear(video, D.Color(0xff000000))
  assert(target:saveAsync(output..'/'..file))
  records[#records+1] = {file=file, time=time, label=label}
  assert(math.abs(video.currentTime-time)<1e-6, 'paused clock advanced during GPU readback')
 end
 D.thread(function()
  local ok, error = xpcall(function()
   assert(not video.playing and video.paused and video.currentTime==0)
   local targets = {math.floor(duration*.4*4)/4, math.floor(duration*.025*4)/4,
    math.floor(duration*.87*4)/4, 0, math.floor(duration*.2*4)/4}
   for index, time in ipairs(targets) do
    video:pause(); video:seek(time)
    assert(video.paused and not video.playing and math.abs(video.currentTime-time)<1e-6)
    D.sleep(.2); capture('paused-'..index)
    video:play(); assert(video.playing and not video.paused)
    D.sleep(.25); video:pause()
    assert(video.currentTime>time and video.currentTime<math.min(duration,time+.6))
    D.sleep(.1); capture('resumed-'..index)
   end
   video:seek(duration*.1); video:seek(duration*.8); video:seek(duration*.05)
   D.sleep(.2); capture('latest-seek')
   video:play(); D.sleep(.1); video:seek(duration*.3)
   D.sleep(.25); video:pause(); D.sleep(.1); capture('playing-seek')
   video:seek(duration-.15); video:play()
   local deadline=D.App.runningTime+4
   while video.playing and D.App.runningTime<deadline do D.sleep() end
   assert(not video.playing and math.abs(video.currentTime-duration)<1e-6, 'EOF state')
   D.sleep(.1); capture('ended')
   video:play(); assert(video.playing)
   D.sleep(.25); video:pause(); D.sleep(.1); capture('replayed')
   assert(video.currentTime>0 and video.currentTime<.6, 'EOF replay clock')
   video:rewind(); assert(video.paused and video.currentTime==0)
   D.sleep(.2); capture('rewound')
   video:seek(-1); assert(video.currentTime==0)
   video:seek(math.huge); assert(video.currentTime==0)
   video:seek(0/0); assert(video.currentTime==0)
   video:seek(duration+10); D.sleep(.2); capture('clamped-end')
   assert(not video.playing and video.currentTime==duration)
   local loop=make(true)
   assert(math.abs(loop.duration-duration)<1e-6)
   loop:seek(duration-.15); loop:play()
   deadline=D.App.runningTime+4
   while loop.currentTime>1 and D.App.runningTime<deadline do D.sleep() end
   assert(loop.playing and loop.currentTime<1, 'loop did not restart after seek')
  end, debug.traceback)
  for _, node in ipairs(nodes) do node:removeFromParent(true) end
  assert(D.Content:save(output..'/result.json',assert(json.encode({success=ok,
   error=not ok and tostring(error) or nil, duration=duration, captures=records}))))
  print('VIDEO_CONTROLS_NATIVE '..tostring(ok))
 end)
 return video
end
