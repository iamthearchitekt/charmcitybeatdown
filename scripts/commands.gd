extends RefCounted
## Input history is sampled at 60 Hz even during hitstop. Directions are facing-relative.
var history: Array = []
var clock: int = 0
var last_dir: int = 5
var display: Array = []
var kick_presses:Array=[]
var punch_presses:Array=[]
var down_charge=0
var charge_ready=0
var back_charge=0
var back_ready=0
const SPECIALS=["special1","special2","special3","special4","special5","special6"]

func reset():
	history.clear()
	display.clear()
	clock = 0
	last_dir = 5
	kick_presses.clear();punch_presses.clear();down_charge=0;charge_ready=0
	back_charge=0;back_ready=0

func sample(direction: int, buttons: Array, kit:Dictionary={}) -> String:
	clock += 1
	charge_ready=maxi(0,charge_ready-1)
	if direction in [1,2,3]: down_charge+=1
	else:
		if down_charge>=40: charge_ready=8
		down_charge=0
	back_ready=maxi(0,back_ready-1)
	if direction in [1,4,7]: back_charge+=1
	else:
		if back_charge>=40: back_ready=8
		back_charge=0
	var changed=direction!=last_dir
	if direction != last_dir:
		history.append({"d":direction,"t":clock})
		last_dir = direction
		display.push_front(str(direction))
	while not history.is_empty() and clock - history[0].t > 28:
		history.pop_front()
	for button in buttons:
		display.push_front(button.to_upper())
	while display.size() > 12:
		display.pop_back()
	if buttons.has("throw") and kit.has("command_grab") and matches([4,1,2,3,6],28):
		history.clear()
		return "command_grab"
	if buttons.has("throw"): return "throw"
	if buttons.has("lk") or buttons.has("mk") or buttons.has("hk"):
		if kit.has("special4") and direction in [7,8,9] and charge_ready>0:
			charge_ready=0;history.clear();kick_presses.clear()
			return "special4"
		var charge_kick=with_input(kit,"charge_back_kick")
		if charge_kick!="" and direction==6 and back_ready>0:
			back_ready=0;history.clear()
			return charge_kick
		var forward_kick=with_input(kit,"qcf_kick")
		if forward_kick!="" and direction==6 and matches([2,3,6],24):
			history.clear()
			return forward_kick
		if kit.has("special3"):
			if kit.special3.get("input","") in ["qcb_kick","mash_kick"] and matches([2,1,4],24):
				history.clear();kick_presses.clear()
				return "special3"
			if kit.special3.get("input","")=="mash_kick":
				kick_presses.append(clock)
				while not kick_presses.is_empty() and clock-kick_presses[0]>22: kick_presses.pop_front()
				if kick_presses.size()>=3:
					kick_presses.clear();history.clear()
					return "special3"
	if buttons.has("lp") or buttons.has("mp") or buttons.has("hp"):
		var charge_punch=with_input(kit,"charge_back_punch")
		if charge_punch!="" and direction==6 and back_ready>0:
			back_ready=0;history.clear();punch_presses.clear()
			return charge_punch
		if direction==4 and kit.get("special3",{}).get("input","")=="qcb_punch" and matches([2,1,4],20):
			history.clear()
			return "special3"
		if matches([6,2,3], 24):
			history.clear()
			return "special2"
		if kit.get("special1",{}).get("input","qcf_punch")=="qcf_punch" and matches([2,3,6], 24):
			history.clear()
			return "special1"
		var palm_barrage=with_input(kit,"mash_punch")
		if palm_barrage!="":
			punch_presses.append(clock)
			while not punch_presses.is_empty() and clock-punch_presses[0]>23: punch_presses.pop_front()
			if punch_presses.size()>=3:
				punch_presses.clear();history.clear()
				return palm_barrage
	for button in ["hk","hp","mk","mp","lk","lp"]:
		if buttons.has(button):
			return button
	if changed and direction in [4,6] and history.size()>=3:
		var tail=history.slice(-3)
		if tail[0].d==direction and tail[1].d==5 and tail[2].d==direction and clock-tail[0].t<=14:
			history.clear()
			return "dash_forward" if direction==6 else "dash_back"
	return ""

static func with_input(kit:Dictionary,input:String)->String:
	for move in SPECIALS:
		if kit.get(move,{}).get("input","")==input: return move
	return ""

func matches(pattern: Array, max_age: int) -> bool:
	var cursor = pattern.size()-1
	for i in range(history.size()-1, -1, -1):
		if clock-history[i].t > max_age:
			break
		if history[i].d == pattern[cursor]:
			cursor -= 1
			if cursor < 0:
				return clock-history[-1].t <= 8
	return false

static func relative_direction(dx: int, down: bool, up: bool, facing: int) -> int:
	var x = dx*facing
	if down: return 2+x
	if up: return 8+x
	return 5+x
