'use strict';
const roomCinematicBase=new URL('media/',document.currentScript.src);
window.DeathCinematic=class DeathCinematic {
 constructor(root){this.root=root;this.prepared=false;this.timer=0;}
 prepare(){if(this.prepared)return;this.prepared=true;const stage=this.root.querySelector('#death-insect');stage.replaceChildren();for(const [i,name]of ['approach','flight','impact'].entries()){const image=new Image;image.src=new URL('defeat-'+name+'.png',roomCinematicBase).href;image.alt='';image.className='death-frame frame-'+i;image.decoding='async';stage.appendChild(image);}const flash=document.createElement('div');flash.className='death-impact-flash';stage.appendChild(flash);}
 play(){this.prepare();clearTimeout(this.timer);this.root.classList.remove('is-running','settled');void this.root.offsetWidth;this.root.classList.add('is-running');this.timer=setTimeout(()=>{this.root.classList.add('settled');this.root.querySelector('button')?.focus({preventScroll:true});},2900);}
 stop(){clearTimeout(this.timer);this.root.classList.remove('is-running','settled');}
};
