local D=require('Dora'); local json=require('json')
local source=D.Content:getFullPath('Example/Creation3D/Game.lua'):match('^(.*)/Game.lua$'); D.Content:insertSearchPath(1,source)
local output=D.Content:getFullPath('Test/Creation3D/Animation.lua'):match('^(.*)/Animation.lua$')..'/evidence/'
local P=require('Kit.Primitive'); P.preset(D.Director.entry)
local A=require('Kit.Adapter'); local m,r=A.load(require('Assets').Fox,D.Director.entry); assert(m)
D.thread(function()
  local results={}; local violations={}
  for _,semantic in ipairs({'idle','walk','run'}) do
    assert(A.play(r,semantic):match('^playing:'),'semantic clip not playing')
    local duration=m.duration; local elapsed=0; local maxRadius,maxY,minY=0,0,math.huge; local initial=m.elapsed
    repeat
      D.sleep(); elapsed=elapsed+D.App.deltaTime
      local envelope=A.checkEnvelope(r)
      if not envelope.ok and not violations[semantic] then violations[semantic]=envelope.diagnostics end
      local mn,mx=m:getWorldBoundsMin(),m:getWorldBoundsMax()
      local x=math.max(math.abs(mn.x),math.abs(mx.x)); local z=math.max(math.abs(mn.z),math.abs(mx.z))
      maxRadius=math.max(maxRadius,math.sqrt(x*x+z*z)); maxY=math.max(maxY,mx.y); minY=math.min(minY,mn.y)
    until elapsed>duration+.1
    if maxRadius>r.collider.radius then violations[semantic]=violations[semantic] or {{message='radius exceeds collider'}} end
    if maxY>r.collider.height then violations[semantic]=violations[semantic] or {{message='height exceeds collider'}} end
    assert(minY>=-(r.profile.groundTolerance or 0)-.00001,'animated feet substantially below ground')
    assert(m.playing and m.elapsed~=initial,'clip time did not advance')
    results[#results+1]={semantic=semantic,clip=r.mapping[semantic],sampleSeconds=elapsed,maxRadius=maxRadius,maxY=maxY,minY=minY}
  end
  D.Content:save(output..'animation.json',assert(json.encode({status=next(violations) and 'failed' or 'passed',violations=violations,checks=results,scope='one full cycle each, current world bounds; not all possible animation blends'})))
  print('CREATION3D_ANIMATION PASS')
end)
