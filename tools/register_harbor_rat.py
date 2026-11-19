"""Register the two generated rat poses on a common paw baseline."""
from pathlib import Path
from PIL import Image
import numpy as np

assets=Path(__file__).resolve().parents[1]/'assets'
sheet=Image.open(assets/'harbor-rat-source.png').convert('RGBA')
for frame,bottom in enumerate([322,679]):
    image=sheet.crop((312,bottom-303,1816,bottom+1)).resize((107,22),Image.Resampling.LANCZOS)
    a=np.array(image).astype(np.float32)
    yy,xx=np.indices(a.shape[:2])
    bayer=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])
    d=((bayer[yy%4,xx%4]+.5)/16-.5)*.8
    a[:,:,:3]=np.clip(np.round(a[:,:,:3]/255*23+d[:,:,None])/23*255,0,255)
    a[:,:,3]=np.where(a[:,:,3]>=128,255,0)
    Image.fromarray(a.astype('uint8')).save(assets/f'harbor-rat-{frame}.png')
    print('Registered rat frame',frame)
