extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var main
var checks:Array=[]
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks.append(("PASS " if ok else "FAIL ")+label);print(checks[-1])
	if not ok: failures+=1
func snap(name:String):
	main.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
	main.set_physics_process(false)
	var names=[]
	for d in main.sim.data.fighters: names.append(d.name)
	check(names==["MARCUS","MAYA","ALEX","EMMA"],"Four generic names include Alex for the brown-haired male")
	main.action("confirm")
	main.action("left")
	check(main.selection[0]==3,"Left wraps from Marcus to Emma")
	main.action("right")
	check(main.selection[0]==0,"Right wraps from Emma to Marcus")
	main.action("fighter2");main.action("confirm")
	check(main.selection[0]==2 and main.select_slot==1,"Alex selection advances to opponent choice")
	main.action("fighter3")
	await snap("roster-four")
	main.action("confirm")
	check(main.sim.fighters[0].kind==2 and main.sim.fighters[1].kind==3,"Alex and Emma start a playable match")
	main.sim.phase="fight";main.sim.time_left=98*60
	await snap("alex-emma-match")
	main.paused=true;await snap("alex-emma-pause");main.paused=false
	for kind in 4:
		var sim=Combat.new();sim.new_match(kind,(kind+1)%4);sim.phase="fight"
		var start_x=sim.fighters[0].x
		var launched=false;var projectile_sound=false;var rush_sound=false
		sim.step([{"command":"special1"},{}])
		for i in 60:
			sim.step([{},{}])
			launched=launched or not sim.projectiles.is_empty()
			for e in sim.events:
				if e.type=="attack" and e.move=="special1":
					projectile_sound=main.sfx.attack_cue(e)=="projectile"
					rush_sound=main.sfx.attack_cue(e)=="rush"
		check((launched and projectile_sound) if kind%2==0 else (sim.fighters[0].x>start_x+40 and rush_sound),"Legal special and matching sound for "+names[kind])
		main.sfx.stop_all();sim.fighters[0].health=0;sim.wins[1]=1;sim.end_round()
		for e in sim.events: main.sfx.combat_event(e,sim)
		var expected="ko_breakwater" if kind%2==0 else "ko_redline"
		check(main.sfx.playback_log.filter(func(e):return e.cue==expected).size()==1,"Correct defeat voice for "+names[kind])
		main.sim.new_match(kind,(kind+1)%4);main.sim.phase="fight";main.sim.time_left=98*60
		main.sim.fighters[0].state="ko";main.sim.fighters[0].health=0
		main.sim.fighters[1].state="ko";main.sim.fighters[1].health=0
		main.sim.fighters[0].x=340;main.sim.fighters[1].x=940
		await snap("supine-ko-"+str(kind))
	main.selection=[2,3];main.begin_match();main.sim.wins=[2,0];main.sim.winner=0;main.sim.phase="results"
	await snap("alex-results")
	main.action("rematch")
	check(main.sim.fighters[0].kind==2 and main.sim.fighters[1].kind==3 and main.sim.wins==[0,0],"Rematch preserves Alex and Emma and resets scores")
	var sim=Combat.new();sim.phase="fight";sim.fighters[1].state="down";sim.fighters[1].down_timer=20
	sim.fighters[1].facing=-1;sim.fighters[0].x=1100
	sim.step([{},{}])
	check(sim.fighters[1].facing==-1,"Prone pose does not flip when the opponent crosses over")
	main.queue_free();await process_frame
	var report=FileAccess.open("res://tests/roster-verification.txt",FileAccess.WRITE)
	report.store_string("\n".join(checks)+"\nFailures: "+str(failures))
	print("ROSTER RESULT: ",checks.size()-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
