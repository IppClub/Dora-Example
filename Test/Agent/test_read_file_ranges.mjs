import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join, relative} from 'node:path';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';

const root = process.env.DORA_SSR_ROOT;
if (!root) throw Error('Set DORA_SSR_ROOT to the Dora-SSR checkout.');
const require = createRequire(join(root, 'Tools/dora-dora/package.json'));
const {build} = require('esbuild');
const lines = count => Array.from({length:count}, (_, i) => `line ${i + 1}`).join('\n');
const files = new Map([['/project/long.txt', lines(4000)], ['/project/short.txt', lines(12)], ['/project/empty.txt', '']]);
files.set('/assets/Script/Lib/Dora/en/Dora.d.ts', lines(4000));
const dora = {
  Content: {
    assetPath:'/assets',
    exist:p => p === '/project' || files.has(p), isdir:p => p === '/project',
    isAbsolutePath:p => p.startsWith('/'), load:p => files.get(p),
    getAttr:p => [files.get(p)?.length, false],
  },
  Path:Object.assign((...parts) => parts.join('/'), {getRelative:(file, base) => relative(base, file)}),
};
let workspace;
async function load(file) {
  const bundled = await build({entryPoints:[join(root, 'Assets/Script/Lib/Agent', file)], bundle:true,
    write:false, format:'cjs', platform:'node', plugins:[{name:'isolated-engine-io', setup(b) {
      b.onResolve({filter:/^(Dora|Agent\/)/}, a => a.path === 'Agent/Config/Defaults'
        ? {path:join(root, 'Assets/Script/Lib/Agent/Config/Defaults.ts')}
        : {path:a.path, namespace:'mock'});
      b.onLoad({filter:/.*/, namespace:'mock'}, a => ({contents:({
        Dora:'module.exports=__dora;',
        'Agent/Tool/Workspace':'module.exports=__workspace;',
        'Agent/Tools':'module.exports=__workspace;',
        'Agent/Utils':'module.exports={Log(){}};',
      })[a.path] ?? 'module.exports={};', loader:'js'}));
    }}]});
  const box = {module:{exports:{}}, exports:{}, math:Math, tostring:String,
    string:{match:text => [text.match(/^[A-Za-z]:[/\\]/)?.[0]]}, __dora:dora, __workspace:workspace};
  vm.runInNewContext(bundled.outputFiles[0].text, box);
  return box.module.exports;
}
workspace = await load('Tool/Workspace.ts');
const {validateAgentToolInput} = await load('Tool/Validation.ts');
const {AGENT_TOOL_HANDLERS} = await load('Tool/Handlers.ts');
const context = {workingDir:'/project', useChineseResponse:false, workflow:{}};
async function agentRead(input) {
  const validated = validateAgentToolInput('read_file', input);
  if (!validated.success) return validated;
  return (await AGENT_TOOL_HANDLERS.read_file(context, validated.value)).output;
}
function check(result, start, end) {
  assert.equal(result.success, true, result.message);
  assert.equal(result.startLine, start);
  assert.equal(result.endLine, end);
  const body = result.content.split('\n\n')[0];
  assert.equal(body, Array.from({length:end - start + 1}, (_, i) => `line ${start + i}`).join('\n'));
}
// Exercise both the direct workspace reader and the actual Agent validation/handler chain.
const cases = [
  [{}, 1, 300], [{startLine:301}, 301, 600], [{startLine:3540}, 3540, 3839],
  [{startLine:3990}, 3990, 4000], [{startLine:4000}, 4000, 4000],
  [{startLine:3540, endLine:3600}, 3540, 3600],
  [{startLine:3540, endLine:-1}, 3540, 4000],
  [{startLine:-2}, 3999, 4000], [{startLine:-400}, 3601, 3900],
  [{startLine:-5000}, 1, 300], [{startLine:-5, endLine:-2}, 3996, 3999],
  [{endLine:2}, 1, 2], [{startLine:3999, endLine:9999}, 3999, 4000],
];
for (const [range, start, end] of cases) {
  check(workspace.readFile('/project', 'long.txt', range.startLine, range.endLine), start, end);
  check(await agentRead({path:'long.txt', ...range}), start, end);
  const batch = await agentRead({reads:[{path:'long.txt', ...range}]});
  assert.equal(batch.success, true);
  check(batch.results[0], start, end);
}
for (const range of [{}, {startLine:10}, {startLine:-2}]) {
  const start = range.startLine === undefined ? 1 : range.startLine < 0 ? 11 : range.startLine;
  check(workspace.readFile('/project', 'short.txt', range.startLine), start, 12);
  check(await agentRead({path:'short.txt', ...range}), start, 12);
}
assert.equal((await agentRead({path:'empty.txt'})).content, '(End of file - 1 lines total)');
for (const range of [{startLine:0}, {endLine:0}, {startLine:4001}, {startLine:3540, endLine:300}]) {
  assert.equal(workspace.readFile('/project', 'long.txt', range.startLine, range.endLine).success, false);
  assert.equal((await agentRead({path:'long.txt', ...range})).success, false);
}
const partial = await agentRead({reads:[{path:'long.txt', startLine:3540}, {path:'long.txt', startLine:4001}]});
assert.equal(partial.partial, true);
assert.equal(partial.succeededReadCount, 1);
check(partial.results[0], 3540, 3839);
check(await agentRead({reads:[{path:'@dora-doc/dora-api/Dora.d.ts', startLine:3540}]}).then(r => r.results[0]), 3540, 3839);
// Follow the real pagination hint without supplying an end; it must advance successfully.
let page = workspace.readFile('/project', 'long.txt');
const next = Number(page.content.match(/Use startLine=(\d+) to continue/)[1]);
check(await agentRead({path:'long.txt', startLine:next}), 301, 600);
// Preserve the narrower read window after compression, including an omitted end.
context.workflow.resumeNarrowReadMode = true;
check(await agentRead({path:'long.txt', startLine:3540}), 3540, 3699);
check(await agentRead({path:'long.txt', startLine:3540, endLine:3550}), 3540, 3550);
// Run generated Lua in an isolated host with only engine file I/O stubbed.
// No engine process, running user project, or model is involved.
const lua = spawnSync(process.env.LUA ?? 'lua', ['-', root], {encoding:'utf8', input:`
local root = arg[1]
package.path = root .. '/Assets/Script/Lib/?.lua;' .. package.path
local text = {}
for i = 1, 4000 do text[i] = 'line ' .. i end
local body = table.concat(text, '\\n')
package.preload['Dora'] = function() return {
  Path = function(a,b) return a .. '/' .. b end,
  Content = {
    exist=function(_,p) return p == '/project' or p == '/project/long.txt' end,
    isdir=function(_,p) return p == '/project' end,
    isAbsolutePath=function(_,p) return p:sub(1,1) == '/' end,
    load=function() return body end,
    getAttr=function() return #body, false end,
  },
} end
for _, name in ipairs({'Agent.Utils','Agent.Runtime.Questionnaire','Agent.Tool.VisionAnalysis','Agent.Runtime.Policy','Agent.Tool.Guards'}) do
  package.preload[name] = function() return {} end
end
local workspace = require('Agent.Tool.Workspace')
package.preload['Agent.Tools'] = function() return workspace end
local validation = require('Agent.Tool.Validation')
local handler = require('Agent.Tool.Handlers').AGENT_TOOL_HANDLERS.read_file
local cases = {
  {{},1,300}, {{startLine=3540},3540,3839}, {{startLine=3999},3999,4000},
  {{startLine=-400},3601,3900}, {{startLine=3540,endLine=-1},3540,4000},
  {{startLine=3540,endLine=3600},3540,3600},
}
for _, c in ipairs(cases) do
  local direct = workspace.readFile('/project','long.txt',c[1].startLine,c[1].endLine)
  assert(direct.success and direct.startLine == c[2] and direct.endLine == c[3])
  c[1].path = 'long.txt'
  local normalized = validation.validateAgentToolInput('read_file',{reads={c[1]}})
  assert(normalized.success)
  local finished = false
  local promise = handler({workingDir='/project',workflow={},useChineseResponse=false}, normalized.value)
  promise['then'](promise, function(_, result)
    local r = result.output.results[1]
    assert(r.success and r.startLine == c[2] and r.endLine == c[3])
    finished = true
  end)
  assert(finished, 'generated Lua read handler did not complete')
end
assert(not workspace.readFile('/project','long.txt',3540,300).success)
print('PASS: generated Lua direct reader and Agent validation/batch handler')
`});
assert.equal(lua.status, 0, lua.error?.message ?? lua.stderr + lua.stdout);
process.stdout.write(lua.stdout);
console.log('PASS: read_file direct, normalized and batch ranges; 300-line defaults, EOF, negative/explicit indices, errors, pagination and post-compression clipping.');
