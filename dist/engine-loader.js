// Godot receives verified, uncompressed bytes. HTTP Content-Encoding describes
// transport compression, so it cannot tell us whether a .gz file is still gzip.
(() => {
  'use strict';
  const nativeFetch = window.fetch.bind(window);
  const manifest = window.engineManifest;
  const pending = new Map();
  const controllers = new Set();
  const progress = { engine: 0, scene: 0 };
  const total = manifest.wasmBytes + manifest.packBytes;
  const timeoutMs = 30000;
  const isWasm = b => b.length >= 8 && b[0] === 0 && b[1] === 97 && b[2] === 115 && b[3] === 109 && b[4] === 1 && b[5] === 0 && b[6] === 0 && b[7] === 0;
  const isGzip = b => b.length >= 2 && b[0] === 31 && b[1] === 139;

  function announce(kind, fraction, message = '') {
    progress[kind] = Math.max(0, Math.min(1, fraction));
    const percent = Math.round(90 * (progress.engine * manifest.wasmBytes + progress.scene * manifest.packBytes) / total);
    window.dispatchEvent(new CustomEvent('dirty-room-load-progress', {
      detail: { percent, message, downloaded: progress.engine === 1 && progress.scene === 1 }
    }));
  }
  function deadline(promise, controller) {
    let timer;
    const stalled = new Promise((_, reject) => {
      timer = setTimeout(() => { controller.abort(); reject(new Error('资源下载超时')); }, timeoutMs);
    });
    return Promise.race([promise, stalled]).finally(() => clearTimeout(timer));
  }
  function assetURL(name, base) {
    const url = new URL(name, base);
    if (manifest.revision) url.searchParams.set('v', manifest.revision);
    return url;
  }
  async function readBytes(response, controller, limit, onChunk = () => {}) {
    if (!response.ok || !response.body) throw new Error(`资源下载失败（${response.status}）`);
    const reader = response.body.getReader();
    const chunks = [];
    const prefix = new Uint8Array(8);
    let count = 0, prefixLength = 0;
    try {
      while (true) {
        const { done, value } = await deadline(reader.read(), controller);
        if (done) break;
        if (!value?.length) continue;
        const n = Math.min(8 - prefixLength, value.length);
        if (n > 0) { prefix.set(value.subarray(0, n), prefixLength); prefixLength += n; }
        count += value.length;
        if (count > limit) throw new Error('资源大小与当前版本不一致');
        chunks.push(value);
        onChunk(count, prefix.subarray(0, prefixLength));
      }
    } catch (error) {
      controller.abort();
      void reader.cancel().catch(() => {});
      throw error;
    } finally { reader.releaseLock(); }
    const bytes = new Uint8Array(count);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return bytes;
  }
  async function download(name, base, init, limit, onChunk, retry = false) {
    const controller = new AbortController();
    controllers.add(controller);
    const abort = () => controller.abort();
    init?.signal?.addEventListener('abort', abort, { once: true });
    if (init?.signal?.aborted) controller.abort();
    try {
      const response = await deadline(nativeFetch(assetURL(name, base), {
        ...init, signal: controller.signal, cache: retry ? 'reload' : 'default'
      }), controller);
      return await readBytes(response, controller, limit, onChunk);
    } finally {
      init?.signal?.removeEventListener('abort', abort);
      controllers.delete(controller);
    }
  }
  async function verify(bytes, size, hash, kind) {
    if (bytes.length !== size) throw new Error(kind + '文件不完整');
    if (kind === '引擎' && !isWasm(bytes)) throw new Error('引擎文件格式错误');
    if (kind === '场景' && !(bytes[0] === 71 && bytes[1] === 68 && bytes[2] === 80 && bytes[3] === 67)) throw new Error('场景文件格式错误');
    if (hash && window.crypto?.subtle) {
      const digest = new Uint8Array(await window.crypto.subtle.digest('SHA-256', bytes));
      const actual = [...digest].map(x => x.toString(16).padStart(2, '0')).join('');
      if (actual !== hash) throw new Error(kind + '文件校验失败');
    }
    return bytes;
  }
  async function engineBytes(base, init) {
    if (typeof DecompressionStream === 'function') {
      try {
        let bytes = await download('game.wasm.gz', base, init, manifest.wasmBytes, (count, prefix) => {
          const expected = isGzip(prefix) ? manifest.gzipBytes : manifest.wasmBytes;
          announce('engine', Math.min(.98, count / expected), '正在加载引擎');
        });
        if (isGzip(bytes)) {
          const controller = new AbortController();
          bytes = await readBytes(new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))), controller, manifest.wasmBytes);
        }
        await verify(bytes, manifest.wasmBytes, manifest.wasmSha256, '引擎');
        announce('engine', 1);
        return bytes;
      } catch (error) {
        if (init?.signal?.aborted) throw error;
        console.warn('Compact engine download failed; retrying with verified chunks.', error);
        announce('engine', 0, '正在切换备用下载');
      }
    }
    const bytes = new Uint8Array(manifest.wasmBytes);
    const loaded = manifest.parts.map(() => 0);
    const partSize = manifest.partBytes || 14000000;
    let next = 0;
    async function worker() {
      while (next < manifest.parts.length) {
        const index = next++;
        const size = Math.min(partSize, manifest.wasmBytes - index * partSize);
        let lastError;
        for (let attempt = 0; attempt < 2; attempt++) {
          try {
            loaded[index] = 0;
            const part = await download(manifest.parts[index], base, init, size, count => {
              loaded[index] = count;
              announce('engine', Math.min(.98, loaded.reduce((a, b) => a + b, 0) / manifest.wasmBytes), '正在加载引擎');
            }, attempt > 0);
            if (part.length !== size) throw new Error('引擎分段下载不完整');
            bytes.set(part, index * partSize);
            lastError = null;
            break;
          } catch (error) { lastError = error; if (init?.signal?.aborted) throw error; }
        }
        if (lastError) throw lastError;
      }
    }
    await Promise.all([worker(), worker()]);
    await verify(bytes, manifest.wasmBytes, manifest.wasmSha256, '引擎');
    announce('engine', 1);
    return bytes;
  }
  async function sceneBytes(base, init) {
    const names = manifest.packParts || ['game.pck'];
    const partSize = manifest.packParts ? manifest.partBytes : manifest.packBytes;
    const bytes = new Uint8Array(manifest.packBytes);
    let offset = 0;
    for (const name of names) {
      const expected = Math.min(partSize, manifest.packBytes - offset);
      let lastError;
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const part = await download(name, base, init, expected,
            count => announce('scene', Math.min(.98, (offset + count) / manifest.packBytes), '正在加载房间'), attempt > 0);
          if (part.length !== expected) throw new Error('场景分段下载不完整');
          bytes.set(part, offset);
          lastError = null;
          break;
        } catch (error) { lastError = error; if (init?.signal?.aborted) throw error; }
      }
      if (lastError) throw lastError;
      offset += expected;
    }
    await verify(bytes, manifest.packBytes, manifest.packSha256, '场景');
    announce('scene', 1);
    return bytes;
  }
  window.fetch = async function (input, init) {
    const raw = typeof input === 'string' ? input : input instanceof URL ? input.href : input?.url;
    const url = new URL(raw || '', location.href);
    const kind = url.pathname.endsWith('/game.wasm') ? 'engine' : url.pathname.endsWith('/game.pck') ? 'scene' : null;
    if (url.origin !== location.origin || !kind) return nativeFetch(input, init);
    if (!pending.has(kind)) pending.set(kind, (kind === 'engine' ? engineBytes(url, init) : sceneBytes(url, init)).catch(error => {
      window.dispatchEvent(new CustomEvent('dirty-room-load-error', { detail: { message: error.message } }));
      throw error;
    }));
    const bytes = await pending.get(kind);
    return new Response(bytes, { status: 200, headers: {
      'Content-Type': kind === 'engine' ? 'application/wasm' : 'application/octet-stream',
      'Content-Length': String(bytes.length)
    } });
  };
  window.addEventListener('dirty-room-game-ready', () => pending.clear(), { once: true });
  window.addEventListener('pagehide', () => { for (const controller of controllers) controller.abort(); }, { once: true });
})();
