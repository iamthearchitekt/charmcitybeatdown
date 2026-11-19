extends RefCounted
## Deterministic combat. All timing is integer simulation frames; drawing never controls collision.
const Grapples=preload("res://scripts/grapple_sequences.gd")
const CollisionProfiles=preload("res://scripts/collision_profiles.gd")
var collision=CollisionProfiles.new()
const FLOOR = 622.0
const LEFT = 84.0
const RIGHT = 1196.0
const GRAVITY = 1.10
const JUMP_SPEED = 22.5
const JUMP_GRAVITY = .97
const MAX_HEALTH = 1000
const ELECTRIC_REACTION_TICKS = 15
const FIRE_REACTION_TICKS = 26
const FIGHTER_SCALE = 2.093
const PUSH_WIDTH = 50.0 * FIGHTER_SCALE
const BACKSTEP_FRAMES = 8
const BACKSTEP_DISTANCE = 36.0
const GRAB_FRAMES = 18
const PROJECTILE_ORIGIN_X = 72.0
const DIZZY_MIN_COMBO_HITS = 4
const DIZZY_MIN_COMBO_DAMAGE = 280
const DIZZY_DURATION = 180
const DIZZY_MIN_DURATION = 60
const DIZZY_IMMUNITY = 180
var data: Dictionary
var fighters: Array = []
var projectiles: Array = []
var events: Array = []
var tick: int = 0
var freeze: int = 0
var time_left: int = 99*60
var phase: String = "intro"
var phase_timer: int = 150
var winner: int = -1
var wins: Array = [0,0]
var round_number: int = 1
var training: bool = false
var dummy: int = 0
var last_result: String = ""
var scores:Array=[0,0]
var round_rewards:Array=[]

func _init():
	data=load_move_tables()
	new_match(0, 1)

static func load_move_tables()->Dictionary:
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/moves.json"))
	for fighter in tables.fighters:
		for prefix in ["","c_","air_"]:
			for limb in ["p","k"]:
				var light:Dictionary=fighter.moves[prefix+"l"+limb]
				var heavy:Dictionary=fighter.moves[prefix+"h"+limb]
				var medium:Dictionary=light.duplicate(true)
				medium.name="Medium Punch" if limb=="p" else "Medium Kick"
				for field in ["startup","active","recovery","damage","hitstun","blockstun","pushback","hitstop"]:
					medium[field]=roundi(lerpf(light[field],heavy[field],.5))
				medium.cancels=light.get("cancels",[]).filter(func(move): return move.begins_with("special"))
				medium.cancel_start=medium.startup
				medium.cancel_end=medium.startup+medium.active+3
				# Use the approved limb poses, with separate medium timing and damage.
				medium.pose_move=prefix+("hp" if prefix=="" and limb=="p" else "l"+limb)
				medium.box=fighter.moves[medium.pose_move].box.duplicate()
				fighter.moves[prefix+"m"+limb]=medium
	return tables

func make_fighter(kind: int, slot: int) -> Dictionary:
	return {"kind":kind,"slot":slot,"x":400.0+480.0*slot,"y":FLOOR,"vx":0.0,"vy":0.0,"air_gravity":GRAVITY,
		"facing":1 if slot==0 else -1,"health":MAX_HEALTH,"state":"idle","move":"","frame":0,
		"stun":0,"crouch":false,"guard":false,"hit":false,"connected":false,"queued":"","walk_phase":0.0,"pose_tick":0,"element_hit":"","element_timer":0,
		"buffer":0,"combo":0,"last_hit":-999,"up_prev":false,"throw_safe":0,"walk":0.0,
		"dash":0,"dash_vx":0.0,"down_timer":0,"down_frames":22,"rise_frames":14,"wake_safe":0,
		"backstep":0,"backstep_used":false,"backstep_pose":-1,"bounce_speed":0.0,"bounced":false,
		"throw_target":-1,"grabbed_by":-1,"grab_frame":0,"throw_dir":0,"throw_back":false,
		"throw_rotation":0.0,"throw_flight":false,"grapple_pose":-1,"grapple_role":"",
		"grab_origin_x":0.0,"grab_origin_y":FLOOR,"grab_facing":1,"grab_hits":0,
		"grab_escape":0,"grab_last_dir":5,"grab_mash_cooldown":0,"grab_pulse_flash":0,"grab_damage":0,"next_hit_frame":0,
		"dizzy_build":0,"dizzy_pending":false,"dizzy_timer":0,"dizzy_age":0,
		"dizzy_immunity":0,"dizzy_last_input":5,"dizzy_input_cooldown":0}

