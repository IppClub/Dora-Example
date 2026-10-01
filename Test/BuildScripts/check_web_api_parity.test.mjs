import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

test('API expectations include Music only when the built Player declares it, and reject incomplete manifests', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(),'dora-api-profile-'));
  try {
    const output=path.join(temporary,'expected.lua'), features=path.join(temporary,'features.json');
    const run = () => spawnSync(process.execPath,[path.join(process.env.DORA_TEST_SCRIPTS,'check_web_api_parity.mjs'),
      '--emit',output,'--features',features],{cwd:process.env.DORA_ENGINE_ROOT,encoding:'utf8'});
    for (const enabled of [false,true]) {
      fs.writeFileSync(features,JSON.stringify({modules:{musicGenerator:enabled}}));
      const result=run();assert.equal(result.status,0,result.stderr);
      const source=fs.readFileSync(output,'utf8');
      assert.equal(source.includes('Dora.Audio.renderMusicAsync'),enabled);
      assert.ok(source.includes('Dora.thread'), 'unrelated mandatory APIs must remain checked');
    }
    fs.writeFileSync(features,JSON.stringify({modules:{}}));
    assert.notEqual(run().status,0, 'missing capability data must fail, not silently omit APIs');
  } finally { fs.rmSync(temporary,{recursive:true,force:true}); }
});
