"""Author new pose keys from the fighters' approved pixel art, preserving its palette."""
import json
import math
from pathlib import Path

from PIL import Image, ImageOps


PROJECT=Path(__file__).resolve().parents[1]
ART=PROJECT.parent/'work'/'collision-art'
POSES=json.loads((ART/'metadata.json').read_text())
UNIT=.9
NEAREST=Image.Resampling.NEAREST


def load(kind,key):
    entry=POSES[str(kind)][key]
    return Image.open(ART/entry['file']).convert('RGBA'), round(entry['anchor']/UNIT)


def tilt(image,anchor,angle):
    turned=image.rotate(angle,resample=NEAREST,expand=True)
    theta=math.radians(angle)
    center=turned.width/2+math.cos(theta)*(anchor-image.width/2)+math.sin(theta)*image.height*.21
    return turned,round(center)


def pose(kind,key,angle=0,mirror=False):
    image,anchor=load(kind,key)
    if mirror: image,anchor=ImageOps.mirror(image),image.width-anchor
    return tilt(image,anchor,angle) if angle else (image,anchor)


def long_arm(add):
    source,anchor=load(10,'base:5')
    result=Image.new('RGBA',(source.width+add,source.height))
    result.alpha_composite(source)
    top,bottom=19,56
    source_start,source_end=91,126
    sleeve=source.crop((source_start,top,source_end,bottom))
    tip=source.crop((source_end,top,source.width,bottom))
    result.paste((0,0,0,0),(source_start,top,result.width,bottom))
    result.alpha_composite(sleeve.resize((sleeve.width+add,sleeve.height),NEAREST),(source_start,top))
    result.alpha_composite(tip,(source_end+add,top))
    return result,anchor


def palm(phase):
    source,anchor=load(8,'base:4' if phase==0 else 'base:5')
    shoot,_=load(8,'movement:3')
    hand=shoot.crop((173,25,195,56))
    hand=hand.crop(hand.getbbox())
    result=Image.new('RGBA',(source.width+10,source.height))
    result.alpha_composite(source)
    seam=source.width-27
    y0=17 if phase else 29
    arm=source.crop((84,y0,seam+7,65))
    slope=[-.04,-.21,.19][phase]
    arm=arm.transform((arm.width,arm.height+16),Image.Transform.AFFINE,(1,0,0,-slope,1,-8),NEAREST)
    result.paste((0,0,0,0),(84,11,result.width,78))
    result.alpha_composite(arm,(84,y0-8))
    left=seam+4; top=round((34 if phase else 41)+slope*(left-84)-10)
    result.alpha_composite(hand,(left,max(1,top)))
    return result,anchor


def lariat(phase):
    source,anchor=load(0,'base:5' if phase!=1 else 'base:4')
    right,_=load(0,'base:5')
    arm=ImageOps.mirror(right.crop((87,21,right.width,53)))
    offset=39
    result=Image.new('RGBA',(source.width+offset,source.height))
    arm_y=[25,35,19][phase]
    arm=arm.rotate([5,-7,13][phase],resample=NEAREST)
    result.alpha_composite(arm,(offset+67-arm.width,arm_y))
    result.alpha_composite(source,(offset,0))
    return tilt(result,anchor+offset,[0,4,-5][phase])


def low_shot():
    source,anchor=load(10,'base:9')
    cast,_=load(10,'movement:3')
    hands=cast.crop((173,31,200,74))
    hands=hands.crop(hands.getbbox()).resize((29,29),NEAREST)
    result=Image.new('RGBA',(source.width+17,source.height))
    result.alpha_composite(source)
    result.paste((0,0,0,0),(126,25,result.width,51))
    result.alpha_composite(hands,(124,23))
    arm=result.crop((66,21,result.width,55))
    result.paste((0,0,0,0),(66,21,result.width,55))
    arm=arm.transform((arm.width,arm.height+48),Image.Transform.AFFINE,(1,0,0,-.49,1,0),NEAREST)
    result.alpha_composite(arm,(66,21))
    return result,anchor


def high_shot():
    result,anchor=load(10,'movement:3')
    arm=result.crop((111,23,result.width,87))
    result.paste((0,0,0,0),(111,10,result.width,87))
    arm=arm.transform((arm.width,arm.height+13),Image.Transform.AFFINE,(1,0,0,.129,1,-13),NEAREST)
    result.alpha_composite(arm,(111,10))
    return result,anchor


