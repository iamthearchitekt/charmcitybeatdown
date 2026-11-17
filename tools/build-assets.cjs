// Original move tables and synthesized music. No downloaded or sampled artwork/audio.
const fs = require('fs'), path = require('path');
const root=path.resolve(__dirname,'..');
for(const dir of ['data','audio'])fs.mkdirSync(path.join(root,dir),{recursive:true});
function move(name,startup,active,recovery,damage,level,box,extra={}){
 const m={name,startup,active,recovery,damage,hitstun:damage<70?18:25,blockstun:damage<70?10:16,pushback:damage<70?17:30,hitstop:damage<70?6:10,level,box,cancel_start:startup,cancel_end:startup+active+7,cancels:[],...extra};
 m.startup=Math.max(3,Math.round(m.startup*.8));
 m.recovery=Math.max(6,Math.round(m.recovery*.74));
 m.hitstun=Math.max(14,Math.round(m.hitstun*.88));
 m.blockstun=Math.max(5,Math.round(m.blockstun*.65));
 m.hitstop=damage<70?3:5;
 m.cancel_start=m.startup;
 m.cancel_end=m.startup+m.active+6;
 return m;
}
function normals(fast){
 const s=fast?-1:0;
 const m={
 lp:move('Pier Jab',5+s,3,10,45,'mid',[20,-132,67,34],{cancels:['hp','lk','special1','special2']}),
 hp:move('Iron Cross',10+s,4,18,100,'mid',[20,-135,92,44],{cancels:['special1','special2']}),
 lk:move('Check Kick',7+s,4,12,60,'mid',[20,-83,91,35],{cancels:['hk','special1','special2']}),
 hk:move('Harbor Heel',14+s,5,22,130,'overhead',[20,-146,121,90]),
 c_lp:move('Low Jab',5+s,3,10,40,'mid',[20,-74,68,29],{cancels:['c_hp','c_lk','special1','special2']}),
 c_hp:move('Dock Upper',10+s,5,19,105,'mid',[10,-156,65,106],{launch:true,cancels:['special2']}),
 c_lk:move('Ankle Check',7+s,4,13,55,'low',[17,-33,92,29],{cancels:['c_hk','special1','special2']}),
 c_hk:move('Brick Sweep',13+s,5,24,120,'low',[12,-36,126,32],{hitstun:34}),
 air_lp:move('Air Jab',5,5,12,50,'overhead',[15,-123,70,44]),
 air_hp:move('Falling Hammer',9,7,17,105,'overhead',[12,-117,83,63]),
 air_lk:move('Jump Check',6,7,13,65,'overhead',[13,-82,99,49]),
 air_hk:move('Skyline Kick',10,9,20,120,'overhead',[12,-94,121,61]),
 throw:move('Mooring Toss',5,2,30,155,'throw',[0,-130,67,130],{hitstun:38,pushback:65,launch:true})};
 if(fast){m.hp.name='Alley Cross';m.hk.name='Neon Axe';m.throw.name='Switchback';}
 return m;
}
const a=normals(false),b=normals(true);
a.special1=move('Harbor Current',14,1,27,110,'mid',[0,-110,20,30],{projectile:true,chip:10,pushback:30});
a.special2=move('Breakwater Rise',6,13,30,160,'mid',[-12,-192,92,145],{rise:true,launch:true,chip:12,pushback:40});
b.special1=move('Pratt Street Rush',8,13,23,120,'mid',[18,-135,88,61],{travel:7,chip:8,cancels:['special2'],cancel_start:8,cancel_end:25});
b.special2=move('Redline Vault',12,10,26,145,'overhead',[10,-145,104,115],{rise:true,travel:4,launch:true,chip:10});
fs.writeFileSync(path.join(root,'data/moves.json'),JSON.stringify({fighters:[
 {id:'breakwater',name:'BREAKWATER',subtitle:'THE DOCKYARD SENTINEL',speed:5.2,color:'#61d8ee',finisher:'DEEP SIX',moves:a},
 {id:'redline',name:'REDLINE',subtitle:'THE PRATT STREET PHANTOM',speed:6.0,color:'#ff615d',finisher:'LAST CALL',moves:b}
]},null,2));
const sr=22050;let seed=8023;function rand(){seed=(seed*1664525+1013904223)>>>0;return seed/4294967296*2-1;}
function wav(name,samples,loop=false){
const bytes=Buffer.alloc(samples.length*2);samples.forEach((v,i)=>bytes.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),i*2));
const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(36+bytes.length,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(sr,24);h.writeUInt32LE(sr*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(bytes.length,40);
fs.writeFileSync(path.join(root,'audio',name+'.wav'),Buffer.concat([h,bytes]));
}
const bpm=132,step=60/bpm/4,seconds=step*128,n=Math.round(seconds*sr),music=new Float32Array(n);
const bass=[36,36,36,43,36,36,34,39,36,36,43,46,34,34,31,34];
for(let i=0;i<n;i++){
const t=i/sr,idx=Math.floor(t/step),q=(t-idx*step),bar=idx%16;
let v=0;
if([0,6,10,11].includes(bar)){v+=Math.sin(2*Math.PI*(48*q+9*(1-Math.exp(-q*35))))*Math.exp(-q*22)*.62;}
if([4,12].includes(bar)){v+=(rand()*.65+Math.sin(2*Math.PI*177*q)*.35)*Math.exp(-q*23)*.45;}
if([3,7,15].includes(bar)){v+=rand()*Math.exp(-q*55)*.09;}
v+=(rand()*.35+Math.sin(2*Math.PI*6173*q)*.25+Math.sin(2*Math.PI*8461*q)*.25)*Math.exp(-q*90)*([2,6,10,14].includes(bar)?.13:.065);
const note=bass[Math.floor(idx/2)%16],freq=440*Math.pow(2,(note-69)/12),env=Math.exp(-q*6);
v+=(Math.sin(2*Math.PI*freq*t)*.22+Math.sin(2*Math.PI*freq*2*t)*.065)*env;
if(idx%4===3)v+=Math.sin(2*Math.PI*freq*8*t)*Math.exp(-q*33)*.06;
v+=Math.sin(2*Math.PI*146.83*t)*.015+Math.sin(2*Math.PI*220*t)*.012;
const fade=Math.min(1,t/.015,(seconds-t)/.02);music[i]=Math.tanh(v*1.3)*.76*fade;
}
wav('harbor-afterhours',music);
for(const name of ['hit','block','heavy','ko','select','finisher']){
const dur=name==='finisher'?1.8:name==='ko'?.7:.16;
const arr=new Float32Array(Math.floor(sr*dur));
for(let i=0;i<arr.length;i++){
const t=i/sr;let v=0;
if(name==='block')v=(Math.sin(2*Math.PI*933*t)+Math.sin(2*Math.PI*1477*t))*.22*Math.exp(-t*30);
else if(name==='select')v=Math.sin(2*Math.PI*660*t)*.18*Math.exp(-t*25);
else v=(rand()*.5+Math.sin(2*Math.PI*(name==='heavy'?64:94)*t)*.5)*Math.exp(-t*(name==='finisher'?3:name==='ko'?7:24))*.7;
arr[i]=v;
}wav(name,arr);
}
console.log('Generated editable move data and seven original audio files.');
