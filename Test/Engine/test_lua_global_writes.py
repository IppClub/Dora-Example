#!/usr/bin/env python3
"""Shared production Lua checker, with optional native Web IDE/Agent acceptance."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import urllib.request

sys.dont_write_bytecode = True
ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()
TEST = Path(__file__).resolve().parents[1]
CASES = json.loads((TEST / 'DoraStudio/tests/lua-global-fixtures.json').read_text())


def literal(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


def check_source():
    server = (ROOT / 'Assets/Script/Dev/WebServer.lua').read_text()
    utils = (ROOT / 'Assets/Script/Lib/Utils.lua').read_text()
    def extract(text, start, end):
        a = text.index(start)
        return text[a:text.index(end, a)]
    source = f'''dofile({literal(str(ROOT / 'Source/Lua/Builtin/tl.lua'))})
local tl = package.loaded.tl
local declarations = {literal(str(ROOT / 'Assets/Script/Lib/Dora/en') + '/')}
tl.read_file = function(path)
 local file = io.open(declarations .. path, 'rb')
 if not file then return nil end
 local content = file:read('a'); file:close(); return content
end
tl.file_exist = function(path)
 local file = io.open(declarations .. path, 'rb')
 if not file then return false end
 file:close(); return true
end
tl.dora_init()
local teal = {{checkAsync = tl.dora_check}}
'''
    source += extract(utils, 'local tic80APIs', '_module_0["CheckTIC80Code"]')
    source += extract(server, 'local disabledCheckForLua = {', 'local yueCheck')
    source += extract(server, 'local luaCheck\n' if 'local luaCheck\n' in server else 'local luaCheck --', 'local luaCheckWithLineInfo')
    substitution = next(line for line in server.splitlines() if 'content = content:gsub(' in line and 'tic80' in line)
    for fixture in CASES:
        source += f'''do
 local content = {literal(fixture['code'])}
 if CheckTIC80Code(content) then
 {substitution}
 end
 local result = luaCheck('globals.lua', content)
 local ok, info = result.success, result.info
 assert(ok == {str(fixture['success']).lower()}, {literal(fixture['name'])} .. ': ' .. tostring(info and info[1] and info[1][5]))
'''
        if not fixture['success']:
            source += '''assert(info[1][1] == 'syntax' and info[1][2] == 'globals.lua')
 assert(info[1][3] > 0 and info[1][4] > 0 and info[1][5]:find('global'))
'''
        source += 'end\n'
    lua = os.environ.get('DORA_LUA') or shutil.which('lua5.5') or 'lua'
    subprocess.run([lua, '-'], input=source, text=True, check=True)
    print(f'Production Lua global-write checker: {len(CASES)} cases passed', flush=True)


@contextmanager
def assets_on_ports(ports):
    with tempfile.TemporaryDirectory(prefix='dora-global-write-assets-') as directory:
        root = Path(directory)
        def layer(source, destination, skip):
            destination.mkdir(parents=True, exist_ok=True)
            for path in source.iterdir():
                if path.name not in skip:
                    (destination / path.name).symlink_to(path, target_is_directory=path.is_dir())
        layer(ROOT / 'Assets', root / 'Assets', {'Script'})
        layer(ROOT / 'Assets/Script', root / 'Assets/Script', {'Dev'})
        layer(ROOT / 'Assets/Script/Dev', root / 'Assets/Script/Dev', {'WebServer.lua'})
        server = (ROOT / 'Assets/Script/Dev/WebServer.lua').read_text()
        # Only listener ports differ; all production checker/compiler code is unchanged.
        (root / 'Assets/Script/Dev/WebServer.lua').write_text(server.replace('8866', str(ports[0])).replace('8868', str(ports[1])))
        yield root


def native(engine):
    sys.path.insert(0, str(TEST / 'support'))
    from native_agent import NativeAgent
    sockets = [socket.socket(), socket.socket()]
    for sock in sockets: sock.bind(('127.0.0.1', 0))
    ports = tuple(sock.getsockname()[1] for sock in sockets)
    for sock in sockets: sock.close()
    with assets_on_ports(ports) as assets, NativeAgent(engine, assets, ports=ports) as agent:
        project = Path(agent.status['writablePath']) / 'global-write-regression'
        project.mkdir()
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        def post(route, body):
            request = urllib.request.Request(f'http://127.0.0.1:{ports[0]}{route}', data=json.dumps(body).encode(),
                                            headers={'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin'})
            with opener.open(request, timeout=50) as response: return json.load(response)
        for index, fixture in enumerate(CASES):
            target = project / f'case{index}.lua'
            target.write_text(fixture['code'])
            result = post('/check', {'file': str(target), 'content': fixture['code']})
            assert result['success'] == fixture['success'], (fixture['name'], result)
            if not fixture['success']: assert result['info'][0][0] == 'syntax'
            # Exercise the real production Agent tool, including aggregation/model diagnostics.
            code = f'''local result, failure
local pending = require('Agent.Tool.Build').build({{workDir = {literal(str(project))}, path = {literal(target.name)}}})
pending["then"](pending, function(_, value) result = value end, function(_, reason) failure = reason end)
require('Dora').wait(function() return result ~= nil or failure ~= nil end)
assert(not failure, tostring(failure))
assert(result.success == {str(fixture['success']).lower()}, {literal(fixture['name'])})
if not result.success then assert(result.messages[1].message:find('global')) end
print('AGENT_BUILD_PARITY_PASS')'''
            answer = agent.command(project, code)
            assert 'AGENT_BUILD_PARITY_PASS' in answer['output'], answer
            if index % 10 == 0: print(f'Native Lua parity: {index + 1}/{len(CASES)}', flush=True)
        driver = subprocess.Popen(['node', str(TEST / 'support/native_typescript_compiler.mjs'), f'http://127.0.0.1:{ports[0]}'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                  env={**agent.environment, 'DORA_ENGINE_ROOT': str(ROOT)})
        try:
            assert driver.stdout.readline().strip() == 'COMPILER_PAGE_READY', driver.stderr.read() if driver.poll() is not None else 'compiler page did not become ready'
            # No-import scripts must emit locals, and the generated Lua must pass the same checker.
            for index, code in enumerate(['const value = 1;', 'function drawBaby() {}\ndrawBaby();',
                                          'const value = 1;\nexport {};', "import { App } from 'Dora';\nconst value = 1;\nconst platform = App.platform;"]):
                folder = project / f'ts{index}'; folder.mkdir()
                target = folder / 'init.ts'; target.write_text(code)
                result = post('/ts/build', {'path': str(target), 'projectRoot': str(folder)})
                assert result['success'], result
                lua = target.with_suffix('.lua').read_text()
                assert ('local value = 1' in lua) if 'value' in code else ('local function drawBaby' in lua), lua
                checked = post('/check', {'file': str(target.with_suffix('.lua')), 'content': lua})
                assert not any('cannot create global' in item[4] for item in checked.get('info', [])), checked
                answer = agent.command(project, 'dofile(' + literal(str(target.with_suffix('.lua'))) + ')\nprint("TS_RUNTIME_PASS")')
                assert 'TS_RUNTIME_PASS' in answer['output'] and 'disallow creating' not in answer['output'], answer
        finally:
            if driver.poll() is None:
                driver.stdin.write('stop\n'); driver.stdin.flush()
            output, errors = driver.communicate(timeout=12)
            if sys.exc_info()[0] is None: assert driver.returncode == 0, errors
        print(f'Native Web IDE and Agent parity: {len(CASES)} Lua cases and 4 TypeScript builds passed', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', type=Path)
    args = parser.parse_args()
    check_source()
    if args.engine: native(args.engine)
