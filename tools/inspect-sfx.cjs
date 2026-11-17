const fs=require('fs'),path=require('path');
const source=process.argv[2];
const destination=process.argv[3];
function readWav(file){
 const b=fs.readFileSync(file);let fmt,data;
 for(let i=12;i+8<=b.length;){const id=b.toString('ascii',i,i+4),n=b.readUInt32LE(i+4);if(id==='fmt ')fmt={format:b.readUInt16LE(i+8),channels:b.readUInt16LE(i+10),rate:b.readUInt32LE(i+12),bits:b.readUInt16LE(i+22)};if(id==='data')data=b.subarray(i+8,i+8+n);i+=8+n+(n%2);}
 if(!fmt||!data||fmt.format!==1)throw new Error('Unsupported WAV: '+file);
 const samples=[];const stride=fmt.bits/8*fmt.channels;
 for(let i=0;i+stride<=data.length;i+=stride){let v=0;for(let ch=0;ch<fmt.channels;ch++)v+=fmt.bits===16?data.readInt16LE(i+ch*2)/32768:(data[i+ch]-128)/128;samples.push(v/fmt.channels);}
 return {...fmt,samples};
}
const names=fs.readdirSync(source).filter(x=>x.endsWith('.wav')).sort();
let montage=[],marks=[];
for(const name of names){
 const w=readWav(path.join(source,name));let sum=0,peak=0,cross=0;
 for(let i=0;i<w.samples.length;i++){const v=w.samples[i];sum+=v*v;peak=Math.max(peak,Math.abs(v));if(i&&v*w.samples[i-1]<0)cross++;}
 const duration=w.samples.length/w.rate;const start=montage.length/22050;
 for(let i=0;i<Math.round(duration*22050);i++)montage.push(w.samples[Math.min(w.samples.length-1,Math.floor(i*w.rate/22050))]*.8);
 for(let i=0;i<22050*.45;i++)montage.push(0);
 marks.push({file:name,start:+start.toFixed(2),duration:+duration.toFixed(3),rate:w.rate,bits:w.bits,peak_db:+(20*Math.log10(peak||1e-9)).toFixed(1),rms_db:+(20*Math.log10(Math.sqrt(sum/w.samples.length)||1e-9)).toFixed(1),zero_cross_hz:Math.round(cross/duration/2)});
}
if(destination){const data=Buffer.alloc(montage.length*2);montage.forEach((v,i)=>data.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),i*2));const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(data.length+36,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(22050,24);h.writeUInt32LE(44100,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(data.length,40);fs.writeFileSync(destination,Buffer.concat([h,data]));}
console.log(JSON.stringify(marks));
