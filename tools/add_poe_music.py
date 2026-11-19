"""Prepare supplied Revenge of Mr. X as a fade-free looping graveyard track."""
from pathlib import Path
import subprocess,json
import numpy as np
root=Path(__file__).resolve().parents[1]
name='revenge-of-mr-x';rate=44100
source=root/'audio'/(name+'.mp3')
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(source),'-f','f32le','-ar',str(rate),'-ac','2','pipe:1'])
samples=np.frombuffer(raw,dtype='<f4').reshape(-1,2).copy()
window=rate//4
db=20*np.log10(np.maximum(np.array([np.sqrt(np.mean(samples[i:i+window]**2)) for i in range(0,len(samples)-window,window)]),1e-9))
active=np.flatnonzero(db>=np.median(db)-3)
first,last=int(active[0]*window),int((active[-1]+1)*window)
trimmed=samples[first:last];overlap=2*rate
weight=np.linspace(0,1,overlap,endpoint=False,dtype=np.float32)[:,None]
loop=np.concatenate((trimmed[overlap:-overlap],trimmed[-overlap:]*(1-weight)+trimmed[:overlap]*weight))
gain=min(1.,.98/max(float(np.max(np.abs(loop))),1e-6));loop*=gain
out=root/'audio/loops'/(name+'.ogg')
subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(rate),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(out)],input=loop.astype('<f4').tobytes(),check=True)
report_path=out.parent/'loop-points.json';report=json.loads(report_path.read_text())
report[name]={'source_seconds':round(len(samples)/rate,3),'start_seconds':round(first/rate,3),'end_seconds':round(last/rate,3),'loop_seconds':round(len(loop)/rate,3),'crossfade_seconds':2,'gain_db':round(20*np.log10(gain),3)}
report_path.write_text(json.dumps(report,indent=2)+'\n')
config_path=root/'data/music.json';config=json.loads(config_path.read_text());config['levels']["WESTMINSTER / POE'S GRAVE"]='res://audio/loops/'+name+'.ogg';config_path.write_text(json.dumps(config,indent=2)+'\n')
print('Poe music prepared:',report[name])
