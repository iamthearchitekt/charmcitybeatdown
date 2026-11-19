extends SceneTree
var game
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false)
	game.selected_mode=1;game.begin_match();game.sim.new_match(6,0);game.sim.phase="fight";game.sim.time_left=98*60
	game.sim.fighters[0].x=300;game.sim.fighters[1].x=980
	game.sim.start_move(game.sim.fighters[0],"special1");game.sim.start_move(game.sim.fighters[1],"special1")
	for frame in 23: game.sim.step([{},{}])
	check(game.sim.projectiles.size()==2,"Spike and Marcus can launch their projectiles together")
	check(game.sim.projectiles[0].m.projectile_skin=="fire" and not game.sim.projectiles[1].m.has("projectile_skin"),"Fire skin belongs only to Spike; other plasma balls remain blue")
	check(game.sim.projectiles[0].m.damage==game.sim.projectiles[1].m.damage,"Spike's visual change preserves projectile damage")
	var warm=0;var cool=0
	for texture in game.arcade_projectile.fire_frames:
		var im=texture.get_image()
		for y in im.get_height():
			for x in im.get_width():
				var c=im.get_pixel(x,y)
				if c.a>.5 and c.r>c.b+.25: warm+=1
	for texture in game.arcade_projectile.frames:
		var im=texture.get_image()
		for y in im.get_height():
			for x in im.get_width():
				var c=im.get_pixel(x,y)
				if c.a>.5 and c.b>c.r+.25: cool+=1
	check(warm>500 and cool>500,"Fire uses warm flame pixels while original plasma keeps its blue palette")
	for skin in ["","fire","violet"]:
		var distinct=true
		for phase in range(0,8,2):
			var bright:Image=game.arcade_projectile.pulse_texture(skin,phase).get_image()
			var dim:Image=game.arcade_projectile.pulse_texture(skin,phase+1).get_image()
			var contrast=0.0
			var opaque=0
			for y in bright.get_height():
				for x in bright.get_width():
					var hot=bright.get_pixel(x,y)
					var cool_pixel=dim.get_pixel(x,y)
					distinct=distinct and hot.a==cool_pixel.a
					if hot.a>.5:
						contrast+=hot.get_luminance()-cool_pixel.get_luminance()
						opaque+=1
			distinct=distinct and opaque>0 and contrast/maxi(1,opaque)>.12
		check(distinct,"Every tick pair strobes in place with the same alpha silhouette: "+(skin if skin!="" else "blue"))
	game.paused=true
	var pulse_tick=game.projectile_tick
	game._physics_process(1.0/60)
	check(game.projectile_tick==pulse_tick,"Pause freezes the projectile strobe")
	game.paused=false
	game.impact_recovery_frames=8
	game.impact_recovery_length=8
	game.simulation_accumulator=0
	var sim_tick=game.sim.tick
	game._physics_process(1.0/60)
	check(game.sim.tick==sim_tick and game.projectile_tick==pulse_tick+1,"The strobe keeps its speed when impact slowdown skips simulation")
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/spike-fire-vs-blue-plasma.png")
	game.queue_free();await process_frame
	print("SPIKE FIRE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
