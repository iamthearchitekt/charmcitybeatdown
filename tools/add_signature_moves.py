"""Idempotently add the approved character-specific kick moves."""
from pathlib import Path
import json

p=Path(__file__).resolve().parents[1]/'data/moves.json'
data=json.loads(p.read_text())
def move(name,damage,startup,active,recovery,interval,box,**extra):
    return dict(name=name,startup=startup,active=active,recovery=recovery,damage=damage,
                hitstun=11,blockstun=7,pushback=12,hitstop=2,level='mid',box=box,
                cancel_start=startup,cancel_end=startup+active,cancels=[],rehit_interval=interval,
                chip=3,**extra)
by_id={f['id']:f for f in data['fighters']}
by_id['spike']['moves']['special1']['projectile_skin']='fire'
by_id['brook-lynne']['moves']['special3']=move('Orange Blitz',30,6,28,19,8,[12,-140,125,100],input='mash_kick',animation='brook-flurry')
by_id['alex']['moves']['special3']=move('Grey Cyclone',35,9,30,23,9,[-20,-147,145,115],input='qcb_kick',animation='alex-hurricane',travel=3.7,hover_height=28)
by_id['vivian']['moves']['special3']=move('Blossom Lightning',34,5,33,18,7,[10,-145,129,108],input='mash_kick',animation='vivian-flurry')
by_id['vivian']['moves']['special4']=move('Sakura Whirlwind',38,10,31,24,9,[-60,-150,175,130],input='charge_down_kick',animation='vivian-spin',travel=2.9,hover_height=48)
p.write_text(json.dumps(data,indent=2)+'\n')
print('Registered Brook flurry, Alex hurricane, Vivian lightning and spinning kick')
