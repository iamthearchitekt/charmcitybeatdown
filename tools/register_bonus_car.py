"""Register four subtly angled car states with a common wheel baseline.

Asset registration only: angled art is bonus-car-angle-source.png; original is preserved.
"""
from pathlib import Path
from PIL import Image
import numpy as np

assets = Path(__file__).resolve().parents[1] / 'assets'
sheet = Image.open(assets / 'bonus-car-angle-source.png').convert('RGBA')
# Each state uses the same source width and 360-pixel canvas in a 384-pixel cell.
# Do not independently fit each state's changing silhouette.
baselines = [374, 758, 1142, 1526]
for frame, bottom in enumerate(baselines):
    image = sheet.crop((204, bottom - 358, 816, bottom + 2))
    # Match the fighter renderer's fine 0.9-unit raster and 23-step palette.
    image = image.resize((462, 289), Image.Resampling.LANCZOS)
    a = np.array(image).astype(np.float32)
    bayer = np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])
    yy, xx = np.indices(a.shape[:2])
    d = ((bayer[yy % 4, xx % 4] + .5) / 16 - .5) * .8
    a[:,:,:3] = np.clip(np.round(a[:,:,:3] / 255 * 23 + d[:,:,None]) / 23 * 255, 0, 255)
    a[:,:,3] = np.where(a[:,:,3] >= 128, 255, 0)
    Image.fromarray(a.astype('uint8')).save(assets / f'bonus-car-{frame}.png')
    print(f'Car frame {frame}: {image.size}, common aligned canvas')
