'use strict';
const $=id=>document.getElementById(id);
let state=null,lastPhase='',ready=false,muted=false,audio=null,lastPart=0,toastTimer=0,lastSound={},pointer=null;
const send=(action,data={})=>{if(typeof window.godotCommand==='function')window.godotCommand(JSON.stringify({action,...data}));};
function toast(text){$('toast').textContent=text;$('toast').classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').classList.remove('show'),2100);}
const soundscape=new RoomAudio();
const deathCinematic=new DeathCinematic($('death-screen'));
const storyIntro=new StoryIntro($('story-screen'));
let enteringRoom=false;
function enterRoom(command,number){
 if(enteringRoom)return;
 enteringRoom=true;
 const curtain=$('entry-transition');
 const names=['','第一间','第二间','第三间','第四间','第五间'];
 curtain.querySelector('.entry-transition__content>span').textContent=`CHAPTER ${String(number).padStart(2,'0')} / 05`;
 const title=curtain.querySelector('strong');
 title.textContent=`${names[number]||'下一间'}\n杂物间`;
 curtain.hidden=false;
 curtain.classList.remove('play');
 void curtain.offsetWidth;
 curtain.classList.add('play');
 const quiet=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 setTimeout(()=>{command();$('canvas').focus({preventScroll:true});},quiet?0:350);
 setTimeout(()=>{curtain.hidden=true;curtain.classList.remove('play');enteringRoom=false;},quiet?180:1700);
}
function beginRun(){initAudio();enterRoom(()=>send('start'),1);}
function initAudio(){soundscape.unlock().catch(()=>{});deathCinematic.prepare();}
function sound(kind,data={}){soundscape.event(kind,data);}
window.gameEvent=function(event){const d=event.data||{};switch(event.kind){case'ready':document.title='蟑螂大作战';ready=true;window.dispatchEvent(new CustomEvent('dirty-room-game-ready'));failedLoading=false;clearTimeout(loadTimer);$('error-screen').hidden=true;$('start').disabled=false;$('start-label').textContent='进入房间';$('loading-fill').style.width='100%';$('loading-hint').textContent='找到虫母，才有机会彻底清理';break;case'toast':toast(d.text);break;case'part':if(performance.now()-lastPart>950){lastPart=performance.now();toast(d.text);}break;case'combo':$('combo-popup').textContent=d.text;$('combo-popup').classList.remove('show');void $('combo-popup').offsetWidth;$('combo-popup').classList.add('show');break;case'hurt':$('hurt').classList.remove('hit');void $('hurt').offsetWidth;$('hurt').classList.add('hit');if(navigator.vibrate)navigator.vibrate([30,20,35]);break;case'crit':$('flash').classList.remove('crit');void $('flash').offsetWidth;$('flash').classList.add('crit');break;case'sound':sound(d.kind,d);}}
function formatTime(t){return `${String(Math.floor(t/60)).padStart(2,'0')}:${String(Math.floor(t)%60).padStart(2,'0')}`;}
function textNode(tag,className,value){const e=document.createElement(tag);e.className=className;e.textContent=value;return e;}
window.receiveGameState=function(s){state=s;window.gameSnapshot=s;soundscape.setState(s);$('room').textContent=String(s.room).padStart(2,'0');$('hearts').replaceChildren(...[0,1,2].map(i=>textNode('span',i<s.life?'full':'empty',i<s.life?'●':'○')));$('timer').textContent=formatTime(s.time);$('killcount').textContent=`清除 ${s.kills}`;$('level').textContent=`LV. ${s.level}`;$('xp').style.width=`${Math.min(100,s.xp/s.need*100)}%`;$('xp-number').textContent=`${Math.floor(s.xp)} / ${Math.ceil(s.need)}`;$('objective').textContent=s.objective;$('mother-dot').classList.toggle('dead',s.mother_dead);$('alive').textContent=`剩余 ${s.alive}`;$('weapon-icon').textContent=s.weapon_icon;$('weapon-name').textContent=s.weapon_name;$('rune-summary').textContent=s.runes.length?s.runes.map(r=>`${r.name}${r.n>1?'×'+r.n:''}${r.active?'':'（未生效）'}`).join(' · '):'绕位命中部位 · 命中获得经验';$('combo-badges').replaceChildren(...s.combos.map(x=>textNode('span','',x)));$('compass').hidden=!s.compass||s.phase!=='playing';$('compass-arrow').style.transform=`rotate(${s.angle}deg)`;$('compass-text').textContent=s.cue;
 if(s.phase!==lastPhase){lastPhase=s.phase;resetStick();if(s.phase!=='dead')deathCinematic.stop();for(const [id,phase]of Object.entries({'start-screen':'start','upgrade-screen':'upgrade','pause-screen':'paused','win-screen':'win','death-screen':'dead'}))$(id).hidden=s.phase!==phase;const play=['playing','upgrade','paused'].includes(s.phase);$('hud').hidden=!play;$('loadout').hidden=!play;$('joystick').hidden=s.phase!=='playing';
 if(s.phase==='upgrade'){renderCards(s.cards);$('upgrade-cards').querySelector('button')?.focus({preventScroll:true});}
 if(s.phase==='paused'){$('pause-build').textContent=`${s.weapon_name} · 等级 ${s.level}\n`+s.runes.map(r=>`${r.name} ×${r.n}${r.active?'':'（专属武器未装备）'}`).join(' / ');$('resume').focus({preventScroll:true});}
 if(s.phase==='win'){const final=!!s.campaign_complete;$('win-screen').classList.toggle('homecoming',final);$('win-chapter').textContent=final?'BACK TO REALITY':`ROOM ${s.room} / ${s.campaign_rooms||5} CLEARED`;$('win-title').textContent=final?'你回到了现实。':'这一间，干净了。';$('win-description').textContent=final?'五间房已经清空。睁开眼，你又坐在那张熟悉的办公桌前。今晚，早点回家吧。':'虫母与剩余蟑螂已全部清除。你的武器与符文，将带进下一间房。';$('next').textContent=final?'再来一局 ↻':'推开下一扇门 ↗';$('win-stats').innerHTML=`<div>${s.kills}<small>清除蟑螂</small></div><div>${s.parts}<small>破坏部位</small></div><div>${formatTime(s.time)}<small>用时</small></div>`;$('next').focus({preventScroll:true});}
 if(s.phase==='dead'){$('death-stats').textContent=`第 ${s.room} 间 · 累计清除 ${s.total} 只 · 破坏 ${s.parts} 个部位`;deathCinematic.play();}
 }
};
function renderCards(cards){$('upgrade-cards').replaceChildren();cards.forEach((c,index)=>{const button=document.createElement('button');button.className='upgrade-card '+(c.type==='weapon'?'weapon':'rune');button.appendChild(textNode('span','card-icon',c.icon));const body=document.createElement('div');body.appendChild(textNode('div','card-type',c.type==='weapon'?'更换武器':`符文 · 第 ${c.stack} 层`));body.appendChild(textNode('div','card-name',c.name));body.appendChild(textNode('div','card-desc',c.desc));if(c.type==='weapon')body.appendChild(textNode('div','card-combo',`替换 ${state.weapon_name} · 已有符文保留`));else if(c.weapon)body.appendChild(textNode('div','card-combo',`${state.weapon_name} 专属联动`));else if(c.stack>1)body.appendChild(textNode('div','card-combo','继续叠加 · 强化现有组合'));button.appendChild(body);button.onclick=()=>send('choose',{index});$('upgrade-cards').appendChild(button);});}
$('start').onclick=()=>{if(!ready||storyIntro.active||enteringRoom)return;initAudio();if(storyIntro.seen())beginRun();else storyIntro.start(beginRun,muted);};$('replay-story').onclick=()=>storyIntro.start(()=>$('replay-story').focus({preventScroll:true}),muted);$('pause').onclick=()=>send('pause');$('resume').onclick=()=>{send('resume');$('canvas').focus({preventScroll:true});};$('next').onclick=()=>{if(state?.campaign_complete)beginRun();else enterRoom(()=>send('next'),Math.min(5,(state?.room||1)+1));};$('restart').onclick=beginRun;$('sound').onclick=()=>{muted=!muted;soundscape.setMuted(muted);$('sound').textContent='声音：'+(muted?'关闭':'开启');};
const base=$('stick-base'),stick=$('stick');let center={x:0,y:0};function moveStick(e){const x=e.clientX-center.x,y=e.clientY-center.y,len=Math.hypot(x,y),scale=Math.min(1,43/Math.max(1,len));stick.style.transform=`translate(${x*scale}px,${y*scale}px)`;send('move',{x:x*scale/43,y:y*scale/43});}function resetStick(){pointer=null;stick.style.transform='translate(0,0)';send('move',{x:0,y:0});}
base.addEventListener('pointerdown',e=>{if(state?.phase!=='playing')return;e.preventDefault();pointer=e.pointerId;base.setPointerCapture(pointer);const r=base.getBoundingClientRect();center={x:r.left+r.width/2,y:r.top+r.height/2};moveStick(e);});base.addEventListener('pointermove',e=>{if(e.pointerId===pointer)moveStick(e);});base.addEventListener('pointerup',resetStick);base.addEventListener('pointercancel',resetStick);base.addEventListener('lostpointercapture',resetStick);
window.addEventListener('keydown',e=>{if(e.code==='Escape'||e.code==='KeyP'){if(state?.phase==='playing')send('pause');else if(state?.phase==='paused')send('resume');}if(state?.phase==='upgrade'&&['Digit1','Digit2','Digit3'].includes(e.code))send('choose',{index:Number(e.code.slice(-1))-1});if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space'].includes(e.code))e.preventDefault();});document.addEventListener('visibilitychange',()=>{soundscape.hidden=document.hidden;soundscape.updateMix();if(document.hidden){resetStick();if(state?.phase==='playing')send('pause');}});window.addEventListener('blur',()=>{resetStick();if(state?.phase==='playing')send('pause');});
let loadTimer=null,failedLoading=false;
function showError(message){if(ready)return;failedLoading=true;clearTimeout(loadTimer);$('error-text').textContent=message;$('error-screen').hidden=false;$('start').disabled=true;}
function guardLoading(){clearTimeout(loadTimer);loadTimer=setTimeout(()=>showError('启动等待过久，请点击“重新进入”重试。'),120000);}
window.addEventListener('dirty-room-load-progress',event=>{
 if(ready||failedLoading)return;
 const d=event.detail;guardLoading();
 $('loading-fill').style.width=(d.downloaded?94:d.percent)+'%';
 $('loading-hint').textContent=d.downloaded?'资源已就绪，正在启动 3D 场景…':`${d.message||'正在准备资源'} · ${d.percent}%`;
});
window.addEventListener('dirty-room-load-error',event=>showError(`加载中断：${event.detail.message}。请点击“重新进入”重试。`));
window.addEventListener('unhandledrejection',event=>{if(!ready){console.error('Game startup rejected:',event.reason);showError('3D 游戏启动失败，请点击“重新进入”重试。');}});
window.addEventListener('error',event=>{if(!ready&&event.message)showError('游戏启动遇到错误，请点击“重新进入”重试。');});
const gameViewport=new GameViewport($('canvas'),$('game-shell'));
const config={args:[],canvas:$('canvas'),canvasResizePolicy:0,executable:'game',mainPack:'game.pck',focusCanvas:false,gdextensionLibs:[],fileSizes:{"game.wasm":window.engineManifest.wasmBytes,"game.pck":window.engineManifest.packBytes},onProgress:()=>{},onPrintError:(...args)=>{console.error('[Godot]',...args);if(!ready&&/SCRIPT ERROR|Parse Error|out of memory/i.test(args.join(' ')))showError('3D 场景启动失败，请点击“重新进入”重试。');}};
guardLoading();
if(typeof Engine==='undefined'){showError('游戏资源尚未加载完成，请刷新重试。');}else{
 const missing=Engine.getMissingFeatures({threads:false});
 if(missing.length){console.error('Missing engine features: '+JSON.stringify(missing));showError(missing.some(x=>x.includes('WebGL'))?'当前浏览器无法运行 WebGL 2，请在 Chrome 或 Safari 中打开试玩。':'请使用 HTTPS 试玩地址，在新版浏览器中重新打开。');}
 else{const engine=new Engine(config);window.dirtyRoomEngine=engine;engine.startGame().catch(error=>{console.error(error);showError('游戏加载中断，请检查网络后重试。');});}
}
if(document.modelContext?.registerTool){const lifecycle=new AbortController();const reg=t=>{try{Promise.resolve(document.modelContext.registerTool(t,{signal:lifecycle.signal})).catch(()=>{});}catch{}};reg({name:'read_game_state',description:'读取当前房间、武器、符文、生命、升级选择与战斗状态。',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true},execute:()=>state?structuredClone(state):{phase:'loading'}});reg({name:'pause_game',description:'暂停正在进行的战斗，与界面暂停按钮一致。',inputSchema:{type:'object',properties:{},additionalProperties:false},execute:async()=>{if(state?.phase!=='playing')throw new Error('当前没有进行中的战斗');send('pause');await new Promise(r=>setTimeout(r,200));return{phase:state.phase};}});reg({name:'choose_upgrade',description:'从当前三选一奖励中选择一项，随后恢复战斗。',inputSchema:{type:'object',properties:{index:{type:'integer',minimum:0,maximum:2}},required:['index'],additionalProperties:false},execute:async input=>{if(!Number.isInteger(input.index)||input.index<0||input.index>2||state?.phase!=='upgrade')throw new Error('必须处于升级选择界面，index 为 0、1 或 2');send('choose',{index:input.index});await new Promise(r=>setTimeout(r,200));return{phase:state.phase,weapon:state.weapon,runes:state.runes};}});window.addEventListener('pagehide',()=>lifecycle.abort(),{once:true});}