func new_match(a: int, b: int, is_training: bool = false):
	training = is_training
	scores=[0,0];round_rewards=[]
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
	phase_timer = 150
	winner = -1

func move_data(f: Dictionary) -> Dictionary:
	if f.move == "": return {}
	return data.fighters[f.kind].moves[f.move]

func hurtboxes(f:Dictionary)->Array:
	if f.state in ["down","getup"] or f.wake_safe>0 or f.grabbed_by>=0: return []
	return collision.world_parts(f,move_data(f),FIGHTER_SCALE)

func hurtbox(f:Dictionary)->Rect2:
	return CollisionProfiles.bounds(hurtboxes(f))

func attackboxes(f:Dictionary,m:Dictionary)->Array:
	if not is_active(f) or m.get("projectile",false): return []
	if m.has("element_area"):
		var parts=[]
		for b in m.element_area:
			parts.append(Rect2(f.x+(b[0] if f.facing==1 else -(b[0]+b[2]))*FIGHTER_SCALE,f.y+b[1]*FIGHTER_SCALE,b[2]*FIGHTER_SCALE,b[3]*FIGHTER_SCALE))
		return parts
	if m.level=="throw":
		var b=m.box
		return [Rect2(f.x+(b[0] if f.facing==1 else -(b[0]+b[2]))*FIGHTER_SCALE,f.y+b[1]*FIGHTER_SCALE,b[2]*FIGHTER_SCALE,b[3]*FIGHTER_SCALE)]
	return collision.world_parts(f,m,FIGHTER_SCALE,true)

func regions_overlap(a:Array,b:Array)->Rect2:
	return CollisionProfiles.overlap(a,b)

func touches_body(box:Rect2,f:Dictionary)->bool:
	return regions_overlap([box],hurtboxes(f)).has_area()

func pushbox(f: Dictionary) -> Rect2:
	# The pushbox covers the torso. Jumping over the shoulders remains possible
	# at the same jump height, while strike regions scale with the full sprite.
	var height=146.0 if f.crouch else 226.0
	return Rect2(f.x-PUSH_WIDTH*.5,f.y-height,PUSH_WIDTH,height)

func attackbox(f:Dictionary,m:Dictionary)->Rect2:
	# Compatibility/broad-phase envelope only. Contacts always test the individual parts.
	return CollisionProfiles.bounds(attackboxes(f,m))

func is_active(f: Dictionary) -> bool:
	if f.move=="": return false
	var m = move_data(f)
	return f.frame>=m.startup and f.frame<m.startup+m.active

func start_move(f: Dictionary, name: String) -> bool:
	if f.state=="dizzy" or f.dizzy_pending: return false
	if not data.fighters[f.kind].moves.has(name): return false
	f.move=name
	f.grapple_role="";f.grapple_pose=-1
	f.frame=0
	f.state="attack"
	f.hit=false
	f.connected=false
	f.next_hit_frame=0
	var move:Dictionary=data.fighters[f.kind].moves[name]
	if name in ["special3","special4","special5","special6"] or move.has("element"):
		f.crouch=bool(move.get("crouching_cast",false));f.vx=0.0
	f.queued=""
	f.buffer=0
	f.backstep=0
	f.backstep_pose=-1
	f.guard=false
	if data.fighters[f.kind].moves[name].get("grapple",false):
		f.throw_dir=-f.facing if f.throw_back else f.facing
	return true

func legal_command(f: Dictionary, cmd: String) -> String:
	if cmd in ["lp","mp","hp","lk","mk","hk"]:
		if f.y<FLOOR-1: return "air_"+cmd
		if f.crouch: return "c_"+cmd
	if cmd=="throw" and f.y<FLOOR-1:
		return "air_throw" if data.fighters[f.kind].moves.has("air_throw") else ""
	if f.y>=FLOOR-1 and cmd=="air_throw": return ""
	if f.y<FLOOR-1 and (cmd=="command_grab" or cmd.begins_with("special")): return ""
	return cmd

func can_cancel(f: Dictionary, target: String) -> bool:
	var m=move_data(f)
	return f.connected and m.has("cancels") and target in m.cancels and f.frame>=m.cancel_start and f.frame<=m.cancel_end

