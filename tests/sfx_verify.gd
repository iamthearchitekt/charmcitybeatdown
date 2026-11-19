extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Sfx=preload("res://scripts/sfx_bank.gd")
var bank
var checks:Array=[]
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks.append(("PASS " if ok else "FAIL ")+label)
	print(checks[-1])
	if not ok: failures+=1

func setup(distance=75.0):
	bank.stop_all()
	var sim=Combat.new()
	sim.phase="fight"
	sim.fighters[0].x=450
	sim.fighters[1].x=450+distance
	return sim

func step(sim,a={},b={}):
	sim.step([a,b])
	for event in sim.events: bank.combat_event(event,sim)

func count_cue(cue:String)->int:
	return bank.playback_log.filter(func(item):return item.cue==cue).size()

func run():
	bank=Sfx.new()
	root.add_child(bank)
	await process_frame
	var requested={}
	for cue in bank.config.cues.values():
		for file in cue.files: requested[file]=true
	var all_loaded=bank.streams.size()==requested.size()
	for stream in bank.streams.values(): all_loaded=all_loaded and stream!=null and stream.get_length()>0.05
	check(all_loaded,"All "+str(requested.size())+" active effects and voice WAVs decode")
	check(bank.voices.size()==8,"Playback pool is bounded to eight voices")
	for move in ["lp","hp","lk","hk","c_lp","c_hk","special1","throw"]:
		var sim=setup()
		step(sim,{"command":move})
		for i in 80: step(sim)
		var cue=Sfx.impact_cue({"type":"hit","move":move,"heavy":sim.data.fighters[0].moves[move].damage>=100})
		check(count_cue(cue)==1,"One matching impact cue for "+move)
	var sim=setup(420)
	step(sim,{"command":"hp"})
	for i in 40: step(sim)
	check(count_cue("swing_heavy")==1 and count_cue("heavy_punch")==0,"Whiff produces one whoosh and no impact")
	sim=setup()
	step(sim,{"command":"lp"},{"back":true})
	for i in 40: step(sim,{}, {"back":true})
	check(count_cue("block")==1 and count_cue("light_punch")==0,"Blocked contact produces block cue instead of damage cue")
	sim=setup(380)
	step(sim,{"command":"special1"})
	for i in 70: step(sim)
	check(count_cue("projectile")==1 and count_cue("special_hit")==1,"Projectile launch and delayed contact have distinct cues")
	check(count_cue("projectile_voice")==1,"Hadouken voice plays once on actual plasma-ball spawn")
	sim=setup(420)
	sim.new_match(6,0);sim.phase="fight"
	sim.fighters[0].x=400;sim.fighters[1].x=820
	step(sim,{"command":"special3"})
	for i in 64: step(sim)
	check(count_cue("electric")==1 and count_cue("electric_pulse")==2 and count_cue("electric_hit")==0,"Live Wire zaps throughout a whiffed active burst")
	check(bank.playback_log.any(func(item):return item.cue=="electric" and item.file=="5C_zap_2.wav" and item.db>=-12),"Live Wire uses the longer, audible supplied zap")
	sim=setup(420)
	sim.new_match(4,0);sim.phase="fight"
	sim.fighters[0].x=400;sim.fighters[1].x=820
	step(sim,{"command":"special1"})
	for i in 50: step(sim)
	check(count_cue("flame")==2 and bank.playback_log.any(func(item):return item.file=="45_dhalsim_flame.wav") and count_cue("flame_hit")==0,"Chelsea casts with the Flame sample and whoosh layer even on a whiff")
	sim=setup()
	sim.new_match(0,0);sim.phase="fight"
	sim.fighters[0].x=450;sim.fighters[1].x=525
	step(sim,{"command":"lp"},{"command":"lp"})
	for i in 25: step(sim)
	check(count_cue("light_punch")==2,"Both sides of a simultaneous trade remain audible")
	sim=setup()
	sim.fighters[1].y=Combat.FLOOR-120
	sim.fighters[1].vy=-6
	sim.fighters[1].health=0
	sim.wins[0]=1
	sim.end_round()
	for event in sim.events: bank.combat_event(event,sim)
	check(count_cue("ko_land")==0,"Airborne KO does not prematurely play a floor thud")
	check(count_cue("final_ko_female")==1,"Airborne female defeat plays supplied final scream immediately")
	for i in 65: step(sim)
	check(count_cue("ko_land")==1,"KO landing produces exactly one body thud")
	check(count_cue("final_ko_female")==1,"Final KO clip plays once through landing and round-end")
	for kind in 2:
		for slot in 2:
			sim=setup()
			sim.new_match(kind,kind);sim.phase="fight"
			sim.fighters[slot].health=0
			sim.wins[1-slot]=1
			sim.end_round()
			for event in sim.events: bank.combat_event(event,sim)
			check(count_cue("final_ko_male" if kind==0 else "final_ko_female")==1 and count_cue("final_ko_female" if kind==0 else "final_ko_male")==0,"KO voice follows fighter identity in slot "+str(slot)+", kind "+str(kind))
	sim=setup()
	for f in sim.fighters: f.health=0
	sim.end_round()
	for event in sim.events: bank.combat_event(event,sim)
	check(count_cue("ko_breakwater")==1 and count_cue("ko_redline")==1,"Double KO gives each defeated fighter a scream")
	for winner in 2:
		sim=setup();sim.fighters[1-winner].health=0;sim.end_round()
		for event in sim.events: bank.combat_event(event,sim)
		check(count_cue("ko_breakwater" if winner==1 else "ko_redline")==1,"First round defeat screams once for slot "+str(1-winner))
		check(count_cue("ko_land")>0,"Early round loss keeps landing sound")
	sim=setup()
	sim.time_left=0;sim.fighters[1].health=500
	sim.end_round()
	for event in sim.events: bank.combat_event(event,sim)
	check(count_cue("ko_breakwater")==0 and count_cue("ko_redline")==0,"Timeout without knockout does not trigger a KO scream")
	sim=setup()
	step(sim,{"up":true})
	for i in 60: step(sim)
	check(count_cue("jump")==1 and count_cue("land")==1,"Jump and touchdown cues fire once each")
	bank.stop_all()
	bank.play("light_punch");bank.play("light_punch")
	check(bank.playback_log[0].file!=bank.playback_log[1].file,"Hit variants alternate without altering pitch")
	bank.set_paused(true)
	check(bank.voices.filter(func(v):return v.playing).all(func(v): return v.stream_paused),"Pause suspends all active combat audio voices")
	check(not bank.play("heavy_punch"),"No new combat sound is started while paused")
	check(bank.play("pause"),"Pause menu feedback remains available")
	bank.set_paused(false)
	check(bank.voices.all(func(v):return not v.stream_paused),"Resume releases paused sounds")
	bank.stop_all()
	check(not bank.play("finish_breakwater"),"Removed finisher cue cannot play")
	for i in 30: bank.play("heavy_kick")
	check(bank.get_child_count()==8,"Rapid repeated impacts do not allocate unbounded players")
	bank.queue_free()
	await process_frame
	await create_timer(.15).timeout
	var file=FileAccess.open("res://tests/sfx-verification.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nFailures: "+str(failures))
	print("SFX RESULT: ",checks.size()-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
