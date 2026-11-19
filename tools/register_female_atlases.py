"""Register generated sprite bounds/pivots. Reads PNG alpha; never edits artwork."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

project = Path(__file__).resolve().parents[1]
reference = json.loads((project / "data/appearance-atlases.json").read_text())["emma-atlas"]
ratios = [115/231,91/183,82/191,100/221,100/262,100/291,72/256,88/282,82/167,90/249,93/321,79/283,92/195,115/245,85/177,.5]
# Square head-and-shoulder crops keep hair and bows inside both portrait sizes.
portrait_overrides={"lauren":[86,0,144,144],"chelsea":[94,8,144,144],"vivian":[70,0,144,144],"spike":[82,8,124,124]}

def components(mask):
    # Connected horizontal runs avoid per-pixel Python loops and extra dependencies.
    parents=[];runs=[];previous=[]
    def root(n):
        while parents[n]!=n:
            parents[n]=parents[parents[n]];n=parents[n]
        return n
    for y,row in enumerate(mask):
        changes=np.diff(np.r_[False,row,False].astype(np.int8))
        starts=np.flatnonzero(changes==1);ends=np.flatnonzero(changes==-1)
        current=[];cursor=0
        for x0,x1 in zip(starts,ends):
            n=len(parents);parents.append(n);runs.append((int(x0),int(x1),y,n))
            while cursor<len(previous) and previous[cursor][1]<=x0: cursor+=1
            j=cursor
            while j<len(previous) and previous[j][0]<x1:
                parents[root(n)]=root(previous[j][2]);j+=1
            current.append((x0,x1,n))
        previous=current
    groups={}
    for x0,x1,y,n in runs:
        key=root(n)
        if key not in groups: groups[key]=[x0,y,x1,y+1,0]
        box=groups[key]
        box[0]=min(box[0],x0);box[1]=min(box[1],y);box[2]=max(box[2],x1);box[3]=max(box[3],y+1);box[4]+=x1-x0
    return sorted(groups.values(),key=lambda b:b[4],reverse=True)

def register(filename, expected):
    image = Image.open(project / "assets" / filename).convert("RGBA")
    if len(expected)==16:
        expected=[[x*image.width/1254,y*image.height/1254,w*image.width/1254,h*image.height/1254] for x,y,w,h in expected]
    elif len(expected)==18:
        expected=[[x*image.width/1254,y*image.height/1568,w*image.width/1254,h*image.height/1568] for x,y,w,h in expected]
    candidates=components(np.asarray(image)[:,:,3]>=160)[:len(expected)]
    if len(candidates) != len(expected) or min(n[4] for n in candidates) < 800:
        raise ValueError(f"Expected {len(expected)} complete sprites: {filename}")
    boxes=[]
    for left,top,right,bottom,area in candidates:
        x0=max(0,left-2);y0=max(0,top-2)
        boxes.append([x0,y0,min(image.width,right+2)-x0,min(image.height,bottom+2)-y0])
    centers=np.array([[x+w/2,y+h/2] for x,y,w,h in boxes])
    targets=np.array([[x+w/2,y+h/2] for x,y,w,h in expected])
    distance=((targets[:,None,:]-centers[None,:,:])**2).sum(axis=2)
    result=[None]*len(expected)
    used=set()
    for index in np.argsort(distance,axis=None):
        row,col=np.unravel_index(index,distance.shape)
        if result[row] is not None or col in used: continue
        if distance[row,col]>(150*max(1,image.width/1254))**2: raise ValueError(f"Unexpected pose layout: {filename} frame {row}")
        result[row]=boxes[col];used.add(col)
    return result

out={}
for identity,filename in [("brook-lynne","brook-lynne-atlas.png"),("lauren","lauren-atlas.png"),("chelsea","chelsea-atlas.png"),("vivian","vivian-atlas.png"),("spike","spike-atlas.png")]:
    if not (project/"assets"/filename).exists(): continue
    expected=reference if identity!="spike" else reference+[[50,1270,260,285],[350,1270,300,285]]
    regions=register(filename,expected)
    x,y,w,h=regions[0]
    out[identity]={"path":"res://assets/"+filename,"regions":regions,
        "anchors":[round((ratios[i] if i<16 else .5)*r[2],2) for i,r in enumerate(regions)],
        "portrait":[round(x+w*.18),round(y+h*.04),round(w*.68),round(h*.40)]}
    if identity in portrait_overrides: out[identity]["portrait"]=portrait_overrides[identity]
    if regions[15][2]<regions[15][3]*2: raise ValueError("KO must be horizontal")
    print(identity, "registered", len(regions), "poses; KO", regions[15])

for identity,filename in [('alex','alex-athletic-atlas.png'),('spike','spike-likeness-atlas.png'),('eric','eric-atlas.png'),('stan','stan-atlas.png'),('rachel','rachel-atlas.png'),('jeff','jeff-atlas.png'),('edgar-allan-poe','poe-atlas.png'),('orioles-mascot','oriole-bird-atlas.png'),('lamar-jackson','lamar-atlas.png')]:
    atlas_path=project/'assets'/filename
    if not atlas_path.exists(): continue
    image=Image.open(atlas_path).convert('RGBA')
    cells={}
    for x0,y0,x1,y1,area in components(np.asarray(image)[:,:,3]>=160):
        if area<800: continue
        # Poses share row baselines; the horizontal KO sits low in its cell.
        row=min(range(6),key=lambda r:abs(y1/image.height-[.187,.373,.523,.699,.859,.991][r]))
        col=min(3,int((x0+x1)/2/image.width*4))
        index=row*4+col
        if index>=22 or index in cells: continue
        x=max(0,x0-2);y=max(0,y0-2)
        cells[index]=[x,y,min(image.width,x1+2)-x,min(image.height,y1+2)-y]
    assert len(cells)==22,(identity+' atlas requires 22 complete poses',cells)
    regions=[cells[i] for i in range(22)]
    x,y,w,h=regions[0]
    out[identity]={'path':'res://assets/'+filename,'regions':regions[:18],
        'anchors':[round((ratios[i] if i<16 else .5)*r[2],2) for i,r in enumerate(regions[:18])],
        'portrait':[round(x+w*.15),max(0,y-3),round(w*.7),round(w*.7)],'throws':regions[18:]}
    assert regions[15][2]>regions[15][3]*2,identity+' KO must lie horizontal'
    print(identity+' registered 18 ordinary and 4 throw poses')

for key,filename in [("jumps","female-jump-poses.png"),("bonus-jumps","bonus-female-jump-poses.png")]:
    jump_path=project/"assets"/filename
    if not jump_path.exists(): continue
    image=Image.open(jump_path)
    w,h=image.size
    expected=[[0,0,w/2,h/2],[w/2,0,w/2,h/2],[0,h/2,w/2,h/2],[w/2,h/2,w/2,h/2]]
    # Normalize reference-space matching to the image's actual dimensions.
    jumps=register(filename,expected)
    out[key]={"path":"res://assets/"+filename,"regions":jumps}
(project/"data/female-atlases.json").write_text(json.dumps(out,indent=2)+"\n")
