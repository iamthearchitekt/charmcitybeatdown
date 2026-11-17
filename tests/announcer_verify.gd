extends SceneTree
var main
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
	main.set_physics_process(false);main.begin_match()
	main.dispatch_combat_event({"type":"fight"})
	check(main.announcer.playing and main.announcer.playback_log[-1]=="fight","Fight voice plays on round start")
	main.toggle_pause();check(main.announcer.stream_paused,"Announcer pauses with match")
	main.toggle_pause();check(not main.announcer.stream_paused,"Announcer resumes with match")
	for mode in [0,1]:
		for winner in 2:
			main.selected_mode=mode;main.begin_match();main.sim.winner=winner;main.sim.wins[winner]=2;main.sim.phase="results"
			main.announcer.playback_log.clear();main.sync_match_end_audio()
			check(main.announcer.playback_log==["you"],"Results start YOU once")
			await create_timer(1.3).timeout
			var result="lose" if mode==0 and winner==1 else "win"
			check(main.announcer.playback_log==["you",result],"Correct sequenced result voice: mode "+str(mode)+" winner "+str(winner))
			main.sync_match_end_audio();check(main.announcer.playback_log.size()==2,"Result voice does not repeat")
	main.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/centered-results.png")
	check(main.buttons.all(func(b): return is_equal_approx(b.rect.get_center().x,640.0)),"Result actions centered")
	main.begin_match();check(not main.announcer.playing and main.announcer.pending.is_empty(),"Rematch stops result voice")
	main.sim.winner=0;main.sim.wins=[2,0];main.sim.phase="results";main.sync_match_end_audio()
	main.action("back");check(not main.announcer.playing and main.announcer.pending.is_empty(),"Title exit stops voice and queue")
	main.queue_free();await process_frame
	print("ANNOUNCER CHECKS: ",checks,"; FAILURES: ",failures)
	quit(1 if failures else 0)