func guard_blocks(f: Dictionary, m: Dictionary, control: Dictionary) -> bool:
	if f.state in ["knockdown","down","getup","dizzy"] or f.dizzy_pending: return false
	if f.y<FLOOR-1 or f.move!="" or f.state=="hit" or f.dash>0 or f.backstep>0 or not control.get("back",false): return false
	if m.level=="throw": return false
	if control.get("down",false): return m.level in ["mid","low"]
	return m.level in ["mid","overhead"]

func step(controls: Array):
	events.clear()
	tick+=1
	for i in 2:
		if phase=="fight" and fighters[i].state!="dizzy" and not fighters[i].dizzy_pending and controls[i].get("command","")!="":
			fighters[i].queued=controls[i].command
			fighters[i].buffer=14 if controls[i].command in ["special3","special4"] else 7
	if freeze>0:
		freeze-=1
		return
	for f in fighters:
		f.pose_tick+=1
		f.element_timer=maxi(0,f.element_timer-1)
		if f.element_timer==0: f.element_hit=""
	if phase in ["round_end","results"]:
		settle_after_round()
	if phase=="results": return
	if phase=="intro":
		phase_timer-=1
		if phase_timer==110: events.append({"type":"round","number":round_number})
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
	advance_grabs(controls)
	# Facing is locked through an attack and recomputed during neutral or stun.
	for i in 2:
		var f=fighters[i]
		var foe=fighters[1-i]
		if f.move=="" and f.grabbed_by<0 and not f.throw_flight and f.state not in ["knockdown","down","getup"]: f.facing=1 if foe.x>=f.x else -1
		update_fighter(f,controls[i])
	resolve_pushboxes()
	# Snapshot all contacts BEFORE applying damage, allowing true simultaneous trades.
	var contacts: Array=[]
	for i in 2:
		var f=fighters[i]
		var foe=fighters[1-i]
		if is_active(f) and not f.hit and f.grabbed_by<0 and f.throw_target<0:
			var m=move_data(f)
			if m.get("projectile",false):
				projectiles.append(make_projectile(f,m))
				events.append({"type":"projectile_spawn","owner":i,"fighter":f.kind})
				f.hit=true
			elif foe.state not in ["down","getup"] and foe.wake_safe==0 and regions_overlap(attackboxes(f,m),hurtboxes(foe)).has_area():
				if m.level!="throw" or valid_grab(f,foe):
					contacts.append({"a":i,"b":1-i,"move":f.move,"m":m.duplicate(true),"block":guard_blocks(foe,m,controls[1-i]),"dir":f.facing,"projectile":false,"impact":regions_overlap(attackboxes(f,m),hurtboxes(foe)).get_center()})
					f.hit=true
					f.next_hit_frame=f.frame+int(m.get("rehit_interval",0))
	for p in projectiles:
		p.previous_x=p.x
		p.x+=p.facing*projectile_speed(p)
		p.life-=1
	# Resolve opposing shots before fighter contacts so cancelled shots cannot hit.
	for i in projectiles.size():
		var a=projectiles[i]
		if a.life<=0: continue
		for j in range(i+1,projectiles.size()):
			var b=projectiles[j]
			if b.life<=0 or a.owner==b.owner or not projectiles_clash(a,b): continue
			a.life=0;b.life=0
			events.append({"type":"projectile_clash","x":(a.x+b.x)*.5,"y":(a.y+b.y)*.5})
			break
	for p in projectiles:
		if p.life<=0: continue
		var target=fighters[1-p.owner]
		var projectile_box=projectile_rect(p)
		if target.state not in ["down","getup"] and target.wake_safe==0 and touches_body(projectile_box,target):
			contacts.append({"a":p.owner,"b":1-p.owner,"move":p.move,"m":p.m,"block":guard_blocks(target,p.m,controls[1-p.owner]),"dir":p.facing,"projectile":true,"impact":regions_overlap([projectile_box],hurtboxes(target)).get_center()})
			p.life=0
	projectiles=projectiles.filter(func(p): return p.life>0 and p.x>LEFT-80 and p.x<RIGHT+80)
	for c in contacts: apply_contact(c)
	resolve_pushboxes()
	if training:
		for f in fighters:
			if f.health<=0 or (f.stun==0 and f.state!="dizzy" and not f.dizzy_pending and tick-f.last_hit>100): f.health=MAX_HEALTH
	elif fighters[0].health<=0 or fighters[1].health<=0 or time_left<=0:
		end_round()

