extends RefCounted
const Combat=preload("res://scripts/combat.gd")
var cooldown:int=0
var reaction:int=0
var intent:Dictionary={}
var burst:int=0
var rest:int=0
var approach:int=0
var approach_limit:float=155.0
var next_projectile_tick:int=0
var observed_move=""
var observed_frame=-1
var repeated_move=""
var repeat_count=0
var last_repeat_tick=-999
var rng=RandomNumberGenerator.new()

func _init(): rng.seed=3701

func control(sim,slot:int,difficulty:int)->Dictionary:
	var me=sim.fighters[slot]
	var foe=sim.fighters[1-slot]
	var poe=me.kind==11
	var out={"dx":0,"down":false,"up":false,"back":false,"command":""}
	if sim.phase!="fight" or sim.freeze>0: return out
	if me.grabbed_by>=0:
		out.dx=1 if int(sim.tick/6)%2==0 else -1
		out.command="lp" if sim.tick%12==0 else ""
		return out
	if me.state=="dizzy":
		# Discrete, human-rate recovery attempts; never instant CPU recovery.
		out.dx=1 if int(sim.tick/4)%2==0 else -1
		out.command="lp" if sim.tick%10==0 else ""
		intent={"dx":0,"down":false,"up":false,"back":false,"command":""}
		reaction=0
		return out
	# Observe actual attacks, including while stunned; never inspect player inputs.
	if foe.move!="" and (foe.move!=observed_move or foe.frame<observed_frame):
		if foe.move==repeated_move and sim.tick-last_repeat_tick<150: repeat_count+=1
		else: repeated_move=foe.move;repeat_count=1
		last_repeat_tick=sim.tick
	observed_move=foe.move
	observed_frame=foe.frame
	if sim.tick-last_repeat_tick>210: repeat_count=0
	if me.state in ["knockdown","down","getup"]: return out
	# Thinking and spacing are distinct from attack speed. No perfect-pressure loop.
	if me.stun>0:
		if repeat_count>=3:
			# A learned guard is held through hitstun just as a player can hold back.
			# This avoids repeatedly starting a fresh retreat against every jab.
			out.dx=-me.facing;out.back=true
			out.down=sim.move_data(foe).get("level","")=="low"
			intent=out.duplicate()
		return out
	if me.move!="": return out
	cooldown=maxi(0,cooldown-1)
	var distance=absf(me.x-foe.x)
	if burst>=2 and rest==0:
		rest=[40,30,21][difficulty]
		burst=0
	if rest>0:
		rest-=1
		reaction=0
		if distance<215:
			out.dx=-me.facing
			out.back=true
		return out
	reaction-=1
	if reaction<=0:
		reaction=[23,15,9][difficulty]+rng.randi_range(0,7)-(2 if poe else 0)
		var foe_move=sim.move_data(foe)
		var reach=(float(foe_move.box[0])+float(foe_move.box[2]))*sim.FIGHTER_SCALE+35 if not foe_move.is_empty() else 185.0
		var predictable=repeat_count>=3 and foe.move==repeated_move
		var recovering=not foe_move.is_empty() and foe.frame>=foe_move.startup+foe_move.active
		var melee_threat=foe.move!="" and not recovering and distance<minf(310,reach)
		var incoming_shot=projectile_approaching(sim,me,slot,[11,17,22][difficulty])
		var target_parts=sim.hurtboxes(foe)
		var kit:Dictionary=sim.data.fighters[me.kind].moves
		intent={"dx":0,"down":false,"up":false,"back":false,"command":""}
		approach_limit=155.0
		var punish=""
		if recovering and not incoming_shot and cooldown==0 and distance<200 and (not foe.connected or predictable):
			var chance=[.24,.54,.69][difficulty]+(.12 if predictable else 0.0)
			if rng.randf()<chance:
				var counters=["lp","mp","hp"]
				if difficulty>0 and distance<150 and me.y>=Combat.FLOOR:
					var recovery_left=int(foe_move.startup+foe_move.active+foe_move.recovery)-foe.frame
					var heavies=["hp","hk"].filter(func(move): return int(kit[move].startup)+4<=recovery_left)
					counters=heavies+["lp","mp"]
				for move in counters:
					if normal_in_reach(sim,me,target_parts,move):
						punish=move
						break
		if punish!="":
			intent.command=punish
		elif (melee_threat or incoming_shot) and rng.randf()<minf(.94,[.44,.70,.86][difficulty]+(.16 if predictable else 0.0)+(.04 if poe else 0.0)):
			intent.back=true
			# A deliberate guard holds ground. Let a retreat already underway finish.
			intent.dx=-me.facing if me.backstep>0 else 0
			intent.down=foe_move.get("level","")=="low" if melee_threat else incoming_shot
		elif distance>185:
			var shot_chance=[.45,.56,.66][difficulty]+(.11 if poe else 0.0)
			if cooldown==0 and distance>=230 and sim.tick>=next_projectile_tick and not incoming_shot and rng.randf()<shot_chance:
				intent.command=ranged_attack(sim,me,foe,kit,target_parts)
			if cooldown==0 and intent.command=="" and distance<350 and not (melee_threat or incoming_shot) and rng.randf()<.34:
				var lunge="special6" if me.kind==0 and foe.guard and not foe.crouch else ("special5" if me.kind==0 else "special1")
				if kit[lunge].get("travel",0.0)>0.0 and normal_in_reach(sim,me,target_parts,lunge): intent.command=lunge
			if intent.command=="":
				intent.dx=me.facing
				approach=reaction
				if distance>280 and rng.randf()<.10: intent.up=true
		elif cooldown==0:
			var choices=["lp","lk","mp","mk","hp","hk"] if distance<150 else ["mp","hp","hk"]
			var low_poke=foe.guard and not foe.crouch and rng.randf()<.46
			if low_poke: choices=["lk","mk","hk"]
			choices=choices.filter(func(move): return normal_in_reach(sim,me,target_parts,move,low_poke))
			if not low_poke:
				for move in ["special1","special3","special4"]:
					if kit.has(move) and not kit[move].get("projectile",false) and rng.randf()<.20 and normal_in_reach(sim,me,target_parts,move):
						choices.append(move)
			if distance<125 and sim.valid_grab(me,foe): choices.append("throw")
			if kit.has("command_grab") and distance<145 and sim.valid_grab(me,foe) and rng.randf()<.18: choices.append("command_grab")
			if kit.has("air_throw") and me.y<sim.FLOOR-1 and foe.y<sim.FLOOR-1: choices.append("throw")
			if foe.y<sim.FLOOR-20 and normal_in_reach(sim,me,target_parts,"special2"): choices.append("special2")
			if not choices.is_empty():
				intent.command=choices[rng.randi_range(0,choices.size()-1)]
				intent.down=low_poke and intent.command in ["lk","mk","hk"]
			elif distance>Combat.PUSH_WIDTH+9.0:
				# Step through the old dead zone only when none of the pokes can reach.
				approach_limit=Combat.PUSH_WIDTH+9.0
				intent.dx=me.facing
				approach=mini(7,reaction)
		else:
			intent.dx=-me.facing if distance<130 else 0
			intent.back=intent.dx!=0
		if intent.command!="":
			cooldown=[22,15,8][difficulty]+rng.randi_range(0,9)
			if kit[intent.command].get("projectile",false): next_projectile_tick=sim.tick+[108,94,80][difficulty]
			else: burst+=1
	out=intent.duplicate()
	intent.command=""
	intent.up=false
	# Approach in brief steps; never keep walking into the opponent's pushbox.
	if out.dx==me.facing:
		if distance<approach_limit or approach<=0: out.dx=0
		else: approach-=1
	return out

