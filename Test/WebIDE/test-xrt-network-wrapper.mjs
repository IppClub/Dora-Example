import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";

const toolsDir = process.cwd();
const repoDir = path.resolve(toolsDir, "../..");
const readRepoFile = (file) => readFile(path.join(repoDir, file), "utf8");

const header = await readRepoFile("Source/Http/XrtNetwork.h");
const implementation = await readRepoFile("Source/Http/XrtNetwork.c");
const httpServer = await readRepoFile("Source/Http/HttpServer.cpp");

assert.match(httpServer, /#include "Http\/XrtNetwork\.h"/);
assert.doesNotMatch(httpServer, /#include [<"]xrt\/xrt\.h[>"]/);
assert.doesNotMatch(httpServer, /\b(?:xhttpd|xws|xnetengine|xnet_result|xrtNet|xrtHttpd|xrtWs)/);

assert.doesNotMatch(header, /#include [<"]xrt\/xrt\.h[>"]/);
assert.doesNotMatch(header, /\b(?:xhttpd|xws|xnetengine|xnet_result|xrtNet|xrtHttpd|xrtWs)/);
assert.match(header, /typedef struct DoraXrtHttpServer DoraXrtHttpServer;/);
assert.match(header, /typedef struct DoraXrtWebSocketServer DoraXrtWebSocketServer;/);
assert.match(implementation, /#define XRT_IMPLEMENTATION/);
assert.match(implementation, /#include "xrt\/xrt\.h"/);

const projectFiles = [
	"Projects/xmake/manifests/engine.lua",
];
for (const projectFile of projectFiles) {
	const source = await readRepoFile(projectFile);
	assert.match(source, /XrtNetwork\.(?:c|h)/, `${projectFile} must include the renamed wrapper`);
	assert.doesNotMatch(source, /XrtHttpClient\.(?:c|h)/, `${projectFile} still references the old wrapper name`);
}

const compile = (command, args, options = {}) => {
	const result = spawnSync(command, args, {
		cwd: repoDir,
		encoding: "utf8",
		...options,
	});
	assert.equal(
		result.status,
		0,
		`${command} ${args.join(" ")} failed:\n${result.stdout}${result.stderr}`,
	);
};

compile("clang", [
	"-std=c11",
	"-fsyntax-only",
	"-ISource",
	"-ISource/3rdParty",
	"Source/Http/XrtNetwork.c",
]);

compile("clang++", [
	"-std=c++20",
	"-fsyntax-only",
	"-ISource",
	"-x",
	"c++",
	"-",
], {
	input: `
#include <stdint.h>
typedef uint64_t u64;
typedef int64_t i64;
#include "Http/XrtNetwork.h"

int main() {
	DoraXrtHttpServer* httpServer = nullptr;
	DoraXrtWebSocketServer* webSocketServer = nullptr;
	DoraXrtHttpResponse response{};
	DoraXrtHttpHeader header{};
	response.headers = &header;
	response.headerCount = 1;
	return httpServer == nullptr && webSocketServer == nullptr
		&& response.headers == &header && response.headerCount == 1 ? 0 : 1;
}
`,
});

console.log("XRT network wrapper isolation tests passed.");

// Exercise the upload client's real size checks and HTTP/network failure paths.
const { createRequire } = await import('node:module');
const requireFromIDE = createRequire(path.resolve('package.json'));
const { build } = requireFromIDE('esbuild');
const bundle = await build({ entryPoints: [path.resolve('src/UploadFile.ts')], bundle: true, format: 'esm', platform: 'node', write: false });
const { MAX_UPLOAD_FILE_BYTES, checkUploadSize, uploadFile, UploadError } = await import(`data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString('base64')}`);
assert.equal(MAX_UPLOAD_FILE_BYTES, Number.MAX_SAFE_INTEGER);
assert.doesNotThrow(() => checkUploadSize({ name: "over-2G.zip", size: 3 * 1024 ** 3 }));
assert.doesNotThrow(() => checkUploadSize({ name: '1.8G.zip', size: 1844 * 1024 ** 2 }));
assert.doesNotThrow(() => checkUploadSize({ name: '2G.zip', size: MAX_UPLOAD_FILE_BYTES }));
assert.throws(() => checkUploadSize({ name: 'too-large.zip', size: MAX_UPLOAD_FILE_BYTES + 1 }), e => e instanceof UploadError && e.reason === 'tooLarge');
const originalFetch = globalThis.fetch;
const file = new File(['project'], '项目.zip');
try {
	let calls = 0;
	globalThis.fetch = async (_url, init) => {
		calls++;
		assert(init.body instanceof FormData);
		assert.equal(init.body.get('file').name, file.name);
		assert.equal(await init.body.get('file').text(), 'project');
		return new Response(null, { status: 200 });
	};
	await uploadFile('/upload', file);
	assert.equal(calls, 1);
	await assert.rejects(uploadFile('/upload', { name: 'too-large.zip', size: MAX_UPLOAD_FILE_BYTES + 1 }), e => e.reason === 'tooLarge');
	assert.equal(calls, 1, 'Oversized files must be rejected before any network request');
	for (const [status, reason] of [[400,'invalidRequest'],[404,'resumeUnsupported'],[409,'resumeConflict'],[422,'integrityError'],[401,'unauthorized'],[403,'forbidden'],[408,'timedOut'],[413,'serverTooLarge'],[503,'busy'],[504,'timedOut'],[507,'storageError'],[500,'serverError']]) {
		globalThis.fetch = async () => new Response(null, { status });
		await assert.rejects(uploadFile('/upload', file), e => e instanceof UploadError && e.fileName === file.name && e.reason === reason && e.status === status);
	}
	globalThis.fetch = async () => { throw new TypeError('Failed to fetch'); };
	await assert.rejects(uploadFile('/upload', file), e => e.reason === 'networkError');
	const controller = new AbortController();
	globalThis.fetch = async (_url, init) => {
		assert.equal(init.signal, controller.signal);
		controller.abort();
		throw new DOMException('Aborted', 'AbortError');
	};
	await assert.rejects(uploadFile('/upload', file, controller.signal), e => e.name === 'AbortError');
} finally { globalThis.fetch = originalFetch; }
console.log('Upload client size boundaries, file body, HTTP failures, network interruption and cancellation: PASS');

// Lost acknowledgements, retries and a fresh client invocation must all query
// the server's checkpoint rather than append a chunk twice.
const content = new Uint8Array(33 * 1024 * 1024);
for (let i = 0; i < content.length; i += 4096) content[i] = i % 251;
const bigFile = new File([content], '续传.zip');
let confirmed = 0, published = false, lost = false, down = false;
const received = [], progress = [];
try {
	globalThis.fetch = async (url, init) => {
		const query = new URL(url, 'http://localhost').searchParams;
		if (down) throw new TypeError('offline');
		if (query.get('action') === 'chunk') {
			const offset = Number(query.get('offset'));
			assert.equal(offset, confirmed, 'Never resend an acknowledged chunk');
			const chunk = new Uint8Array(await init.body.arrayBuffer());
			assert.deepEqual(chunk, content.subarray(offset, offset + chunk.length));
			assert(chunk.length <= 4 * 1024 * 1024);
			received.push(offset);
			confirmed += chunk.length;
			if (!lost) { lost = true; throw new TypeError('response lost after saving'); }
			if (confirmed >= 12 * 1024 * 1024) { down = true; throw new TypeError('offline'); }
		}
		if (query.get('action') === 'complete') published = true;
		return Response.json({ offset: confirmed, complete: published });
	};
	await assert.rejects(uploadFile('/upload?path=game&name=续传.zip', bigFile), e => e.reason === 'networkError');
	const checkpoint = confirmed;
	assert(checkpoint > 0 && checkpoint < bigFile.size);
	down = false;
	// Fresh invocation simulates selecting the same file after a page reload.
	const resumeFetch = globalThis.fetch;
	globalThis.fetch = async (url, init) => {
		// Do not inject a second outage after reconnecting.
		const query = new URL(url, 'http://localhost').searchParams;
		if (query.get('action') === 'chunk') {
			const offset = Number(query.get('offset'));
			assert.equal(offset, confirmed);
			const chunk = new Uint8Array(await init.body.arrayBuffer());
			assert.deepEqual(chunk, content.subarray(offset, offset + chunk.length));
			received.push(offset); confirmed += chunk.length;
			return Response.json({ offset: confirmed, complete: false });
		}
		return resumeFetch(url, init);
	};
	await uploadFile('/upload?path=game&name=续传.zip', bigFile, undefined, (percent, phase) => progress.push({ percent, phase }));
	assert(published);
	assert.equal(confirmed, bigFile.size);
	assert.equal(new Set(received).size, received.length, 'No chunk was appended twice');
	assert(progress.some(p => p.phase === 'uploading' && p.percent > 0 && p.percent < 100));
	assert(progress.some(p => p.phase === 'verifying'));
	assert.equal(progress.at(-1).percent, 100);
} finally { globalThis.fetch = originalFetch; }
console.log('Resumable client: lost acknowledgements, exhausted retries, fresh-invocation recovery and progress: PASS');

let inFlight = 0, peak = 0, starts = 0;
const releaseRequests = [];
try {
	globalThis.fetch = async () => {
		starts++; inFlight++; peak = Math.max(peak, inFlight);
		if (starts <= 2) await new Promise(resolve => releaseRequests.push(resolve));
		inFlight--; return new Response(null, { status: 200 });
	};
	const cancelQueued = new AbortController();
	const results = Promise.allSettled([
		uploadFile('/upload', file), uploadFile('/upload', file),
		uploadFile('/upload', file, cancelQueued.signal), uploadFile('/upload', file),
	]);
	await new Promise(resolve => setTimeout(resolve, 0));
	assert.equal(starts, 2);
	cancelQueued.abort();
	releaseRequests.forEach(release => release());
	const settled = await results;
	assert.equal(peak, 2);
	assert.equal(starts, 3);
	assert.equal(settled.filter(r => r.status === 'fulfilled').length, 3);
	assert.equal(settled[2].reason.name, 'AbortError');
} finally { globalThis.fetch = originalFetch; }
console.log('Bounded folder upload queue and cancellation before admission: PASS');
