"""Install generated auxiliary art and map complete alpha components to original pose roles."""
from pathlib import Path
import ast,base64,json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];work=r.parent/'work'
module=ast.parse((r/'tools/register_female_atlases.py').read_text());space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
def install(name,columns,rows,indices=None):
 path=r/'assets'/(name+'.png');path.write_bytes(base64.b64decode((work/(name+'.base64')).read_text()))
 image=Image.open(path).convert('RGBA');mask=np.asarray(image)[:,:,3]>=160
 indices=list(range(columns*rows)) if indices is None else indices
 blobs=space['components'](mask)[:len(indices)]
 assert len(blobs)==len(indices) and min(b[4] for b in blobs)>500,(name,'missing poses')
 boxes=[[x,y,endx-x,endy-y] for x,y,endx,endy,area in blobs]
 targets=np.array([[((i%columns)+.5)*image.width/columns,((i//columns)+.55)*image.height/rows] for i in indices])
 centers=np.array([[x+w*.5,y+h*.5] for x,y,w,h in boxes]);dist=((targets[:,None,:]-centers[None,:,:])**2).sum(axis=2)
 registered=[None]*len(indices);used=set()
 for flat in np.argsort(dist,axis=None):
  i,j=np.unravel_index(flat,dist.shape)
  if registered[i] is not None or j in used:continue
  assert dist[i,j]<max(image.width/columns,image.height/rows)**2*.65,(name,indices[i],'pose moved')
  registered[i]=boxes[j];used.add(j)
 return 'res://assets/'+name+'.png',registered
def load(name):return json.loads((r/'data'/(name+'.json')).read_text())
def save(name,obj):(r/'data'/(name+'.json')).write_text(json.dumps(obj,indent=2)+'\n')
m=load('movement-atlases');s=load('signature-atlases');p=load('results-portraits')
path,regions=install('female-motion-refined',4,5);jumps={}
for row,k in enumerate([1,3,4,5,9]):
 cells=regions[row*4:row*4+4];height=cells[0][3]
 m[str(k)]={'path':path,'regions':cells[:2],'anchors':[round(c[2]*.5,2) for c in cells[:2]],'height':height,'projectile':False,'uniform_scale':True}
 jumps[str(k)]={'path':path,'neutral':cells[2],'punch':cells[3],'reference_height':height}
save('refined-jumps',jumps)
path,regions=install('female-signature-refined',4,5)
for start,k,count in [(0,1,8),(8,5,12)]:
 cells=regions[start:start+count];old=s[str(k)]
 anchors=[round(c[2]*(old['anchors'][i]/old['regions'][i][2]),2) for i,c in enumerate(cells)]
 s[str(k)]={'path':path,'regions':cells,'anchors':anchors,'height':cells[0][3]}
path,regions=install('female-results-refined',2,5)
for row,k in enumerate([1,3,4,5,9]):p[str(k)]={'path':path,'victory':regions[row*2],'defeat':regions[row*2+1]}
path,regions=install('spike-supplement-refined',4,2,[0,1,2,3,4,5])
m['6']={'path':path,'regions':regions[:4],'anchors':[round(c[2]*(.38 if i==3 else .5),2) for i,c in enumerate(regions[:4])],'height':regions[0][3],'projectile':True,'uniform_scale':True}
p['6']={'path':path,'victory':regions[4],'defeat':regions[5]}
save('movement-atlases',m);save('signature-atlases',s);save('results-portraits',p)
print('Registered20female motion,20signature,10result portraits and6Spike supplemental poses')