func ranged_attack(sim,me:Dictionary,foe:Dictionary,kit:Dictionary,target_parts:Array)->String:
	if target_parts.is_empty() or me.y<Combat.FLOOR-1: return ""
	if sim.projectiles.any(func(shot): return shot.owner==me.slot and shot.life>0): return ""
	var candidates:Array=[]
	for move in kit:
		if not kit[move].get("projectile",false): continue
		var shot=Combat.make_projectile(me,kit[move])
		var lane=Combat.projectile_rect(shot)
		if target_parts.any(func(part): return part.end.y>lane.position.y and part.position.y<lane.end.y):
			if foe.guard and not foe.crouch and kit[move].level=="low": return move
			candidates.append(move)
	return candidates[0] if not candidates.is_empty() else ""

func projectile_approaching(sim,me:Dictionary,slot:int,lookahead:int)->bool:
	var body:Rect2=sim.hurtbox(me)
	if not body.has_area(): return false
	for shot in sim.projectiles:
		if shot.owner==slot or shot.life<=0: continue
		var travel=(me.x-shot.x)*shot.facing
		var box=Combat.projectile_rect(shot)
		var width=box.size.x*.5
		if travel>=-width and travel<=lookahead*Combat.projectile_speed(shot)+width and box.end.y>body.position.y and box.position.y<body.end.y:
			return true
	return false

func normal_in_reach(sim,me:Dictionary,target_parts:Array,move:String,crouch:bool=false)->bool:
	if target_parts.is_empty(): return false
	var probe=me.duplicate()
	probe.crouch=crouch
	probe.move=sim.legal_command(probe,move)
	if probe.move=="": return false
	var data=sim.move_data(probe)
	for frame in range(int(data.startup),int(data.startup+data.active)):
		probe.frame=frame
		if sim.regions_overlap(sim.attackboxes(probe,data),target_parts).has_area(): return true
		probe.x+=float(data.get("travel",0.0))*me.facing
	return false
