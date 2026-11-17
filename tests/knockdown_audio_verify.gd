extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var checks:Array=[]
var failures=0
var main

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks.append(("PASS " if ok else "FAIL ")+label)
	print(checks[-1])
	if not ok: failures+=1

func snapshot(label:String):
	main.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+label+".png")

func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	await create_timer(.08).timeout
	check(main.menu_music.playing and main.menu_music.volume_db==-13 and not main.music.playing,"Title starts menu music at the increased level without the match track")
	check(main.font.resource_path=="res://assets/fonts/UpheavalPro.ttf","All screens use bundled Upheaval Pro")
	await snapshot("title-upheaval")
	var menu_position=main.menu_music.get_playback_position()
	main.action("confirm");main.sync_match_end_audio()
	await create_timer(.25).timeout
	print("Menu playback continuity: ",menu_position," -> ",main.menu_music.get_playback_position()," playing=",main.menu_music.playing)
	check(main.menu_music.playing and main.menu_music.get_playback_position()>menu_position,"Character selection continues menu music without restarting")
	main.selected_mode=1;main.begin_match();main.sim.phase="fight"
	check(not main.menu_music.playing and main.music.playing,"Starting a match cuts menu music before match music begins")
	main.sync_match_end_audio()
	await create_timer(.08).timeout
	check(main.music.playing and main.music_enabled and main.music.volume_db==-13,"Go Straight starts at the increased level during the match")
	check(main.music.stream is AudioStreamMP3 and main.music.stream.loop,"Match music uses the supplied looping MP3")
	check(main.match_end_audio.stream.get_length()>1 and not main.match_end_audio.stream.loop,"Completion clip decodes and is non-looping")
	for kind in 2:
		for side in [-1,1]:
			for move in ["throw","c_hk","special2"]:
				var sim=Combat.new();sim.new_match(kind,1-kind);sim.phase="fight"
				var a=sim.fighters[0];var b=sim.fighters[1]
				a.x=640-60*side;b.x=640;a.facing=side;b.facing=-side
				sim.apply_contact({"a":0,"b":1,"move":move,"m":sim.data.fighters[kind].moves[move],"block":false,"dir":side,"projectile":false})
				check(b.state=="knockdown" and b.vx*side>=8 and b.vy<0,"Backward launch: kind "+str(kind)+", "+move+", direction "+str(side))
				var landed=false;var rose=false;var land_count=0;var down_x=0.0
				for frame in 100:
					sim.step([{}, {"dx":-side,"up":true,"command":"hp"}])
					for e in sim.events:
						if e.type=="land" and e.owner==1: land_count+=1
					if b.state=="down": landed=true;down_x=b.x
					if b.state=="getup": rose=true
					if rose and b.state=="idle": break
				check(landed and rose and b.state=="idle" and b.y==Combat.FLOOR and land_count==1 and (down_x-640)*side>95,"Full grounded knockdown and recovery: "+str(kind)+"/"+move+"/"+str(side))
	main.begin_match();main.sim.phase="fight"
	main.sim.fighters[0].x=500;main.sim.fighters[1].x=580
	var sim=main.sim
	sim.apply_contact({"a":0,"b":1,"move":"throw","m":sim.data.fighters[0].moves.throw,"block":false,"dir":1,"projectile":false})
	sim.freeze=0
	for i in 12: sim.step([{},{}])
	await snapshot("knockdown-air")
	while sim.fighters[1].state=="knockdown": sim.step([{},{}])
	await snapshot("knockdown-ground")
	var health=sim.fighters[1].health
	sim.fighters[0].x=sim.fighters[1].x-75
	for i in 20: sim.step([{"command":"lp"},{}])
	check(sim.fighters[1].health==health,"Prone fighter cannot be repeatedly hit on the floor")
	for side in [-1,1]:
		var corner=Combat.new();corner.phase="fight"
		corner.fighters[1].x=Combat.RIGHT if side==1 else Combat.LEFT
		corner.apply_contact({"a":0,"b":1,"move":"throw","m":corner.data.fighters[0].moves.throw,"block":false,"dir":side,"projectile":false})
		for i in 110: corner.step([{},{}])
		check(corner.fighters[1].state=="idle" and corner.fighters[1].y==Combat.FLOOR and corner.fighters[1].x>=Combat.LEFT and corner.fighters[1].x<=Combat.RIGHT,"Corner knockdown lands and recovers inside stage, side "+str(side))
	while sim.fighters[1].state=="down": sim.step([{},{}])
	await snapshot("knockdown-getup")
	main.begin_match();main.sim.phase="fight";main.sim.wins=[1,0]
	main.sim.fighters[1].health=0
	main.sim.end_round()
	for event in main.sim.events: main.dispatch_combat_event(event)
	check(not main.music.playing,"Music stops on the KO frame before defeat voice dispatch")
	check(main.ko_slowmo_frames==72 and main.combat_time_scale()==.25,"Decisive KO starts quarter-speed presentation")
	var tick_before=main.sim.tick
	for i in 24: main._physics_process(1.0/60.0)
	check(main.sim.tick-tick_before==6,"Combat remains fixed-step: six simulation steps over 24 slow-motion frames")
	var remaining=main.ko_slowmo_frames
	main.toggle_pause()
	for i in 12: main._physics_process(1.0/60.0)
	check(main.ko_slowmo_frames==remaining,"Pause freezes the slow-motion effect")
	main.toggle_pause()
	for i in 60: main._physics_process(1.0/60.0)
	check(main.combat_time_scale()==1.0,"Slow motion returns automatically to normal speed")
	check(not main.match_end_audio.playing,"Completion clip waits for the KO presentation to finish")
	main.sim.phase="round_end";main.sim.phase_timer=1
	main._physics_process(1.0/60.0)
	await create_timer(.08).timeout
	check(main.sim.phase=="results" and main.match_end_audio.playing and main.match_end_played,"Final KO goes directly to results and completion audio")
	var position=main.match_end_audio.get_playback_position()
	for i in 20: main.sync_match_end_audio()
	await create_timer(.08).timeout
	check(main.match_end_audio.get_playback_position()>position,"Results frames do not restart the completion clip")
	main.match_end_audio.seek(main.match_end_audio.stream.get_length()-.10)
	await create_timer(.35).timeout
	main.sync_match_end_audio()
	check(not main.match_end_audio.playing and main.match_end_played,"Completion clip finishes once without restarting on the results screen")
	main.action("rematch")
	check(not main.match_end_audio.playing and not main.match_end_played and main.music.playing,"Rematch stops the completion clip and restarts match music")
	main.sim.phase="round_end";main.sim.phase_timer=1;main.sim.winner=0;main.sim.wins=[2,0]
	main._physics_process(1.0/60.0)
	check(main.match_end_audio.playing,"A second completed match triggers completion audio again")
	main.action("back")
	check(not main.match_end_audio.playing and not main.music.playing,"Returning to title stops both tracks")
	check(main.menu_music.playing,"Returning to title restarts menu music")
	main.music_enabled=false;main.sync_match_end_audio()
	check(not main.menu_music.playing and not main.music.playing,"Music toggle also silences menu music")
	main.music_enabled=true;main.sync_match_end_audio()
	main.begin_match();main.sim.phase="fight";main.sim.fighters[1].health=0;main.sim.end_round()
	for event in main.sim.events: main.dispatch_combat_event(event)
	check(main.ko_slowmo_frames==0,"Non-decisive rounds do not trigger final-KO slow motion")
	main.queue_free()
	await process_frame
	var report=FileAccess.open("res://tests/knockdown-audio-verification.txt",FileAccess.WRITE)
	report.store_string("\n".join(checks)+"\nFailures: "+str(failures))
	print("KNOCKDOWN/AUDIO RESULT: ",checks.size()-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
