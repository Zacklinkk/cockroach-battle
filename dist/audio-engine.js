'use strict';
const roomAudioBase=new URL('media/audio/',document.currentScript.src);
// Original rendered samples; independent buses and limited voices keep combos clear.
window.RoomAudio=class RoomAudio {
 constructor(){this.ctx=null;this.buffers=new Map;this.pending=new Map;this.last={};this.variants={};this.loops=new Map;this.voices=new Set;this.phase='start';this.muted=false;this.music=[];this.hidden=false;}
 async unlock(){
  if(!this.ctx){const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return;this.ctx=new AC;const c=this.ctx;this.master=c.createGain();this.fx=c.createGain();this.score=c.createGain();this.tension=c.createGain();const limiter=c.createDynamicsCompressor();limiter.threshold.value=-12;limiter.knee.value=12;limiter.ratio.value=5;limiter.attack.value=.004;limiter.release.value=.15;this.fx.gain.value=.60;this.score.gain.value=.55;this.tension.gain.value=0;this.fx.connect(this.master);this.score.connect(this.master);this.tension.connect(this.master);this.master.connect(limiter).connect(c.destination);this.master.gain.value=this.muted?0:.8;}
  await this.ctx.resume();this.startMusic();
  for(const n of ['crit-0','break-0','splat-0','rush','hurt','death-flight','level','cast-wand'])this.load(n).catch(()=>{});
 }
 async load(name){if(this.buffers.has(name))return this.buffers.get(name);if(this.pending.has(name))return this.pending.get(name);const promise=(async()=>{const r=await fetch(new URL(name+(name.startsWith('room-')?'.mp3':'.wav'),roomAudioBase));if(!r.ok)throw Error('Audio '+r.status);const b=await this.ctx.decodeAudioData(await r.arrayBuffer());this.buffers.set(name,b);return b;})();this.pending.set(name,promise);try{return await promise;}finally{this.pending.delete(name);}}
 setMuted(m){this.muted=m;if(this.ctx)this.master.gain.setTargetAtTime(m?0:.8,this.ctx.currentTime,.035);}
 async startMusic(){if(this.startingMusic||this.music.length||!this.ctx)return;this.startingMusic=true;try{const buffers=await Promise.all(['room-score','room-tension'].map(n=>this.load(n)));const at=this.ctx.currentTime+.05;buffers.forEach((b,i)=>{const s=this.ctx.createBufferSource();s.buffer=b;s.loop=true;s.connect(i?this.tension:this.score);s.start(at);this.music.push(s);});this.updateMix();}catch(e){console.warn('Music unavailable',e.message);}finally{this.startingMusic=false;}}
 updateMix(){if(!this.ctx)return;const active=this.phase==='playing'&&!this.hidden;this.score.gain.setTargetAtTime(active?.60:this.phase==='upgrade'?.16:0,this.ctx.currentTime,.3);this.tension.gain.setTargetAtTime(active?(this.danger||0)*.43:0,this.ctx.currentTime,.3);if(!active)this.stopLoops();}
 setState(s){this.phase=s.phase;this.danger=Math.min(1,(3-s.life)*.32+(s.alive>35?.2:0)+(s.compass?.18:0));this.updateMix();}
 stopLoops(){for(const [name,l]of this.loops){clearTimeout(l.timer);l.gain.gain.setTargetAtTime(0,this.ctx.currentTime,.035);l.source.stop(this.ctx.currentTime+.17);}this.loops.clear();}
 async loop(name){
  if(!this.ctx||this.phase!=='playing'||this.muted)return;
  let l=this.loops.get(name);if(l){clearTimeout(l.timer);l.timer=setTimeout(()=>this.endLoop(name),230);return;}
  const b=await this.load(name+'-loop').catch(()=>null);if(!b||this.phase!=='playing'||this.loops.has(name))return;
  const source=this.ctx.createBufferSource(),gain=this.ctx.createGain();source.buffer=b;source.loop=true;gain.gain.value=.21;source.connect(gain).connect(this.fx);source.start();l={source,gain,timer:setTimeout(()=>this.endLoop(name),230)};this.loops.set(name,l);
 }
 endLoop(name){const l=this.loops.get(name);if(!l)return;l.gain.gain.setTargetAtTime(0,this.ctx.currentTime,.025);l.source.stop(this.ctx.currentTime+.12);this.loops.delete(name);}
 variant(name){const n=(this.variants[name]??Math.floor(Math.random()*3)+1)%3;this.variants[name]=n+1;return name+'-'+n;}
 async play(name,gain=.48,pan=0,rate=1){
  if(!this.ctx||this.muted||this.hidden)return;const requested=performance.now();const b=await this.load(name).catch(()=>null);if(!b||performance.now()-requested>700||this.hidden||this.muted)return;
  if(this.voices.size>=16){const old=this.voices.values().next().value;try{old.stop();}catch{}this.voices.delete(old);}
  const c=this.ctx,s=c.createBufferSource(),g=c.createGain();s.buffer=b;s.playbackRate.value=rate;g.gain.value=gain;s.connect(g);if(c.createStereoPanner){const p=c.createStereoPanner();p.pan.value=Math.max(-.85,Math.min(.85,pan));g.connect(p).connect(this.fx);}else g.connect(this.fx);this.voices.add(s);s.onended=()=>this.voices.delete(s);s.start();
 }
 event(kind,d={}){if(!this.ctx||this.muted)return;const now=performance.now(),gap=kind==='hit'?65:kind==='break'?100:75;if(now-(this.last[kind]||0)<gap)return;this.last[kind]=now;
  if(['chainsaw','spray','vacuum'].includes(kind)){this.loop(kind);return;}
  if(kind==='hit'){if(d.element==='lightning')this.play('lightning-chain',.24,d.pan||0);if(d.element==='shatter')this.play('ice-crack',.35,d.pan||0);this.play(this.variant('hit-'+(d.weapon||'wand')),.47,d.pan||0,.95+Math.random()*.10);return;}
  if(['crit','break','splat'].includes(kind)){this.play(this.variant(kind),kind==='crit'?.64:kind==='splat'?.68:.45,d.pan||0);return;}
  if(kind==='rush'){this.play('rush',.30,d.pan||0);return;}
  const map={shot:'cast-wand',staple:'cast-staple',slingshot:'cast-swing',slipper:'cast-swing',zapper:'hit-zapper-0',death:'death-flight',freeze:'ice-crack'};
  if(map[kind]||['hurt','level','win','mother'].includes(kind))this.play(map[kind]||kind,kind==='death'?.85:kind==='shot'?.22:.52);
 }
};
