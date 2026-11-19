extends SceneTree
var game
var destination=""
func _initialize(): call_deferred("run")
func capture(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(name+".png"))
func run():
	destination=ProjectSettings.globalize_path("res://tests/visual")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("capture="): destination=arg.trim_prefix("capture=")
	DirAccess.make_dir_recursive_absolute(destination)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.selected_mode=1;game.begin_match()
	for entry in [[6,"special3"],[4,"special1"]]:
		var kind=int(entry[0]);var name=String(entry[1]);game.stage.set_stage(0 if kind==6 else 3)
		game.sim.new_match(kind,0);game.sim.phase="fight";game.sim.time_left=98*60
		game.sim.fighters[0].x=440;game.sim.fighters[1].x=860
		var f=game.sim.fighters[0];game.sim.start_move(f,name);var move=game.sim.move_data(f)
		for step in [0,2,4,6]:
			f.frame=move.startup+step;await capture("element-"+str(kind)+"-phase-"+str(step))
		f.frame=move.startup+4
		var target=game.sim.fighters[1];target.x=630;target.state="hit";target.element_hit=move.element;target.element_timer=20;target.pose_tick=4
		await capture("element-"+str(kind)+"-impact")
		f.x=800;f.facing=-1;target.x=610;target.facing=1
		await capture("element-"+str(kind)+"-left")
	game.sim.new_match(6,4);game.paused=true;await capture("element-sega-moves")
	game.queue_free();await process_frame
	print("ELEMENT VISUAL CAPTURES COMPLETE")
	quit()
