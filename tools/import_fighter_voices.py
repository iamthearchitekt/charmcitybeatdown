"""Import the user's final voices unchanged and split two grunts at silence."""
from pathlib import Path
import wave
import json
import shutil
import numpy as np

project=Path(__file__).resolve().parents[1]
source=project/'audio/fighter-voices/source'
dest=project/'audio/fighter-voices'
dest.mkdir(exist_ok=True)
for original,final in [('DEATH MALE FINAL.wav','final-male.wav'),('DEATH FEMALE FINAL.wav','final-female.wav'),('FEMALE TAUNT.wav','female-victory.wav')]:
    shutil.copyfile(source/original,dest/final)
for sex in ['male','female']:
    with wave.open(str(source/(sex.upper()+' GRUNTS.wav')),'rb') as w:
        params=w.getparams();raw=w.readframes(w.getnframes())
    samples=np.frombuffer(raw,dtype='<i2').reshape(-1,params.nchannels)
    for i,part in enumerate(np.array_split(samples,2)):
        active=np.flatnonzero(np.max(np.abs(part.astype(np.int32)),axis=1)>max(100,np.max(np.abs(part.astype(np.int32)))*.025))
        left=max(0,int(active[0])-int(params.framerate*.005))
        right=min(len(part),int(active[-1])+int(params.framerate*.025))
        with wave.open(str(dest/f'block-{sex}-{i+1}.wav'),'wb') as w:
            w.setparams(params);w.writeframes(part[left:right].tobytes())
        print(sex,i+1,round((right-left)/params.framerate,3),'seconds')
config_path=project/'audio/sfx-map.json'
config=json.loads(config_path.read_text())
for sex in ['male','female']:
    config['cues']['final_ko_'+sex]={'files':[f'../fighter-voices/final-{sex}.wav'],'db':-10,'group':'final_ko'}
    config['cues']['block_'+sex]={'files':[f'../fighter-voices/block-{sex}-{i}.wav' for i in [1,2]],'db':-23,'random':True}
config['cues']['female_victory']={'files':['../fighter-voices/female-victory.wav'],'db':-11,'group':'victory'}
config_path.write_text(json.dumps(config,indent=2)+'\n')
