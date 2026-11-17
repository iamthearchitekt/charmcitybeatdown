extends RefCounted
## Deterministic combat. All timing is integer simulation frames; drawing never controls collision.
const FLOOR = 622.0
const LEFT = 84.0
const RIGHT = 1196.0
const GRAVITY = 1.10
const MAX_HEALTH = 1000
const FIGHTER_SCALE = 1.82
const PUSH_WIDTH = 50.0 * FIGHTER_SCALE
var data: Dictionary
var fighters: Array = []
var projectiles: Array = []
var events: Array = []
var tick: int = 0
var freeze: int = 0
var time_left: int = 99*60
var phase: String = "intro"
var phase_timer: int = 120
var winner: int = -1
var wins: Array = [0,0]
var round_number: int = 1
var training: bool = false
var dummy: int = 0
var last_result: String = ""

func _init():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/moves.json"))
	new_match(0, 1)

func make_fighter(kind: int, slot: int) -> Dictionary:
	return {"kind":kind,"slot":slot,"x":400.0+480.0*slot,"y":FLOOR,"vx":0.0,"vy":0.0,
		"facing":1 if slot==0 else -1,"health":MAX_HEALTH,"state":"idle","move":"","frame":0,
		"stun":0,"crouch":false,"guard":false,"hit":false,"connected":false,"queued":"",
		"buffer":0,"combo":0,"last_hit":-999,"up_prev":false,"throw_safe":0,"walk":0.0,
		"dash":0,"dash_vx":0.0,"down_timer":0,"down_frames":22,"rise_frames":14,"wake_safe":0}

func new_match(a: int, b: int, is_training: bool = false):
	training = is_training
	fighters = [make_fighter(a,0),make_fighter(b,1)]
	wins = [0,0]
	round_number = 1
	winner = -1
	reset_round()

func reset_round():
	var kinds = [fighters[0].kind,fighters[1].kind]
	fighters = [make_fighter(kinds[0],0),make_fighter(kinds[1],1)]
	projectiles.clear()
	events.clear()
	freeze = 0
	time_left = 99*60
	phase = "fight" if training else "intro"
	phase_timer = 120
	winner = -1

func move_data(f: Dictionary) -> Dictionary:
	if f.move == "": return {}
	return data.fighters[f.kind].moves[f.move]

func hurtbox(f: Dictionary) -> Rect2:
	if f.state in ["down","getup"] or f.wake_safe>0: return Rect2(f.x,FLOOR,0,0)
	var height = (87.0 if f.crouch else 154.0) * FIGHTER_SCALE
	return Rect2(f.x-27*FIGHTER_SCALE, f.y-height, 54*FIGHTER_SCALE, height)

func pushbox(f: Dictionary) -> Rect2:
	var height=(80 if f.crouch else 145)*FIGHTER_SCALE
	return Rect2(f.x-PUSH_WIDTH*.5,f.y-height,PUSH_WIDTH,height)

func attackbox(f: Dictionary, m: Dictionary) -> Rect2:
	var b = m.box
	var x = f.x+b[0]*FIGHTER_SCALE if f.facing==1 else f.x-(b[0]+b[2])*FIGHTER_SCALE
	return Rect2(x,f.y+b[1]*FIGHTER_SCALE,b[2]*FIGHTER_SCALE,b[3]*FIGHTER_SCALE)

func is_active(f: Dictionary) -> bool:
	if f.move=="": return false
	var m = move_data(f)
	return f.frame>=m.startup and f.frame<m.startup+m.active

func start_move(f: Dictionary, name: String) -> bool:
	if not data.fighters[f.kind].moves.has(name): return false
	f.move=name
	f.frame=0
	f.state="attack"
	f.hit=false
	f.connected=false
	f.queued=""
	f.buffer=0
	return true

func legal_command(f: Dictionary, cmd: String) -> String:
	if cmd in ["lp","hp","lk","hk"]:
		if f.y<FLOOR-1: return "air_"+cmd
		if f.crouch: return "c_"+cmd
	if f.y<FLOOR-1 and cmd in ["throw","special1","special2"]: return ""
	return cmd