static func projectile_speed(shot:Dictionary)->float:
	return float(shot.get("m",{}).get("projectile_speed",10.5))

static func make_projectile(f:Dictionary,m:Dictionary)->Dictionary:
	return {"owner":f.slot,"move":f.move,"x":f.x+f.facing*float(m.get("projectile_origin_x",PROJECTILE_ORIGIN_X))*FIGHTER_SCALE,
		"y":f.y-float(m.get("projectile_origin_y",92.0))*FIGHTER_SCALE,"facing":f.facing,"life":130,"m":m.duplicate(true)}

static func projectile_rect(shot:Dictionary)->Rect2:
	var size:Array=shot.get("m",{}).get("projectile_size",[40.0,34.0])
	var extent=Vector2(size[0],size[1])
	return Rect2(Vector2(shot.x,shot.y)-extent*.5,extent)

func projectiles_clash(a:Dictionary,b:Dictionary)->bool:
	var a_box=projectile_rect(a)
	var b_box=projectile_rect(b)
	if a_box.end.y<=b_box.position.y or b_box.end.y<=a_box.position.y: return false
	# Sweep the relative motion as well as testing overlap at the end of the step.
	var before=float(a.previous_x-b.previous_x)
	var after=float(a.x-b.x)
	var reach=(a_box.size.x+b_box.size.x)*.5
	return minf(before,after)<reach and maxf(before,after)>-reach

func clear_dizzy(f:Dictionary,protect:bool=false):
	f.dizzy_build=0;f.dizzy_pending=false;f.dizzy_timer=0;f.dizzy_age=0
	f.dizzy_last_input=5;f.dizzy_input_cooldown=0
	f.dizzy_immunity=DIZZY_IMMUNITY if protect else 0

func record_dizzy_damage(f:Dictionary,damage:int):
	if f.health<=0:
		clear_dizzy(f)
		return
	if f.dizzy_immunity>0 or f.dizzy_pending: return
	f.dizzy_build+=damage
	if f.combo>=DIZZY_MIN_COMBO_HITS and f.dizzy_build>=DIZZY_MIN_COMBO_DAMAGE:
		f.dizzy_pending=true

func begin_dizzy(f:Dictionary):
	f.state="dizzy";f.dizzy_pending=false;f.dizzy_build=0
	f.dizzy_timer=DIZZY_DURATION;f.dizzy_age=0;f.stun=0
	f.move="";f.queued="";f.buffer=0;f.combo=0
	f.crouch=false;f.guard=false;f.vx=0.0;f.vy=0.0;f.dash=0
	f.dizzy_last_input=5;f.dizzy_input_cooldown=0
	events.append({"type":"dizzy","owner":f.slot})

func update_dizzy(f:Dictionary,control:Dictionary):
	f.queued="";f.buffer=0;f.guard=false;f.crouch=false
	f.vx=0.0;f.vy=0.0;f.y=FLOOR
	f.dizzy_age+=1;f.dizzy_timer-=1
	f.dizzy_input_cooldown=maxi(0,f.dizzy_input_cooldown-1)
	var direction=(2 if control.get("down",false) else (8 if control.get("up",false) else 5))+int(control.get("dx",0))
	var changed=direction!=5 and direction!=f.dizzy_last_input
	var tapped=not control.get("buttons",[]).is_empty() if control.has("buttons") else control.get("command","")!=""
	if (changed or tapped) and f.dizzy_input_cooldown==0:
		f.dizzy_timer=maxi(DIZZY_MIN_DURATION-f.dizzy_age,f.dizzy_timer-4)
		f.dizzy_input_cooldown=3
	f.dizzy_last_input=direction
	f.up_prev=control.get("up",false)
	if f.dizzy_timer<=0:
		clear_dizzy(f,true)
		f.state="idle"

