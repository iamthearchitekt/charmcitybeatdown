extends SceneTree
var main
var destination="res://tests/visual"

func _initialize(): call_deferred("run")

func snap(name:String):
	main.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+"/"+name+".png")
	print("Captured ",name)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): destination=arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(destination)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock=0
	await snap("title")
	main.screen="select"
	await snap("select")
	main.selected_mode=1
	main.begin_match()
	main.sim.phase="fight"
	main.sim.time_left=98*60
	await snap("match")
	main.sim.step([{"up":true},{"up":true}])
	for i in 23: main.sim.step([{},{}])
	await snap("jump-apex")
	main.sim.new_match(0,1)
	main.sim.phase="fight";main.sim.time_left=98*60
	main.paused=true
	await snap("pause")
	main.paused=false
	main.sim.fighters[0].x=520.0
	main.sim.fighters[1].x=710.0
	main.sim.start_move(main.sim.fighters[0],"hp")
	main.sim.fighters[0].frame=12
	main.sim.fighters[1].state="block"
	await snap("attack-guard")
	main.sim.fighters[0].move=""
	main.sim.fighters[0].crouch=true
	main.sim.fighters[1].state="ko"
	await snap("crouch-ko")
	main.sim.phase="results"
	main.sim.winner=0
	main.sim.wins=[2,1]
	await snap("results")
	main.queue_free()
	await process_frame
	quit()