def bicycle(phase):
    source,anchor=load(1,f'signature:{[1,2,3,2][phase]}')
    pad=42
    size=(source.width+pad+58,source.height+8)
    torso=Image.new('RGBA',size)
    torso.alpha_composite(source,(pad,0))
    upper=Image.new('RGBA',size)
    lower=Image.new('RGBA',size)
    hip=(pad+40,94)
    knee=(pad+39,133)
    upper.alpha_composite(source.crop((19,91,56,139)),(pad+19,91))
    lower.alpha_composite(source.crop((18,128,57,source.height)),(pad+18,128))
    if phase==0:
        torso.paste((0,0,0,0),(0,94,pad+80,source.height))
        torso.paste((0,0,0,0),(pad+80,104,torso.width,source.height))
    elif phase==2:
        torso.paste((0,0,0,0),(0,94,torso.width,source.height))
    else:
        torso.paste((0,0,0,0),(0,94,pad+62,source.height))
        torso.paste((0,0,0,0),(pad+62,137,torso.width,source.height))

    def rotate_to(layer, angle, pivot, target):
        c=math.cos(math.radians(angle));s=math.sin(math.radians(angle))
        x,y=target
        return layer.transform(size,Image.Transform.AFFINE,(c,-s,pivot[0]-c*x+s*y,s,c,pivot[1]-s*x-c*y),NEAREST)

    thigh=[-28,64,-38,54][phase]
    shin=[-54,69,-68,67][phase]
    r=math.radians(thigh)
    x,y=knee[0]-hip[0],knee[1]-hip[1]
    carried_knee=(hip[0]+math.cos(r)*x+math.sin(r)*y,hip[1]-math.sin(r)*x+math.cos(r)*y)
    lower=rotate_to(lower,shin,knee,carried_knee)
    lower.alpha_composite(rotate_to(upper,thigh,hip,hip))
    lower.alpha_composite(torso)
    return lower,anchor+pad


def bake():
    entries={}
    atlas=Image.new('RGBA',(1500,1400))
    cursor_x=cursor_y=row_height=0

    def add(id_,kind,source):
        nonlocal cursor_x,cursor_y,row_height
        image,anchor=source
        w,h=image.size
        if cursor_x+w>=atlas.width: cursor_x,cursor_y,row_height=0,cursor_y+row_height,0
        if cursor_y+h>=atlas.height: raise ValueError('Style atlas ran out of room')
        atlas.alpha_composite(image,(cursor_x,cursor_y))
        entries[id_]={'kind':kind,'region':[cursor_x,cursor_y,w,h],'anchor':round(anchor*UNIT,2)}
        cursor_x+=w+2
        row_height=max(row_height,h+2)

    for i in range(3): add(f'stan-arm-{i}',8,palm(i))
    for i,reach in enumerate([39,78,60]): add(f'jeff-long-{i}',10,long_arm(reach))
    add('jeff-high-shot',10,high_shot())
    add('jeff-low-shot',10,low_shot())
    add('jeff-knee',10,pose(10,'base:14',-10))
    add('marcus-straight',0,pose(0,'base:5',-8))
    add('marcus-body',0,pose(0,'base:9',-4))
    for i in range(3): add(f'marcus-spin-{i}',0,lariat(i))
    for i in range(4): add(f'brook-cycle-{i}',1,bicycle(i))
    add('lauren-spin-0',3,pose(3,'base:11',8))
    add('lauren-spin-1',3,pose(3,'base:11',-13,True))
    add('lauren-spin-2',3,pose(3,'base:6',-20))
    for i,rotation in enumerate((19,66,106)): add(f'lauren-arc-{i}',3,pose(3,'base:7',rotation))
    atlas.crop((0,0,atlas.width,cursor_y+row_height)).save(PROJECT/'assets'/'style-poses.png',optimize=True)
    (PROJECT/'data'/'style-poses.json').write_text(json.dumps(entries,separators=(',',':'))+'\n',encoding='utf-8')
    print('Style poses baked:',len(entries))


if __name__=='__main__':
    bake()