func update_fighter(f: Dictionary, control: Dictionary):
	var start_x=float(f.x)
	var profile:Dictionary=data.fighters[f.kind]
	var air_speed=5.6*float(profile.get("air_speed_scale",1.0))
	var retreat_scale=float(profile.get("retreat_scale",1.0))
	f.dizzy_immunity=maxi(0,f.dizzy_immunity-1)
	if f.grabbed_by>=0 or f.throw_target>=0:
		f.queued="";f.buffer=0;f.guard=false;f.walk=0.0
		return
	var grounded=f.y>=FLOOR
	f.wake_safe=maxi(0,f.wake_safe-1)
	f.throw_safe=maxi(0,f.throw_safe-1)
	f.buffer=maxi(0,f.buffer-1)
	if f.buffer==0: f.queued=""
	f.guard=false
	f.walk=0.0
	f.backstep_pose=-1
	if not control.get("back",false):
		f.backstep=0
		f.backstep_used=false
	if f.state in ["down","getup"]:
		f.queued="";f.buffer=0;f.crouch=false
		f.y=FLOOR;f.vy=0.0;f.vx=0.0
		f.down_timer-=1
		if f.down_timer<=0:
			if f.state=="down":
				f.state="getup";f.down_timer=f.rise_frames
			else:
				f.state="idle";f.stun=0;f.throw_safe=12;f.wake_safe=3
				f.dizzy_build=0
				if f.dizzy_pending:
					begin_dizzy(f)
					f.throw_safe=0;f.wake_safe=0
		f.up_prev=control.get("up",false)
		return
	if f.state=="dizzy":
		update_dizzy(f,control)
		return
	if f.state=="knockdown":
		f.queued="";f.buffer=0;f.crouch=false
		f.x=clampf(f.x+f.vx,LEFT,RIGHT)
		f.y+=f.vy;f.vy+=GRAVITY
		f.vx*=0.985
		if f.y>=FLOOR:
			f.y=FLOOR;f.vy=0.0;f.vx=0.0
			f.throw_flight=false;f.throw_rotation=0.0
			if f.bounce_speed>0 and not f.bounced:
				f.y=FLOOR-0.1;f.vy=-f.bounce_speed
				f.bounced=true
				events.append({"type":"bounce","owner":f.slot})
				f.up_prev=control.get("up",false)
				return
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
			f.dizzy_build=0
			f.throw_safe=8
	else:
		if f.move=="":
			f.crouch=grounded and control.get("down",false)
			f.guard=grounded and control.get("back",false)
			if control.get("up",false) and not f.up_prev and grounded and f.queued!="special4":
				f.vy=-JUMP_SPEED
				f.air_gravity=JUMP_GRAVITY
				f.vx=control.get("dx",0)*air_speed
				f.dash=0
				f.backstep=0
				f.backstep_used=control.get("back",false)
				f.guard=false
				f.crouch=false
				f.y-=0.1
				grounded=false
				events.append({"type":"jump","owner":f.slot})
			if grounded and not f.crouch and f.dash==0:
				if control.get("back",false) and control.get("dx",0)*f.facing<0:
					if not f.backstep_used:
						f.backstep=BACKSTEP_FRAMES
						f.backstep_used=true
					if f.backstep>0 and f.queued!="dash_back":
						f.backstep_pose=mini(2,int((BACKSTEP_FRAMES-f.backstep)/3))
						f.walk=-f.facing
						f.x-=f.facing*BACKSTEP_DISTANCE*retreat_scale/BACKSTEP_FRAMES
						f.backstep-=1
						f.guard=false
				else:
					f.walk=float(control.get("dx",0))
					f.x+=f.walk*float(profile.speed)
			elif grounded and f.crouch and control.get("back",false):
				f.backstep=0
				f.backstep_used=true
		if f.queued!="":
			var cmd=legal_command(f,f.queued)
			f.throw_back=control.get("back",false)
			if cmd in ["dash_forward","dash_back"] and grounded and f.move=="" and f.dash==0:
				f.dash=9
				f.dash_vx=f.facing*(10.5 if cmd=="dash_forward" else -11.0*retreat_scale)*float(profile.get("dash_speed_scale",1.0))
				f.backstep=0
				f.backstep_pose=-1
				f.backstep_used=control.get("back",false)
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
			f.vx=move_toward(f.vx,control.dx*air_speed,0.40)
	if f.move!="":
		var m=move_data(f)
		if m.get("rehit_interval",0)>0 and f.hit and f.frame>=f.next_hit_frame: f.hit=false
		if f.frame>=m.startup and f.frame<m.startup+m.active:
			f.x+=m.get("travel",0)*f.facing
			if m.has("hover_height"):
				f.y=FLOOR-float(m.hover_height);f.vy=0.0;f.vx=0.0
		if m.get("rise",false) and f.frame==m.startup:
			f.vy=-float(m.get("rise_speed",11.0))
			f.y-=0.1
			f.vx=float(m.get("rise_forward",1.8))*f.facing
		f.frame+=1
		if f.frame==int(m.startup):
			events.append({"type":"attack","move":f.move,"owner":f.slot,"fighter":f.kind,"style":data.fighters[f.kind].style,"element":m.get("element","")})
		elif m.get("element","")=="electric" and is_active(f):
			var frames_active=int(f.frame-m.startup)
			if frames_active%12==0: events.append({"type":"electric_pulse"})
		if f.frame>=m.startup+m.active+m.recovery:
			f.move=""
			f.grapple_pose=-1;f.grapple_role=""
			f.state="idle"
	if f.y<FLOOR or f.vy<0:
		f.x+=f.vx
		f.y+=f.vy
		f.vy+=f.air_gravity
		if f.y>=FLOOR:
			events.append({"type":"land","owner":f.slot,"hard":f.state=="hit","ko":false})
			f.y=FLOOR
			f.vy=0.0
			f.vx=0.0
			f.air_gravity=GRAVITY
			if f.move.begins_with("air_"):
				f.move=""
				f.stun=maxi(f.stun,4)
	else:
		f.y=FLOOR
		f.vy=0.0
		f.air_gravity=GRAVITY
	f.x=clampf(f.x,LEFT,RIGHT)
	if f.y>=FLOOR and f.move=="" and f.state=="idle" and f.dash==0 and f.backstep_pose<0 and absf(f.walk)>0:
		f.walk_phase+=absf(f.x-start_x)/44.0
	f.up_prev=control.get("up",false)
	if f.stun==0 and tick-f.last_hit>65: f.combo=0

