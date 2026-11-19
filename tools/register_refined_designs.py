"""Install generated refinements and re-register alpha bounds; preserve all pose identities."""
from pathlib import Path
import ast,base64,json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1];work=r.parent/'work'
module=ast.parse((r/'tools/register_female_atlases.py').read_text());space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
p=r/'data/female-atlases.json';data=json.loads(p.read_text())
for name,generated in [('brook-lynne','brook-refined'),('lauren','lauren-refined'),('vivian','vivian-refined'),('spike','spike-refined')]:
 e=data[name];path=r/e['path'].replace('res://','');old=Image.open(work/'art-original-reference'/path.name)
 old_regions=e['regions']+e.get('throws',[])
 path.write_bytes(base64.b64decode((work/(generated+'.base64')).read_text()))
 image=Image.open(path).convert('RGBA');alpha=np.asarray(image)[:,:,3]>=160
 blobs=space['components'](alpha)[:len(old_regions)]
 assert len(blobs)==len(old_regions) and min(x[4] for x in blobs)>500,(name,'missing poses')
 boxes=[[max(0,x-2),max(0,y-2),min(image.width,endx+2)-max(0,x-2),min(image.height,endy+2)-max(0,y-2)] for x,y,endx,endy,area in blobs]
 targets=np.array([[(x+w*.5)*image.width/old.width,(y+h*.5)*image.height/old.height] for x,y,w,h in old_regions])
 centers=np.array([[x+w*.5,y+h*.5] for x,y,w,h in boxes]);dist=((targets[:,None]-centers[None,:])**2).sum(axis=2)
 registered=[None]*len(old_regions);used=set()
 for index in np.argsort(dist,axis=None):
  i,j=np.unravel_index(index,dist.shape)
  if registered[i] is not None or j in used:continue
  assert dist[i,j]<(image.width*.18)**2,(name,i,'pose moved')
  registered[i]=boxes[j];used.add(j)
 old0=old_regions[0];new0=registered[0];portrait=e['portrait']
 e['portrait']=[round(new0[0]+(portrait[0]-old0[0])*new0[2]/old0[2]),round(new0[1]+(portrait[1]-old0[1])*new0[3]/old0[3]),round(portrait[2]*new0[2]/old0[2]),round(portrait[3]*new0[3]/old0[3])]
 e['anchors']=[round(a/old_regions[i][2]*registered[i][2],2) for i,a in enumerate(e['anchors'])]
 e['regions']=registered[:len(e['regions'])]
 if 'throws' in e:e['throws']=registered[len(e['regions']):]
 assert registered[15][2]>registered[15][3]*2,(name,'KO must lie on back')
 print(name,len(registered),'registered refined poses')
p.write_text(json.dumps(data,indent=2)+'\n')