func can_cancel(f: Dictionary, target: String) -> bool:
	var m=move_data(f)
	return f.connected and m.has("cancels") and target in m.cancels and f.frame>=m.cancel_start and f.frame<=m.cancel_end

func guard_blocks(f: Dictionary, m: Dictionary, control: Dictionary) -> bool:
	if f.state in ["knockdown","down","getup"]: return false
	if f.y<FLOOR-1 or f.move!="" or f.state=="hit" or f.dash>0 or not control.get("back",false): return false
	if m.level=="throw": return false
	if control.get("down",false): return m.level in ["mid","low"]
	return m.level in ["mid","overhead"]

func step(controls: Array):
	events.clear()
	tick+=1
	for i in 2:
		if controls[i].get("command","")!="":
			fighters[i].queued=controls[i].command
			fighters[i].buffer=7
	if freeze>0:
		freeze-=1
		return
	if phase in ["round_end","results"]:
		settle_after_round()
	if phase=="results": return
	if phase=="intro":
		phase_timer-=1
		if phase_timer<=0:
			phase="fight"
			for f in fighters: f.queued=""
			events.append({"type":"fight"})
		return
	if phase=="round_end":
		phase_timer-=1
		if phase_timer<=0:
			if winner>=0 and wins[winner]>=2:
				phase="results"
				fighters[winner].move=""
				fighters[winner].state="idle"
			else:
				round_number+=1
				reset_round()
		return
	if not training: time_left-=1
	# Facing is locked through an attack and recomputed during neutral or stun.
	for i in 2:
		var f=fighters[i]
		var foe=fighters[1-i]
		if f.move=="" and f.state not in ["knockdown","down","getup"]: f.facing=1 if foe.x>=f.x else -1
		update_fighter(f,controls[i])
	resolve_pushboxes()
	# Snapshot all contacts BEFORE applying damage, allowing true simultaneous trades.
	var contacts: Array=[]
	for i in 2:
		var f=fighters[i]
		var foe=fighters[1-i]
		if is_active(f) and not f.hit:
			var m=move_data(f)
			if m.get("projectile",false):
				projectiles.append({"owner":i,"move":f.move,"x":f.x+f.facing*52*FIGHTER_SCALE,"y":f.y-92*FIGHTER_SCALE,"facing":f.facing,"life":130,"m":m.duplicate(true)})
				f.hit=true
			elif foe.state not in ["down","getup"] and foe.wake_safe==0 and attackbox(f,m).intersects(hurtbox(foe)):
				if m.level!="throw" or (foe.y>=FLOOR and foe.stun<=0 and foe.throw_safe<=0):
					contacts.append({"a":i,"b":1-i,"move":f.move,"m":m.duplicate(true),"block":guard_blocks(foe,m,controls[1-i]),"dir":f.facing,"projectile":false})
					f.hit=true
	for p in projectiles:
		p.x+=p.facing*10.5
		p.life-=1
		var target=fighters[1-p.owner]
		if target.state not in ["down","getup"] and target.wake_safe==0 and Rect2(p.x-20,p.y-17,40,34).intersects(hurtbox(target)):
			contacts.append({"a":p.owner,"b":1-p.owner,"move":p.move,"m":p.m,"block":guard_blocks(target,p.m,controls[1-p.owner]),"dir":p.facing,"projectile":true})
			p.life=0
	projectiles=projectiles.filter(func(p): return p.life>0 and p.x>LEFT-80 and p.x<RIGHT+80)
	for c in contacts: apply_contact(c)
	resolve_pushboxes()
	if training:
		for f in fighters:
			if f.health<=0 or (f.stun==0 and tick-f.last_hit>100): f.health=MAX_HEALTH
	elif fighters[0].health<=0 or fighters[1].health<=0 or time_left<=0:
		end_round()

