extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false);game.clock=0
	game.screen="select";await capture("baltimore-player-select")
	check(game.city_map.data.boundary.size()==8 and game.city_map.data.markers.size()==6,"Baltimore municipal silhouette and six local stage markers replace the world map")
	check(game.art.presentation_scale(7)<game.art.presentation_scale(6) and game.art.presentation_scale(7)>.97,"Eric is nearly Spike's height while staying slightly shorter")
	for kind in 11:
		var grounded=true
		for frame in [0,1,2,3,8,15]:
			var sprite=game.art.sprite_frame(kind,frame);game.art.cache_ground_contacts(sprite)
			var used=sprite.texture.get_image().get_used_rect()
			var sole=-sprite.size.y+used.end.y*game.art.PIXEL_UNIT+sprite.ground_gap
			grounded=grounded and absf(sole)<.001 and not sprite.ground_contacts.is_empty()
		check(grounded,"Opaque contact row sits on floor in idle/crouch/KO: fighter "+str(kind))
	game.selected_mode=1;game.begin_match();game.sim.phase="fight";game.sim.time_left=98*60
	game.stage.set_stage(3);game.sim.new_match(7,6);game.sim.phase="fight";game.sim.time_left=98*60
	await capture("eric-spike-grounded")
	game.sim.new_match(1,9);game.sim.phase="fight";game.sim.time_left=98*60
	await capture("women-grounded")
	game.sim.fighters[1].state="ko"
	await capture("supine-grounded")
	game.queue_free();await process_frame
	print("PRESENTATION RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
