"""Register the new pose cells without changing their generated artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

project=Path(__file__).resolve().parents[1]
out={}
for kind,name,rows,standing in [(5,'vivian-specials',3,0),(2,'alex-specials',2,7),(1,'brook-specials',2,7)]:
    image=Image.open(project/'assets'/(name+'.png')).convert('RGBA')
    a=np.asarray(image)
    regions=[];anchors=[]
    for frame in range(rows*4):
        x0=round(frame%4*image.width/4);x1=round((frame%4+1)*image.width/4)
        y0=round(frame//4*image.height/rows);y1=round((frame//4+1)*image.height/rows)
        mask=a[y0:y1,x0:x1,3]>=160
        yy,xx=np.where(mask)
        assert len(xx)>1000,(name,frame,'empty pose')
        left,top,right,bottom=int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)
        regions.append([x0+left,y0+top,right-left,bottom-top])
        cropped=mask[top:bottom,left:right]
        if kind==5 and frame in [6,7,8,9]: anchor=(right-left)*.5
        elif kind==2:
            upper=np.where(cropped[:max(1,int((bottom-top)*.23))])[1]
            anchor=float(np.median(upper))
        else:
            lower=np.where(cropped[-max(4,int((bottom-top)*.04)):])[1]
            anchor=float(np.median(lower))
        anchors.append(round(anchor,2))
    out[str(kind)]={'path':'res://assets/'+name+'.png','regions':regions,'anchors':anchors,'height':regions[standing][3]}
    print(name,len(regions),'registered, base height',out[str(kind)]['height'])
(project/'data/signature-atlases.json').write_text(json.dumps(out,indent=2)+'\n')
