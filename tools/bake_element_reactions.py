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
    [(31,11),(38,20),(36,25),(51,26),(34,40),(60,34),(32,51),(70,34),(46,36),(56,49),(52,53),(64,52),(57,68),(72,62),(70,87),(83,77),(77,96),(92,82)],
    [(22,11),(29,22),(22,32),(53,30),(17,45),(68,37),(17,54),(82,34),(45,40),(55,54),(45,57),(67,57),(38,72),(81,66),(21,89),(84,88),(22,96),(95,94)],
    [(18,10),(26,20),(22,29),(42,30),(22,43),(50,35),(24,54),(63,33),(37,37),(49,49),(46,54),(59,52),(55,67),(72,61),(64,86),(81,79),(74,96),(89,84)],
    [(30,10),(37,18),(29,27),(49,22),(25,38),(61,28),(27,46),(75,22),(46,32),(57,45),(51,51),(64,50),(42,69),(76,64),(28,89),(81,89),(22,96),(88,95)],
    [(27,11),(35,20),(31,29),(53,27),(26,40),(61,34),(27,47),(75,31),(47,36),(55,49),(46,52),(66,51),(49,68),(76,69),(36,88),(84,88),(30,97),(97,96)],
    [(19,10),(30,20),(21,29),(55,28),(17,46),(68,30),(20,54),(80,28),(45,37),(55,53),(46,58),(66,56),(47,72),(81,67),(30,90),(67,90),(38,97),(74,97)],
    [(31,11),(37,21),(23,30),(55,30),(18,43),(71,38),(24,53),(84,33),(46,41),(56,56),(50,61),(68,59),(46,74),(82,77),(26,89),(80,91),(34,96),(96,96)],
    [(21,10),(35,20),(25,29),(55,28),(17,41),(69,33),(17,49),(81,28),(48,40),(56,54),(48,59),(67,57),(44,72),(77,75),(24,91),(81,90),(28,97),(95,96)],
    [(20,10),(26,20),(22,29),(46,28),(22,44),(54,34),(30,55),(66,27),(36,37),(47,51),(44,54),(56,51),(58,69),(70,64),(66,87),(82,77),(74,97),(92,84)],
    [(20,10),(31,20),(23,29),(53,29),(21,43),(68,34),(24,51),(82,29),(46,40),(59,52),(49,57),(69,55),(58,68),(78,66),(32,89),(78,89),(37,96),(93,96)],
    [(21,10),(31,19),(23,29),(54,26),(21,43),(73,32),(19,51),(86,26),(45,39),(57,53),(49,58),(67,56),(54,69),(77,66),(34,89),(75,89),(41,96),(93,97)],
    [(27,14),(37,26),(23,30),(54,31),(16,41),(68,38),(18,56),(84,33),(41,42),(53,56),(43,59),(65,60),(42,75),(77,71),(29,92),(78,90),(14,98),(93,97)],
    [(21,11),(32,20),(26,32),(59,27),(18,45),(72,34),(17,51),(85,32),(49,39),(58,55),(48,59),(66,55),(38,73),(82,70),(23,89),(83,89),(28,96),(98,96)],
]


def shift(point, delta):
    return tuple(round(a + b) for a, b in zip(point, delta))


def draw_skull(pen, head, neck, height, kind):
    # Side profile in a local cranial plane, tilted to follow the recoil pose.
    back = '#3e7192'
    cold = '#7fb3c9'
    light = '#d9e9da'
    highlight = '#fff7dd'
    cavity = '#13273e'
    hx, hy = head
    rx, ry = max(10, height * .069), max(11, height * .070)
    angle = np.clip(math.atan2(hx-neck[0], neck[1]-hy), -.64, -.25)
    cos, sin = math.cos(angle), math.sin(angle)
    if kind == 12:  # The Bird's costume head is wider around the beak.
        rx *= 1.32

    def points(plane):
        return [(round(hx + x*rx*cos - y*ry*sin), round(hy + x*rx*sin + y*ry*cos)) for x, y in plane]

    def shape(plane, fill, outline=None):
        pen.polygon(points(plane), fill=fill, outline=outline)

    # Separate mandible, cheek arch, orbit and nasal opening.
    shape([(-.69,.17),(-.45,.24),(-.32,.64),(.08,.79),(.67,.63),(.80,.51),(.84,.71),
           (.64,.90),(.02,1.03),(-.44,.88),(-.57,.66)], light, back)
    shape([(-.94,.04),(-1.04,-.34),(-.91,-.65),(-.65,-.89),(-.32,-1.00),(.12,-1.00),
           (.46,-.85),(.64,-.58),(.64,-.26),(.78,-.13),(.73,.05),(.94,.30),(.85,.41),
           (.80,.53),(.47,.61),(.14,.47),(-.08,.31),(-.38,.34),(-.59,.36),(-.82,.23)], light, back)
    shape([(-.99,-.34),(-.90,-.53),(-.81,-.12),(-.51,.11),(-.16,.10),(-.38,.27),(-.65,.32),(-.87,.16)], cold)
    pen.line(points([(-.78,-.65),(-.53,-.83),(-.14,-.89),(.25,-.85),(.45,-.71)]), fill=highlight)
    shape([(.15,-.26),(.34,-.32),(.55,-.26),(.60,-.14),(.51,.05),(.35,.10),(.17,.02),(.10,-.11)], cavity)
    pen.line(points([(-.49,.21),(-.22,.19),(.10,.23),(.39,.20),(.59,.14)]), fill=highlight)
    shape([(.68,.09),(.64,.18),(.67,.33),(.85,.33),(.78,.23)], cavity)
    pen.line(points([(.25,.51),(.46,.62),(.65,.60),(.78,.53)]), fill=back)
    for x, y in ((.40,.49),(.52,.53),(.64,.52),(.75,.49)):
        pen.line(points([(x,y),(x,y+.13)]),fill=highlight)
    pen.line(points([(-.46,.68),(-.26,.83),(.07,.88),(.39,.79)]), fill=cold)


