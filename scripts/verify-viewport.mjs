import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const viewport = await readFile(new URL('../dist/viewport.js', import.meta.url), 'utf8');
// Exercise the shipped engine's sizing code, not a reimplementation of it.
const engine = await readFile(new URL('../dist/game.js', import.meta.url), 'utf8');
const start = engine.indexOf('var GodotDisplayScreen=');
const end = engine.indexOf(';var GodotInputGamepads=', start);
assert.ok(start >= 0 && end > start, 'Locate the shipped Godot sizing implementation');
const displaySource = engine.slice(start, end + 1);
function events() {
  const listeners = new Map();
  return {
    addEventListener(type, fn) { if (!listeners.has(type)) listeners.set(type, new Set()); listeners.get(type).add(fn); },
    removeEventListener(type, fn) { listeners.get(type)?.delete(fn); },
    emit(type) { for (const fn of [...(listeners.get(type) || [])]) fn(); },
    count(type) { return listeners.get(type)?.size || 0; },
  };
}
function fixture(width, height, ratio = 1) {
  const host = {clientWidth:Math.min(width, 758), clientHeight:height};
  let writes = 0, w = 300, h = 150, resize, density;
  const canvas = {style:{}, get width(){return w;}, set width(v){w=v;writes++;}, get height(){return h;}, set height(v){h=v;writes++;}};
  const window = Object.assign(events(), {innerWidth:width, innerHeight:height, devicePixelRatio:ratio, visualViewport:events(), matchMedia(){return density=events();}});
  const context = vm.createContext({window, document:{}, GodotConfig:{canvas, canvas_resize_policy:0}, ResizeObserver:class{constructor(fn){resize=fn;}observe(target){assert.equal(target,host);}disconnect(){resize=()=>{};}}, canvas, host});
  vm.runInContext(viewport+'\n'+displaySource+'\nGodotDisplayScreen._updateGL=()=>{};',context);
  return {canvas, host, window, context, get writes(){return writes;}, get density(){return density;}, resize(){resize();}, start(){vm.runInContext('var sizing=new GameViewport(canvas,host);',context);}, tick(){return vm.runInContext('GodotDisplayScreen.updateSize()',context);}};
}
let checks = 0;
function check(fn){fn();checks++;}

check(()=>{
  const t=fixture(1920,1080);
  vm.runInContext('GodotConfig.canvas_resize_policy=2;',t.context);
  t.tick();
  assert.equal(t.canvas.style.width,'1920px');
  const sceneLeft=(t.canvas.width-t.canvas.height*720/1280)/2;
  assert.ok(sceneLeft>650 && t.host.clientWidth-sceneLeft<110, 'Original engine policy reproduces the narrow visible strip');
});

for(const [width,height,ratio] of [[1920,1080,1],[1366,768,1.25],[2560,1440,2],[390,844,3],[844,390,2]]) {
  check(()=>{
    const t=fixture(width,height,ratio);t.start();
    assert.equal(t.canvas.width,Math.round(t.host.clientWidth*ratio));
    assert.equal(t.canvas.height,Math.round(t.host.clientHeight*ratio));
    assert.equal(t.tick(),1);
    assert.deepEqual(Array.from(vm.runInContext('GodotDisplayScreen.desired_size',t.context)),[t.canvas.width,t.canvas.height]);
    assert.equal(t.canvas.style.width,undefined,'Godot must not override CSS with window dimensions');
    const writes=t.writes;t.resize();t.window.emit('resize');t.window.visualViewport.emit('resize');
    assert.equal(t.tick(),0);assert.equal(t.writes,writes,'Unchanged dimensions never clear the drawing buffer');
    // A centered aspect-preserving 720×1280 viewport fits entirely inside the host.
    const scale=Math.min(t.canvas.width/720,t.canvas.height/1280);
    assert.ok(720*scale<=t.canvas.width && 1280*scale<=t.canvas.height);
  });
}
check(()=>{
  const t=fixture(1920,1080);t.start();t.tick();
  t.host.clientWidth=390;t.host.clientHeight=700;t.resize();
  assert.equal(t.canvas.width,390);assert.equal(t.canvas.height,700);assert.equal(t.tick(),1);
  t.host.clientHeight=844;t.window.visualViewport.emit('resize');
  assert.equal(t.canvas.height,844);assert.equal(t.tick(),1);
});
check(()=>{
  const t=fixture(1920,1080);t.start();t.tick();const old=t.density;
  t.window.devicePixelRatio=2;old.emit('change');
  assert.equal(old.count('change'),0,'DPR observer detaches from previous monitor');
  assert.equal(t.density.count('change'),1);assert.equal(t.canvas.width,1516);assert.equal(t.canvas.height,2160);assert.equal(t.tick(),1);
});
check(()=>{
  const t=fixture(390,844,2);t.start();const writes=t.writes;
  t.host.clientWidth=0;t.host.clientHeight=0;t.resize();assert.equal(t.writes,writes);
  t.host.clientWidth=430;t.host.clientHeight=932;t.window.emit('pageshow');assert.equal(t.canvas.width,860);assert.equal(t.canvas.height,1864);
  vm.runInContext('sizing.destroy()',t.context);
  t.host.clientWidth=320;t.resize();t.window.emit('resize');t.window.emit('pageshow');t.window.visualViewport.emit('resize');t.density.emit('change');
  assert.equal(t.canvas.width,860,'Detached observers no longer resize the canvas');
});
check(()=>{
  const t=fixture(390,844,2);t.start();t.tick();
  vm.runInContext('document.fullscreenElement=host;',t.context);
  t.host.clientWidth=1920;t.host.clientHeight=1080;t.resize();t.tick();
  assert.equal(t.canvas.width,3840);assert.equal(t.canvas.height,2160);
});
console.log(JSON.stringify({checks,result:'PASS',engine:'shipped GodotDisplayScreen',scope:'drawing buffer / host sizing; no browser rendering claim'}));
