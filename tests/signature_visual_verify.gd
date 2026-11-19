extends SceneTree
var game
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.selected_mode=1;game.begin_match();game.stage.set_stage(3)
	for entry in [[1,"special3"],[2,"special3"],[5,"special3"],[5,"special4"]]:
		var kind=int(entry[0]);var name=String(entry[1])
		game.sim.new_match(kind,6);game.sim.phase="fight";game.sim.time_left=98*60
		game.sim.fighters[0].x=480;game.sim.fighters[1].x=900
		var f=game.sim.fighters[0];game.sim.start_move(f,name)
		var move=game.sim.move_data(f)
		var poses={}
		for step in [1,5,9,13,17,21]:
			f.frame=move.startup+step
			if move.has("hover_height"): f.y=game.sim.FLOOR-move.hover_height
			var sprite=game.art.signature_art.sprite(f,move,game.art)
			poses[game.art.signature_art.animation_frame(f,move)]=true
			check(not sprite.is_empty() and sprite.texture.get_image().get_used_rect().has_area(),"Real sprite frame decodes: "+str(kind)+" "+name+" "+str(step))
			await capture("signature-"+str(kind)+"-"+name+"-"+str(step))
		check(poses.size()>=3,"Animation uses at least three distinct poses: "+str(kind)+" "+name)
	game.sim.new_match(5,1);game.paused=true;await capture("signature-sega-move-list")
	game.queue_free();await process_frame
	print("SIGNATURE VISUAL RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
