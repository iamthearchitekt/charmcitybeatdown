extends SceneTree
var game
var failures=0
func _initialize(): call_deferred("run")
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_physics_process(false)
	await snap("no-maroon-title")
	game.screen="select";game.selection=[6,3];game.selected_mode=1
	await snap("corrected-spike-lauren-select")
	game.selected_mode=1;game.begin_match();game.sim.time_left=98*60;game.sim.phase="fight"
	for kind in 14:
		game.sim.new_match(kind,(kind+1)%14);game.sim.phase="fight";game.sim.time_left=98*60
		game.sim.fighters[0].x=580;game.sim.fighters[1].x=671
		game.sim.step([{"command":"throw"},{}])
		var seen={}
		for i in 90:
			game.sim.step([{},{}])
			var a=game.sim.fighters[0]
			var impact=preload("res://scripts/grapple_sequences.gd").profile(kind,"throw").impact
			for step in [1,8,14,impact]:
				if a.throw_target>=0 and a.grab_frame==step and not seen.has(step):
					seen[step]=true;await snap("throw-"+str(kind)+"-"+str(step))
		if seen.size()!=4: failures+=1
	game.paused=true;await snap("quiet-grunts-sega-y-moves")
	game.queue_free();await process_frame
	print("THROW VISUAL RESULT: ",14-failures," fighters captured; ",failures," failed")
	quit(1 if failures else 0)
