// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const engine = process.env.DORA_ENGINE_ROOT || process.env.DORA_SSR_ROOT;
if (!engine || !fs.existsSync(path.join(engine, 'Source/Node/VideoNode.cpp'))) throw Error('DORA_ENGINE_ROOT must point at Dora-SSR');
const source = fileURLToPath(new URL('../Video/', import.meta.url));
// CMake caches its source path. Local overrides and immutable remote snapshots
// must not share a build directory when switching test revisions/checkouts.
const sourceId = createHash('sha256').update(source).digest('hex').slice(0, 12);
const build = path.join(engine, 'build/tests', `video-regressions-${sourceId}`);
function run(command, args) {
 const result = spawnSync(command, args, {stdio:'inherit'});
 if (result.error) throw result.error;
 if (result.status !== 0) throw Error(`${command} failed: ${result.status ?? result.signal}`);
}
run('cmake', ['-S', source, '-B', build, `-DDORA_SSR_ROOT=${engine}`, '-DCMAKE_BUILD_TYPE=Release']);
run('cmake', ['--build', build, '--config', 'Release', '--parallel', '4']);
run('ctest', ['--test-dir', build, '-C', 'Release', '--output-on-failure', '--no-tests=error']);