def xray(source, kind):
    alpha = source.getchannel('A')
    x0, y0, x1, y1 = alpha.getbbox()
    w, h = x1 - x0, y1 - y0
    points = [(round(x0+x*w/100), round(y0+y*h/100)) for x, y in RIGS[kind]]
    head, neck, s0, s1, e0, e1, h0, h1, ribs, pelvis, p0, p1, k0, k1, a0, a1, t0, t1 = points
    step = max(3, round(h*.025))
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

    def paint_hand(wrist, elbow, near):
        dx, dy = (wrist[0]-elbow[0], wrist[1]-elbow[1])
        length = max(1,math.hypot(dx,dy))
        dx,dy=dx/length,dy/length
        for digit in range(4):
            spread=(digit-1.5)*1.45
            root=shift(wrist,(-dy*spread,dx*spread))
            middle=shift(root,(dx*3.3-dy*.45*spread,dy*3.3+dx*.45*spread))
            tip=shift(middle,(dx*(3-abs(spread)*.46)-dy*.35*spread,dy*(3-abs(spread)*.46)+dx*.35*spread))
            pen.line((root,middle,tip),fill=main if near else edge,width=1)
        thumb=shift(wrist,(-dy*4.2+dx,dx*4.2+dy))
        pen.line((wrist,thumb,shift(thumb,(dx*2,dy*2))),fill=edge,width=1)

    for i, (hip,knee,ankle,toe) in enumerate(((p1,k1,a1,t1),(p0,k0,a0,t0))):
        bone(hip,knee,step+1,near=bool(i))
        bone(knee,ankle,step,near=bool(i))
        bone(shift(knee,(step,0)),shift(ankle,(step//2,-2)),max(1,step//2),near=bool(i))
        bone(ankle,toe,step)
        joint(knee)
    hands = []
    for shoulder,elbow,hand,near in ((s1,e1,h1,False),(s0,e0,h0,True)):
        bone(shoulder,elbow,step,near=near)
        bone(elbow,hand,max(2,step-1),near=near)
        bone(shift(elbow,(3,-1)),shift(hand,(3,0)),1,near=near)
        joint(elbow)
        joint(hand,max(3,step-2))
        hands.append((hand,elbow,near))

    spine = [neck, ribs, pelvis]
    for start,end in zip(spine,spine[1:]):
        bone(start,end,step+1)
        for t in np.arange(.15,1,.19):
            x,y=(round(start[i]+(end[i]-start[i])*t) for i in range(2))
            pen.line((x-2,y,x+2,y+1), fill='#fcfae5', width=1)
    base_of_skull=shift(head,(-step*.60,step*1.75))
    bone(base_of_skull,neck,max(2,step-1))
    collar=shift(neck,((ribs[0]-neck[0])*.22,(ribs[1]-neck[1])*.22))
    bone(s0,collar,max(2,step-1))
    bone(collar,s1,max(2,step-2),near=False)
    for shoulder in (s0,s1): joint(shoulder)
    # Project the rib cage at three-quarter view with an open lower margin.
    chest_width=max(8,round(math.dist(s0,s1)*.43))
    for n in range(7):
        offset=round((n-3)*h*.024)
        x,y=shift(ribs,(offset*.56,offset))
        radius=round(chest_width*(1-.085*abs(n-3.3)))
        depth=max(3,round(radius*.42))
        near=[(x-radius,y-3),(x-radius+2,y),(x-radius//2,y+depth),(x+radius//2,y+depth+1)]
        far=[(x+radius//2,y+depth+1),(x+radius-1,y+depth-2),(x+radius,y-3)]
        pen.line(near,fill=shade,width=2)
        pen.line(near,fill=main if n<5 else edge,width=1)
        pen.line(far,fill=edge,width=1)
    # Both iliac wings taper around the hip sockets, with paired openings.
    for hip, side in ((p1,1),(p0,-1)):
        wing=shift(hip,(side*3,-8))
        pubis=shift(pelvis,(side*2+2,8))
        pen.polygon([wing,shift(wing,(-side*4,-1)),pelvis,pubis,shift(hip,(side*3,3))],fill=edge,outline=shade)
        pen.line([wing,shift(wing,(-side*4,-1)),pelvis],fill=main,width=2)
        pen.line([shift(hip,(-side*2,0)),shift(pubis,(side*1,-1))],fill='#284665',width=2)
        joint(hip)
    for wrist,elbow,near in hands:
        paint_hand(wrist,elbow,near)
    draw_skull(pen,head,neck,h,kind)

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
    flow=x*.18+np.sin(y*.14+frame*.56)*.9+y*.04-frame*1.3
    flames=(.5+.5*np.sin(flow))**2.8 + .35*np.sin(y*.19+x*.20-frame*1.05)
    bayer=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])[y%4,x%4]/16-.5
    heat=np.clip(np.floor(1.25+luma*4.1+2.8*flames+bayer*.66).astype(int),1,7)
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
