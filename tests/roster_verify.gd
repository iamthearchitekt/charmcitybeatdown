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
	main.set_process_input(false)
	main.set_physics_process(false)
	main.selected_mode=1
	main.unlocks.all_unlocked=false;main.unlocks.unlocked=[]
	var names=[]
	for d in main.sim.data.fighters: names.append(d.name)
	check(names==["MARCUS","BROOK LYNNE","ALEX","LAUREN","CHELSEA","VIVIAN","SPIKE","ERIC","STAN","RACHEL","JEFF"],"Eleven fighters have the requested names")
	main.action("confirm")
	main.action("down")
	check(main.selection[0]==main.select_columns(),"Down moves to the second portrait row")
	main.action("up")
	check(main.selection[0]==0,"Up moves to the first portrait row")
	await snap("select-player-one")
	var tiles=main.buttons.filter(func(b):return b.action.begins_with("fighter"))
	var selectable=tiles.size()==11
	for a in tiles:
		selectable=selectable and Rect2(0,0,1280,720).encloses(a.rect)
		for b in tiles:
			if a.action!=b.action: selectable=selectable and not a.rect.intersects(b.rect)
	check(selectable,"Eleven portrait buttons are visible, distinct and clickable")
	main.action("left")
	check(main.selection[0]==10,"Left wraps from Marcus to Jeff")
	main.action("right")
	check(main.selection[0]==0,"Right wraps from Jeff to Marcus")
	main.action("fighter2");main.action("confirm")
	check(main.selection[0]==2 and main.select_slot==1,"Alex selection advances to opponent choice")
	main.action("fighter3")
	await snap("roster-seven")
	main.action("left");main.action("down")
	check(main.selection[1]==2+main.select_columns(),"Opponent selection moves to the second portrait row")
	main.action("up")
	check(main.selection[1]==2,"Opponent row navigation preserves the selected column")
	main.selection[1]=2
	await snap("select-same-fighter")
	main.selection[1]=3
	main.action("confirm")
	check(main.sim.fighters[0].kind==2 and main.sim.fighters[1].kind==3,"Alex and Lauren start a playable match")
	main.sim.phase="fight";main.sim.time_left=98*60
	await snap("alex-lauren-match")
	main.paused=true;await snap("alex-lauren-pause");main.paused=false
	for kind in names.size():
		var sim=Combat.new();sim.new_match(kind,(kind+1)%names.size());sim.phase="fight"
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
		check((launched and projectile_sound) if sim.data.fighters[kind].style==0 else (sim.fighters[0].x>start_x+40 and rush_sound),"Legal special and matching sound for "+names[kind])
		main.sfx.stop_all();sim.fighters[0].health=0;sim.wins[1]=1;sim.end_round()
		for e in sim.events: main.sfx.combat_event(e,sim)
		var expected="final_ko_female" if main.SfxBank.female(kind) else "final_ko_male"
		check(main.sfx.playback_log.filter(func(e):return e.cue==expected).size()==1,"Correct defeat voice for "+names[kind])
		main.sim.new_match(kind,(kind+1)%names.size());main.sim.phase="fight";main.sim.time_left=98*60
		main.sim.fighters[0].state="ko";main.sim.fighters[0].health=0
		main.sim.fighters[1].state="ko";main.sim.fighters[1].health=0
		main.sim.fighters[0].x=340;main.sim.fighters[1].x=940
		await snap("supine-ko-"+str(kind))
	main.selection=[2,3];main.begin_match();main.sim.wins=[2,0];main.sim.winner=0;main.sim.phase="results"
	await snap("alex-results")
	main.action("rematch")
	check(main.sim.fighters[0].kind==2 and main.sim.fighters[1].kind==3 and main.sim.wins==[0,0],"Rematch preserves Alex and Lauren and resets scores")
	var sim=Combat.new();sim.phase="fight";sim.fighters[1].state="down";sim.fighters[1].down_timer=20
	sim.fighters[1].facing=-1;sim.fighters[0].x=1100
	sim.step([{},{}])
	check(sim.fighters[1].facing==-1,"Prone pose does not flip when the opponent crosses over")
	main.queue_free();await process_frame
	var report=FileAccess.open("res://tests/roster-verification.txt",FileAccess.WRITE)
	report.store_string("\n".join(checks)+"\nFailures: "+str(failures))
	print("ROSTER RESULT: ",checks.size()-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
