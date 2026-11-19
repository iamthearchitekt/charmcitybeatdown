"""Append Jeff without rewriting existing designs or balance changes."""
import copy
import json
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'data/moves.json'
data=json.loads(p.read_text())
jeff=copy.deepcopy(next(f for f in data['fighters'] if f['id']=='alex'))
jeff.update(id='jeff',name='JEFF',subtitle='THE LONG REACH',color='#d0d2d8',speed=6.4,locked=False)
for key,name in [('special1','BSE Signal'),('special2','High Frequency'),('throw','Long Haul Toss')]:
    jeff['moves'][key]['name']=name
matches=[i for i,f in enumerate(data['fighters']) if f['id']=='jeff']
if matches:data['fighters'][matches[0]]=jeff
else:data['fighters'].append(jeff)
p.write_text(json.dumps(data,indent=2)+'\n')
