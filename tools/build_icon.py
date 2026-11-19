"""Encode the transparent PNG artwork as a multi-resolution Windows ICO."""
from pathlib import Path
from PIL import Image

project=Path(__file__).resolve().parents[1]
source=project/'assets/game-icon.png'
target=project/'assets/charm-city-beatdown.ico'
image=Image.open(source).convert('RGBA')
assert image.getchannel('A').getextrema()[0]==0, 'Icon must have a transparent background.'
# ICO frames need square storage; transparent padding preserves the PNG's
# original freeform silhouette and aspect ratio without stretching the artwork.
if image.width!=image.height:
    edge=max(image.size)
    canvas=Image.new('RGBA',(edge,edge),(0,0,0,0))
    canvas.alpha_composite(image,((edge-image.width)//2,(edge-image.height)//2))
    image=canvas
sizes=[(n,n) for n in [16,20,24,32,40,48,64,96,128,256]]
image.save(target,format='ICO',sizes=sizes)
encoded=Image.open(target)
assert encoded.info['sizes']==set(sizes)
print('Encoded Windows icon:',target,sorted(encoded.info['sizes']))
