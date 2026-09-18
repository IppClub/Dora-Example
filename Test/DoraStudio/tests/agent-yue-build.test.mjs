import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const adapter=fileURLToPath(new URL('../packages/runtime-web/StudioAgentYueBuild.lua',import.meta.url));
test('tool-triggered Yue callback saves only active results and clears failed output',t=>{
  const probe=spawnSync('lua',['-v'],{encoding:'utf8'});
  if(probe.error?.code==='ENOENT'){t.skip('System Lua unavailable; real Web engine Chrome fixture exercises Yue');return;}
  assert.equal(probe.status,0,probe.stderr);
  const source=String.raw`
local content = {files = {}, removed = {}}
function content:save(path, text) self.files[path] = text; return true end
function content:remove(path) self.files[path] = nil; self.removed[path] = true; return true end
function content:exist(path) return self.files[path] ~= nil end
function content:load(path) return self.files[path] end
local path = setmetatable({}, {__call = function(_, ...) return table.concat({...}, '/') end})
function path:replaceExt(file, ext) return (file:gsub('%.[^.]+$', '.' .. ext)) end
local queued
local yue = {compile = function(file, destination, searchPath, handler, done)
  queued = {file = file, destination = destination, searchPath = searchPath, handler = handler, done = done}
end}
package.preload.Dora = function() return {Content = content, Path = path, yue = yue} end
package.preload.Utils = function() return {
  CheckTIC80Code = function() return false end,
  LintYueGlobals = function(_, globals)
    if globals[1] then return false, globals end
    return true, ''
  end
} end
local build = dofile(os.getenv('STUDIO_YUE_TEST_ADAPTER'))
local file, root = '/user/studio-project/main.yue', '/user/studio-project'
content.files[file] = "print 'ready'"
local active, result = true, nil
local function begin(id)
  result = nil
  build.start(file, "print 'ready'", root, id, function() return active end, function(value) result = value end)
  assert(queued.file == file and queued.searchPath:find('/Script/?.lua', 1, true))
end
begin('first')
assert(queued.handler("print('ready')", nil, {}) == "-- [yue]: main.yue\nprint('ready')")
queued.done(true)
assert(result.success and content.files['/user/studio-project/main.lua'] == result.luaCode)
assert(content.removed[queued.destination])
active = false
begin('cancelled')
assert(queued.handler("print('late')", nil, {}) == nil)
queued.done(true)
assert(result == nil and content.files['/user/studio-project/main.lua']:find('ready', 1, true))
assert(content.removed[queued.destination])
active = true
begin('lint-failure')
assert(queued.handler('print(wrong)', nil, {{'wrong', 2, 3}}) == nil)
queued.done(false)
assert(result.success == false and result.message:find('wrong at line 2:3', 1, true))
assert(content.files['/user/studio-project/main.lua'] == nil)
begin('source-changed')
assert(queued.handler("print('ready')", nil, {}) ~= nil)
content.files[file] = "print 'changed'"
queued.done(true)
assert(result.success == false and result.message:find('source changed', 1, true))
assert(content.files['/user/studio-project/main.lua'] == nil)
content.files[file] = "print 'ready'"
local occupied = file .. '.studio-agent-occupied.lua'
content.files[occupied] = 'author-owned'
local previousQueue = queued
result = nil
build.start(file, "print 'ready'", root, 'occupied', function() return true end, function(value) result = value end)
assert(result.success == false and result.message:find('occupied', 1, true))
assert(content.files[occupied] == 'author-owned' and queued == previousQueue)
`;
  const result=spawnSync('lua',['-e',source],{encoding:'utf8',env:{...process.env,STUDIO_YUE_TEST_ADAPTER:adapter}});
  assert.equal(result.status,0,result.stderr||result.stdout);
});
