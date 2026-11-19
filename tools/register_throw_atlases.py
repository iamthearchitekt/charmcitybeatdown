"""Read sprite alpha and register each fighter's four throw poses."""
import ast
import json
from pathlib import Path
import numpy as np
from PIL import Image

project=Path(__file__).resolve().parents[1]
# Import only the alpha helper; never regenerate unrelated portrait framing.
module=ast.parse((project/'tools/register_female_atlases.py').read_text())
space={'np':np}
exec(compile(ast.Module(body=[n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='components'],type_ignores=[]),'<components>','exec'),space)
components=space['components']
out={}
for filename,kinds in [('throw-men.png',[0,2,6]),('throw-women.png',[1,3,4,5])]:
    image=Image.open(project/'assets'/filename).convert('RGBA')
    alpha=np.asarray(image)[:,:,3]>=160
    cells={}
    for x0,y0,x1,y1,area in components(alpha):
        if area<1500: continue
        row=min(len(kinds)-1,int((y0+y1)/2/image.height*len(kinds)))
        col=min(3,int((x0+x1)/2/image.width*4))
        if (row,col) in cells: continue
        cells[row,col]=[max(0,x0-2),max(0,y0-2),min(image.width,x1+2)-max(0,x0-2),min(image.height,y1+2)-max(0,y0-2)]
    assert len(cells)==len(kinds)*4,(filename,cells)
    for row,kind in enumerate(kinds):
        regions=[cells[row,col] for col in range(4)]
        # Grab stance is lower than standing; use a consistent per-row scale.
        # Feet form the pivot, independent of the outstretched hands.
        anchors=[]
        for x,y,w,h in regions:
            feet=np.argwhere(alpha[y+int(h*.88):min(image.height,y+h),x:x+w])
            anchors.append(round(float(np.median(feet[:,1])) if len(feet) else w*.4,2))
        out[str(kind)]={'path':'res://assets/'+filename,'regions':regions,'anchors':anchors,'height':regions[0][3]}
        print(kind,regions)
revised=json.loads((project/'data/female-atlases.json').read_text())
for kind,identity in [(2,'alex'),(6,'spike'),(7,'eric'),(8,'stan'),(9,'rachel'),(10,'jeff'),(11,'edgar-allan-poe'),(12,'orioles-mascot'),(13,'lamar-jackson')]:
    if identity not in revised: continue
    entry=revised[identity];image=Image.open(project/entry['path'].replace('res://','')).convert('RGBA')
    alpha=np.asarray(image)[:,:,3]>=160
    anchors=[]
    for x,y,w,h in entry['throws']:
        feet=np.argwhere(alpha[y+int(h*.88):min(image.height,y+h),x:x+w])
        anchors.append(round(float(np.median(feet[:,1])) if len(feet) else w*.4,2))
    out[str(kind)]={'path':entry['path'],'regions':entry['throws'],'anchors':anchors,'height':entry['throws'][0][3]}
(project/'data/throw-atlases.json').write_text(json.dumps(out,indent=2)+'\n')
