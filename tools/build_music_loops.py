"""Build sample-continuous stage loops before the source MP3s' recorded fades.

Requires ffmpeg on PATH and NumPy. Original MP3s remain unchanged.
"""
from pathlib import Path
import subprocess
import json
import numpy as np

audio = Path(__file__).resolve().parents[1] / 'audio'
destination = audio / 'loops'
destination.mkdir(exist_ok=True)
rate = 44100
report = {}
for name in ['alien-power', 'back-to-the-industry', 'go-straight', 'never-return-alive']:
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(audio/(name+'.mp3')),
                                   '-f','f32le','-ar',str(rate),'-ac','2','pipe:1'])
    samples = np.frombuffer(raw,dtype='<f4').reshape(-1,2).copy()
    window = rate // 4
    rms = np.array([np.sqrt(np.mean(samples[i:i+window]**2))
                    for i in range(0,len(samples)-window,window)])
    db = 20*np.log10(np.maximum(rms,1e-9))
    threshold = np.median(db)-3
    active = np.flatnonzero(db >= threshold)
    first, last = int(active[0]*window), int((active[-1]+1)*window)
    trimmed = samples[first:last]
    overlap = 2*rate
    # The output is rotated by the overlap duration. Its final sample leads
    # directly into its first sample in the original source waveform.
    weight = np.linspace(0,1,overlap,endpoint=False,dtype=np.float32)[:,None]
    join = trimmed[-overlap:]*(1-weight)+trimmed[:overlap]*weight
    loop = np.concatenate((trimmed[overlap:-overlap],join))
    peak = float(np.max(np.abs(loop)))
    gain = min(1.0,.98/max(peak,1e-6))
    loop *= gain
    out = destination/(name+'.ogg')
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(rate),'-ac','2',
                    '-i','pipe:0','-c:a','libvorbis','-q:a','5',str(out)],
                   input=loop.astype('<f4').tobytes(),check=True)
    report[name] = {'source_seconds':round(len(samples)/rate,3),
                    'start_seconds':round(first/rate,3),'end_seconds':round(last/rate,3),
                    'loop_seconds':round(len(loop)/rate,3),'crossfade_seconds':2,
                    'gain_db':round(20*np.log10(gain),3)}
    print(name,report[name])
(destination/'loop-points.json').write_text(json.dumps(report,indent=2)+'\n')
