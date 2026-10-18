#!/usr/bin/env python3
"""Production Agent storage Lua against real SQLite, plus optional desktop acceptance.

The CI adapter supplies Dora's DB/UI boundary, not a second cleanup
implementation. --engine additionally verifies the native codec, manual
cleanup, HTTP usage endpoint and complete multi-checkpoint file rollback in a
disposable engine profile.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import socket
import sqlite3
import subprocess
import tempfile
import time
import urllib.request
import zlib

ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()

SCENARIOS = r'''
local D = require("Dora")
local DB = D.DB
local S = require("Agent.Storage.Database")
assert(S.isAgentStorageReady(), S.getAgentStorageError())
if TEST_CALLBACK_COUNT then assert(TEST_CALLBACK_COUNT()==0, "storage initialization installed a background job") end
local function exec(sql, args) local n; if args then n=DB:exec(sql,args) else n=DB:exec(sql) end; assert(n >= 0,sql) end
local function scalar(sql, args) local rows; if args then rows=DB:query(sql,args) else rows=DB:query(sql) end; return assert(rows)[1][1] end
local function usage() local r = S.getStorageUsage(); assert(r.success, r.message); return r.usage end
assert(usage().records.tasks == 0, "acceptance requires an empty disposable profile")
for i = 1, 17 do
 local status = i == 8 and "RUNNING" or i == 10 and "WAITING_USER" or "DONE"
 exec("INSERT INTO agent.AgentTask(id,status,prompt,created_at,updated_at) VALUES(?,?,?,1,1)", {i,status,"retained prompt "..i})
 exec("UPDATE agent.AgentTask SET head_seq=1 WHERE id=?", {i})
 if i ~= 12 and i ~= 14 then
  exec("INSERT INTO agent.AgentCheckpoint(id,task_id,seq,status,created_at) VALUES(?,?,1,'APPLIED',1)", {i,i})
  local parts={};for n=1,3000 do parts[n]=string.format("%08x",n*2654435761) end
  local text = "checkpoint内容"..table.concat(parts)
  exec("INSERT INTO agent.AgentCheckpointEntry(checkpoint_id,ord,path,op,before_exists,before_data,after_exists,after_data,bytes_before,bytes_after) VALUES(?,1,'fixture.lua','write',1,dora_compress_text(?),1,dora_compress_text(?),?,?)", {i,text,text,#text,#text})
  exec("INSERT INTO agent.AgentSessionStep(session_id,task_id,step,reason,created_at,updated_at) VALUES(1,?,1,'keep or reclaim',1,1)", {i})
 end
end
exec("INSERT INTO agent.AgentSession(id,project_root,kind,current_task_id,status,created_at,updated_at) VALUES(1,?,'main',1,'DONE',1,1)", {TEST_PROJECT})
-- A current completed task and its cyclic, transitive/shared references remain
-- fully operable. Detached active/waiting tasks also protect their descendants.
for _, edge in ipairs({{1,2},{2,3},{3,2},{1,4},{5,4},{5,6},{6,7},{7,5},{8,9},{10,11}}) do
 assert(S.addTaskReference(edge[1],edge[2]))
end
exec("INSERT INTO agent.AgentSessionMessage(session_id,task_id,role,content,display_content,created_at,updated_at) VALUES(1,12,'user',?,'display',1,1)", {"聊天历史必须保留"})
exec("INSERT INTO agent.AgentSessionMessage(session_id,task_id,role,content,created_at,updated_at) VALUES(1,13,'assistant','retained answer',1,1)")
local history = scalar("SELECT group_concat(content,'|') FROM agent.AgentSessionMessage ORDER BY id")
local protected = {1,2,3,4,8,9,10,11}
local initial = usage()
assert(initial.records.messages == 2 and initial.records.checkpoints == 15)
assert(initial.payload.messageBytes == #"聊天历史必须保留" + #"display" + #"retained answer")
assert(initial.payload.checkpointStoredBytes < initial.payload.checkpointRawBytes)
assert(initial.orphanHeavyData.taskCount == 8)
assert(initial.orphanHeavyData.checkpointCount == 7)
local function assertProtected()
 for _, id in ipairs(protected) do
  assert(scalar("SELECT count(*) FROM agent.AgentCheckpointEntry WHERE checkpoint_id=?", {id}) == 1, "protected checkpoint removed "..id)
 end
 assert(scalar("SELECT group_concat(content,'|') FROM agent.AgentSessionMessage ORDER BY id") == history, "chat history changed")
end
for _, id in ipairs(protected) do assert(not S.cleanupTaskHeavyData(id), "direct cleanup bypassed protection") end
assertProtected()
if TEST_FAULTS then
 TEST_FAULTS.query = true
 local failed = S.cleanupOrphanHeavyDataBatch()
 assert(not failed.success and failed.cleanedTaskCount == 0, "query failure must fail closed")
 TEST_FAULTS.query = true
 assert(not S.getStorageUsage().success, "failed statistics must not be reported as empty")
 TEST_FAULTS.transaction = true
 local failedTx = S.cleanupOrphanHeavyDataBatch(1)
 assert(failedTx.failedTaskCount == 1 and failedTx.cleanedTaskCount == 0)
 assert(scalar("SELECT count(*) FROM agent.AgentCheckpointEntry WHERE checkpoint_id=5") == 1, "failed transaction partially deleted blobs")
 assert(scalar("SELECT count(*) FROM agent.AgentCheckpoint WHERE id=5") == 1, "failed transaction partially deleted checkpoint")
 -- The audit may succeed while the final pre-delete reachability check fails.
 TEST_FAULTS.query = 2
 local finalGuard = S.cleanupOrphanHeavyDataBatch(1)
 assert(finalGuard.failedTaskCount == 1 and finalGuard.cleanedTaskCount == 0)
 assert(usage().orphanHeavyData.taskCount == 8, "failed final guard allowed deletion")
 assertProtected()
end
local batch = S.cleanupOrphanHeavyDataBatch(1)
assert(batch.success and batch.cleanedTaskCount == 1)
assert(usage().orphanHeavyData.taskCount == 7, "recursive cleanup exceeded one-task budget")
assertProtected()
local batch2 = S.cleanupOrphanHeavyDataBatch(4)
assert(batch2.cleanedTaskCount == 4 and usage().orphanHeavyData.taskCount == 3)
assertProtected()
while usage().orphanHeavyData.taskCount > 0 do assert(S.cleanupOrphanHeavyDataBatch().cleanedTaskCount > 0) end
assertProtected()
assert(scalar("SELECT count(*) FROM agent.AgentTask WHERE id IN (12,13)") == 2, "history task metadata removed")
assert(scalar("SELECT count(*) FROM agent.AgentTaskReference WHERE owner_task_id IN (5,6,7)") == 0)
local after = usage()
assert(after.records.checkpoints == #protected and after.payload.checkpointRawBytes < initial.payload.checkpointRawBytes)
assert(after.database.allocatedBytes == after.database.usedBytes + after.database.freeBytes)
assert(after.database.freeBytes > 0, "SQLite free pages must be reported separately")
-- Releasing a reference makes only its now-unreachable subgraph eligible.
exec("DELETE FROM agent.AgentTaskReference WHERE owner_task_id=1 AND target_task_id=2")
assert(usage().orphanHeavyData.taskCount == 2, "unreferenced cycle was not collectible")
assert(S.cleanupOrphanHeavyDataBatch().cleanedTaskCount == 2)
assert(scalar("SELECT count(*) FROM agent.AgentCheckpoint WHERE id=4") == 1, "shared target was removed")
-- A previously selected candidate becomes protected before deletion.
exec("INSERT INTO agent.AgentTask(id,status,created_at,updated_at) VALUES(100,'DONE',1,1)")
local candidates = S.auditOrphanHeavyData()
assert(candidates.taskCount == 1)
assert(S.addTaskReference(1,100))
assert(not S.cleanupTaskHeavyData(100), "new reference ignored by final deletion guard")
exec("DELETE FROM agent.AgentTaskReference WHERE target_task_id=100")
assert(S.cleanupOrphanHeavyDataBatch().cleanedTaskCount == 1)
-- Reading usage or passing time must never collect this orphan automatically.
exec("INSERT INTO agent.AgentTask(id,status,created_at,updated_at) VALUES(200,'DONE',1,1)")
exec("INSERT INTO agent.AgentCheckpoint(id,task_id,seq,status,created_at) VALUES(200,200,1,'APPLIED',1)")
local garbage=string.rep("orphan checkpoint",10000)
exec("INSERT INTO agent.AgentCheckpointEntry(checkpoint_id,ord,path,op,before_exists,before_data,after_exists,after_data,bytes_before,bytes_after) VALUES(200,1,'orphan.lua','write',1,dora_compress_text(?),1,dora_compress_text(?),?,?)",{garbage,garbage,#garbage,#garbage})
if TEST_TICK then
 TEST_TICK(5);TEST_TICK(60000)
 assert(scalar("SELECT count(*) FROM agent.AgentTask WHERE id=200") == 1, "unsolicited cleanup ran")
 assert(TEST_CALLBACK_COUNT()==0)
end
print("PASS: real SQLite cleanup, bounded batches, cyclic/transitive/shared references, detached active roots, history preservation and usage accounting")
'''

UI_SCENARIOS = r'''
local D=require("Dora")
local S=require("Agent.Storage.Database")
local open, clicked, disabled = false, nil, false
local pending, schedules = 0, 0
local retryFailure = TEST_FAULTS ~= nil
local texts={}
local fake={}
function fake.TreeNode(_,inside) if open then inside() end;return open end
function fake.Text(text) texts[#texts+1]=text end
fake.TextWrapped=fake.Text
function fake.SameLine() end
function fake.PushTextWrapPos(_,inside) inside() end
function fake.IsItemHovered() return false end
function fake.BeginTooltip(inside) inside() end
function fake.BeginDisabled(inside) local old=disabled;disabled=true;inside();disabled=old end
function fake.Button(label)
 if not disabled and label==clicked then clicked=nil;return true end
 return false
end
local render
local facade={ImGui=fake,Director={systemScheduler={schedule=function(_,fn)
 pending=pending+1;schedules=schedules+1
 D.Director.systemScheduler:schedule(function()
  if fn() then
   pending=pending-1
   assert(pending==0)
   clicked=nil
   if retryFailure then
    retryFailure=false
    assert(S.getStorageUsage().usage.orphanHeavyData.taskCount==1,"failed cleanup deleted data")
    render(false)
    assert(schedules==1 and pending==0,"failed cleanup retried without a click")
    assert(table.concat(texts,"\n"):find("Some data remains",1,true),"failure result missing")
    clicked="Clean previous turn data";render(false)
    assert(schedules==2 and pending==1,"manual retry did not start")
    return true
   end
   assert(S.getStorageUsage().usage.orphanHeavyData.taskCount==0)
   render(false)
   assert(table.concat(texts,"\n"):find("Cleaned 1 tasks.",1,true),"cleanup result missing")
   local before=schedules;clicked="Clean previous turn data";render(false)
   assert(schedules==before,"empty cleanup button was enabled")
   TEST_UI_FINISHED=true
   print("PASS: production settings panel, cached usage, disabled duplicate/empty cleanup, finite failure and explicit retry")
   if TEST_UI_COMPLETE then TEST_UI_COMPLETE() end
   return true
  end
  return false
 end)
end}}}
local env=setmetatable({require=function(name) if name=="Dora" then return facade end;return require(name) end},{__index=_G})
render=assert(loadfile(ENGINE_ROOT.."/Assets/Script/Dev/AgentStoragePanel.lua","t",env))()
local queries=TEST_QUERY_COUNT
render(false)
if queries then assert(TEST_QUERY_COUNT==queries,"collapsed panel queried storage") end
open=true;render(false)
queries=TEST_QUERY_COUNT
for i=1,10 do render(false) end
if queries then assert(TEST_QUERY_COUNT==queries,"panel queried every frame") end
assert(table.concat(texts,"\n"):find("Previous turns with cleanable data: 1",1,true))
clicked="Refresh usage";render(false)
if queries then assert(TEST_QUERY_COUNT>queries,"refresh button did not read usage") end
assert(schedules==0,"statistics triggered background cleanup")
if TEST_FAULTS then TEST_FAULTS.transaction=true end
clicked="Clean previous turn data";render(false)
assert(schedules==1 and pending==1,"cleanup button did not schedule one finite operation")
clicked="Clean previous turn data";render(false)
assert(schedules==1,"duplicate cleanup was allowed while busy")
'''

ADAPTER = r'''
package.path = ENGINE_ROOT.."/Assets/Script/Lib/?.lua;"..package.path
local function encode(v)
 if type(v)=="table" then local a={}; for i=1,#v do a[i]=encode(v[i]) end; return "["..table.concat(a,",").."]" end
 if type(v)=="string" then return '"'..v:gsub('[%z\1-\31\\"]',function(c) return string.format('\\u%04x',c:byte()) end)..'"' end
 if v==nil then return "null" end
 return tostring(v)
end
local function rpc(op,sql,args)
 io.write(encode({op,sql,args or {}}).."\n");io.flush()
 return assert(load("return "..assert(io.read("*l")),"SQLite reply","t",{}))()
end
local callbacks={}
local app={platform="Linux",runningTime=0}
TEST_FAULTS={}
local db={}
function db:existDB(name) return rpc("exists",name) end
function db:query(sql,args)
 TEST_QUERY_COUNT=(TEST_QUERY_COUNT or 0)+1
 if TEST_FAULTS.query and sql:find("WITH RECURSIVE protected",1,true) then
  local left = type(TEST_FAULTS.query)=="number" and TEST_FAULTS.query-1 or 0
  TEST_FAULTS.query = left>0 and left or nil
  if left==0 then return nil end
 end
 return rpc("query",sql,args)
end
function db:exec(sql,args) return rpc("exec",sql,args) end
function db:transaction(sql)
 if TEST_FAULTS.transaction then TEST_FAULTS.transaction=nil;return rpc("fail_transaction",sql) end
 return rpc("transaction",sql)
end
local function path(...)
 local parts=table.pack(...)
 for i=1,parts.n do assert(type(parts[i])=="string","Path expects non-nil string components") end
 return table.concat(parts,"/",1,parts.n)
end
package.loaded.Dora={App=app,Content={appPath=TEST_PROFILE,writablePath=TEST_PROFILE},DB=db,Path=path,Director={systemScheduler={schedule=function(_,fn) callbacks[#callbacks+1]=fn end}}}
package.loaded['Agent.Utils']={Log=function() end}
function TEST_CALLBACK_COUNT() return #callbacks end
function TEST_TICK(t)
 app.runningTime=t
 for i=#callbacks,1,-1 do if callbacks[i]() then table.remove(callbacks,i) end end
end
'''


def lua_value(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua_value(v) for v in value) + '}'
    if isinstance(value, bytes):
        return '"' + ''.join('\\%03d' % b for b in value) + '"'
    if isinstance(value, str):
        return lua_value(value.encode())
    return repr(value)


def sqlite_fixture(temp):
    connection = sqlite3.connect(':memory:')
    # Compatible boundary representation for the production codec's probe;
    # --engine below additionally exercises the actual C++ codec.
    connection.create_function('dora_compress_text', 1, lambda s: zlib.compress(s.encode()) if len(s.encode()) >= 512 else s)
    connection.create_function('dora_decompress_text', 1, lambda s: zlib.decompress(s).decode() if isinstance(s, bytes) else s)
    source = temp / 'fixture.lua'
    source.write_text('ENGINE_ROOT=' + lua_value(str(ROOT)) + '\nTEST_PROFILE=' + lua_value(str(temp)) + '\nTEST_PROJECT="/fixture"\n' + ADAPTER + SCENARIOS + UI_SCENARIOS + '\nfor i=1,10 do TEST_TICK(60000+i) end;assert(TEST_UI_FINISHED and TEST_CALLBACK_COUNT()==0)\n')
    proc = subprocess.Popen([os.environ.get('DORA_LUA', 'lua'), str(source)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    try:
        for line in proc.stdout:
            if line.startswith('PASS:'):
                print(line.strip(), flush=True)
                continue
            op, sql, args = json.loads(line)
            if op == 'exists':
                result = any(r[1] == sql for r in connection.execute('PRAGMA database_list'))
            elif op == 'query':
                result = connection.execute(sql, args).fetchall()
            elif op == 'exec':
                before = connection.total_changes
                connection.execute(sql, args)
                connection.commit()
                result = connection.total_changes - before
            elif op in ('transaction', 'fail_transaction'):
                try:
                    connection.execute('BEGIN')
                    for index, command in enumerate(sql):
                        connection.execute(command)
                        if op == 'fail_transaction' and index == 0:
                            raise sqlite3.OperationalError('injected mid-transaction failure')
                    connection.commit()
                    result = True
                except sqlite3.OperationalError:
                    connection.rollback()
                    result = False
            else:
                raise AssertionError(op)
            proc.stdin.write(lua_value(result) + '\n')
            proc.stdin.flush()
        assert proc.wait(timeout=5) == 0
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        connection.close()


def native_fixture(engine, temp, hold=False):
    assert os.name != "nt", "Native profile isolation currently supports macOS/Linux only"
    for port in (8866, 8868):
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1', port))
    profile = temp / 'profile'
    profile.mkdir()
    project = temp / 'project'
    project.mkdir()
    (project / 'init.lua').write_text('return true\n')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def post(route, data=None):
        request = urllib.request.Request('http://127.0.0.1:8866' + route, data=json.dumps(data or {}).encode(), headers={'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin'})
        with opener.open(request, timeout=30) as response:
            return json.load(response)

    def command(code):
        result = post('/agent/command', {'projectRoot': str(project), 'mode': 'lua', 'code': code, 'timeoutSeconds': 20})
        assert result['success'], result
        return result

    with (temp / 'native.log').open('w+') as log:
        proc = subprocess.Popen([str(engine), '--asset', str(ROOT / 'Assets')], cwd=ROOT / 'Assets', stdout=log, stderr=log,
                                env={**os.environ, 'CFFIXED_USER_HOME': str(profile), 'XDG_DATA_HOME': str(profile / 'data')})
        try:
            deadline = time.monotonic() + 30
            while True:
                try:
                    status = post('/status')
                    assert profile in Path(status['writablePath']).parents, status
                    break
                except OSError:
                    assert time.monotonic() < deadline and proc.poll() is None, 'engine startup failed'
                    time.sleep(.1)
            command('TEST_PROJECT=projectDir\n' + SCENARIOS)
            usage = post('/agent/storage/usage')
            assert usage['success'], usage
            time.sleep(6)
            usage = post('/agent/storage/usage')
            assert usage['success'] and usage['usage']['orphanHeavyData']['taskCount'] == 1, usage
            if hold:
                print('NATIVE SETTINGS READY: manually open Misc / Agent storage and clean previous turn data', flush=True)
                input('Press Enter after native UI acceptance: ')
            else:
                command('local S=require("Agent.Storage.Database");local r=S.cleanupOrphanHeavyDataBatch(4);assert(r.success and r.cleanedTaskCount==1)')
            deadline = time.monotonic() + 10
            while True:
                usage = post('/agent/storage/usage')
                assert usage['success'], usage
                if usage['usage']['orphanHeavyData']['taskCount'] == 0:
                    break
                assert time.monotonic() < deadline, 'manual orphan cleanup did not finish'
                time.sleep(.1)
            assert usage['usage']['records']['messages'] == 2, usage
            databases = list(profile.rglob('agent.db'))
            assert len(databases) == 1, databases
            assert databases[0].stat().st_size == usage['usage']['database']['allocatedBytes'], usage
            # Multiple file revisions on the current task must remain intact,
            # including the earliest before-image needed for whole-task undo.
            command(r'''
local D=require("Dora");local S=require("Agent.Storage.Database");local C=require("Agent.Tool.Checkpoint")
local file=projectDir.."/rollback.lua"
assert(D.Content:save(file,"original\n"))
for _,text in ipairs({"revision one\n","revision two\n","revision three\n"}) do
 local r=C.applyFileChanges(1,projectDir,{{op="write",path="rollback.lua",content=text}});assert(r.success,r.message)
end
local before=#C.listCheckpoints(1)
assert(before==4,"current task lost early checkpoints")
S.cleanupOrphanHeavyDataBatch(16)
assert(#C.listCheckpoints(1)==before)
local r=C.rollbackTaskChangeSet(1,projectDir);assert(r.success,r.message)
assert(D.Content:load(file)=="original\n","whole-task rollback lost earliest before-image")
assert(D.DB:query("SELECT count(*) FROM agent.AgentSessionMessage")[1][1]==2)
''')
            assert (project / 'rollback.lua').read_text() == 'original\n'
            print('PASS: native manual cleanup, read-only HTTP statistics, compressed blobs, retained chat and complete current-task file rollback', flush=True)
        except BaseException:
            log.flush()
            log.seek(0)
            print(log.read()[-5000:], flush=True)
            raise
        finally:
            if proc.poll() is None:
                proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                raise AssertionError('engine shutdown timed out')
            assert proc.returncode == 0, proc.returncode


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', type=Path)
    parser.add_argument('--hold', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dora-agent-storage-') as directory:
        sqlite_fixture(Path(directory))
        if args.engine:
            native_fixture(args.engine.resolve(), Path(directory), args.hold)
