"""Register 84 generated grapple poses by alpha; never edit artwork."""
from pathlib import Path
import base64,json
import numpy as np
from PIL import Image
import ast
root=Path(__file__).resolve().parents[1];work=root.parent/'work'
module=ast.parse((root/'tools/register_female_atlases.py').read_text());space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
groups=[('a-approved',[0,1,2,3]),('b-approved',[4,5,6,7]),('c-final',[8,9,10,11]),('d-approved',[12,13])]
out={}
for name,kinds in groups:
 stem='grapple-'+name[0];path=root/'assets'/(stem+'.png')
 path.write_bytes(base64.b64decode((work/('grapple-'+name+'.base64')).read_text()))
 image=Image.open(path).convert('RGBA');alpha=np.asarray(image)[:,:,3]>=128
 for row,kind in enumerate(kinds):
  regions=[];anchors=[]
  for col in range(6):
   x0,x1=round(col*image.width/6),round((col+1)*image.width/6)
   y0,y1=round(row*image.height/len(kinds)),round((row+1)*image.height/len(kinds))
   if kind==8 and col in [0,1,5]: y1=260  # Stan's soles extend below the first row guide.
   mask=alpha[y0:y1,x0:x1]
   blobs=space['components'](mask);assert blobs,(name,row,col)
   left,top,right,bottom,area=blobs[0]
   # Tiny detached alpha specks must not define the body scale or sprite pivot.
   for l,t,r,b,n in blobs[1:]:
    if n>area*.02 and l<right+8 and r>left-8 and t<bottom+8 and b>top-8:
     left,top,right,bottom=min(left,l),min(top,t),max(right,r),max(bottom,b)
   ys,xs=np.where(mask[top:bottom,left:right]);ys+=top;xs+=left
   assert len(xs)>500,(name,row,col,'empty sprite')
   x,y=x0+int(xs.min()),y0+int(ys.min());w,h=int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)
   regions.append([x,y,w,h])
   feet=np.where(mask[max(0,int(ys.max())-5):int(ys.max())+1])[1]
   anchors.append(round(w*.5 if col in [3,4] else float(np.median(feet))-float(xs.min()),2))
  out[str(kind)]={'path':'res://assets/'+stem+'.png','regions':regions,'anchors':anchors,'height':regions[0][3]}
  print(kind,'six grapple poses',regions)
(root/'data/grapple-atlases.json').write_text(json.dumps(out,indent=2)+'\n')
