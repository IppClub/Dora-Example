import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createSnapshotReadBackend } from '../packages/agent-contracts/dist/snapshot-read.js';
import { verifyDocumentBundle } from '../packages/agent-contracts/dist/documents.js';

test('built documentation preserves actual bilingual sources and reads through the snapshot backend', async () => {
  for (const [language, directory] of [['en', 'en'], ['zh', 'zh-Hans']]) {
    const bundle = JSON.parse(await readFile(new URL(`../packages/agent-contracts/dist/docs/${language}.json`, import.meta.url), 'utf8'));
    assert.equal(new Set(bundle.documents.map(doc => doc.path)).size, bundle.documents.length);
    const doc = bundle.documents.find(doc => doc.path === '@dora-doc/dora-api/Dora.d.ts');
    const original = await readFile(new URL(`../../Assets/Script/Lib/Dora/${directory}/Dora.d.ts`, import.meta.url));
    assert.equal(doc.text, original.toString('utf8'));
    assert.equal(doc.sha256, createHash('sha256').update(original).digest('hex'));
    assert.ok(bundle.documents.some(doc => doc.path.startsWith('@dora-doc/dora-tutorial/')));
    const verified = await verifyDocumentBundle(bundle, language);
    const read = createSnapshotReadBackend({ version: 1, projectId: 'docs', revision: 0, entry: 'main.lua', files: [{ path: 'main.lua', kind: 'text', text: '' }] }, verified);
    assert.equal(read('docs', doc.path, 1, 2).success, true);
  }
});
test('document loader rejects tampering, wrong language and duplicate or unsafe virtual paths', async () => {
  const record = { path: '@dora-doc/dora-api/example.ts', text: 'hello', sha256: createHash('sha256').update('hello').digest('hex') };
  const bundle = { version: 1, language: 'en', documents: [record] };
  await assert.rejects(verifyDocumentBundle(bundle, 'zh'));
  await assert.rejects(verifyDocumentBundle({ ...bundle, documents: [record, record] }, 'en'));
  await assert.rejects(verifyDocumentBundle({ ...bundle, documents: [{ ...record, text: 'changed' }] }, 'en'));
  await assert.rejects(verifyDocumentBundle({ ...bundle, documents: [{ ...record, path: '@dora-doc/dora-api/../secret' }] }, 'en'));
  const pending = verifyDocumentBundle(bundle, 'en');
  record.text = 'late mutation';
  assert.equal((await pending)[0].text, 'hello');
});
