"""Register Poe's art and unlockable kit without rewriting existing fighters."""
import ast
import copy
import json
from pathlib import Path
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]
path=root/'data/moves.json'
data=json.loads(path.read_text())
poe=copy.deepcopy(next(f for f in data['fighters'] if f['id']=='marcus'))
poe.update(id='edgar-allan-poe',name='EDGAR ALLAN POE',select_name='POE',subtitle='THE RAVEN',color='#b8bfd2',speed=6.0,locked=True)
for move,label in [('special1','Nevermore'),('special2','The Raven Rises'),('throw','The Final Chapter')]:
    poe['moves'][move]['name']=label
poe['moves']['special1']['projectile_skin']='violet'
matches=[i for i,f in enumerate(data['fighters']) if f['id']==poe['id']]
if matches: data['fighters'][matches[0]]=poe
else: data['fighters'].append(poe)
path.write_text(json.dumps(data,indent=2)+'\n')

# Reuse the existing alpha-connected run registrar, without executing its main.
module=ast.parse((root/'tools/register_female_atlases.py').read_text())
space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
image=Image.open(root/'assets/poe-atlas.png').convert('RGBA')
cells={}
for x0,y0,x1,y1,area in space['components'](np.asarray(image)[:,:,3]>=160):
    if area<800: continue
    row=min(range(6),key=lambda r:abs(y1/image.height-[.187,.373,.523,.699,.859,.991][r]))
    col=min(3,int((x0+x1)/2/image.width*4)); index=row*4+col
    if index>=22 or index in cells: continue
    x=max(0,x0-2);y=max(0,y0-2)
    cells[index]=[x,y,min(image.width,x1+2)-x,min(image.height,y1+2)-y]
assert len(cells)==22,cells
regions=[cells[i] for i in range(22)]
assert regions[15][2]>regions[15][3]*2,'Poe KO must be horizontal on his back'
ratios=[115/231,91/183,82/191,100/221,100/262,100/291,72/256,88/282,82/167,90/249,93/321,79/283,92/195,115/245,85/177,.5]
path=root/'data/female-atlases.json'; atlases=json.loads(path.read_text())
x,y,w,h=regions[0]
atlases['edgar-allan-poe']={'path':'res://assets/poe-atlas.png','regions':regions[:18],
    'anchors':[round((ratios[i] if i<16 else .5)*r[2],2) for i,r in enumerate(regions[:18])],
    'portrait':[round(x+w*.24),max(0,y-3),round(w*.64),round(w*.64)],'throws':regions[18:]}
path.write_text(json.dumps(atlases,indent=2)+'\n')
path=root/'data/character-unlocks.json'; registry=json.loads(path.read_text())
registry['deferred_characters']=[identity for identity in registry['deferred_characters'] if identity!=poe['id']]
path.write_text(json.dumps(registry,indent=2)+'\n')
print('Poe registered: locked behind POE, 18 regular poses and 4 throw poses')