func update_fighter(f: Dictionary, control: Dictionary):
	var grounded=f.y>=FLOOR
	f.wake_safe=maxi(0,f.wake_safe-1)
	f.throw_safe=maxi(0,f.throw_safe-1)
	f.buffer=maxi(0,f.buffer-1)
	if f.buffer==0: f.queued=""
	f.guard=false
	f.walk=0.0
	if f.state in ["down","getup"]:
		f.queued="";f.buffer=0;f.crouch=false
		f.y=FLOOR;f.vy=0.0;f.vx=0.0
		f.down_timer-=1
		if f.down_timer<=0:
			if f.state=="down":
				f.state="getup";f.down_timer=f.rise_frames
			else:
				f.state="idle";f.stun=0;f.throw_safe=12;f.wake_safe=3
		f.up_prev=control.get("up",false)
		return
	if f.state=="knockdown":
		f.queued="";f.buffer=0;f.crouch=false
		f.x=clampf(f.x+f.vx,LEFT,RIGHT)
		f.y+=f.vy;f.vy+=GRAVITY
		f.vx*=0.985
		if f.y>=FLOOR:
			f.y=FLOOR;f.vy=0.0;f.vx=0.0
			f.state="down";f.down_timer=f.down_frames
			events.append({"type":"land","owner":f.slot,"hard":true,"ko":false})
		f.up_prev=control.get("up",false)
		return
	if f.stun>0:
		f.stun-=1
		if grounded: f.x+=f.vx
		f.vx*=0.84
		if f.stun==0:
			f.state="idle"
			f.throw_safe=8
	else:
		if f.move=="":
			f.crouch=grounded and control.get("down",false)
			f.guard=grounded and control.get("back",false)
			if control.get("up",false) and not f.up_prev and grounded:
				f.vy=-25.5
				f.vx=control.get("dx",0)*5.6
				f.dash=0
				f.crouch=false
				f.y-=0.1
				grounded=false
				events.append({"type":"jump","owner":f.slot})
			if grounded and not f.crouch and f.dash==0:
				f.walk=float(control.get("dx",0))
				f.x+=f.walk*float(data.fighters[f.kind].speed)
		if f.queued!="":
			var cmd=legal_command(f,f.queued)
			if cmd in ["dash_forward","dash_back"] and grounded and f.move=="" and f.dash==0:
				f.dash=9
				f.dash_vx=f.facing*(10.5 if cmd=="dash_forward" else -11.0)
				f.queued=""
				f.buffer=0
				events.append({"type":"dash","owner":f.slot})
			elif cmd!="" and cmd not in ["dash_forward","dash_back"] and (f.move=="" or can_cancel(f,cmd)) and f.dash<=5:
				f.dash=0
				start_move(f,cmd)
		if f.dash>0:
			f.x+=f.dash_vx
			f.walk=signf(f.dash_vx)
			f.guard=false
			f.dash-=1
		if not grounded and f.move=="" and control.get("dx",0)!=0:
			f.vx=move_toward(f.vx,control.dx*5.6,0.40)
	if f.move!="":
		var m=move_data(f)
		if f.frame>=m.startup and f.frame<m.startup+m.active:
			f.x+=m.get("travel",0)*f.facing
		if m.get("rise",false) and f.frame==m.startup:
			f.vy=-11.0
			f.y-=0.1
			f.vx=1.8*f.facing
		f.frame+=1
		if f.frame==int(m.startup):
			events.append({"type":"attack","move":f.move,"owner":f.slot,"fighter":f.kind,"style":data.fighters[f.kind].style})
		if f.frame>=m.startup+m.active+m.recovery:
			f.move=""
			f.state="idle"
	if f.y<FLOOR or f.vy<0:
		f.x+=f.vx
		f.y+=f.vy
		f.vy+=GRAVITY
		if f.y>=FLOOR:
			events.append({"type":"land","owner":f.slot,"hard":f.state=="hit","ko":false})
			f.y=FLOOR
			f.vy=0.0
			f.vx=0.0
			if f.move.begins_with("air_"):
				f.move=""
				f.stun=maxi(f.stun,4)
	else:
		f.y=FLOOR
		f.vy=0.0
	f.x=clampf(f.x,LEFT,RIGHT)
	f.up_prev=control.get("up",false)
	if f.stun==0 and tick-f.last_hit>65: f.combo=0

