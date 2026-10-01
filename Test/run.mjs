import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const engine = process.env.DORA_ENGINE_ROOT && path.resolve(process.env.DORA_ENGINE_ROOT);
if (!engine || !fs.existsSync(path.join(engine, 'xmake.lua'))) throw Error('DORA_ENGINE_ROOT must point at the current engine checkout');
const argv = process.argv.slice(2), separator = argv.indexOf('--');
const options = separator < 0 ? argv : argv.slice(0, separator);
const extra = separator < 0 ? [] : argv.slice(separator + 1);
const value = (name, fallback) => options.find(a => a.startsWith(`--${name}=`))?.slice(name.length + 3) ?? fallback;
const files = JSON.parse(fs.readFileSync(path.join(repo, 'Test/manifest.json'), 'utf8')).files;
const cases = files.filter(f => /\.(mjs|lua|cjs|py)$/.test(f.path) && /Test\/(BuildScripts|WebIDE|StudioPrototype|Art)\//.test(f.path));
cases.push({name:'studio', source:'Studio/tests/run.mjs', path:'Test/DoraStudio/run.mjs'});
const suites = {
  contract: ['check_touch_input_sources', 'check_web_builtin_libraries.test', 'check_web_api_parity.test', 'check_web_loader', 'check_web_package', 'test_web_audio_state', 'test_web_gallery', 'test_lualib_utf8_trim'],
  web: ['check_web_output', 'check_web_love_capabilities', 'check_web_player_output', 'check_web_forbidden_deps'],
  'web-ide': cases.filter(f => f.path.startsWith('Test/WebIDE/')).map(f => path.basename(f.path, '.mjs')),
  studio: ['studio'],
  prototype: ['test', 'money-test'],
  art: ['test_mascot'],
};
const suite = value('suite', 'contract'), single = value('case');
if (!Object.hasOwn(suites, suite)) throw Error(`Unknown suite: ${suite}`);
const selected = single ? [single] : suites[suite];
if (options.includes('--list')) {
  console.log(cases.map(f => f.name || path.basename(f.path, path.extname(f.path))).sort().join('\n'));
  process.exit(0);
}
const gitSha = directory => spawnSync('git', ['-C', directory, 'rev-parse', 'HEAD'], {encoding:'utf8'}).stdout?.trim();
const record = {engine: gitSha(engine), tests: gitSha(repo), suite, cases: [], startedAt: new Date().toISOString()};
const dirty = directory => Boolean(spawnSync('git', ['-C', directory, 'status', '--porcelain'], {encoding:'utf8'}).stdout?.trim());
record.engineDirty = dirty(engine);
record.testsDirty = dirty(repo);
const resultDir = path.join(engine, 'build/test-results');
let failed = false;
fs.mkdirSync(resultDir, {recursive:true});
console.log(`Engine ${record.engine}; Dora-Example ${record.tests}`);
for (const name of selected) {
  const file = cases.find(f => (f.name || path.basename(f.path, path.extname(f.path))) === name);
  if (!file) throw Error(`Unknown test case: ${name}`);
  const ide = file.path.startsWith('Test/WebIDE/');
  const env = {...process.env, DORA_SSR_ROOT:engine, DORA_TEST_REPO:repo, DORA_TEST_SCRIPTS:path.join(repo,'Test/BuildScripts'), DORA_TEST_WEB:path.join(repo,'Test/Web'),
    DORA_TEST_ORIGIN_URL:pathToFileURL(path.join(engine,file.source)).href,
    DORA_IDE_SCRIPT_URL:pathToFileURL(path.join(engine,file.source)).href,
    DORA_IDE_SCRIPTS_DIR:path.join(engine,'Tools/dora-dora/scripts')};
  const nodeArgs = ['--import', path.join(repo,'Test/support/register.mjs')];
  if (name.endsWith('.test')) nodeArgs.push('--test');
  nodeArgs.push(path.join(repo,file.path), ...extra);
  const lua = file.path.endsWith('.lua');
  const python = file.path.endsWith('.py');
  if (file.path.startsWith('Test/StudioPrototype/') && !env.STUDIO_PLAYWRIGHT_MODULE) {
    env.STUDIO_PLAYWRIGHT_MODULE = createRequire(path.join(engine,'Studio/package.json')).resolve('playwright');
  }
  const result = spawnSync(lua ? process.env.DORA_LUA || 'lua' : python ? process.env.DORA_PYTHON || 'python3' : process.execPath,
    lua || python ? [path.join(repo,file.path), ...extra] : nodeArgs,
    {cwd:ide ? path.join(engine,'Tools/dora-dora') : engine, env, stdio:'inherit'});
  record.cases.push({name,status:result.status,signal:result.signal,error:result.error?.message});
  fs.writeFileSync(path.join(resultDir, `${suite}-${single || 'suite'}.json`), JSON.stringify(record,null,2));
  if (result.error || result.status !== 0) failed = true;
}
console.log(`Finished ${record.cases.length} test cases; ${record.cases.filter(c => c.status !== 0).length} failed`);
record.finishedAt = new Date().toISOString();
fs.writeFileSync(path.join(resultDir, `${suite}-${single || 'suite'}.json`), JSON.stringify(record,null,2));
if (failed) process.exit(1);
