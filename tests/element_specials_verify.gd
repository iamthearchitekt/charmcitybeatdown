extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
const FX=preload("res://scripts/element_effects.gd")
const SFX=preload("res://scripts/sfx_bank.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func fight(kind:int,name:String,distance:float=125,guard:bool=false,facing:int=1,ko:bool=false,low:bool=false)->Dictionary:
	var sim=Combat.new();sim.new_match(kind,0);sim.phase="fight"
	var a=sim.fighters[0];var b=sim.fighters[1]
	a.x=600-distance*.5*facing;b.x=600+distance*.5*facing;a.facing=facing;b.facing=-facing
	b.backstep_used=true
	if ko: b.health=20;sim.wins=[1,0]
	sim.start_move(a,name)
	var hits=0;var blocks=0;var effect_seen=false;var wrong_effect=false;var stationary=true;var attack_done=false;var health_at_end=-1
	var expected="electric" if kind==6 else "fire"
	for tick in 210:
		sim.step([{}, {"back":guard,"down":low}])
		if a.move==name: stationary=stationary and a.y==Combat.FLOOR and not a.crouch
		if b.element_timer>0: effect_seen=true;wrong_effect=wrong_effect or b.element_hit!=expected
		for event in sim.events:
			if event.type=="hit": hits+=1
			if event.type=="block": blocks+=1
		if a.move=="" and not attack_done: attack_done=true;health_at_end=b.health
	return {"sim":sim,"hits":hits,"blocks":blocks,"effect":effect_seen,"wrong":wrong_effect,"stationary":stationary,"health_at_end":health_at_end}
func run():
	var base=Combat.new();var kit=base.data.fighters[6].moves
	var reader=Commands.new();var command=""
	var accidental=false
	for direction in [5,4,2,1]:
		reader.reset()
		for tick in 25:
			command=reader.sample(direction,[["lp","mp","hp"][tick%3]],kit)
			accidental=accidental or command=="special3"
	check(not accidental,"Punch mashing while neutral, retreating or crouching cannot trigger shock")
	reader.reset();reader.sample(2,[],kit);reader.sample(1,[],kit)
	check(reader.sample(4,["hk"],kit)=="hk","Quarter-circle back kick cannot trigger punch electricity")
	reader.reset();reader.sample(2,[],kit);reader.sample(3,[],kit)
	check(reader.sample(6,["lp"],kit)=="special1","Spike retains his existing fiery plasma command")
	for facing in [-1,1]:
		for punch in ["lp","mp","hp"]:
			reader.reset()
			reader.sample(Commands.relative_direction(0,true,false,facing),[],kit)
			reader.sample(Commands.relative_direction(-facing,true,false,facing),[],kit)
			command=reader.sample(Commands.relative_direction(-facing,false,false,facing),[punch],kit)
			check(command=="special3","Quarter-circle back + "+punch+" starts Live Wire, facing "+str(facing))
	reader.reset();reader.sample(2,[],kit);reader.sample(1,[],kit);reader.sample(4,[],kit)
	for tick in 12: reader.sample(4,[],kit)
	check(reader.sample(4,["mp"],kit)=="mp","A stale motion does not turn a later punch into Live Wire")
	reader.reset();reader.sample(2,[],kit);reader.sample(1,[],kit);reader.sample(4,[],kit)
	check(reader.sample(5,["mp"],kit)=="mp","Live Wire requires finishing on Back with the punch")
	var live=Combat.new();live.new_match(6,0);live.phase="fight";reader.reset()
	live.step([{"down":true},{}]);reader.sample(2,[],kit)
	live.step([{"down":true,"dx":-1,"back":true},{}]);reader.sample(1,[],kit)
	command=reader.sample(4,["lp"],kit)
	live.step([{"dx":-1,"back":true,"command":command},{}])
	check(live.fighters[0].move=="special3" and not live.fighters[0].crouch,"Live Wire starts upright through the normal combat input path")
	for entry in [[6,"special3"],[4,"special1"]]:
		var kind=int(entry[0]);var name=String(entry[1]);var label=str(kind)+" "+name
		for facing in [-1,1]:
			var result=fight(kind,name,125,false,facing)
			check(result.hits>0 and result.hits<=(3 if kind==6 else 1),"Bounded contacts in both directions: "+label+" "+str(facing)+" hits="+str(result.hits))
			check(result.effect and not result.wrong,"Successful hit receives matching elemental reaction: "+label)
			check(result.stationary,"Cast stays grounded and upright: "+label)
			check(result.sim.fighters[0].move=="" and result.sim.fighters[1].element_timer==0,"Recovery completes and effect expires: "+label)
			check(result.health_at_end==result.sim.fighters[1].health,"No lingering damage over time: "+label)
			for low in [false,true]:
				var guarded=fight(kind,name,125,true,facing,false,low)
				var stance="Crouching" if low else "Standing"
				check(guarded.hits>0 and guarded.blocks==0 and guarded.effect and not guarded.wrong,stance+" guard takes the elemental hit: "+label)
		var miss=fight(kind,name,420)
		check(miss.hits==0 and not miss.effect and miss.sim.projectiles.is_empty(),"Close-range special does not become a projectile: "+label)
		var ko=fight(kind,name,125,false,1,true)
		check(ko.sim.winner==0 and ko.sim.fighters[0].move=="" and ko.sim.fighters[1].y==Combat.FLOOR,"Final KO follows through and settles: "+label)
		var f=base.make_fighter(kind,0);base.start_move(f,name);var move=base.move_data(f)
		f.frame=move.startup-1;check(base.attackboxes(f,move).is_empty(),"No startup hitbox: "+label)
		f.frame=move.startup;check(not base.attackboxes(f,move).is_empty(),"Authored effect hitbox during active frames: "+label)
		f.frame=move.startup+move.active;check(base.attackboxes(f,move).is_empty(),"No recovery hitbox: "+label)
		f.y=Combat.FLOOR-80;check(base.legal_command(f,name)=="","Ground-only cast cannot begin in air: "+label)
	var f=base.make_fighter(6,0);base.start_move(f,"special3");var move=base.move_data(f)
	f.frame=move.startup;check(FX.palette(f,move)=="cyan","Spike flashes cyan around the white lightning core")
	f.frame=move.startup+4;check(FX.palette(f,move)=="","Normal costume returns between electrical flashes")
	f.frame=move.startup+move.active;check(FX.palette(f,move)=="","The colored strobe stops at recovery")
	f.element_hit="electric";f.element_timer=12;base.fighters[0]=f;base.phase="fight";base.freeze=2
	base.step([{},{}]);check(f.element_timer==12,"Element timing pauses during hitstop")
	base.reset_round();check(base.fighters[0].element_timer==0,"Round reset clears elemental reactions")
	check(SFX.attack_cue({"move":"special3","fighter":6,"element":"electric"})=="electric","Shock routes to electrical sound")
	check(SFX.attack_cue({"move":"special1","fighter":4,"element":"fire"})=="flame","Flame cast routes to flame sound")
	print("ELEMENT SPECIALS RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
