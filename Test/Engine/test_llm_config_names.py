#!/usr/bin/env python3
"""Real SQLite + production Lua routes; --engine also exercises real HTTP concurrency."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import socket
import sqlite3
import subprocess
import tempfile
import threading
import time
import urllib.request

ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()
COLUMNS = ['id', 'name', 'url', 'model', 'api_key', 'context_window', 'temperature', 'max_tokens',
           'reasoning_effort', 'custom_options', 'supports_function_calling', 'active', 'created_at', 'updated_at']
SCHEMA = re.search(r'CREATE TABLE IF NOT EXISTS LLMConfig\(.*?\);',
                   (ROOT / 'Assets/Script/Dev/WebServer.yue').read_text(), re.S).group()


def records(db):
    return db.execute('SELECT ' + ','.join(COLUMNS) + ' FROM LLMConfig ORDER BY id').fetchall()


def seed(db):
    names = ['Same', 'Same', 'Same (2)', ' Same ', '', 'Model', '模型', '模型', '__dora_llm_name_2__']
    for i, name in enumerate(names, 1):
        values = [i, name, f'https://provider-{i}.invalid', f'model-{i}', f"fixture-key-'秘密-{i}",
                  64000 + i, i / 10, 2048 + i, 'low', '{ "top_p": 0.83, "unknown": [1,2] }', i % 2, i % 2, 100 + i, 200 + i]
        db.execute('INSERT INTO LLMConfig(' + ','.join(COLUMNS) + ') VALUES(' + ','.join('?' for _ in values) + ')', values)
    db.commit()
    return records(db)


def assert_preserved(before, after):
    assert len(before) == len(after)
    assert [r[0] for r in before] == [r[0] for r in after]
    for old, new in zip(before, after):
        assert old[:1] + old[2:] == new[:1] + new[2:], f'Non-name fields changed for ID {old[0]}'
    assert [r[1] for r in after] == ['Same', 'Same (3)', 'Same (2)', 'Same (4)', 'Model (2)', 'Model', '模型', '模型 (2)', '__dora_llm_name_2__']


def lua_value(value):
    if value is None:
        return 'nil'
    if value is True or value is False:
        return str(value).lower()
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua_value(v) for v in value) + '}'
    if isinstance(value, str):
        return '"' + ''.join('\\%03d' % c for c in value.encode()) + '"'
    return str(value)


ADAPTER = r'''
package.path=ROOT..'/Assets/Script/Lib/?.lua;'..package.path
local function encode(v)
 if type(v)=='table' then local a={};for i=1,#v do a[i]=encode(v[i]) end;return '['..table.concat(a,',')..']' end
 if type(v)=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"' end
 if v==nil then return 'null' end
 return tostring(v)
end
local function rpc(op,sql,args)
 io.write(encode({op,sql,args or {}})..'\n');io.flush()
 return assert(load('return '..assert(io.read('*l')),'SQLite response','t',{}))()
end
local db={}
function db:exist(name) return #assert(self:query('SELECT name FROM sqlite_master WHERE type=? AND name=?',{'table',name}))>0 end
function db:query(sql,args) return rpc('query',sql,args) end
function db:exec(sql,args)
 if RACE and sql:find('insert into LLMConfig',1,true) then
  RACE=false
  assert(self:exec('INSERT INTO LLMConfig(name,url,model,api_key) VALUES(?,?,?,?)',{args[1],'rival','rival','fixture'})==1)
 end
 return rpc('exec',sql,args)
end
function db:transaction(sql) return rpc(FAIL and 'fail_transaction' or 'transaction',sql) end
package.loaded.Dora={DB=db,json={decode=function()error('Unexpected JSON decoding in name migration')end}}
local names=require('Agent.Config.LLMConfigNames')
FAIL=true;assert(not pcall(names.upgradeLLMConfigNames));FAIL=false
assert(rpc('assert_rollback',''))
names.upgradeLLMConfigNames()
assert(rpc('assert_preserved',''))
local count=rpc('changes','');names.upgradeLLMConfigNames();assert(count==rpc('changes',''))
-- Reapplying to a database that already has a raw-name unique index must work.
assert(db:exec("UPDATE LLMConfig SET name=' Same ' WHERE id=1")==1)
assert(db:exec("UPDATE LLMConfig SET name='Same' WHERE id=2")==1)
assert(db:exec("DELETE FROM Config WHERE name='agentLLMConfigNamesVersion'")==1)
names.upgradeLLMConfigNames();assert(rpc('assert_preserved',''))
local source=assert(io.open(ROOT..'/Assets/Script/Dev/WebServer.lua')):read('*a')
local begin=assert(source:find('local ensureLLMConfigTable',1,true))
local ending=assert(source:find('HttpServer:post("/local-agent/list"',begin,true))
local routes={}
local env=setmetatable({DB=db,json=package.loaded.Dora.json,invalidArguments={success=false,code='INVALID_ARGUMENTS'},HttpServer={post=function(_,path,fn)routes[path]=fn end}},{__index=_G})
assert(load(source:sub(begin,ending-1),'production LLM routes','t',env))()
local function body(name,id) return {name=name,id=id,url='https://fixture.invalid',model='fixture',key='fixture-only',customOptions=''} end
local function call(path,data) return routes['/llm/'..path]({body=data}) end
assert(call('list').success)
for _,name in ipairs({'Same',' Same ','\tSame\n'}) do
 local r=call('create',body(name));assert(not r.success and r.code=='LLM_CONFIG_NAME_EXISTS')
end
for _,name in ipairs({'','  ',42,true}) do
 local r=call('create',body(name));assert(not r.success and r.code=='INVALID_LLM_CONFIG_NAME')
end
local before=rpc('snapshot','')
local r=call('update',body('Same',2));assert(not r.success and r.code=='LLM_CONFIG_NAME_EXISTS')
assert(before==rpc('snapshot',''),'conflicting update changed fields')
assert(call('update',body(' Same ',1)).success,'updating the same ID must allow its own name')
assert(call('create',body(' New model ')).success)
assert(#db:query('SELECT id FROM LLMConfig WHERE name=?',{'New model'})==1)
RACE=true
r=call('create',body('racing'));assert(not r.success and r.code=='LLM_CONFIG_NAME_EXISTS')
assert(#db:query('SELECT id FROM LLMConfig WHERE name=?',{'racing'})==1)
assert(not call('update',body('missing',99999)).success)
assert(rpc('assert_unique',''))
print('PASS: real SQLite production Lua migration/routes, rollback, name collisions, byte-exact parameter preservation, idempotence and unique-index race fallback')
'''


def adapter(temp):
    db = sqlite3.connect(temp / 'adapter.db')
    db.execute('CREATE TABLE Config(name TEXT PRIMARY KEY,value_num REAL,value_str TEXT,value_bool INTEGER)')
    db.execute("INSERT INTO Config(name,value_num) VALUES('agentLLMConfigVersion',1)")
    db.execute(SCHEMA)
    before = seed(db)
    script = temp / 'adapter.lua'
    script.write_text('ROOT=' + lua_value(str(ROOT)) + '\n' + ADAPTER)
    proc = subprocess.Popen([os.environ.get('DORA_LUA', 'lua'), str(script)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    try:
        for line in proc.stdout:
            if line.startswith('PASS:'):
                print(line.strip(), flush=True)
                continue
            op, sql, args = json.loads(line)
            if op == 'query':
                result = db.execute(sql, args).fetchall()
            elif op == 'exec':
                try:
                    result = db.execute(sql, args).rowcount
                    db.commit()
                except sqlite3.Error:
                    db.rollback()
                    result = -1
            elif op in ('transaction', 'fail_transaction'):
                try:
                    db.execute('BEGIN')
                    for index, command in enumerate(sql):
                        if isinstance(command, str):
                            db.execute(command)
                        else:
                            db.executemany(command[0], command[1])
                        if op == 'fail_transaction' and isinstance(command, str) and command.startswith('CREATE UNIQUE INDEX'):
                            raise sqlite3.OperationalError('injected transaction failure')
                    db.commit()
                    result = True
                except sqlite3.Error:
                    db.rollback()
                    result = False
            elif op == 'assert_rollback':
                assert records(db) == before
                assert not db.execute("SELECT 1 FROM Config WHERE name='agentLLMConfigNamesVersion'").fetchall()
                assert not db.execute("SELECT 1 FROM sqlite_master WHERE name='idx_llm_config_name'").fetchall()
                result = True
            elif op == 'assert_preserved':
                assert_preserved(before, records(db))
                result = True
            elif op == 'changes':
                result = db.total_changes
            elif op == 'snapshot':
                result = json.dumps(records(db))
            elif op == 'assert_unique':
                try:
                    db.execute("UPDATE LLMConfig SET name='Same' WHERE id=2")
                    raise AssertionError('unique index did not protect direct writes')
                except sqlite3.IntegrityError:
                    db.rollback()
                result = True
            else:
                raise AssertionError(op)
            proc.stdin.write(lua_value(result) + '\n')
            proc.stdin.flush()
        assert proc.wait(timeout=5) == 0
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        db.close()


def post(route, data=None):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    request = urllib.request.Request('http://127.0.0.1:8866' + route, data=json.dumps(data or {}).encode(),
                                    headers={'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin'})
    with opener.open(request, timeout=30) as response:
        return json.load(response)


@contextmanager
def native(engine, profile, logfile):
    for port in (8866, 8868):
        with socket.socket() as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(('127.0.0.1', port))
    with logfile.open('w') as log:
        proc = subprocess.Popen([str(engine), '--asset', str(ROOT / 'Assets')], cwd=ROOT / 'Assets', stdout=log, stderr=log,
                                env={**os.environ, 'CFFIXED_USER_HOME': str(profile), 'XDG_DATA_HOME': str(profile / 'data')})
        try:
            deadline = time.monotonic() + 30
            while True:
                try:
                    status = post('/status')
                    assert profile in Path(status['writablePath']).parents, 'Refusing a non-disposable profile'
                    break
                except OSError:
                    assert proc.poll() is None and time.monotonic() < deadline, logfile.read_text()[-2000:]
                    time.sleep(.1)
            yield Path(status['appPath'])
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=12)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                raise AssertionError('Native test engine did not exit normally')
            assert proc.returncode == 0, f'Native engine exit: {proc.returncode}'


def native_scenarios(engine, temp):
    assert os.name != 'nt', 'Disposable native profile isolation currently supports macOS/Linux only'
    profile = temp / 'profile'
    profile.mkdir()
    with native(engine, profile, temp / 'initialize.log') as app:
        assert post('/llm/list')['success']
    database = app / 'dora.db'
    assert database.is_file(), list(app.iterdir())
    with sqlite3.connect(database) as db:
        db.execute('DELETE FROM LLMConfig')
        db.execute('DROP INDEX idx_llm_config_name')
        db.execute("DELETE FROM Config WHERE name='agentLLMConfigNamesVersion'")
        before = seed(db)
    with native(engine, profile, temp / 'acceptance.log'):
        assert post('/llm/list')['success']
        with sqlite3.connect(database) as db:
            assert_preserved(before, records(db))
        payload = dict(name='HTTP test', url='https://fixture.invalid', model='fixture', key='fixture-key',
                       contextWindow=128000, temperature=.7, maxTokens=32000, customOptions='{"top_p":0.9}')
        assert post('/llm/create', payload)['success']
        for name in ('HTTP test', ' HTTP test '):
            result = post('/llm/create', {**payload, 'name': name})
            assert not result['success'] and result['code'] == 'LLM_CONFIG_NAME_EXISTS'
        for name in ('', '  ', 42, True):
            result = post('/llm/create', {**payload, 'name': name})
            assert not result['success'] and result['code'] == 'INVALID_LLM_CONFIG_NAME'
        item = next(row for row in post('/llm/list')['items'] if row['name'] == 'HTTP test')
        with sqlite3.connect(database) as db:
            original = records(db)
        result = post('/llm/update', {**payload, 'id': item['id'], 'name': 'Same', 'key': 'must-not-save'})
        assert not result['success'] and result['code'] == 'LLM_CONFIG_NAME_EXISTS'
        with sqlite3.connect(database) as db:
            assert records(db) == original
        assert post('/llm/update', {**payload, 'id': item['id'], 'name': ' HTTP test ', 'temperature': .6})['success']
        barrier = threading.Barrier(20)
        def create(index):
            barrier.wait(timeout=15)
            return post('/llm/create', {**payload, 'name': 'Concurrent model', 'key': 'fixture-' + str(index)})
        with ThreadPoolExecutor(max_workers=20) as pool:
            results = list(pool.map(create, range(20)))
        assert sum(r['success'] is True for r in results) == 1, results
        assert all(r['success'] or r.get('code') == 'LLM_CONFIG_NAME_EXISTS' for r in results), results
        with sqlite3.connect(database) as db:
            assert db.execute("SELECT count(*) FROM LLMConfig WHERE name='Concurrent model'").fetchone()[0] == 1
            try:
                db.execute("UPDATE LLMConfig SET name='Same' WHERE id=2")
                raise AssertionError('Native database unique index missing')
            except sqlite3.IntegrityError:
                db.rollback()
            final = records(db)
    with native(engine, profile, temp / 'restart.log'):
        assert post('/llm/list')['success']
        with sqlite3.connect(database) as db:
            assert records(db) == final, 'Restart changed names or parameters'
    print('PASS: native HTTP duplicate/trimmed creation, 20 concurrent requests with one insert, conflicting/self update, legacy migration with ID/key/parameter preservation, restart persistence and normal exit', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dora-llm-names-') as folder:
        temp = Path(folder)
        adapter(temp)
        if args.engine:
            native_scenarios(args.engine.resolve(), temp)


if __name__ == '__main__':
    main()