func resolve_pushboxes():
	var a=fighters[0]
	var b=fighters[1]
	if a.grabbed_by>=0 or b.grabbed_by>=0 or a.throw_target>=0 or b.throw_target>=0: return
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

func valid_grab(a:Dictionary,b:Dictionary)->bool:
	if b.stun>0 or b.throw_safe>0 or b.wake_safe>0 or b.state in ["down","getup","knockdown"]: return false
	if a.move=="air_throw": return a.y<FLOOR-1 and b.y<FLOOR-1
	return a.y>=FLOOR-1 and b.y>=FLOOR-1

func begin_grab(c:Dictionary):
	var a=fighters[c.a];var b=fighters[c.b]
	a.connected=true;a.hit=true;a.throw_target=b.slot;a.grab_frame=0
	a.grab_origin_x=a.x;a.grab_origin_y=a.y;a.grab_facing=a.facing
	a.grab_hits=0;a.grab_damage=0;a.grab_escape=0;a.grab_last_dir=5;a.grab_mash_cooldown=0;a.grab_pulse_flash=0
	if a.throw_dir==0: a.throw_dir=c.dir
	b.grabbed_by=a.slot;b.throw_flight=false;b.throw_rotation=0.0
	b.move="";b.queued="";b.buffer=0;b.frame=0;b.state="grabbed"
	b.vx=0.0;b.vy=0.0;b.crouch=false;b.guard=false;b.dash=0;b.backstep=0
	clear_dizzy(b,true)
	Grapples.place(a,b,FIGHTER_SCALE,FLOOR,LEFT,RIGHT)
	freeze=maxi(freeze,2)
	events.append({"type":"grab","owner":a.slot,"fighter":a.kind,"move":a.move})

