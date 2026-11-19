"""Register the Oriole Bird's art and REL unlock, preserving existing fighters."""
import ast
import copy
import json
from pathlib import Path
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]
path=root/'data/moves.json'
data=json.loads(path.read_text())
bird=copy.deepcopy(next(f for f in data['fighters'] if f['id']=='stan'))
bird.update(id='orioles-mascot',name='ORIOLE BIRD',select_name='THE BIRD',subtitle='BIRDLAND BRAWLER',color='#f28c20',locked=True)
for move,label in [('special1','Birdland Blast'),('special2','Dugout Uppercut'),('throw','Home Plate Toss')]:
    bird['moves'][move]['name']=label
matches=[i for i,f in enumerate(data['fighters']) if f['id']==bird['id']]
if matches: data['fighters'][matches[0]]=bird
else: data['fighters'].append(bird)
path.write_text(json.dumps(data,indent=2)+'\n')

module=ast.parse((root/'tools/register_female_atlases.py').read_text())
space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
image=Image.open(root/'assets/oriole-bird-atlas.png').convert('RGBA')
cells={}
for x0,y0,x1,y1,area in space['components'](np.asarray(image)[:,:,3]>=160):
    if area<800: continue
    row=min(range(6),key=lambda r:abs(y1/image.height-[.187,.373,.523,.699,.859,.991][r]))
    col=min(3,int((x0+x1)/2/image.width*4)); index=row*4+col
    if index>=22 or index in cells: continue
    x=max(0,x0-2); y=max(0,y0-2)
    cells[index]=[x,y,min(image.width,x1+2)-x,min(image.height,y1+2)-y]
assert len(cells)==22,cells
regions=[cells[i] for i in range(22)]
assert regions[15][2]>regions[15][3]*2,'Bird KO must lie horizontally on his back'
ratios=[115/231,91/183,82/191,100/221,100/262,100/291,72/256,88/282,82/167,90/249,93/321,79/283,92/195,115/245,85/177,.5]
path=root/'data/female-atlases.json'; atlases=json.loads(path.read_text())
x,y,w,h=regions[0]
size=round(w*.76)
atlases['orioles-mascot']={'path':'res://assets/oriole-bird-atlas.png','regions':regions[:18],
    'anchors':[round((ratios[i] if i<16 else .5)*r[2],2) for i,r in enumerate(regions[:18])],
    'portrait':[round(x+w*.16),max(0,y-3),size,size],'throws':regions[18:]}
path.write_text(json.dumps(atlases,indent=2)+'\n')
path=root/'data/character-unlocks.json'; registry=json.loads(path.read_text())
registry['deferred_characters']=[identity for identity in registry['deferred_characters'] if identity!=bird['id']]
registry['character_names'][bird['id']]='ORIOLE BIRD'
path.write_text(json.dumps(registry,indent=2)+'\n')
print('Oriole Bird registered: REL unlock; 18 regular poses and 4 throw poses')
