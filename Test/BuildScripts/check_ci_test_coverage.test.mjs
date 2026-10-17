import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const engine = process.env.DORA_ENGINE_ROOT;
const repo = process.env.DORA_TEST_REPO;
const manifest = JSON.parse(fs.readFileSync(path.join(repo, 'Test/manifest.json'))).files;
const suites = JSON.parse(fs.readFileSync(path.join(repo, 'Test/suites.json')));
const baseline = JSON.parse(fs.readFileSync(path.join(repo, 'Test/ci-coverage.json')));
const workflow = name => fs.readFileSync(path.join(engine, '.github/workflows', name), 'utf8');
const names = manifest.filter(file => /Test\/(BuildScripts|WebIDE|StudioPrototype|Art|Agent|Engine|Frontend)\//.test(file.path) && /\.(mjs|lua|cjs|py)$/.test(file.path)).map(file => file.name || path.basename(file.path, path.extname(file.path)));
// The test repository is published first. Older engine checkouts keep their
// existing contract suite until the CI migration lands. Missing files in an
// already migrated engine must still fail this audit.
const launcher = fs.readFileSync(path.join(engine, 'Projects/xmake/tasks/test.lua'), 'utf8');
const splitCi = launcher.includes('contract|engine|ui|')
  || fs.existsSync(path.join(engine, '.github/workflows/engine-tests.yml'))
  || fs.existsSync(path.join(engine, '.github/workflows/studio.yml'));
const applicability = {skip: !splitCi && 'CI split has not landed in this engine revision'};
const planned = [];
if (splitCi) for (const owner of ['ui.yml', 'engine-tests.yml', 'studio.yml']) {
  for (const match of workflow(owner).matchAll(/^\s*(?:run:\s*)?xmake dora-test(?=\s|$)([^\n]*)/gm)) {
    const single = match[1].match(/--case=([^\s]+)/)?.[1];
    const suite = match[1].match(/--suite=([^\s]+)/)?.[1] || 'contract';
    for (const name of single ? [single] : suites[suite]) planned.push({name, owner});
  }
}

test('every previous UI CI test remains assigned exactly once', applicability, () => {
  for (const name of [...baseline.previousUiCases, ...baseline.addedCases]) {
    assert.equal(planned.filter(item => item.name === name).length, 1, name);
  }
  assert.equal(planned.length, baseline.previousUiCases.length + baseline.addedCases.length);
  assert.equal(new Set(planned.map(item => item.name)).size, planned.length, 'duplicate case across workflows');
  assert.match(workflow('engine-tests.yml'), /go test -mod=vendor \.\/internal\/gitjobs/);
  assert.match(workflow('ui.yml'), /pnpm lint/);
  assert.match(workflow('ui.yml'), /pnpm typecheck/);
  assert.match(workflow('ui.yml'), /pnpm build/);
  assert.match(workflow('ui.yml'), /pnpm verify:web-release-assets/);
});

test('migrated tests have one external owner and manual acceptance stays discoverable', applicability, () => {
  assert.equal(new Set(names).size, names.length, 'ambiguous test case name');
  for (const file of manifest) {
    assert.ok(fs.existsSync(path.join(repo, file.path)), file.path);
    if (!file.path.startsWith('Test/Frontend/') && !file.path.startsWith('Test/Engine/')) continue;
    assert.ok(!fs.existsSync(path.join(engine, file.source)), `engine still contains ${file.source}`);
    if (!/\.(?:py|lua|mjs)$/.test(file.path)) continue;
    const name = path.basename(file.path, path.extname(file.path));
    if (['test_macos_bundle', 'web-package-names.test', 'test_webbuild'].includes(name)) continue;
    if (baseline.manualCases.includes(name)) continue;
    assert.equal(planned.filter(item => item.name === name).length, 1, name);
  }
  assert.match(workflow('macos.yml'), /xmake dora-test --case=test_macos_bundle -- --bundle/);
  assert.match(workflow('web.yml'), /xmake dora-test --case=web-package-names.test/);
  assert.match(workflow('webbuilder.yml'), /xmake dora-test --case=test_webbuild/);
});

function matches(glob, filename) {
  const pattern = glob.replaceAll('\\+', '+').split(/(\*\*|\*)/).map(part =>
    part === '**' ? '.*' : part === '*' ? '[^/]*' : part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('');
  return new RegExp(`^${pattern}$`).test(filename);
}

test('push and PR triggers cover source inputs, shared dependencies and test entrypoints', applicability, () => {
  for (const [name, inputs] of Object.entries(baseline.triggerInputs)) {
    const source = workflow(name);
    const filters = [...source.matchAll(/    paths:\n((?:      - '[^\n]+'\n)+)/g)].map(match =>
      [...match[1].matchAll(/      - '([^']+)'/g)].map(value => value[1]));
    assert.equal(filters.length, 2, name);
    assert.deepEqual(filters[0], filters[1], `${name}: push/PR drift`);
    assert.equal(new Set(filters[0]).size, filters[0].length, `${name}: duplicate paths`);
    for (const input of inputs) assert.ok(filters[0].some(glob => matches(glob, input)), `${name} misses ${input}`);
    assert.match(source, /xmake dora-test-deps --env-file="\$GITHUB_ENV"/);
  }
  assert.doesNotMatch(workflow('ui.yml'), /setup-go|suite=studio|test_http_|test_shutdown_watchdog/);
  assert.doesNotMatch(workflow('engine-tests.yml'), /pnpm install|setup-pnpm/);
  assert.match(workflow('ui.yml'), /node Studio\/packages\/agent-contracts\/build\.mjs/);
  for (const name of ['web.yml', 'webbuilder.yml', 'macos.yml', 'static.yml', 'release.yml']) {
    assert.match(workflow(name), /xmake dora-test-deps --env-file="\$GITHUB_ENV"/);
  }
});

test('branch-only source checks are not repeated in platform build workflows', applicability, () => {
  assert.doesNotMatch(workflow('windows.yml'), /--case=check_touch_input_sources/);
  assert.doesNotMatch(workflow('static.yml'), /--case=(?:test_web_gallery|test_web_audio_state)(?:\s|$)/);
  const web = workflow('web.yml');
  const gate = web.slice(web.indexOf('- name: Verify source contracts for tag publication'), web.indexOf('- name: Verify Web package'));
  assert.match(gate, /if: startsWith\(github.ref, 'refs\/tags\/'\)/);
  for (const name of ['check_web_builtin_libraries.test', 'check_web_loader', 'check_web_package']) {
    assert.equal(web.split(`--case=${name}\n`).length - 1, 1, name);
    assert.ok(gate.includes(`--case=${name}`), name);
  }
});
