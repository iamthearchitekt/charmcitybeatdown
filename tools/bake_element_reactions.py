"""Bake original pixel effects from the rendered reaction poses.

Export collision art in Godot first, then run with Pillow and NumPy installed.
Landmarks use percentages of each pose's opaque bounds.
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter


PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT.parent / 'work' / 'collision-art'
MARGIN = 26
PIXEL = 0.9
FIRE = ('#4b141c', '#862019', '#c7351c', '#ed5018', '#ff801d', '#ffb22c', '#ffe574', '#fff3b5')
# Head, neck, shoulders, elbows, hands, rib center, pelvis, hips, knees,
# ankles and toes. Each pair is ordered near limb, then far limb.
RIGS = [
    [(21,10),(32,20),(20,27),(48,27),(22,40),(63,35),(37,47),(76,28),(43,38),(51,52),(44,57),(62,56),(34,69),(76,68),(16,91),(81,90),(9,97),(94,96)],
    [(31,11),(39,21),(35,26),(51,26),(34,42),(60,34),(39,54),(71,34),(46,36),(56,49),(52,53),(64,52),(61,69),(73,63),(71,86),(83,74),(77,96),(92,82)],
    [(22,11),(29,22),(22,32),(53,30),(17,47),(68,37),(23,57),(84,34),(45,40),(55,54),(45,57),(67,57),(38,72),(81,66),(21,89),(84,88),(22,96),(95,94)],
    [(18,10),(26,20),(22,29),(42,30),(22,43),(50,35),(24,54),(63,33),(37,37),(49,49),(46,54),(59,52),(55,67),(72,61),(64,86),(81,79),(74,96),(89,84)],
    [(30,10),(37,18),(29,27),(49,22),(25,38),(61,28),(27,46),(75,22),(46,32),(57,45),(51,51),(64,50),(42,69),(76,64),(28,89),(81,89),(22,96),(88,95)],
    [(27,11),(35,20),(31,29),(53,27),(26,40),(61,34),(27,47),(75,31),(47,36),(55,49),(46,52),(66,51),(49,68),(76,69),(36,88),(84,88),(30,97),(97,96)],
    [(19,10),(30,20),(21,29),(56,28),(17,47),(69,30),(22,58),(82,28),(45,37),(55,53),(46,58),(66,56),(48,72),(81,67),(30,90),(67,90),(38,97),(74,97)],
    [(26,12),(36,21),(23,30),(55,30),(18,43),(71,38),(26,57),(86,33),(46,41),(56,56),(50,61),(68,59),(46,74),(82,77),(26,89),(80,91),(34,96),(96,96)],
    [(21,10),(36,21),(26,30),(55,28),(20,43),(69,33),(24,56),(83,28),(48,40),(56,54),(49,60),(67,57),(49,73),(77,75),(34,91),(81,90),(33,96),(95,96)],
    [(20,10),(26,20),(22,29),(46,28),(22,44),(54,34),(30,55),(66,27),(36,37),(47,51),(44,54),(56,51),(58,69),(70,64),(66,87),(82,77),(74,97),(92,84)],
    [(20,10),(33,20),(23,29),(53,29),(22,43),(68,34),(28,55),(84,29),(46,40),(59,52),(49,57),(69,55),(55,74),(78,66),(32,89),(78,89),(37,96),(93,96)],
    [(21,10),(32,20),(23,29),(54,26),(22,44),(73,32),(28,55),(88,26),(45,39),(57,53),(49,58),(67,56),(56,73),(77,66),(34,89),(75,89),(41,96),(93,97)],
    [(27,14),(37,26),(23,30),(54,31),(16,41),(68,38),(18,56),(84,33),(41,42),(53,56),(43,59),(65,60),(42,75),(77,71),(29,92),(78,90),(14,98),(93,97)],
    [(21,11),(32,20),(26,32),(59,27),(18,45),(72,34),(23,56),(87,32),(49,39),(58,55),(48,59),(66,55),(40,74),(82,70),(23,89),(83,89),(28,96),(98,96)],
]


def shift(point, delta):
    return tuple(round(a + b) for a, b in zip(point, delta))


def xray(source, kind):
    alpha = source.getchannel('A')
    x0, y0, x1, y1 = alpha.getbbox()
    w, h = x1 - x0, y1 - y0
    points = [(round(x0+x*w/100), round(y0+y*h/100)) for x, y in RIGS[kind]]
    head, neck, s0, s1, e0, e1, h0, h1, ribs, pelvis, p0, p1, k0, k1, a0, a1, t0, t1 = points
    step = max(3, round(h*.022))
    anatomy = Image.new('RGBA', source.size)
    pen = ImageDraw.Draw(anatomy)
    shade, edge, main = '#3f7b98', '#9cd4dd', '#f3f8df'

    def bone(a, b, width=step, near=True):
        pen.line((a,b), fill=shade, width=width+2)
        pen.line((a,b), fill=edge if near else '#6da2b3', width=width)
        pen.line((shift(a,(-1,-1)),shift(b,(-1,-1))), fill=main if near else '#acd4ce', width=max(1,width-2))

    def joint(point, width=step):
        x,y=point
        r=max(2,width//2)
        pen.ellipse((x-r,y-r,x+r,y+r), fill=edge, outline=shade)
        pen.point((x-1,y-1), fill=main)

    for i, (hip,knee,ankle,toe) in enumerate(((p1,k1,a1,t1),(p0,k0,a0,t0))):
        bone(hip,knee,step+1,near=bool(i))
        bone(knee,ankle,step,near=bool(i))
        bone(shift(knee,(step,0)),shift(ankle,(step//2,-2)),max(1,step//2),near=bool(i))
        bone(ankle,toe,step)
        joint(knee)
    for shoulder,elbow,hand,near in ((s1,e1,h1,False),(s0,e0,h0,True)):
        bone(shoulder,elbow,step,near=near)
        bone(elbow,hand,max(2,step-1),near=near)
        bone(shift(elbow,(3,-1)),shift(hand,(3,0)),1,near=near)
        joint(elbow)
        joint(hand,max(3,step-2))

    spine = [neck, ribs, pelvis]
    for start,end in zip(spine,spine[1:]):
        bone(start,end,step+1)
        for t in np.arange(.15,1,.19):
            x,y=(round(start[i]+(end[i]-start[i])*t) for i in range(2))
            pen.line((x-2,y,x+2,y+1), fill='#fcfae5', width=1)
    bone(s0,neck,step)
    bone(neck,s1,max(2,step-1),near=False)
    for shoulder in (s0,s1): joint(shoulder)
    # Stepped rib arcs and a compact pelvic ring.
    chest_width=max(5,round(math.dist(s0,s1)*.40))
    for n in range(5):
        offset=round((n-2)*h*.028)
        x=ribs[0]+round(offset*.58)
        y=ribs[1]+offset
        radius=round(chest_width*(1-.07*abs(n-1.7)))
        arch=[(x-radius,y-3),(x-radius+2,y+1),(x-1,y+4),(x+radius-2,y+2),(x+radius,y-1)]
        pen.line(arch,fill=shade,width=step+1)
        pen.line(arch,fill=main if n<3 else edge,width=max(2,step-1))
    bone(p0,p1,step+2)
    bone(p0,shift(pelvis,(2,7)),step)
    bone(shift(pelvis,(2,7)),p1,max(2,step-1),near=False)
    joint(p0);joint(p1)

    # Profile skull with an angled jaw and a single visible eye socket.
    hx,hy=head
    rx=max(8,round(h*.064));ry=max(9,round(h*.065))
    skull=[(-.92,-.30),(-.68,-.80),(-.19,-1.01),(.27,-.98),(.62,-.60),(.72,-.12),
           (.99,.10),(.79,.34),(.59,.42),(.56,.71),(.06,.96),(-.38,.66),(-.66,.41),(-.92,.10)]
    pen.polygon([(hx+round(x*rx),hy+round(y*ry)) for x,y in skull],fill=main,outline=shade,width=2)
    pen.polygon([(hx-round(rx*.64),hy+2),(hx-round(rx*.20),hy+round(ry*.48)),(hx+round(rx*.52),hy+round(ry*.61)),(hx+2,hy+round(ry*.82)),(hx-round(rx*.30),hy+round(ry*.53))], fill=edge)
    pen.polygon([(hx+1,hy-3),(hx+round(rx*.63),hy-3),(hx+round(rx*.55),hy+2),(hx+2,hy+3)],fill='#101d32')
    pen.point((hx+max(4,round(rx*.64)),hy+3),fill='#101d32')
    pen.line((hx+1,hy+round(ry*.58),hx+round(rx*.56),hy+round(ry*.49)),fill='#344d60',width=1)
    for x in range(hx+2,hx+round(rx*.52),2): pen.point((x,hy+round(ry*.61)),fill='#5c91a6')

    # Reuse the defender's exact opacity, with a crisp dark radiation silhouette.
    result=Image.new('RGBA',source.size)
    rim=ImageChops.subtract(alpha,alpha.filter(ImageFilter.MinFilter(5)))
    result.paste('#0e1d36',(0,0,source.width,source.height),alpha)
    result.paste('#365c83',(0,0,source.width,source.height),rim)
    anatomy.putalpha(ImageChops.multiply(anatomy.getchannel('A'),alpha))
    result.alpha_composite(anatomy)
    return result


def flame(source, kind, pose, frame):
    w,h=source.size
    margin=MARGIN
    size=(w+margin*2,h+margin*2)
    body=Image.new('RGBA',size)
    body.alpha_composite(source,(margin,margin))
    alpha=body.getchannel('A')
    solid=np.asarray(alpha)>127
    outer=alpha.filter(ImageFilter.MaxFilter(9))
    contour=alpha.filter(ImageFilter.MaxFilter(5))
    result=Image.new('RGBA',size)
    result.paste(FIRE[0],(0,0,*size),outer)
    result.paste(FIRE[2 if frame%2==0 else 1],(0,0,*size),contour)
    rgb=np.asarray(body)[:,:,:3].astype(np.float32)/255
    luma=rgb@np.array([.299,.587,.114],dtype=np.float32)
    y,x=np.mgrid[:size[1],:size[0]]
    bands=np.sin(x*.13+y*.083+frame*1.24)+np.sin(x*.23-y*.14+frame*.8)*.52
    bayer=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])[y%4,x%4]/16-.5
    heat=np.clip(np.floor(2.6+luma*2.5+bands+bayer*.40+(frame%2)*.34).astype(int),1,7)
    palette=np.array([tuple(int(color[i:i+2],16) for i in (1,3,5)) for color in FIRE],dtype=np.uint8)
    hot=np.zeros((size[1],size[0],4),dtype=np.uint8)
    hot[:,:,:3]=palette[heat]
    hot[:,:,3]=solid*255
    result.alpha_composite(Image.fromarray(hot))

    bounds=alpha.getbbox()
    left,top,right,bottom=bounds
    rng=random.Random(603+17*kind+pose)
    pen=ImageDraw.Draw(result)

    def lick(cx,cy,height,width,drift,strength):
        for scale, index in ((1,1),(.80,3),(.55,5),(.29,7 if strength else 6)):
            dx=width*scale
            rise=height*scale
            points=[(cx-dx,cy),(cx-dx*.65,cy-rise*.35),(cx-dx*.20+drift*.17,cy-rise*.68),
                    (cx+drift*.37,cy-rise*.78),(cx+drift,cy-rise),(cx+drift*.78+dx*.18,cy-rise*.49),
                    (cx+dx*.68,cy-rise*.33),(cx+dx*.59,cy-rise*.10),(cx+dx*.28,cy+3)]
            pen.polygon([(round(a),round(b)) for a,b in points],fill=FIRE[index])

    interval=max(9,round((bottom-top)/12))
    for row in range(top+interval//2,bottom,interval):
        xs=np.flatnonzero(solid[row])
        if not xs.size: continue
        for side in (-1,1):
            if rng.random()<.16: continue
            extent=xs[0] if side<0 else xs[-1]
            cx=int(extent-side*rng.uniform(1,5))
            height=rng.randrange(12,23)+[0,4,-2,2][frame]
            drift=rng.randrange(-4,5)+side*(2+frame%2)
            lick(cx,row,height,rng.randrange(4,8),drift,frame%2==0)
        # A few hot tongues cross the torso and legs rather than only ringing the outline.
        core=int(xs[len(xs)//2])
        if solid[row,core] and rng.random()>.28:
            lick(core,row+2,rng.randrange(11,23)+frame,rng.randrange(4,8),rng.randrange(-7,8),True)
    for col in range(left+5,right-5,max(12,round((right-left)/9))):
        ys=np.flatnonzero(solid[:,col])
        if ys.size and abs(int(ys[0])-top)<(bottom-top)*.28:
            lick(col,int(ys[0])+5,13+rng.randrange(0,11)+frame,5,rng.randrange(-6,7),True)
    # Perimeter embers move between the four fixed poses.
    for _ in range(19):
        cy=rng.randrange(top,bottom)
        xs=np.flatnonzero(solid[cy])
        if not xs.size: continue
        side=rng.choice([-1,1])
        cx=int(xs[0] if side==-1 else xs[-1])+side*rng.randrange(4,19)
        ey=cy-rng.randrange(5,20)-frame*2
        if 0<=cx<size[0]-1 and 0<=ey<size[1]-2:
            pen.rectangle((cx,ey,cx+int(frame%2==0),ey+rng.choice([1,2,3])),fill=FIRE[rng.choice([3,5,6])])
    return result


def bake():
    atlas=Image.new('RGBA',(3072,5120))
    metadata={}
    x=y=row_height=0

    def pack(image,offset):
        nonlocal x,y,row_height
        bounds=image.getbbox()
        image=image.crop(bounds)
        w,h=image.size
        if x+w>=atlas.width: x,y,row_height=0,y+row_height,0
        if y+h>=atlas.height: raise ValueError('Reaction atlas ran out of room')
        atlas.alpha_composite(image,(x,y))
        entry=[x,y,w,h,bounds[0]+offset,bounds[1]+offset]
        x+=w+1
        row_height=max(row_height,h+1)
        return entry

    for kind in range(len(RIGS)):
        for pose in (13,15):
            source=Image.open(SOURCE/f'{kind}-base-{pose}.png').convert('RGBA')
            entry={'size':list(source.size),'fire':[pack(flame(source,kind,pose,phase),-MARGIN) for phase in range(4)]}
            if pose==13: entry['xray']=pack(xray(source,kind),0)
            metadata[f'{kind}:base:{pose}']=entry
    atlas=atlas.crop((0,0,atlas.width,y+row_height))
    atlas.save(PROJECT/'assets'/'element-reactions.png',optimize=True)
    (PROJECT/'data'/'element-reactions.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n',encoding='utf-8')
    print(f'Reaction atlas {atlas.width}x{atlas.height}, {len(metadata)} registered poses')


if __name__=='__main__':
    bake()
