"""Native SQLite regression of the one-time, data-only output-budget upgrade."""
import json, os, pathlib, shutil, tempfile, urllib.request

root = pathlib.Path(tempfile.mkdtemp(prefix='dora-llm-migration-'))
(root / 'init.lua').write_text('return true\n')
engine = os.environ.get('DORA_ENGINE_ROOT', '/Users/Jin/Workspace/Dora-SSR')
code = r'''
local D=require('Dora')
local db=D.DB
local schema='budget_migration_test'
assert(not db:existDB(schema),'test schema already attached')
assert(db:exec('ATTACH DATABASE ? AS '..schema, {projectDir..'/fixture.db'}) >= 0)
local ok,err=pcall(function()
 assert(db:transaction({
  'CREATE TABLE '..schema..'.Config(name TEXT PRIMARY KEY,value_num REAL,value_str TEXT,value_bool INTEGER)',
  'CREATE TABLE '..schema..'.LLMConfig(id INTEGER PRIMARY KEY,max_tokens INTEGER,custom_options TEXT,name TEXT,api_key TEXT)',
  'CREATE TABLE '..schema..'.Unrelated(value TEXT)',
  "INSERT INTO "..schema..".Unrelated VALUES('preserve')",
 }))
 local function sql(s)
  return (s:gsub('%f[%w]LLMConfig%f[%W]',schema..'.LLMConfig'):gsub('%f[%w]Config%f[%W]',schema..'.Config'))
 end
 local fail=false
 local facade={json=D.json,DB={},Log=D.Log}
 function facade.DB:exist(name) return db:exist(name,schema) end
 function facade.DB:query(s,...) return db:query(sql(s),...) end
 function facade.DB:transaction(stmts)
  local mapped={}
  for _,stmt in ipairs(stmts) do
   if type(stmt)=='string' then mapped[#mapped+1]=sql(stmt)
   else mapped[#mapped+1]={sql(stmt[1]),stmt[2]} end
  end
  if fail then mapped[#mapped+1]='UPDATE missing_migration_table SET x=1' end
  return db:transaction(mapped)
 end
 local env=setmetatable({require=function(name)
  if name=='Dora' then return facade end
  if name=='Agent.Config.Defaults' then return assert(loadfile('ENGINE_ROOT/Assets/Script/Lib/Agent/Config/Defaults.lua'))() end
  return require(name)
 end},{__index=_G})
 local M=assert(load(assert(D.Content:load('ENGINE_ROOT/Assets/Script/Lib/Agent/Config/LLMConfigMigration.lua')),'migration-test','t',env))()
 local function query(s) return assert(db:query(sql(s))) end
 local function exec(s,args) local n;if args then n=db:exec(sql(s),args) else n=db:exec(sql(s)) end;assert(n>=0) end
 local function version() local r=query("SELECT value_num FROM Config WHERE name='agentLLMConfigVersion'");return r[1] and r[1][1] end
 local function options(id) return assert(D.json.decode(query('SELECT custom_options FROM LLMConfig WHERE id='..id)[1][1])) end
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{1,8192,'{"max_tokens":1024,"auxiliaryOptions":{"max_tokens":2048,"max_completion_tokens":4096,"reasoning_effort":"low"},"top_p":0.95}','fixture','test-only'})
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{2,131072,'{"max_tokens":null,"max_completion_tokens":8192,"auxiliaryOptions":{"thinking":{"type":"disabled"}}}','fixture2','test-only'})
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{3,2048,'','fixture3','test-only'})
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{4,2048,'{"max_tokens":null,"max_completion_tokens":null}','fixture4','test-only'})
 local unrelatedJSON='{ "top_p": 0.95, "auxiliaryOptions": {"reasoning_effort": "low"} }'
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{5,8192,unrelatedJSON,'fixture5','test-only'})
 local before=query('SELECT name,sql FROM '..schema..'.sqlite_master ORDER BY name')
 -- A failed transaction must roll back every change, including the version marker.
 fail=true
 local migrated,migrationError=pcall(M.upgradeLLMConfig);assert(not migrated,'expected failure: '..tostring(migrationError))
 assert(version()==nil and query('SELECT max_tokens FROM LLMConfig WHERE id=1')[1][1]==8192,'rollback failed version='..tostring(version()))
 assert(options(1).auxiliaryOptions.max_tokens==2048)
 fail=false
 M.upgradeLLMConfig()
 assert(version()==M.LLM_CONFIG_VERSION)
 for _,r in ipairs(query('SELECT max_tokens,name,api_key FROM LLMConfig')) do assert(r[1]==64000 and r[3]=='test-only') end
 local a,b=options(1),options(2)
 assert(a.max_tokens==64000 and a.top_p==0.95)
 assert(a.auxiliaryOptions.max_tokens==nil and a.auxiliaryOptions.max_completion_tokens==nil and a.auxiliaryOptions.reasoning_effort=='low')
 assert(b.max_tokens==D.json.null and b.max_completion_tokens==64000 and b.auxiliaryOptions.thinking.type=='disabled')
 assert(options(4).max_tokens==nil)
 assert(query('SELECT custom_options FROM LLMConfig WHERE id=5')[1][1]==unrelatedJSON,'unrelated custom JSON was rewritten')
 local after=query('SELECT name,sql FROM '..schema..'.sqlite_master ORDER BY name')
 assert(#before==#after)
 for i,r in ipairs(before) do assert(r[1]==after[i][1] and r[2]==after[i][2],'schema changed') end
 assert(query('SELECT value FROM '..schema..'.Unrelated')[1][1]=='preserve')
 -- Simulate a later user edit and a fresh module load: it must not be forced again.
 exec('UPDATE LLMConfig SET max_tokens=32768 WHERE id=1')
 M=assert(load(assert(D.Content:load('ENGINE_ROOT/Assets/Script/Lib/Agent/Config/LLMConfigMigration.lua')),'migration-test','t',env))()
 M.upgradeLLMConfig()
 assert(query('SELECT max_tokens FROM LLMConfig WHERE id=1')[1][1]==32768)
 -- Invalid legacy JSON must remain editable and must not block other rows.
 exec("DELETE FROM Config WHERE name='agentLLMConfigVersion'")
 exec('UPDATE LLMConfig SET custom_options=? WHERE id=1',{'{bad json'})
 exec('UPDATE LLMConfig SET custom_options=? WHERE id=2',{'{"auxiliaryOptions":{"max_tokens":1024,"reasoning_effort":"low"}}'})
 M.upgradeLLMConfig()
 assert(version()==1 and query('SELECT max_tokens FROM LLMConfig WHERE id=1')[1][1]==64000)
 assert(query('SELECT custom_options FROM LLMConfig WHERE id=1')[1][1]=='{bad json')
 assert(options(2).auxiliaryOptions.max_tokens==nil and options(2).auxiliaryOptions.reasoning_effort=='low')
 exec('UPDATE LLMConfig SET custom_options=? WHERE id=1',{'{}'})
 M.upgradeLLMConfig()
 assert(version()==1)
 -- Empty, newly initialized configuration storage is also marked once.
 exec('DELETE FROM LLMConfig');exec("DELETE FROM Config WHERE name='agentLLMConfigVersion'")
 M.upgradeLLMConfig();assert(version()==1)
 exec("UPDATE Config SET value_num=2 WHERE name='agentLLMConfigVersion'")
 exec('INSERT INTO LLMConfig VALUES(?,?,?,?,?)',{1,32768,'{}','fixture','test-only'})
 M.upgradeLLMConfig();assert(version()==2 and query('SELECT max_tokens FROM LLMConfig')[1][1]==32768)
 exec('DROP TABLE LLMConfig');M.upgradeLLMConfig()
end)
assert(db:exec('DETACH DATABASE '..schema)>=0)
assert(ok,tostring(err))
print('LLM_CONFIG_MIGRATION_PASS: atomic rollback, forced 64000, auxiliary cleanup, reasoning preserved, field selection, unchanged schema, one-time persistence, invalid JSON, empty database')
'''.replace('ENGINE_ROOT',engine)
try:
 op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
 body={'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':30}
 result=json.load(op.open(urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'}),timeout=35))
 assert result['success'],result
 print(json.dumps(result,ensure_ascii=False))
finally:
 shutil.rmtree(root)
