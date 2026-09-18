import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const adapter=fileURLToPath(new URL('../packages/runtime-web/StudioAgentXmlBuild.lua',import.meta.url));
test('tool-triggered XML conversion preserves original output and source-change boundaries',t=>{
  const probe=spawnSync('lua',['-v'],{encoding:'utf8'});
  if(probe.error?.code==='ENOENT'){t.skip('System Lua unavailable; real Web engine Chrome fixture exercises XML');return;}
  assert.equal(probe.status,0,probe.stderr);
  const source=String.raw`
local content = {files = {}, removed = {}}
function content:load(path) return self.files[path] end
function content:save(path, text) self.files[path] = text; return true end
function content:remove(path) self.files[path] = nil; self.removed[path] = true; return true end
local path = {}
function path:replaceExt(file, ext) return (file:gsub('%.[^.]+$', '.' .. ext)) end
local xml = {tolua = function(source)
  if source:find('invalid', 1, true) then return nil, 'bad XML at line 1' end
  if source:find('changed', 1, true) then content.files['/user/studio-project/main.xml'] = 'changed after request' end
  return 'local node = Dora.Node()'
end}
package.preload.Dora = function() return {Content = content, Path = path, xml = xml} end
local build = dofile(os.getenv('STUDIO_XML_TEST_ADAPTER'))
local file, root = '/user/studio-project/main.xml', '/user/studio-project'
content.files[file] = '<Dora/>'
local result = build.run(file, '<Dora/>', root)
assert(result.success and result.luaCode == '-- [xml]: main.xml\nlocal node = Dora.Node()')
assert(content.files['/user/studio-project/main.lua'] == result.luaCode)
content.files[file] = 'invalid'
result = build.run(file, 'invalid', root)
assert(result.success == false and result.message:find('bad XML', 1, true))
assert(content.removed['/user/studio-project/main.lua'])
content.files[file] = 'changed'
content.files['/user/studio-project/main.lua'] = 'previous-author-output'
result = build.run(file, 'changed', root)
assert(result.success == false and result.message:find('source changed', 1, true))
assert(content.files['/user/studio-project/main.lua'] == 'previous-author-output')
`;
  const result=spawnSync('lua',['-e',source],{encoding:'utf8',env:{...process.env,STUDIO_XML_TEST_ADAPTER:adapter}});
  assert.equal(result.status,0,result.stderr||result.stdout);
});
