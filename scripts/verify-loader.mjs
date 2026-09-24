// Exercise the shipped loader with the actual exported engine, including the
// double-compression response that produced exactly 43% with the previous loader.
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const dist=new URL('../dist/',import.meta.url);
const code=await readFile(new URL('engine-loader.js',dist),'utf8');
const manifest=JSON.parse((await readFile(new URL('engine-manifest.js',dist),'utf8')).split('=',2)[1].trim().replace(/;$/,''));
const gzip=await readFile(new URL('game.wasm.gz',dist));
const wasm=gunzipSync(gzip);
const packParts=await Promise.all((manifest.packParts||['game.pck']).map(p=>readFile(new URL(p,dist))));
const pack=Buffer.concat(packParts);
const parts=await Promise.all(manifest.parts.map(p=>readFile(new URL(p,dist))));
assert.equal(wasm.length,manifest.wasmBytes);assert.deepEqual(Buffer.concat(parts),wasm);
function harness(fetcher,{decoder=true,fastTimeout=false}={}) {
  const target=new EventTarget();const events=[];
  target.addEventListener('dirty-room-load-progress',e=>events.push(e.detail));
  target.addEventListener('dirty-room-load-error',e=>events.push({error:e.detail.message}));
  const context={URL,Response,Blob,ReadableStream,Uint8Array,ArrayBuffer,AbortController,CustomEvent,location:new URL('https://game.invalid/'),crypto:webcrypto,console:{warn(){},error:console.error},setTimeout:fastTimeout?(fn,ms)=>setTimeout(fn,Math.min(ms,40)):setTimeout,clearTimeout,engineManifest:manifest,fetch:fetcher,dispatchEvent:target.dispatchEvent.bind(target),addEventListener:target.addEventListener.bind(target)};
  if(decoder)context.DecompressionStream=DecompressionStream;
  context.window=context;vm.runInNewContext(code,context);
  return {fetch:context.fetch,events};
}
let checks=0;
async function scenario(name,configure,options={}) {
  const requests=[];const counts=new Map();
  const app=harness(async (input,init)=>{
    const url=new URL(input);const name=url.pathname.split('/').at(-1);
    requests.push(url);const count=(counts.get(name)||0)+1;counts.set(name,count);
    const overridden=configure?.(name,count,init);
    if(overridden!==undefined)return overridden;
    if(name==='game.wasm.gz')return new Response(gzip);
    if(name==='game.pck')return new Response(pack);
    const packIndex=(manifest.packParts||[]).indexOf(name);
    if(packIndex>=0)return new Response(packParts[packIndex]);
    const index=manifest.parts.indexOf(name);
    if(index>=0)return new Response(parts[index]);
    return new Response('passthrough');
  },options);
  const [engineResponse,sceneResponse]=await Promise.all([app.fetch('game.wasm'),app.fetch('game.pck')]);
  const engine=new Uint8Array(await engineResponse.arrayBuffer());
  assert.deepEqual(Buffer.from(engine),wasm,name);
  assert.deepEqual(Buffer.from(await sceneResponse.arrayBuffer()),pack,name);
  assert.equal(engineResponse.headers.get('content-type'),'application/wasm');
  assert.equal(engineResponse.headers.get('content-length'),String(wasm.length));
  assert.ok(app.events.some(e=>e.downloaded&&e.percent===90));
  assert.ok(!app.events.some(e=>e.error));
  assert.ok(requests.every(u=>u.searchParams.get('v')===manifest.revision));
  checks++;console.log('PASS',name);
  return {app,engine,counts};
}
await scenario('ordinary gzip');
const critical=await scenario('gzip file still compressed after HTTP transport decoding',name=>name==='game.wasm.gz'?new Response(gzip,{headers:{'Content-Encoding':'gzip'}}):undefined);
const compiled=await WebAssembly.compile(critical.engine);
assert.ok(WebAssembly.Module.exports(compiled).length>0);checks++;console.log('PASS real Godot WebAssembly compiles after the 43% reproduction');
await scenario('HTTP body already decompressed to Wasm',name=>name==='game.wasm.gz'?new Response(wasm,{headers:{'Content-Encoding':'gzip'}}):undefined);
await scenario('truncated gzip falls back to chunks',name=>name==='game.wasm.gz'?new Response(gzip.subarray(0,1000)):undefined);
await scenario('HTML/error body falls back to chunks',name=>name==='game.wasm.gz'?new Response('<html>error</html>'):undefined);
await scenario('browser without DecompressionStream',undefined,{decoder:false});
const retried=await scenario('truncated engine chunk retries', (name,count)=>name===manifest.parts[0]&&count===1?new Response(parts[0].subarray(0,100)):undefined,{decoder:false});
assert.equal(retried.counts.get(manifest.parts[0]),2);
const packRetry=await scenario('truncated scene pack retries',(name,count)=>name===(manifest.packParts?.[0]||'game.pck')&&count===1?new Response(pack.subarray(0,100)):undefined);
assert.equal(packRetry.counts.get(manifest.packParts?.[0]||'game.pck'),2);
await scenario('same-size corrupt gzip output falls back by hash',name=>{if(name==='game.wasm.gz'){const damaged=Buffer.from(wasm);damaged[1000]^=1;return new Response(damaged);} });
await scenario('stalled gzip request switches to chunks',(name,_count,init)=>name==='game.wasm.gz'?new Promise((_,reject)=>init.signal.addEventListener('abort',()=>reject(new Error('aborted')),{once:true})):undefined,{fastTimeout:true});
const failed=harness(async()=>new Response('unavailable',{status:503}));
await assert.rejects(failed.fetch('game.wasm'));
assert.ok(failed.events.some(e=>e.error));checks++;console.log('PASS terminal failure is reported instead of silent loading');
const truncated=harness(async()=>new Response(pack.subarray(0,100)));
await assert.rejects(truncated.fetch('game.pck'),/不完整/);checks++;console.log('PASS incomplete scene never reaches Godot');
console.log(JSON.stringify({checks,result:'PASS',wasmBytes:wasm.length,packBytes:pack.length}));
