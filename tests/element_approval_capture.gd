extends SceneTree
var game
var destination=""
func _initialize(): call_deferred("run")
func run():
	destination=ProjectSettings.globalize_path("res://../work/element-approval-frames")
	DirAccess.make_dir_recursive_absolute(destination)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.selected_mode=1;game.begin_match()
	for entry in [[6,"special3","Spike"],[4,"special1","Chelsea"]]:
		var kind=int(entry[0]);var name=String(entry[1]);var label=String(entry[2])
		game.stage.set_stage(0 if kind==6 else 3)
		game.sim.new_match(kind,0);game.sim.phase="fight";game.sim.time_left=98*60
		var f=game.sim.fighters[0];f.x=440;game.sim.fighters[1].x=930
		for tick in 120:
			if tick==24: game.sim.start_move(f,name)
			game.sim.step([{},{}])
			if tick%2!=0: continue
			game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			# Native-resolution in-game viewport crop; no redraw or simulated art.
			var shot=root.get_texture().get_image().get_region(Rect2i(260,240,520,420))
			shot.save_png(destination.path_join(label+"-"+str(int(tick/2)).pad_zeros(3)+".png"))
	game.queue_free();await process_frame
	print("APPROVAL CAPTURES COMPLETE")
	quit()
