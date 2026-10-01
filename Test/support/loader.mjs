import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const engine = process.env.DORA_ENGINE_ROOT;
const repo = process.env.DORA_TEST_REPO;
const files = JSON.parse(fs.readFileSync(path.join(repo, 'Test/manifest.json'), 'utf8')).files;
const originals = new Map(files.map(f => [pathToFileURL(path.join(repo, f.path)).href, f.source]));
const destinations = new Map(files.map(f => [path.resolve(engine, f.source), path.join(repo, f.path)]));
const require = createRequire(path.join(engine, 'Tools/dora-dora/package.json'));

export async function resolve(specifier, context, nextResolve) {
  if (context.parentURL && originals.has(context.parentURL)) {
    if (specifier.startsWith('.')) {
      const original = path.resolve(engine, path.dirname(originals.get(context.parentURL)), specifier);
      const candidate = destinations.get(original) || original;
      if (fs.existsSync(candidate)) return nextResolve(pathToFileURL(candidate).href, context);
    } else if (!specifier.startsWith('node:') && !specifier.startsWith('/') && !specifier.includes(':')) {
      try { return await nextResolve(pathToFileURL(require.resolve(specifier)).href, context); }
      catch (error) { if (error.code !== 'MODULE_NOT_FOUND') throw error; }
    }
  }
  return nextResolve(specifier, context);
}
