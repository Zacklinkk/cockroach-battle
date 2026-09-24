import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';

const viewport=await readFile(new URL('../dist/viewport.js',import.meta.url),'utf8');
const script=await readFile(new URL('../dist/story.js',import.meta.url),'utf8');
const ui=await readFile(new URL('../dist/ui.js',import.meta.url),'utf8');
let checks=0;
function makeElement(){
  const events={};const children=new Map();
  return {clientWidth:390,clientHeight:844,hidden:true,style:{},textContent:'',disabled:false,currentTime:0,duration:23.4,
    classList:{add(){},remove(){},toggle(){}},dataset:{},
    removeEventListener(){},addEventListener(k,fn){(events[k]??=[]).push(fn);},emit(k,e={}){for(const fn of events[k]||[])fn(e);},
    querySelector(k){if(!children.has(k))children.set(k,makeElement());return children.get(k);},
    querySelectorAll(){return [];},focus(){},appendChild(){},replaceChildren(){},setAttribute(){},
    play(){this.emit('playing');return Promise.resolve();},pause(){this.paused=true;},
  };
}
function context(storageWorks=true){
  const elements=new Map(),commands=[];const doc=makeElement();
  doc.hidden=false;doc.getElementById=id=>{if(!elements.has(id))elements.set(id,makeElement());return elements.get(id);};
  doc.createElement=()=>makeElement();let stored='';
  const window=makeElement();window.dispatchEvent=()=>{};window.matchMedia=()=>makeElement();window.engineManifest={wasmBytes:1,packBytes:1};
  window.godotCommand=value=>commands.push(JSON.parse(value));
  let now=0,nextTimer=1;const timers=new Map();
  const setTimeoutFake=(fn,delay)=>{const id=nextTimer++;timers.set(id,{at:now+delay,fn});return id;};
  const advance=ms=>{const end=now+ms;while(true){const pending=[...timers].filter(([,t])=>t.at<=end).sort((a,b)=>a[1].at-b[1].at)[0];if(!pending)break;const [id,t]=pending;timers.delete(id);now=t.at;t.fn();}now=end;};
  const c=vm.createContext({ResizeObserver:class{observe(){}disconnect(){}},document:doc,window,localStorage:{getItem(){if(!storageWorks)throw Error('blocked');return stored;},setItem(k,v){if(!storageWorks)throw Error('blocked');stored=v;}},setTimeout:setTimeoutFake,clearTimeout:id=>timers.delete(id),console,performance:{now:()=>now},navigator:{},CustomEvent:class{},RoomAudio:class{unlock(){return Promise.resolve();}setState(){}setMuted(){}updateMix(){}},DeathCinematic:class{prepare(){}play(){}stop(){}},Engine:class{static getMissingFeatures(){return [];}startGame(){return Promise.resolve();}},AbortController,structuredClone});
  vm.runInContext(viewport+'\n'+script+'\n'+ui,c);return {c,doc,window,commands,advance,$:doc.getElementById};
}
const snapshot=(phase,extra={})=>({phase,room:1,life:3,time:0,kills:0,level:1,xp:0,need:22,alive:22,weapon:'slipper',weapon_name:'拖鞋',weapon_icon:'▰',runes:[],combos:[],parts:0,...extra});
{
  const t=context();t.window.receiveGameState(snapshot('start'));t.window.gameEvent({kind:'ready'});t.commands.length=0;
  t.$('start').onclick();assert.equal(t.$('story-screen').hidden,false);assert.equal(t.commands.length,0);checks++;
  t.$('story-screen').querySelector('[data-story-skip]').onclick();assert.equal(t.commands.length,0);t.advance(350);assert.equal(t.commands.length,1);assert.deepEqual(t.commands[0],{action:'start'});checks++;
  t.$('story-screen').querySelector('video').emit('ended');assert.equal(t.commands.length,1);checks++;
  t.advance(1350);t.$('restart').onclick();t.advance(350);assert.deepEqual(t.commands.at(-1),{action:'start'});assert.equal(t.$('story-screen').hidden,true);checks++;
  t.$('replay-story').onclick();const count=t.commands.length;t.$('story-screen').querySelector('video').emit('ended');assert.equal(t.commands.length,count);checks++;
  t.advance(1350);t.window.receiveGameState(snapshot('win',{campaign_complete:true,room:5,campaign_rooms:5}));assert.equal(t.$('win-title').textContent,'你回到了现实。');t.$('next').onclick();t.advance(350);assert.deepEqual(t.commands.at(-1),{action:'start'});checks++;
  t.advance(1350);t.window.receiveGameState(snapshot('playing'));t.window.receiveGameState(snapshot('win'));t.$('next').onclick();t.advance(350);assert.deepEqual(t.commands.at(-1),{action:'next'});checks++;
}
{
  const t=context(false);t.window.gameEvent({kind:'ready'});t.$('start').onclick();t.$('story-screen').querySelector('video').emit('error');t.advance(350);assert.deepEqual(t.commands.at(-1),{action:'start'});checks++;
}
{
  const t=context();const v=t.$('story-screen').querySelector('video');v.play=()=>Promise.reject(Error('autoplay denied'));t.window.gameEvent({kind:'ready'});t.$('start').onclick();await new Promise(r=>setImmediate(r));assert.equal(t.$('story-screen').querySelector('[data-story-resume]').hidden,false);checks++;
  t.doc.hidden=true;t.doc.emit('visibilitychange');assert.equal(v.paused,true);checks++;
  t.$('story-screen').querySelector('[data-story-skip]').onclick();t.advance(350);assert.deepEqual(t.commands.at(-1),{action:'start'});checks++;
}
console.log(JSON.stringify({checks,result:'PASS'}));
