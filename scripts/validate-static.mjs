import {readFile,stat,readdir} from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const root=path.resolve('dist');
const manifest=JSON.parse((await readFile(path.join(root,'engine-manifest.js'),'utf8')).split('=',2)[1].trim().replace(/;$/,''));
for(const [names,size,digest] of [[manifest.parts,manifest.wasmBytes,manifest.wasmSha256],[manifest.packParts,manifest.packBytes,manifest.packSha256]]){
  const hash=createHash('sha256');let bytes=0;
  for(const name of names){const data=await readFile(path.join(root,name));hash.update(data);bytes+=data.length;}
  if(bytes!==size||hash.digest('hex')!==digest)throw new Error('Invalid release chunks');
}
for(const name of ['index.html','style.css','ui.js','viewport.js','game.js','engine-loader.js','engine-manifest.js','audio-engine.js','cinematic.js','story.js','media/story/intro.mp4','media/story/poster.jpg','media/story/office.png','media/defeat-approach.png','media/defeat-flight.png','media/defeat-impact.png']){
  if(!(await stat(path.join(root,name))).size)throw new Error('Empty required asset: '+name);
  if(name.endsWith('.js'))new vm.Script(await readFile(path.join(root,name),'utf8'),{filename:name});
}
const audio=JSON.parse(await readFile(path.join(root,'media/audio/manifest.json'),'utf8'));
for(const [name,size] of Object.entries(audio.files))if((await stat(path.join(root,'media/audio',name))).size!==size)throw new Error('Audio mismatch: '+name);
let count=0;
async function visit(dir){
  for(const entry of await readdir(dir,{withFileTypes:true})){
    const file=path.join(dir,entry.name);
    if(entry.isDirectory()){await visit(file);continue;}
    count++;if((await stat(file)).size>=25*1024*1024)throw new Error('Hosting file too large: '+file);
    if(!file.endsWith('.html'))continue;
    const html=await readFile(file,'utf8');
    if(html.includes('__CF$cv$params'))throw new Error('Transient hosting script retained: '+file);
    for(const match of html.matchAll(/(?:src|href)=["']([^"']+)["']/g)){
      let ref=match[1].split(/[?#]/)[0];if(!ref||/^[a-z][a-z\d+.-]*:/i.test(ref)||ref.startsWith('//'))continue;
      const target=ref.startsWith('/')?path.join(root,ref):path.resolve(path.dirname(file),ref);
      if(target.startsWith(root))await stat(target);
    }
  }
}
await visit(root);
console.log(JSON.stringify({files:count,packBytes:manifest.packBytes,validation:'PASS'}));
