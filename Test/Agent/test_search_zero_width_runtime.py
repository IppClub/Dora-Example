"""Opt-in native search regression for the actual Ornith ^ crash."""
import json,pathlib,tempfile,urllib.request,time,shutil
root=pathlib.Path(tempfile.mkdtemp(prefix='dora-search-zero-'))
(root/'init.lua').write_text('return true\n')
(root/'sample.ts').write_text('aaa\n\n中文\n')
code=r'''local D=require("Dora");local U=require("Agent.Utils")
D.thread(function()
 local ok,err=pcall(function()
  local function search(pattern)
   local rows=D.Content:searchFilesAsync(projectDir,{"ts"},{},{"sample.ts"},pattern,true,true,true,20)
   for _,r in ipairs(rows) do assert(r.pos>=0 and r.pos<=12 and r.column>=1); assert(type(r.content)=="string") end
   return rows
  end
  local start=search("^");assert(#start==4,"^ must match original line starts once")
  local expected={0,4,5,12}
  for i,r in ipairs(start) do assert(r.pos==expected[i] and r.line==i and r.column==1) end
  assert(#search("^aa")==1,"anchored suffix matched twice")
  search("$") -- Preserve tiny-regex existing end-anchor semantics; verify safety.
  search("a*");search(".")
 end)
 D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=ok,message=tostring(err)}))
end)
print("ZERO_WIDTH_SEARCH_STARTED")'''
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
 r=json.load(op.open(urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps({'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':30}).encode(),headers={'Content-Type':'application/json'}),timeout=35));assert r['success'],r
 deadline=time.monotonic()+10
 while not (root/'result.json').exists() and time.monotonic()<deadline:time.sleep(.1)
 result=json.loads((root/'result.json').read_text());assert result['success'],result
 print('PASS: actual native ^, ^aa, $, a*, . searches; original line anchors, empty/trailing lines, UTF-8 snippets, no zero-width overrun.')
finally:shutil.rmtree(root)
