"""Register four fire flicker cells at the projectile's existing native scale."""
from pathlib import Path
from PIL import Image
import numpy as np

assets=Path(__file__).resolve().parents[1]/'assets'
sheet=Image.open(assets/'spike-fire-source.png').convert('RGBA')
a=np.asarray(sheet)
boxes=[]
for frame in range(4):
    x0=round(frame*sheet.width/4);x1=round((frame+1)*sheet.width/4)
    yy,xx=np.where(a[:,x0:x1,3]>=160)
    boxes.append((int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)))
left=min(b[0] for b in boxes);top=min(b[1] for b in boxes)
right=max(b[2] for b in boxes);bottom=max(b[3] for b in boxes)
for frame in range(4):
    x0=round(frame*sheet.width/4)
    im=sheet.crop((x0+left,top,x0+right,bottom)).resize((46,28),Image.Resampling.LANCZOS)
    pixels=np.array(im).astype(np.float32)
    pixels[:,:,:3]=np.round(pixels[:,:,:3]/255*23)/23*255
    pixels[:,:,3]=np.where(pixels[:,:,3]>=128,255,0)
    Image.fromarray(pixels.astype('uint8')).save(assets/f'spike-fire-{frame}.png')
print('Registered four aligned orange-red fire frames')
