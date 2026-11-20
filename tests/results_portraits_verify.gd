extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name:String):
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/results/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual/results")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	game.clock=0
	game.selected_mode=1
	game.begin_match()
	check(game.results_portraits.entries.size()==game.sim.data.fighters.size(),"All playable fighters have dedicated result artwork")
	for kind in game.sim.data.fighters.size():
		var win:Texture2D=game.results_portraits.portrait_frame(game.art,kind,true)
		var loss:Texture2D=game.results_portraits.portrait_frame(game.art,kind,false)
		check(win.get_image().get_data()!=loss.get_image().get_data(),"Victory and injured expressions are distinct: "+str(kind))
		var clean_alpha=true
		for texture in [win,loss]:
			var pixels:Image=texture.get_image()
			for y in pixels.get_height():
				for x in pixels.get_width():
					var alpha=pixels.get_pixel(x,y).a
					clean_alpha=clean_alpha and (alpha==0.0 or alpha==1.0)
		check(clean_alpha,"No soft background halo after shared pixel treatment: "+str(kind))
		game.sim.new_match(kind,(kind+1)%game.sim.data.fighters.size())
		game.sim.phase="results"
		game.sim.winner=0
		game.sim.wins=[2,0]
		await capture("fighter-"+str(kind))
	check(game.results_portraits.frames.size()==game.sim.data.fighters.size()*2,"Every victory and defeat portrait renders through the shared cache")
	game.sim.new_match(9,10)
	game.sim.winner=1
	game.sim.wins=[0,2]
	game.sim.phase="results"
	await capture("jeff-wins-from-p2")
	game.action("confirm")
	check(game.screen=="match" and game.sim.phase=="intro","Results confirmation still starts the next match")
	game.selected_mode=0
	game.begin_bonus()
	game.sim.phase="fight"
	check(game.sim.time_left==25*60,"Car bonus starts with 25 seconds")
	await capture("car-clean-hud")
	game.sim.finish(true)
	game.sync_match_end_audio()
	await capture("car-code")
	check(game.sim.reward_code.length()==3,"Clean car results retain earned unlock code")
	game.queue_free()
	await process_frame
	print("RESULT PORTRAITS: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
