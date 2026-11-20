extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false)
	check(game.menu_music.stream.resource_name=="title-street-of-rage.mp3" and game.menu_music.playing,"New supplied Street of Rage track plays on the title screen")
	check(game.menu_music.stream.loop and game.menu_music.stream.get_length()>15,"Title MP3 decodes and loops without requiring an editor import")
	game.selected_mode=1;game.begin_match();game.sim.phase="fight"
	var expected=["go-straight.ogg","back-to-the-industry.ogg","alien-power.ogg","go-straight.ogg","never-return-alive.ogg","revenge-of-mr-x.ogg","back-to-the-industry.ogg","alien-power.ogg","go-straight.ogg","go-straight.ogg","back-to-the-industry.ogg"]
	for index in expected.size():
		game.stage.set_stage(index);game.sync_match_end_audio()
		check(game.music.stream.resource_name==expected[index] and game.music.playing,"Correct stage track: "+game.stage.stage_name())
		check(game.music.stream.loop and game.music.stream.get_length()>15,"Stage track decodes as a seamless Ogg loop: "+expected[index])
		game.music.seek(game.music.stream.get_length()-.20)
		await create_timer(.45).timeout
		check(game.music.playing and game.music.get_playback_position()<1.0,"Prepared music crosses its loop boundary without stopping: "+expected[index])
	check(not game.menu_music.playing,"Title track stops while a stage track is playing")
	game.stage.set_stage(2);game.sync_match_end_audio();await create_timer(.15).timeout
	var stream=game.music.stream
	var before=game.music.get_playback_position()
	game.sim.fighters[1].health=0;game.sim.end_round()
	for event in game.sim.events: game.dispatch_combat_event(event)
	game.sync_match_end_audio();await create_timer(.15).timeout
	check(game.music.playing and game.music.stream==stream and game.music.get_playback_position()>before,"Alien Power continues through a non-final KO without restarting")
	before=game.music.get_playback_position();game.sim.reset_round();game.sync_match_end_audio();await create_timer(.15).timeout
	check(game.music.stream==stream and game.music.get_playback_position()>before,"Next-round intro retains the same Alien Power playback")
	game.toggle_pause();check(game.music.stream_paused,"Stage music pauses with gameplay")
	game.toggle_pause();check(not game.music.stream_paused,"Stage music resumes with gameplay")
	game.sim.phase="fight";game.sim.wins=[1,0];game.sim.fighters[1].health=0;game.sim.end_round()
	for event in game.sim.events: game.dispatch_combat_event(event)
	game.sync_match_end_audio();check(not game.music.playing,"Only the completed fight stops the stage track")
	game.action("title")
	check(game.menu_music.playing and game.menu_music.stream.resource_name=="title-street-of-rage.mp3" and not game.music.playing,"Returning to title restores the new title song")
	game.queue_free();await process_frame
	print("STAGE MUSIC RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