func resolve_pushboxes():
	var a=fighters[0]
	var b=fighters[1]
	if a.state in ["down","getup","knockdown"] or b.state in ["down","getup","knockdown"]: return
	if not pushbox(a).intersects(pushbox(b)): return
	var direction=1 if b.x>=a.x else -1
	var overlap=PUSH_WIDTH-absf(a.x-b.x)
	a.x=clampf(a.x-direction*overlap*0.5,LEFT,RIGHT)
	b.x=clampf(b.x+direction*overlap*0.5,LEFT,RIGHT)
	var remainder=PUSH_WIDTH-absf(a.x-b.x)
	if remainder>0:
		if a.x==LEFT or a.x==RIGHT: b.x=clampf(b.x+direction*remainder,LEFT,RIGHT)
		else: a.x=clampf(a.x-direction*remainder,LEFT,RIGHT)

func apply_contact(c: Dictionary):
	var a=fighters[c.a]
	var b=fighters[c.b]
	var m=c.m
	a.connected=true
	b.move=""
	b.dash=0
	b.frame=0
	b.last_hit=tick
	b.vx=c.dir*m.pushback*0.18
	if c.block:
		b.stun=int(m.blockstun)
		b.state="block"
		b.health=maxi(1,b.health-int(m.get("chip",0)))
		# Guard contact opens spacing instead of allowing continuous body pressure.
		b.x=clampf(b.x+c.dir*10.0,LEFT,RIGHT)
		if not c.projectile: a.x=clampf(a.x-c.dir*8.0,LEFT,RIGHT)
	else:
		if b.stun>0 and b.state=="hit": b.combo+=1
		else: b.combo=1
		var scale=maxf(0.5,1.0-(b.combo-1)*0.12)
		b.health=maxi(0,b.health-int(m.damage*scale))
		b.stun=int(m.hitstun)
		b.state="hit"
		if m.get("knockdown",false) or m.get("launch",false) or b.y<FLOOR or b.health<=0:
			b.state="knockdown"
			b.crouch=false
			b.vx=c.dir*float(m.get("knockback_speed",8.5))
			b.vy=-float(m.get("launch_speed",15.5))
			b.y=minf(b.y,FLOOR-1)
			b.down_frames=int(m.get("down_frames",22))
			b.rise_frames=int(m.get("rise_frames",14))
	var at_corner=b.x<=LEFT+2 or b.x>=RIGHT-2
	if at_corner and not c.projectile: a.x=clampf(a.x-c.dir*m.pushback*0.5,LEFT,RIGHT)
	freeze=maxi(freeze,int(m.hitstop))
	events.append({"type":"block" if c.block else "hit","move":c.get("move","lp"),"fighter":a.kind,"owner":c.a,"x":b.x-c.dir*18*FIGHTER_SCALE,"y":b.y-(55 if m.level=="low" else 105)*FIGHTER_SCALE,"heavy":m.damage>=100,"combo":b.combo})

func end_round():
	projectiles.clear()
	phase="round_end"
	phase_timer=130
	if fighters[0].health==fighters[1].health:
		winner=-1
		last_result="DOUBLE KO" if fighters[0].health==0 else "DRAW"
	else:
		winner=0 if fighters[0].health>fighters[1].health else 1
		wins[winner]+=1
		last_result="TIME UP" if time_left<=0 else "K.O."
		fighters[1-winner].state="ko"
	for f in fighters:
		f.move=""
		f.dash=0
		f.stun=0
		f.walk=0.0
		f.guard=false
		f.crouch=false
		if f.health<=0: f.state="ko"
		elif f.slot==winner: f.state="idle"
	events.append({"type":"ko"})

func settle_after_round():
	# Round-end presentation must never suspend airborne bodies or the winner.
	for f in fighters:
		var airborne=f.y<FLOOR or f.vy<0
		if airborne:
			f.x=clampf(f.x+f.vx,LEFT,RIGHT)
			f.y+=f.vy
			f.vy+=GRAVITY
			f.vx*=0.985 if f.state=="ko" else 0.92
		if f.y>=FLOOR:
			if airborne: events.append({"type":"land","owner":f.slot,"ko":f.state=="ko","hard":f.state=="ko"})
			f.y=FLOOR
			f.vy=0.0
			f.vx=0.0
