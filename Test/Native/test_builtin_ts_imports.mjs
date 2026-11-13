import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';

// Requires a running native Dora service using this checkout's Assets directory.
const root = process.env.DORA_SSR_ROOT;
assert.ok(root, 'Set DORA_SSR_ROOT to the engine checkout');
const assets = resolve(root, 'Assets');
const base = process.env.DORA_COMPILER_URL ?? 'http://127.0.0.1:8866';
const post = async (route, data) => {
  const response = await fetch(base + route, {
    method: 'POST', headers: {'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin'},
    body: JSON.stringify(data), signal: AbortSignal.timeout(90000),
  });
  assert.equal(response.status, 200);
  return response.json();
};
const status = await post('/status', {});
assert.equal(resolve(status.assetPath), assets, 'Native service must use the requested checkout');
const names = ['View', 'UpdateSync'];
const paths = names.map(name => join(assets, 'Script/Tools/SelfUpdater', name + '.lua'));
const backups = await Promise.all(paths.map(file => readFile(file)));
const syncSource = await readFile(join(assets, 'Script/Tools/SelfUpdater/UpdateSync.ts'), 'utf8');
assert.match(syncSource, /from "Script\/Tools\/ResourceDownloader\/Git"/);
try {
  for (const projectRoot of [assets, join(assets, 'Script')]) {
    const prefix = projectRoot === assets ? 'Script.' : '';
    for (const [index, name] of names.entries()) {
      const result = await post('/ts/build', {
        path: join(assets, 'Script/Tools/SelfUpdater', name + '.ts'), projectRoot,
      });
      assert.equal(result.success, true, JSON.stringify(result));
      const lua = await readFile(paths[index], 'utf8');
      if (name === 'View') {
        assert.match(lua, /require\("ImGui"\)/);
        assert.ok(lua.includes(`require("${prefix}Tools.SelfUpdater.Service")`));
      } else {
        assert.ok(lua.includes(`require("${prefix}Tools.ResourceDownloader.Git")`));
      }
    }
  }
  console.log('PASS: native engine builds original Script/Tools imports from Assets and Script roots; ImGui runtime binding preserved');
} finally {
  await Promise.all(paths.map((file, index) => writeFile(file, backups[index])));
}