func apply_contact(c: Dictionary):
	var a=fighters[c.a]
	var b=fighters[c.b]
	var m=c.m
	var health_before=int(b.health)
	# The first successful grip owns the pair; a snapshotted counter-grab cannot
	# make the same two bodies throw each other simultaneously.
	if a.grabbed_by>=0 or b.grabbed_by>=0 or a.throw_target>=0 or b.throw_target>=0: return
	if m.level=="throw":
		begin_grab(c)
		return
	if not c.block and b.state=="dizzy": clear_dizzy(b,true)
	var first_contact=not a.connected
	a.connected=true
	b.move=""
	b.dash=0
	b.backstep=0
	b.backstep_used=true
	b.backstep_pose=-1
	b.frame=0
	b.last_hit=tick
	var move=String(c.get("move",""))
	var strong_impact=move.begins_with("special") or move in ["hp","hk","c_hp","c_hk","air_hp","air_hk"]
	var repeated_hit=int(m.get("rehit_interval",0))>0
	b.vx=c.dir*m.pushback*0.18
	if c.block:
		b.dizzy_build=0
		b.stun=int(m.blockstun)
		b.state="block"
		b.health=maxi(1,b.health-int(m.get("chip",0)))
		# Strong blocks spend more of their pushback sliding during blockstun.
		if strong_impact: b.vx+=c.dir*(1.5 if repeated_hit else 2.6)
		var slide_scale=float(data.fighters[b.kind].get("guard_slide_scale",1.0))
		b.vx*=slide_scale
		b.x=clampf(b.x+c.dir*(4.0 if strong_impact else 10.0)*slide_scale,LEFT,RIGHT)
		if not c.projectile: a.x=clampf(a.x-c.dir*8.0,LEFT,RIGHT)
	else:
		if b.stun>0 and b.state=="hit": b.combo+=1
		else:
			b.combo=1
			b.dizzy_build=0
		var scale=maxf(0.5,1.0-(b.combo-1)*0.12)
		b.health=maxi(0,b.health-int(m.damage*scale))
		record_dizzy_damage(b,health_before-int(b.health))
		b.stun=int(m.hitstun)
		b.state="hit"
		if strong_impact and not repeated_hit: b.vx+=c.dir*1.5
		b.element_hit=m.get("element","")
		b.element_timer=(FIRE_REACTION_TICKS if b.element_hit=="fire" else ELECTRIC_REACTION_TICKS) if b.element_hit!="" else 0
		var plasma_hit=c.projectile and m.get("projectile",false) and m.get("projectile_knockdown",true)
		if plasma_hit or m.get("knockdown",false) or m.get("launch",false) or b.y<FLOOR or b.health<=0 or b.dizzy_pending:
			b.state="knockdown"
			b.crouch=false
			b.vx=c.dir*float(m.get("knockback_speed",5.5 if plasma_hit else 8.5))
			b.vy=-float(m.get("launch_speed",7.5 if plasma_hit else 15.5))
			b.y=minf(b.y,FLOOR-1)
			b.down_frames=int(m.get("down_frames",22))
			b.rise_frames=int(m.get("rise_frames",14))
			b.bounce_speed=float(m.get("bounce_speed",0.0))
			b.bounced=false
	var at_corner=b.x<=LEFT+2 or b.x>=RIGHT-2
	if not training: scores[c.a]+=maxi(0,health_before-int(b.health))*10
	if at_corner and not c.projectile: a.x=clampf(a.x-c.dir*m.pushback*0.5,LEFT,RIGHT)
	freeze=maxi(freeze,int(m.hitstop))
	events.append({"type":"block" if c.block else "hit","move":c.get("move","lp"),"fighter":a.kind,"owner":c.a,"x":c.get("impact",Vector2(b.x-c.dir*18*FIGHTER_SCALE,b.y-105*FIGHTER_SCALE)).x,"y":c.get("impact",Vector2(b.x,b.y-(55 if m.level=="low" else 105)*FIGHTER_SCALE)).y,"heavy":m.damage>=100,"impact_recovery":strong_impact and (not repeated_hit or first_contact),"combo":b.combo,"element":m.get("element","")})

func position_grab(a:Dictionary,b:Dictionary):
	Grapples.place(a,b,FIGHTER_SCALE,FLOOR,LEFT,RIGHT)

func grapple_damage(a:Dictionary,b:Dictionary,amount:int,final:bool):
	if phase!="fight" or b.health<=0: return
	var before=int(b.health)
	b.health=maxi(0,b.health-amount);b.last_hit=tick
	a.grab_damage+=before-int(b.health);a.grab_hits+=1;b.combo=a.grab_hits
	a.grab_pulse_flash=4
	if not training: scores[a.slot]+=(before-int(b.health))*10
	freeze=maxi(freeze,5 if final else 3)
	events.append({"type":"hit","move":a.move,"grapple":true,"fighter":a.kind,"owner":a.slot,"x":b.x,"y":FLOOR-14 if final else b.y-92*FIGHTER_SCALE,"heavy":final,"combo":b.combo})

