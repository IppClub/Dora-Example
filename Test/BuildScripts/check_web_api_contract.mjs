// Local browser behavior tests; intentionally not part of CI.
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root = path.resolve(process.env.DORA_ENGINE_ROOT || process.cwd());
const build = path.resolve(process.argv[2] || path.join(root, 'build/web'));
const source = path.join(root, 'build/web-api-contract-source');
const output = path.join(root, 'build/web-api-contract');
const run = (script, args = [], env = {}) => execFileSync(process.execPath, [path.join(script === 'package_web_game.mjs' ? path.join(root, 'Projects/xmake/tools/web') : process.env.DORA_TEST_SCRIPTS, script), ...args], {cwd:root, stdio:'inherit', env:{...process.env, ...env}});
fs.mkdirSync(source, {recursive:true});
fs.copyFileSync(path.join(process.env.DORA_TEST_WEB, "api-contract/init.lua"), path.join(source, 'init.lua'));
fs.copyFileSync(path.join(process.env.DORA_TEST_WEB, "api-contract/builtin-libraries.lua"), path.join(source, 'builtin-libraries.lua'));
run('check_web_api_parity.mjs', ['--emit', path.join(source, 'expected.lua'), '--features', path.join(build, 'dora-web-features.json')]);
run('package_web_game.mjs', [source, output], {DORA_WEB_GAME_PROFILE:'dora-preset', DORA_WEB_EAGER_GAME_ASSETS:'1'});
for (const name of ['dora-player-runtime.js', 'dora-player-runtime.wasm', 'dora-player-runtime.data', 'dora-web-features.json', 'dora-audio-mixer.wasm', 'audio-worklet.js']) fs.copyFileSync(path.join(build, name), path.join(output, name));
fs.copyFileSync(path.join(build, 'dora-player-runtime.html'), path.join(output, 'index.html'));
run('check_web_game_smoke.mjs', [output], {DORA_WEB_SMOKE_LOG:'1'});
