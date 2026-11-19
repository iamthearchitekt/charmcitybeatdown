extends SceneTree
var game
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(path:String)->Image:
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();image.save_png(path);return image
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false)
	game.bonus_rewards.path="res://.runtime/car-visual-rewards.cfg";game.bonus_rewards.earned=[]
	game.begin_bonus();game.sim.phase="fight";game.clock=0
	check(game.music.stream.resource_name=="alien-power.ogg" and game.music.playing,"Alien Power plays on the Fells Point bonus stage")
	check(game.sim.car.textures.size()==0,"Car art loads lazily once")
	var folder="res://tests/visual/car-bonus/";DirAccess.make_dir_recursive_absolute(folder)
	var first=await capture(folder+"bonus-intact.png")
	check(game.sim.car.textures.size()==4,"Four front-facing damage states decode")
	game.clock=.25;var second=await capture(folder+"bonus-frame-2.png")
	game.clock=0;var repeat=await capture(folder+"bonus-repeat.png")
	check(first.get_data()==repeat.get_data(),"The two-frame loop repeats pixel-identically")
	var changes=0;var outside=0
	var crowd_changes=0
	for y in first.get_height():
		for x in first.get_width():
			if first.get_pixel(x,y)==second.get_pixel(x,y): continue
			changes+=1
			var source_y=float(y)*941.0/720.0
			if source_y>=418 and source_y<=585: crowd_changes+=1
			elif source_y>=410 and source_y<690: outside+=1
	check(changes>1000 and outside==0,"Two-frame changes stay in lights, upper-body crowd and reflections")
	check(crowd_changes>100,"Fells Point people have a restrained second upper-body pose")
	game.sim.car.hp=[0,140,350,350,400,350]
	await capture(folder+"bonus-part-damaged.png")
	game.sim.car.hp=[0,0,0,0,0,0]
	await capture(folder+"bonus-wreck.png")
	game.sim.finish(true);game.sync_match_end_audio()
	await capture(folder+"bonus-code-reward.png")
	check(game.sim.reward_code.length()==3,"Success view includes a three-letter reward")
	game.queue_free();await process_frame
	DirAccess.remove_absolute("res://.runtime/car-visual-rewards.cfg")
	print("CAR VISUAL RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
