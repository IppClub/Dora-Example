local module = assert((arg and arg[1]) or os.getenv("DORA_GODOT_PLAYER_SOURCE"), "GodotPlayer.lua path required")
local cases = 0
local function setup()
    local nodes, games, created = {}, {}, {}
    local D = {Director={ui={}}}
    function D.Node()
        local n = {}
        function n:addTo() return self end
        function n:schedule(fn) self.fn = fn end
        function n:removeFromParent() self.dead = true end
        nodes[#nodes+1] = n
        return n
    end
    function D.GodotNode(path)
        local g = {path=path,running=false,lastError="",acks={}}
        function g:addTo() return self end
        function g:unloadAsync(fn) self.acks[#self.acks+1]=fn end
        function g:ack(ok,err)
            local callbacks=self.acks;self.acks={};self.unloaded=ok
            for _,fn in ipairs(callbacks) do fn(ok,err or "") end
        end
        games[#games+1]=g;created[#created+1]=path
        return g
    end
    package.loaded.Dora=D
    local Player=assert(loadfile(module))()
    local p=Player()
    local function tick(dt)
        for _,n in ipairs(nodes) do if not n.dead then n.fn(dt or 0.1) end end
    end
    return p,tick,games,created
end
local function test(name,body)
    body();cases=cases+1;print("PASS "..name)
end
test("FIFO and native acknowledgement gate",function()
    local p,t,g,created=setup();local done={}
    p:switchAsync("A",{},function(ok,node) assert(ok and node==g[1]);done[#done+1]="A" end)
    p:switchAsync("B",{},function(ok) assert(ok);done[#done+1]="B" end)
    assert(#g==0);t();assert(#g==1)
    g[1].running=true;t();assert(p.state=="unloading" and #g==1 and #done==1)
    for i=1,5 do t() end;assert(#g==1,"elapsed time bypassed the barrier")
    g[1]:ack(true);assert(#g==2 and created[2]=="B")
    g[2].running=true;t();assert(table.concat(done)=="AB")
end)
test("callback reentrancy preserves queued order",function()
    local p,t,g,c=setup()
    p:switchAsync("A",{},function() p:switchAsync("C") end)
    p:switchAsync("B");t();g[1].running=true;t();g[1]:ack(true)
    g[2].running=true;t();g[2]:ack(true);assert(table.concat(c)=="ABC")
end)
test("failed startup drains before notifying or continuing",function()
    local p,t,g=setup();local result
    p:switchAsync("bad",{},function(ok,_,err) assert(not ok and err=="bad script");result=true end)
    p:switchAsync("good");t();g[1].lastError="bad script";t()
    assert(not result and #g==1);g[1]:ack(true);assert(result);t();assert(#g==2)
end)
test("timeout uses the same unload barrier",function()
    local p,t,g=setup();local done=false
    p:switchAsync("slow",{timeout=1},function(ok,_,err) assert(not ok and err:find("timed out"));done=true end)
    t();t(2);assert(not done);g[1]:ack(true);assert(done)
end)
test("failed unload faults queued requests and close",function()
    local p,t,g=setup();local errors=0;local closed
    p:switchAsync("A");p:switchAsync("B",{},function(ok,_,err) assert(not ok and err=="unsafe");errors=errors+1 end)
    p:switchAsync("C",{},function(ok) assert(not ok);errors=errors+1 end)
    p:closeAsync(function(ok,err) assert(not ok and err=="unsafe");closed=true end)
    t();g[1].running=true;t();g[1]:ack(false,"unsafe");t()
    assert(#g==1 and errors==2 and closed and p.state=="closed")
end)
test("close drains queued work and rejects new requests",function()
    local p,t,g=setup();local count=0
    p:switchAsync("A");p:closeAsync(function(ok) assert(ok);count=count+1 end)
    p:closeAsync(function(ok) assert(ok);count=count+1 end)
    assert(p:switchAsync("B")==nil)
    t();g[1].running=true;t();assert(count==0);g[1]:ack(true);assert(count==2 and p.state=="closed")
    p:closeAsync(function(ok) assert(ok);count=count+1 end);assert(count==2);t();assert(count==3)
end)
test("callback errors do not wedge the queue",function()
    local p,t,g=setup()
    p:switchAsync("A",{},function() error("expected callback error") end)
    p:switchAsync("B");t();g[1].running=true;t();assert(p.state=="unloading");g[1]:ack(true);assert(#g==2)
end)
test("empty unload is asynchronous and invalid options are rejected",function()
    local p,t,g=setup();local done=false
    p:unloadAsync(function(ok) assert(ok);done=true end);assert(not done);t();assert(done)
    assert(not pcall(function() p:switchAsync("A",{width=0}) end));assert(#g==0)
end)
assert(cases==8);print("GodotPlayer contract: PASS (8 cases)")
