"""Register the authored elemental animation sheets and classic special move data."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def read(path): return json.loads((ROOT/path).read_text())
def write(path,data): (ROOT/path).write_text(json.dumps(data,indent=2)+'\n')
entries=read('data/signature-atlases.json')
for kind,name,height,centers in [(6,'spike-shock',669,[271,826,1369,1901]),(4,'chelsea-flame',643,[272,789,1341,1908])]:
    im=Image.open(ROOT/'assets'/f'{name}.png').convert('RGBA')
    regions=[];anchors=[]
    for i in range(4):
        left=i*im.width//4;right=(i+1)*im.width//4
        box=im.crop((left,0,right,im.height)).getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
        x,y,r,b=box;regions.append([left+x,y,r-x,b-y]);anchors.append(centers[i]-left-x)
    entries[str(kind)]={'path':f'res://assets/{name}.png','regions':regions,'anchors':anchors,'height':height}
write('data/signature-atlases.json',entries)
moves=read('data/moves.json')
moves['fighters'][6]['moves']['special3']={'name':'Live Wire','input':'qcb_punch','animation':'spike-shock','element':'electric','startup':8,'active':36,'recovery':22,'damage':48,'hitstun':15,'blockstun':9,'pushback':8,'hitstop':4,'level':'mid','box':[-53,-168,106,164],'element_area':[[-42,-168,84,28],[-53,-140,106,100],[-45,-40,90,36]],'rehit_interval':12,'chip':2,'dizzy':12,'cancel_start':0,'cancel_end':0,'cancels':[]}
moves['fighters'][4]['moves']['special1']={'name':'Flash Fire','animation':'chelsea-flame','element':'fire','startup':14,'active':18,'recovery':25,'damage':140,'hitstun':22,'blockstun':13,'pushback':26,'hitstop':6,'level':'mid','box':[38,-146,108,70],'element_area':[[38,-126,30,25],[68,-138,38,50],[106,-146,40,70]],'knockdown':True,'launch_speed':12.5,'knockback_speed':8.0,'down_frames':22,'rise_frames':14,'chip':7,'cancel_start':0,'cancel_end':0,'cancels':[]}
write('data/moves.json',moves)
audio=read('audio/sfx-map.json')
audio['cues'].update({'electric':{'files':['5B_zap_1.wav'],'db':-18,'min_interval_ms':90},'electric_hit':{'files':['5C_zap_2.wav'],'db':-20,'min_interval_ms':70},'flame':{'files':['5D_whoosh_2.wav'],'db':-16},'flame_hit':{'files':['5E_zap_3.wav'],'db':-19}})
write('audio/sfx-map.json',audio)
print('Registered four new frames per fighter, two elemental moves, and four sound cues.')
