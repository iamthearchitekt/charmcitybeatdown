"""Add Rachel as the hardest-hitting woman, preserving the rest of the roster."""
import copy
import json
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'data/moves.json'
data=json.loads(p.read_text())
base=next(f for f in data['fighters'] if f['id']=='brook-lynne')
rachel=copy.deepcopy(base)
rachel.update(id='rachel',name='RACHEL',subtitle='THE DIRECTOR',color='#b5bac4',speed=6.2,locked=False,boss=True)
for move in rachel['moves'].values(): move['damage']=round(move['damage']*1.22)
for key,name in [('special1','Black Directive'),('special2','Final Authority'),('throw','Detainment')]:
    rachel['moves'][key]['name']=name
matches=[i for i,f in enumerate(data['fighters']) if f['id']=='rachel']
if matches:data['fighters'][matches[0]]=rachel
else:data['fighters'].append(rachel)
p.write_text(json.dumps(data,indent=2)+'\n')
