"""Append the two photo-inspired racers; preserve every existing fighter."""
import copy
import json
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'data/moves.json'
data=json.loads(p.read_text())
for identity,name,subtitle,color,speed,names in [
    ('eric','ERIC','THE PIT CREW','#e8e7e2',5.5,['Pit Lane Pulse','Checkered Uppercut','Pit Stop Toss']),
    ('stan','STAN','THE LONG HAUL','#cf4548',5.8,['Blacktop Pulse','Redline Uppercut','Victory Lap Toss'])]:
    fighter=copy.deepcopy(data['fighters'][0])
    fighter.update(id=identity,name=name,subtitle=subtitle,color=color,speed=speed,locked=False)
    for key,label in zip(['special1','special2','throw'],names): fighter['moves'][key]['name']=label
    matches=[i for i,f in enumerate(data['fighters']) if f['id']==identity]
    if matches: data['fighters'][matches[0]]=fighter
    else: data['fighters'].append(fighter)
p.write_text(json.dumps(data,indent=2)+'\n')
