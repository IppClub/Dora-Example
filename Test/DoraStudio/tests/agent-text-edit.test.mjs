import test from 'node:test';
import assert from 'node:assert/strict';
import { replaceFirst, findIndentTolerantReplacement, normalizeLineEndings, countOccurrences } from '../packages/agent-contracts/dist/text-edit.js';

test('native edit helpers preserve literal replacement, line normalization and match counting', () => {
  assert.equal(replaceFirst('x x', 'x', '$&'), '$& x');
  assert.equal(replaceFirst('abc', '', 'new'), 'abc');
  assert.equal(normalizeLineEndings('a\r\nb\rc'), 'a\nb\nc');
  assert.equal(countOccurrences('x x', 'x'), 2);
  assert.equal(countOccurrences('abc', ''), 0);
});
test('native tolerant replacement retains indentation and rejects ambiguous targets', () => {
  assert.deepEqual(findIndentTolerantReplacement('start\n\tfoo()\n\tbar()\nend', '  foo()\n  bar()', '  baz()\n    nested()'),
    { success: true, content: 'start\n\tbaz()\n\t  nested()\nend' });
  assert.equal(findIndentTolerantReplacement('foo()\nfoo()', ' foo()', 'bar()').success, false);
  assert.deepEqual(findIndentTolerantReplacement('let x = 1;', 'let  x\t= 1;', 'let x = 2;'),
    { success: true, content: 'let x = 2;' });
  assert.equal(findIndentTolerantReplacement('x = 1; x = 1;', 'x  = 1;', 'x = 2;').success, false);
  assert.equal(findIndentTolerantReplacement('unrelated', 'missing', 'new').success, false);
});
