import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../Projects/Web/web-platform.js', import.meta.url), 'utf8');

test('fault cleanup releases host state without re-entering an aborted runtime', async () => {
  class BrowserEvent extends Event {
    constructor(type, options = {}) { super(type); Object.assign(this, options); }
  }
  const page = new EventTarget(), canvas = new EventTarget(), document = new EventTarget();
  let disconnected = 0, workletDisposed = 0, capturesReleased = 0;
  canvas.hasPointerCapture = () => true;
  canvas.releasePointerCapture = () => { capturesReleased++; };
  document.getElementById = () => canvas;
  document.createElement = () => ({ canPlayType: () => '' });
  const audio = { state: 'running', async suspend() { this.state = 'suspended'; },
    async resume() { this.state = 'running'; } };
  const processor = { onaudioprocess() {}, disconnect() { disconnected++; } };
  const context = vm.createContext({
    Module: { canvas, SDL2: { audioContext: audio, audio: { scriptProcessorNode: processor } },
      ccall() { throw new Error('Must not enter faulted Wasm'); },
      doraAudio: { resume() {}, dispose() { workletDisposed++; } } },
    document, navigator: {}, CustomEvent: BrowserEvent, KeyboardEvent: BrowserEvent,
    PointerEvent: BrowserEvent,
    addEventListener: (type, handler, options) => page.addEventListener(type, handler,
      typeof options === 'boolean' ? { capture: options } : options),
    removeEventListener: (type, handler, options) => page.removeEventListener(type, handler,
      typeof options === 'boolean' ? { capture: options } : options),
    dispatchEvent: page.dispatchEvent.bind(page),
  });
  vm.runInContext(source, context);
  page.dispatchEvent(new BrowserEvent('keydown', { code: 'ArrowRight', key: 'ArrowRight' }));
  canvas.dispatchEvent(new BrowserEvent('pointerdown', { pointerId: 1 }));
  await Promise.resolve();
  assert.equal(context.DoraWebPlatform.state.pressedKeys, 1);
  page.dispatchEvent(new BrowserEvent('dora-statechange', { detail: { state: 'faulted' } }));
  await Promise.resolve();
  const api = context.DoraWebPlatform;
  assert.equal(api.state.active, false);
  assert.equal(api.state.pressedKeys, 0);
  assert.equal(api.state.activePointers, 0);
  assert.equal(capturesReleased, 1);
  assert.equal(disconnected, 1);
  assert.equal(workletDisposed, 1);
  await api.unlockAudio();
  await api.setSuspended(false);
  page.dispatchEvent(new BrowserEvent('keydown', { code: 'KeyA' }));
  assert.equal(api.state.pressedKeys, 0);
  assert.equal(audio.state, 'suspended');
  assert.equal(api.dispose(), false);
});
