extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_physics_process(false)
	game.unlocks.all_unlocked=false;game.unlocks.unlocked=[]
	for kind in [7,8]:
		check(game.unlocks.available(game.sim.data.fighters[kind]),"Racer is available with a fresh save: "+str(kind))
		check(game.art.regions[kind].size()==18 and game.art.throw_atlases[str(kind)].regions.size()==4,"Complete attacks, jumps, KO and throw poses: "+str(kind))
	check(game.art.sprite_frame(8,0).size.y>game.art.sprite_frame(7,0).size.y*1.1,"Stan is visibly taller than Eric")
	check(game.select_columns()==6,"Eleven-fighter selection fits two rows")
	game.selected_mode=1;game.screen="select";game.selection=[7,8];game.select_slot=0
	await snap("eric-stan-select")
	game.action("fighter7");game.action("confirm");game.action("fighter8");game.action("confirm")
	check(game.sim.fighters[0].kind==7 and game.sim.fighters[1].kind==8,"Eric and Stan can be selected into a match")
	game.sim.phase="fight";game.sim.time_left=98*60
	await snap("eric-stan-match")
	for f in game.sim.fighters: f.state="ko";f.health=0
	await snap("eric-stan-face-up-ko")
	game.sim.new_match(2,6);game.sim.phase="fight";game.sim.time_left=98*60
	await snap("alex-spike-likeness-match")
	game.screen="select";game.selection=[2,6];await snap("alex-spike-likeness-select")
	game.queue_free();await process_frame
	print("RACERS RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
