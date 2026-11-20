extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const CPU=preload("res://scripts/cpu.gd")
const Commands=preload("res://scripts/commands.gd")
const Pose=preload("res://scripts/combat_pose.gd")
const Sparks=preload("res://scripts/impact_sparks.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func setup():
	var s=Combat.new();s.new_match(0,6);s.phase="fight"
	s.fighters[0].x=300;s.fighters[1].x=980
	return s
func hit(s,name="hp",block=false):
	var m=s.data.fighters[0].moves[name].duplicate(true)
	s.apply_contact({"a":0,"b":1,"move":name,"m":m,"block":block,"dir":1,"projectile":name=="special1"})
	s.freeze=0
func shot(s,owner,x,y=454.56,facing=0,life=130):
	return {"owner":owner,"move":"special1","x":float(x),"y":float(y),"facing":(1 if owner==0 else -1) if facing==0 else facing,"life":life,"m":s.data.fighters[owner].moves.special1.duplicate(true)}
func wait_dizzy(s):
	for i in 220:
		if s.fighters[1].state=="dizzy": return true
		s.step([{},{}])
	return false
func recovery(mode:int)->int:
	var s=setup();s.begin_dizzy(s.fighters[1])
	for i in 200:
		var control={}
		if mode==1: control={"dx":1,"buttons":[]}
		if mode==2: control={"dx":1 if int(i/3)%2==0 else -1,"buttons":["lp"] if i%3==0 else []}
		s.step([{},control])
		if s.fighters[1].state!="dizzy": return i+1
	return 999
func test_plasma(s,kind:int,facing:int,guard:bool):
	s.new_match(kind,0)
	s.phase="fight"
	s.fighters[0].x=450 if facing>0 else 830
	var defender=s.fighters[1]
	defender.x=830 if facing>0 else 450
	var start_x=float(defender.x)
	var move=s.data.fighters[kind].moves.special1
	var result=""
	for frame in 80:
		s.step([{"command":"special1"} if frame==0 else {},{"back":guard}])
		for event in s.events:
			if event.type in ["hit","block"]: result=event.type
		if result!="": break
	if guard:
		var stays_grounded=result=="block" and defender.state=="block" and defender.health==1000-int(move.chip)
		var contact_x=float(defender.x)
		var frozen=true
		for frame in s.freeze:
			s.step([{}, {"back":true}])
			frozen=frozen and is_equal_approx(defender.x,contact_x)
		for frame in 20:
			s.step([{},{"back":true}])
			stays_grounded=stays_grounded and is_equal_approx(defender.y,Combat.FLOOR)
		var distance=(defender.x-start_x)*facing
		var slide=(defender.x-contact_x)*facing
		check(frozen and stays_grounded and slide>30 and distance<100,"Guard freezes at impact, then slides visibly without falling: %d (%.1f px)" % [kind,slide])
	elif not move.get("projectile_knockdown",true):
		var standing=result=="hit" and defender.state=="hit" and defender.health==1000-int(move.damage)
		for frame in 18:
			s.step([{},{}])
			standing=standing and is_equal_approx(defender.y,Combat.FLOOR)
		check(standing and (defender.x-start_x)*facing>8,"Charged blade pushes back without a knockdown: "+str(kind))
	else:
		var falls=result=="hit" and defender.state=="knockdown" and defender.health==1000-int(move.damage)
		var peak=float(defender.y)
		for frame in 55:
			if defender.state=="down": break
			s.step([{},{}])
			peak=minf(peak,defender.y)
		var distance=(defender.x-start_x)*facing
		check(falls and defender.state=="down" and distance>45 and distance<95 and peak>Combat.FLOOR-40,"Clean plasma causes a short backward fall: "+str(kind))

func measure_guard(s,move:String,facing:int=1,low:bool=false,corner:bool=false)->Dictionary:
	s.new_match(0,0)
	s.phase="fight"
	var defender=s.fighters[1]
	defender.x=(Combat.RIGHT if facing>0 else Combat.LEFT) if corner else 640+56*facing
	s.fighters[0].x=defender.x-112*facing
	var guard={"back":true,"down":low}
	var block_event:Dictionary={}
	for frame in 32:
		s.step([{"command":move} if frame==0 else {},guard])
		for event in s.events:
			if event.type=="block": block_event=event
		if not block_event.is_empty(): break
	if block_event.is_empty(): return {"slide":0.0,"early_slide":0.0,"locked":false,"rigid":false,"stop":0,"recovered":false}
	var contact_x=float(defender.x)
	var base=Pose.key(defender,{})
	var stop:int=s.freeze
	var locked=defender.health==1000 and base==("base:8" if low else "base:12")
	var rigid=Pose.impact_shear(defender)==0.0
	for frame in stop:
		s.step([{},guard])
		locked=locked and is_equal_approx(defender.x,contact_x) and Pose.key(defender,{})==base
		rigid=rigid and Pose.impact_shear(defender)==0.0
	var early_slide=0.0
	for frame in 18:
		s.step([{},guard])
		rigid=rigid and Pose.impact_shear(defender)==0.0 and Pose.key(defender,{})==base
		if frame==3: early_slide=(defender.x-contact_x)*facing
	return {"slide":(defender.x-contact_x)*facing,"early_slide":early_slide,"locked":locked,"rigid":rigid,
		"stop":stop,"spark_life":Sparks.lifetime(block_event),"recovered":defender.state=="idle"}

func guarded_followup(s,kind:int,first:String,second:String,facing:int)->bool:
	s.new_match(kind,0)
	s.phase="fight"
	s.fighters[0].x=640-54.5*facing
	s.fighters[1].x=640+54.5*facing
	var first_hit=false
	var input=first
	for frame in 80:
		s.step([{"command":input},{"back":first_hit}])
		input=""
		for event in s.events:
			if event.type=="hit" and event.owner==0:
				if event.move==second: return event.combo==2
				if event.move==first and not first_hit:
					input=second
					first_hit=true
	return false

func fierce_jump_combo(s,kind:int,facing:int)->bool:
	s.new_match(kind,0)
	s.phase="fight"
	var a=s.fighters[0]
	var b=s.fighters[1]
	a.x=640-110*facing
	b.x=640+110*facing
	var hits=[]
	var queued=""
	var jab_sent=false
	var motion_step=-1
	var reader=Commands.new()
	var kit=s.data.fighters[kind].moves
	for frame in 132:
		var control={"dx":facing if a.y<Combat.FLOOR or frame==0 else 0}
		if frame==0: control.up=true
		if frame==28: control.command="hk"
		if hits.size()==1 and a.y>=Combat.FLOOR and not jab_sent:
			control.command="lp"
			jab_sent=true
		if queued!="":
			control.command=queued
			queued=""
		if motion_step>=0:
			control.down=motion_step<2
			control.dx=facing if motion_step>0 else 0
			if motion_step==2: control.command="lp"
			motion_step=motion_step+1 if motion_step<2 else -1
		var direction=Commands.relative_direction(control.dx,control.get("down",false),control.get("up",false),facing)
		var buttons=[control.command] if control.has("command") else []
		control.command=reader.sample(direction,buttons,kit)
		s.step([control,{"back":not hits.is_empty()}])
		for event in s.events:
			if event.type=="hit" and event.owner==0:
				hits.append(event.move)
				if event.move=="lp": queued="hp"
				if event.move=="hp": motion_step=0
		if b.dizzy_pending:
			return hits==["air_hk","lp","hp","special1"] and 1000-b.health>=Combat.DIZZY_MIN_COMBO_DAMAGE
	return false

func run():
	var s=setup()
	hit(s,"lp")
	check(s.fighters[1].dizzy_build==45 and not s.fighters[1].dizzy_pending,"A jab gives ordinary hitstun and cannot cause dizzy")
	s=setup();hit(s,"hp")
	var defender=s.fighters[1]
	var stun:int=defender.stun
	for frame in stun:
		s.step([{}, {"command":"hk"} if frame==0 else {}])
	check(defender.move=="" and defender.stun==0,"A recovery kick cannot interrupt hitstun")
	s.step([{},{}])
	check(defender.move=="hk","A kick pressed early in hitstun starts on the first free tick")
	s=setup();s.fighters[1].dizzy_build=299;hit(s,"special1",true)
	check(s.fighters[1].dizzy_build==0 and not s.fighters[1].dizzy_pending,"A blocked special breaks the dizzy combo and adds no stun")
	s=setup();hit(s,"throw")
	check(s.fighters[1].dizzy_build==0,"Throws do not build dizzy")
	s=setup();hit(s)
	for i in 28: s.step([{},{}])
	check(s.fighters[1].dizzy_build==0,"Regaining control immediately clears the interrupted combo's damage")
	s=setup()
	for i in 4: hit(s,"lp")
	check(s.fighters[1].combo==4 and not s.fighters[1].dizzy_pending,"Four light strikes lack the damage to stun")
	s=setup()
	for i in 3:
		var move=s.data.fighters[0].moves.hp.duplicate(true)
		move.damage=155
		s.apply_contact({"a":0,"b":1,"move":"hp","m":move,"block":false,"dir":1,"projectile":false})
	check(s.fighters[1].dizzy_build>=Combat.DIZZY_MIN_COMBO_DAMAGE and not s.fighters[1].dizzy_pending,"A damaging three-hit combo is still too short to stun")
	check(fierce_jump_combo(s,0,1) and s.fighters[1].state=="knockdown","A fierce four-hit combo causes a knockdown before the dizzy stance")
	check(wait_dizzy(s),"Knockdown and getup naturally lead into dizzy")
	check(s.fighters[1].dizzy_timer==180 and s.fighters[1].health>0,"Dizzy begins alive with three seconds of vulnerability")
	var x=s.fighters[1].x
	s.step([{}, {"dx":-1,"back":true,"down":true,"up":true,"command":"special1"}])
	check(s.fighters[1].x==x and s.fighters[1].y==Combat.FLOOR and s.fighters[1].move=="" and s.fighters[1].queued=="","Dizzy prevents movement, jumping and buffered attacks")
	check(not s.guard_blocks(s.fighters[1],s.data.fighters[0].moves.hp,{"back":true}),"Dizzy cannot guard")
	check(not s.start_move(s.fighters[1],"lp"),"Direct move starts cannot bypass dizzy")
	var timer=s.fighters[1].dizzy_timer;s.freeze=5
	for i in 5: s.step([{}, {"command":"lp"}])
	check(s.fighters[1].dizzy_timer==timer and s.fighters[1].move=="","Hitstop freezes dizzy and cannot start an escape attack")
	hit(s)
	check(s.fighters[1].state=="hit" and s.fighters[1].dizzy_timer==0 and s.fighters[1].dizzy_immunity>0,"A punish ends dizzy and protects against immediate redizzy")
	check(s.fighters[1].dizzy_build==0,"The first punish cannot immediately rebuild dizzy")
	var ordinary=recovery(0);var held=recovery(1);var mashed=recovery(2)
	check(ordinary==180,"Dizzy expires naturally after 180 simulation frames")
	check(held>=176,"Holding one direction does not repeatedly shorten recovery")
	check(mashed>=60 and mashed<ordinary,"Distinct movement/button taps accelerate recovery with a one-second floor")
	s=setup();s.begin_dizzy(s.fighters[1])
	defender=s.fighters[1]
	s.step([{}, {"command":"lp"}])
	for frame in Combat.DIZZY_MIN_DURATION-1: s.step([{},{}])
	check(defender.state=="dizzy" and defender.move=="","An early attack press cannot skip the minimum dizzy window")
	s.step([{}, {"command":"hp"}])
	s.step([{},{}])
	check(defender.move=="hp" and defender.dizzy_timer==0,"A fresh attack tap after the dizzy window immediately queues a recovery strike")
	s=setup();s.begin_dizzy(s.fighters[1]);s.fighters[1].health=20;hit(s);s.end_round()
	check(s.fighters[1].state=="ko" and s.fighters[1].dizzy_timer==0 and not s.fighters[1].dizzy_pending,"A lethal punish ends in KO without lingering stars")
	s.reset_round()
	check(s.fighters.all(func(f):return f.dizzy_build==0 and f.dizzy_timer==0 and not f.dizzy_pending and f.dizzy_immunity==0),"Round reset clears every dizzy field")
	s=setup();s.begin_dizzy(s.fighters[1]);var cpu=CPU.new();var recovered=false
	for i in 240:
		s.step([{},cpu.control(s,1,1)])
		if s.fighters[1].state!="dizzy": recovered=true
	check(recovered,"CPU recovers at a bounded pace and resumes ordinary decisions")
	# Repeated attacks with enough time to recover never count as a continuous combo.
	s=setup();s.fighters[0].x=500;s.fighters[1].x=630
	for n in 4:
		s.fighters[0].x=500;s.fighters[1].x=630
		s.step([{"command":"hp"},{}])
		for i in 32: s.step([{},{}])
	check(s.fighters[1].health<700 and not s.fighters[1].dizzy_pending and s.fighters[1].state!="dizzy","Spaced heavy hits deal damage without stunning")
	for kind in s.data.fighters.size():
		check(guarded_followup(s,kind,"lp","lk",1) and guarded_followup(s,kind,"mp","special1",-1),"Normal and special cancel combos beat guard after the opener: "+str(kind))
	check(fierce_jump_combo(s,0,-1) and fierce_jump_combo(s,4,1) and fierce_jump_combo(s,6,-1),"Jump-in into jab, heavy punch and special is a real stun string across different kits and facings")
	s=setup();s.projectiles=[shot(s,0,620),shot(s,1,660)]
	s.step([{},{}])
	check(s.projectiles.is_empty() and s.events.filter(func(e):return e.type=="projectile_clash").size()==1,"Opposing projectiles cancel once and emit one burst")
	check(s.fighters[0].health==1000 and s.fighters[1].health==1000 and s.freeze==0,"A clash damages nobody and does not halt fighter movement")
	s=setup();s.fighters[1].x=650;s.projectiles=[shot(s,0,620),shot(s,1,660)]
	s.step([{},{}])
	check(s.fighters[1].health==1000 and not s.events.any(func(e):return e.type=="hit"),"Clashes take priority over a simultaneous fighter collision")
	s=setup();s.projectiles=[shot(s,0,620),shot(s,0,640)]
	s.step([{},{}])
	check(s.projectiles.size()==2,"Same-owner projectiles never cancel each other")
	s=setup();s.projectiles=[shot(s,0,620,450),shot(s,1,650,490)]
	s.step([{},{}])
	check(s.projectiles.size()==2,"Shots passing at different heights do not clash")
	s=setup();s.projectiles=[shot(s,0,600),shot(s,1,610),shot(s,1,615)]
	s.step([{},{}])
	check(s.projectiles.size()==1 and s.projectiles[0].owner==1,"Each shot cancels at most one opposing shot")
	s=setup();s.projectiles=[shot(s,0,620,454.56,0,1),shot(s,1,650)]
	s.step([{},{}])
	check(s.projectiles.size()==1 and not s.events.any(func(e):return e.type=="projectile_clash"),"Expired projectiles cannot cancel live ones")
	check(s.projectiles_clash({"previous_x":600,"x":700,"y":450},{"previous_x":680,"x":580,"y":450}),"Relative sweep detects shots crossing within a single step")
	for kinds in [[0,6],[6,0]]:
		s=setup();s.new_match(kinds[0],kinds[1]);s.phase="fight"
		var count=0
		s.step([{"command":"special1"},{"command":"special1"}])
		for i in 65:
			s.step([{},{}])
			for event in s.events:
				if event.type=="projectile_clash": count+=1
		check(count==1 and s.projectiles.is_empty() and s.fighters.all(func(f):return f.health==1000),"Real fire and blue specials cancel in both directions: "+str(kinds))
	for kind in s.data.fighters.size():
		if s.data.fighters[kind].moves.special1.get("projectile",false):
			var facing=1 if kind%2==0 else -1
			test_plasma(s,kind,facing,false)
			test_plasma(s,kind,-facing,true)
	var light=measure_guard(s,"lp")
	var heavy=measure_guard(s,"hp")
	check(light.slide>44.0 and heavy.slide>light.slide+32.0 and heavy.slide<112.0,"A guarded heavy punch gives more ground than a guarded jab (%.1f / %.1f px)" % [light.slide,heavy.slide])
	check(heavy.early_slide>52.0 and heavy.locked and heavy.stop>=8 and heavy.rigid and heavy.recovered,"Heavy guard stays rigid through blockstop and the backward skid")
	check(heavy.get("spark_life",0)>=heavy.stop+7,"Heavy guard burst stays visible as the skid begins")
	var low=measure_guard(s,"c_hk",-1,true)
	check(low.early_slide>50.0 and low.locked and low.rigid and low.recovered,"Crouching guard stays rigid and skids in the mirrored direction")
	var wall=measure_guard(s,"hp",1,false,true)
	check(wall.slide==0.0 and wall.locked and wall.rigid and wall.recovered,"Wall guard holds its pose inside the stage boundary")
	print("DIZZY / CLASH RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
