// Tests the actual captured browser decoder against a freshly generated Android
// export with synthetic metadata. No real user catalog or access code is used.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
const [fixturePath, readerPath] = process.argv.slice(2);
if (!fixturePath || !readerPath) throw Error('Pass synthetic Java fixture JSON and captured songbook.js');
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const source = fs.readFileSync(readerPath, 'utf8');
const start = source.indexOf('async function decrypt(');
const end = source.indexOf('\nfunction fill(', start);
assert.ok(start >= 0 && end > start, 'Captured decoder boundary changed; inspect it before updating');
const decrypt = vm.runInNewContext(source.slice(start, end) + ';decrypt', {
  crypto: webcrypto, TextEncoder, TextDecoder, atob,
}, { timeout: 1000 });
const expected = Buffer.from(fixture.csvBase64, 'base64').toString('utf8');
assert.equal(await decrypt(JSON.stringify(fixture.envelope), fixture.code), expected);
const wrongCode = fixture.code[0] === '0' ? '1' + fixture.code.slice(1) : '0' + fixture.code.slice(1);
await assert.rejects(decrypt(JSON.stringify(fixture.envelope), wrongCode));
const tampered = structuredClone(fixture.envelope);
const bytes = Buffer.from(tampered.payload, 'base64'); bytes[bytes.length - 1] ^= 1;
tampered.payload = bytes.toString('base64');
await assert.rejects(decrypt(JSON.stringify(tampered), fixture.code));
console.log('Actual browser decoder: Android export decrypted; wrong-code and tamper checks passed');
