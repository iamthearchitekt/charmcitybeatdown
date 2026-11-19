"""Install reviewed generated sprites; register regions without repainting pixels.

The immutable metadata snapshot makes repeat registration deterministic.
"""
from pathlib import Path
import ast,base64,json,shutil
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[1]; W=R.parent/'work'
B=R/'tools/art-registration-baseline';B.mkdir(exist_ok=True)
names=['female-atlases','movement-atlases','refined-jumps','signature-atlases','results-portraits','grapple-atlases']
for name in names:
 p=R/'data'/(name+'.json')
 if not (B/p.name).exists():
  snapshot=W/'slender-pass-before'/p.name
  shutil.copy2(snapshot if snapshot.exists() else p,B/p.name)
data={name:json.loads((B/(name+'.json')).read_text()) for name in names}
module=ast.parse((R/'tools/register_female_atlases.py').read_text());scope={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),scope)

def install(name,targets):
 path=R/'assets'/(name+'.png')
 staged=W/(name+'.base64')
 if staged.exists():path.write_bytes(base64.b64decode(staged.read_text()))
 assert path.exists(),(name,'generated source PNG missing')
 image=Image.open(path).convert('RGBA'); mask=np.asarray(image)[:,:,3]>=160
 blobs=scope['components'](mask)[:len(targets)]
 assert len(blobs)==len(targets) and min(b[4] for b in blobs)>500,(name,'incomplete figures')
 boxes=[[x,y,x1-x,y1-y] for x,y,x1,y1,n in blobs]
 target=np.array(targets)*[image.width,image.height]
 center=np.array([[x+w/2,y+h/2] for x,y,w,h in boxes]);dist=((target[:,None]-center[None,:])**2).sum(axis=2)
 ordered=[None]*len(targets);used=set()
 for flat in np.argsort(dist,axis=None):
  i,j=np.unravel_index(flat,dist.shape)
  if ordered[i] is not None or j in used:continue
  assert dist[i,j]<max(image.size)**2*.04,(name,i,'unexpected movement')
  ordered[i]=boxes[j];used.add(j)
 print(name,len(ordered),'registered')
 return 'res://assets/'+path.name,ordered

def grid(cols,rows):return [[(i%cols+.5)/cols,(i//cols+.55)/rows] for i in range(cols*rows)]

for identity,name in [('brook-lynne','brook-slender-final'),('vivian','vivian-slender-final')]:
 e=data['female-atlases'][identity];old=e['regions'];im=Image.open(R/e['path'].replace('res://',''))
 targets=[[(x+w/2)/im.width,(y+h/2)/im.height] for x,y,w,h in old]
 path,regions=install(name,targets)
 a,b=old[0],regions[0];p=e['portrait']
 e['portrait']=[round(b[0]+(p[0]-a[0])*b[2]/a[2]),round(b[1]+(p[1]-a[1])*b[3]/a[3]),round(p[2]*b[2]/a[2]),round(p[3]*b[3]/a[3])]
 e['anchors']=[round(anchor*regions[i][2]/old[i][2],2) for i,anchor in enumerate(e['anchors'])]
 e['regions']=regions;e['path']=path

path,regions=install('female-motion-slender',grid(4,5))
for row,kind in enumerate([1,3,4,5,9]):
 cells=regions[row*4:row*4+4];old=data['movement-atlases'][str(kind)]
 data['movement-atlases'][str(kind)]={'path':path,'regions':cells[:2],'anchors':[round(c[2]*old['anchors'][i]/old['regions'][i][2],2) for i,c in enumerate(cells[:2])],'height':cells[0][3],'projectile':False,'uniform_scale':True}
 data['refined-jumps'][str(kind)]={'path':path,'neutral':cells[2],'punch':cells[3],'reference_height':cells[0][3]}

path,regions=install('brook-vivian-motion-final',grid(4,2))
for row,kind in enumerate([1,5]):
 cells=regions[row*4:row*4+4];old=data['movement-atlases'][str(kind)]
 data['movement-atlases'][str(kind)]={'path':path,'regions':cells[:2],'anchors':[round(c[2]*old['anchors'][i]/old['regions'][i][2],2) for i,c in enumerate(cells[:2])],'height':cells[0][3],'projectile':False,'uniform_scale':True}
 data['refined-jumps'][str(kind)]={'path':path,'neutral':cells[2],'punch':cells[3],'reference_height':cells[0][3]}

path,regions=install('female-signature-slender',grid(4,5))
for start,kind,count in [(0,1,8),(8,5,12)]:
 cells=regions[start:start+count];old=data['signature-atlases'][str(kind)]
 data['signature-atlases'][str(kind)]={'path':path,'regions':cells,'anchors':[round(c[2]*old['anchors'][i]/old['regions'][i][2],2) for i,c in enumerate(cells)],'height':cells[0][3]}

path,regions=install('brook-results-slender',[[.25,.67],[.75,.67]])
data['results-portraits']['1']={'path':path,'victory':regions[0],'defeat':regions[1]}

for kind,name in [(1,'grapple-brook-slender'),(3,'grapple-lauren-final'),(4,'grapple-chelsea-final'),(5,'grapple-vivian-slender'),(6,'grapple-spike-corrected')]:
 path,regions=install(name,grid(3,2))
 data['grapple-atlases'][str(kind)]={'path':path,'regions':regions,'anchors':[round(c[2]*.5,2) for c in regions],'height':regions[0][3]}

for name,obj in data.items():(R/'data'/(name+'.json')).write_text(json.dumps(obj,indent=2)+'\n')
print('Main male atlases and their regions unchanged. Female and requested Spike supplemental corrections installed.')
