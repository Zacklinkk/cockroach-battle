'use strict';
// Playback never advances the Godot simulation; the engine stays on its title screen.
class StoryIntro {
  constructor(root) {
    this.root=root;
    this.video=root.querySelector('video');
    this.resume=root.querySelector('[data-story-resume]');
    this.progress=root.querySelector('[data-story-progress]');
    this.status=root.querySelector('[data-story-status]');
    this.active=false;
    this.done=null;
    root.querySelector('[data-story-skip]').onclick=()=>this.finish();
    this.resume.onclick=()=>this.play();
    this.video.addEventListener('ended',()=>this.finish());
    this.video.addEventListener('error',()=>this.finish());
    this.video.addEventListener('timeupdate',()=>{
      const fraction=this.video.duration?this.video.currentTime/this.video.duration:0;
      this.progress.style.width=`${Math.min(100,fraction*100)}%`;
    });
    this.video.addEventListener('playing',()=>{
      clearTimeout(this.waitTimer);this.resume.hidden=true;this.status.textContent='';
    });
    this.video.addEventListener('waiting',()=>this.waiting());
    document.addEventListener('visibilitychange',()=>{
      if(this.active&&document.hidden){this.video.pause();this.resume.hidden=false;}
    });
    root.addEventListener('keydown',e=>{
      if(e.key==='Escape'&&this.active){e.preventDefault();this.finish();}
    });
  }
  seen(){try{return localStorage.getItem('cockroach-battle-story-v1')==='seen';}catch{return false;}}
  remember(){try{localStorage.setItem('cockroach-battle-story-v1','seen');}catch{}}
  start(done,muted=false){
    if(this.active)return;
    this.active=true;this.done=done;this.root.hidden=false;
    this.video.currentTime=0;this.video.muted=muted;this.progress.style.width='0%';
    this.root.querySelector('[data-story-skip]').focus({preventScroll:true});
    this.play();
  }
  waiting(){
    clearTimeout(this.waitTimer);
    this.status.textContent='故事正在加载，可随时跳过';
    this.waitTimer=setTimeout(()=>{
      if(this.active){this.resume.hidden=false;this.status.textContent='加载较慢，可重试播放或直接跳过';}
    },8000);
  }
  play(){
    if(!this.active)return;
    this.resume.hidden=true;this.waiting();
    try{Promise.resolve(this.video.play()).catch(()=>{
      if(this.active){clearTimeout(this.waitTimer);this.resume.hidden=false;this.status.textContent='轻点播放故事，或跳过开始';}
    });}catch{this.finish();}
  }
  finish(){
    if(!this.active)return;
    this.active=false;clearTimeout(this.waitTimer);this.video.pause();this.root.hidden=true;
    this.remember();const done=this.done;this.done=null;done?.();
  }
}
window.StoryIntro=StoryIntro;
