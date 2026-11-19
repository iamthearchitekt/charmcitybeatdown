"""Bake deterministic collision geometry from final sprite alpha, never from RGB/dither.

Run tools/export_collision_art.gd first. Rectangles use fighter-local game units,
before FIGHTER_SCALE. The same pose selector/anchors are used at runtime.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT.parent/'work/collision-art'
meta=json.loads((ART/'metadata.json').read_text())
moves=json.loads((ROOT/'data/moves.json').read_text())['fighters']
UNIT=.9

def runs(row):
    edges=np.diff(np.r_[False,row,False].astype(int))
    return list(zip(np.where(edges==1)[0],np.where(edges==-1)[0]))

def rectangles(mask,anchor,gap):
    # Four native-pixel horizontal strips preserve the holes around separated limbs.
    # Require half of each strip to be occupied: this excludes stray outline pixels.
    boxes=[]
    h,w=mask.shape
    for y in range(0,h,4):
        band=mask[y:min(y+4,h)].mean(axis=0)>=.5
        for x,end in runs(band):
            if end-x<3: continue
            box=[round(x*UNIT-anchor,3),round((y-h)*UNIT+gap,3),round((end-x)*UNIT,3),round(min(4,h-y)*UNIT,3)]
            # Merge identical adjacent spans without replacing holes by a convex hull.
            previous=next((b for b in reversed(boxes) if b[0]==box[0] and b[2]==box[2] and abs(b[1]+b[3]-box[1])<.01),None)
            if previous: previous[3]=round(previous[3]+box[3],3)
            else: boxes.append(box)
    return boxes

def component(mask,seed):
    result=np.zeros_like(mask);stack=[seed]
    while stack:
        y,x=stack.pop()
        if y<0 or x<0 or y>=mask.shape[0] or x>=mask.shape[1] or result[y,x] or not mask[y,x]: continue
        result[y,x]=True
        stack.extend(((y-1,x),(y+1,x),(y,x-1),(y,x+1)))
    return result

def attack_mask(mask,entry,name,move,key):
    h,w=mask.shape;yy,xx=np.indices(mask.shape)
    lx=xx*UNIT-entry['anchor']
    # Throws are intentional grab volumes, authored in move data (not striking limbs).
    if name=='throw' or move.get('projectile') or move.get('element_area'): return np.zeros_like(mask)
    if move.get('strike_band'):
        bounds=move['strike_band']
        bands=bounds if isinstance(bounds[0],list) else [bounds]
        region=np.zeros_like(mask)
        ly=(yy-h)*UNIT+entry['ground_gap']
        for x,y,w,h in bands:
            region|=(lx>=x)&(lx<x+w)&(ly>=y)&(ly<y+h)
        return mask & region
    punches=name in ('lp','hp','c_lp','c_hp','air_lp','air_hp','special1')
    if name=='special2':
        candidates=mask & (lx>8) & (yy<h*.60)
        if not candidates.any(): return candidates
        top=np.where(candidates)[0].min()
        # Upper fist and forearm. Exclude the head/torso and the lifted knee.
        region=candidates & (yy<=top+max(22,int(h*.26)))
        seed=tuple(np.argwhere(region)[0])
        return component(region,seed)
    if key.startswith('signature:'):
        # Spinning/flurry poses can extend to either side; only distal limbs strike.
        # Below the head and above standing soles excludes hair and supporting feet.
        region=mask & (yy>h*.18) & (yy<h*.90)
        occupied=np.where(region)
        if not len(occupied[0]): return region
        far=max(abs(float(lx[occupied].min())),abs(float(lx[occupied].max())))
        return region & (abs(lx)>max(20,far*.56))
    candidates=mask & (yy<h*.73) if punches else mask.copy()
    if not candidates.any(): return candidates
    right=np.where(candidates)[1].max()
    # Find the actual hand/boot at the outer tip, then follow its contiguous distal limb.
    tip=candidates & (xx>=right-2)
    ys=np.where(tip)[0];tip_y=int(np.median(ys))
    actual_y=int(ys[np.argmin(abs(ys-tip_y))])
    actual_x=int(np.where(tip[actual_y])[0][-1])
    extent=right*UNIT-entry['anchor']
    # The elevated kick strikes with the shin/boot. Its proximal thigh should
    # not clip the top of a crouching opponent's hair at point-blank range.
    distal=.52 if name=='hk' else .46
    region=candidates & (lx>=max(14,extent*distal))
    return component(region,(actual_y,actual_x))

profiles={};count=0
for kind,poses in meta.items():
    result={}
    for key,entry in poses.items():
        alpha=np.array(Image.open(ART/entry['file']).convert('RGBA'))[:,:,3]>=128
        # One native-pixel erosion gives forgiveness at outlines; small hands remain intact.
        padded=np.pad(alpha,1)
        inset=alpha & padded[1:-1,:-2] & padded[1:-1,2:] & padded[:-2,1:-1] & padded[2:,1:-1]
        hurt=rectangles(inset,entry['anchor'],entry['ground_gap'])
        attacks={}
        for name,move in moves[int(kind)]['moves'].items():
            strike=attack_mask(alpha,entry,name,move,key)
            if strike.any(): attacks[name]=rectangles(strike,entry['anchor'],entry['ground_gap'])
        result[key]={'hurt':hurt,'attacks':attacks,'size':entry['size'],'anchor':entry['anchor'],'ground_gap':entry['ground_gap']}
        count+=1
    profiles[kind]=result
out={'schema':1,'pixel_unit':UNIT,'description':'Final rendered sprite alpha; inset body strips and distal striking limbs. Rebuild with tools/export_collision_art.gd then tools/bake_collision.py.','fighters':profiles}
(ROOT/'data/collision-profiles.json').write_text(json.dumps(out,separators=(',',':')))
print(f'Baked {count} poses for {len(profiles)} fighters')

# Review sheet: green hurt regions/red active limbs; source image is not changed.
selected=[('lp','base:4'),('hp','base:5'),('lk','base:6'),('hk','base:7'),('c_lp','base:9'),('c_hk','base:10'),('air_hp','base:17'),('special2','base:14')]
for group in range(4):
    kinds=list(range(group*4,min(group*4+4,14)))
    sheet=Image.new('RGB',(8*245,len(kinds)*245),(35,38,45));draw=ImageDraw.Draw(sheet)
    for row,kind in enumerate(kinds):
        for col,(name,key) in enumerate(selected):
            e=meta[str(kind)][key];profile=profiles[str(kind)][key]
            im=Image.open(ART/e['file']);im=im.resize(tuple(round(x) for x in e['size']))
            x=col*245+67;y=row*245+225
            sheet.paste(im,(round(x-e['anchor']),round(y-e['size'][1]+e['ground_gap'])),im)
            for rect in profile['hurt']:
                a,b,c,d=rect;draw.rectangle((x+a,y+b,x+a+c,y+b+d),outline=(45,145,90))
            for rect in profile['attacks'].get(name,[]):
                a,b,c,d=rect;draw.rectangle((x+a,y+b,x+a+c,y+b+d),outline=(255,55,55))
            draw.text((col*245+4,row*245+4),f'{kind} {name}',fill='white')
    sheet.save(ROOT.parent/f'work/hitbox-review-{group}.png')