func release_grab(a:Dictionary,b:Dictionary,escaped:bool=false):
	a.throw_target=-1;b.grabbed_by=-1
	a.y=FLOOR;a.vx=0.0;a.vy=0.0
	a.frame=int(move_data(a).startup+move_data(a).active)
	b.y=FLOOR;b.vx=0.0;b.vy=0.0;b.throw_rotation=0.0;b.throw_flight=false
	b.grapple_pose=-1;b.grapple_role="";b.facing=-a.throw_dir
	b.throw_safe=24;b.crouch=false
	if b.health<=0: b.state="ko";b.stun=0
	elif escaped: b.state="hit";b.stun=10
	else: b.state="down";b.down_timer=24;b.rise_frames=14;b.stun=0
	events.append({"type":"grab_release","owner":a.slot,"escaped":escaped})

func advance_grabs(controls:Array=[]):
	for a in fighters:
		if a.throw_target<0: continue
		var b=fighters[a.throw_target]
		var p=Grapples.profile(a.kind,a.move);var m=move_data(a)
		a.grab_frame+=1;a.grab_pulse_flash=maxi(0,a.grab_pulse_flash-1)
		if p.hold and not controls.is_empty():
			var control=controls[b.slot]
			var direction=(2 if control.get("down",false) else (8 if control.get("up",false) else 5))+int(control.get("dx",0))
			a.grab_mash_cooldown=maxi(0,a.grab_mash_cooldown-1)
			var tapped=not control.get("buttons",[]).is_empty() or control.get("command","")!=""
			if a.grab_mash_cooldown==0 and (tapped or (direction!=5 and direction!=a.grab_last_dir)):
				a.grab_escape+=1;a.grab_mash_cooldown=4
			a.grab_last_dir=direction
		position_grab(a,b)
		if p.hold:
			if a.grab_hits<3 and a.grab_frame>=[10,22,34][a.grab_hits]:
				var damage=int(m.damage)/3 if a.grab_hits<2 else int(m.damage)-a.grab_damage
				grapple_damage(a,b,damage,a.grab_hits==2)
				position_grab(a,b)
			if a.grab_escape>=6 and a.grab_frame>=12 and b.health>0:
				release_grab(a,b,true);continue
		elif a.grab_frame==int(p.impact): grapple_damage(a,b,int(m.damage),true)
		if a.grab_frame>=int(p.duration) or (p.hold and b.health<=0): release_grab(a,b)


func end_round():
	if phase!="fight": return
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
		if not training:
			var reward={"owner":winner,"time":maxi(0,ceili(time_left/60.0))*100,"health":int(fighters[winner].health)*10,"perfect":10000 if fighters[winner].health==MAX_HEALTH else 0}
			reward.total=reward.time+reward.health+reward.perfect
			scores[winner]+=reward.total
			round_rewards.append(reward)
			events.append({"type":"round_bonus","owner":winner,"perfect":reward.perfect>0})
	for f in fighters:
		clear_dizzy(f)
		# Keep the surviving winner's current attack, frame and momentum intact.
		# It finishes its active/recovery frames during the round-end presentation.
		var follow_through=f.slot==winner and f.health>0 and f.move!=""
		if not follow_through: f.move=""
		f.queued="";f.buffer=0
		f.dash=0
		f.stun=0
		f.walk=0.0
		f.guard=false
		if not follow_through: f.crouch=false
		if f.health<=0: f.state="ko"
		elif f.slot==winner and not follow_through: f.state="idle"
	events.append({"type":"ko"})

func settle_after_round():
	# Round-end presentation must never suspend airborne bodies or the winner.
	advance_grabs()
	for f in fighters:
		if f.grabbed_by>=0 or f.throw_target>=0: continue
		if f.health>0 and f.move!="":
			# Neutral controls disallow a new move while continuing the exact winner
			# movement/airborne physics used before the KO. No further contacts run.
			update_fighter(f,{})
			continue
		var airborne=f.y<FLOOR or f.vy<0
		if airborne:
			f.x=clampf(f.x+f.vx,LEFT,RIGHT)
			f.y+=f.vy
			f.vy+=GRAVITY
			f.vx*=0.985 if f.state=="ko" else 0.92
		if f.y>=FLOOR:
			if airborne and f.state=="ko" and f.bounce_speed>0 and not f.bounced:
				f.y=FLOOR-0.1;f.vy=-f.bounce_speed;f.vx=0.0
				f.bounced=true
				events.append({"type":"bounce","owner":f.slot})
				continue
			if airborne: events.append({"type":"land","owner":f.slot,"ko":f.state=="ko","hard":f.state=="ko"})
			f.y=FLOOR
			f.vy=0.0
			f.vx=0.0
			f.throw_flight=false;f.throw_rotation=0.0
