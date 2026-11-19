extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture()->Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	var layer=Node2D.new();root.add_child(layer)
	var stage=Harbor.new();stage.attach(layer);stage.set_stage(4)
	check(stage.stage_name()=="POWER PLANT LIVE!" and stage.powerplant.get_size()==Vector2(1672,941),"Fifth stage loads the nightlife plaza art")
	stage.powerplant_material.set_shader_parameter("water_frame",0);var first=await capture()
	stage.powerplant_material.set_shader_parameter("water_frame",1);var second=await capture()
	stage.powerplant_material.set_shader_parameter("water_frame",0);var repeat=await capture()
	check(first.get_data()==repeat.get_data(),"Exactly two fixed light states repeat identically")
	stage.backdrop.material=null;var original=await capture();stage.backdrop.material=stage.powerplant_material
	var neon_counts=[0,0,0,0]
	var reflected=0
	var outside=0
	var crowd_changes=0
	var styled=0
	var rail_changes=0
	var delta=0.0
	for y in first.get_height():
		for x in first.get_width():
			var a=first.get_pixel(x,y);var b=second.get_pixel(x,y)
			var p=Vector2(x+.5,y+.5)*Vector2(1672.0/first.get_width(),941.0/first.get_height())
			if a!=original.get_pixel(x,y) and Harbor.POWERPLANT_CROWD_REGIONS[0].has_point(p): styled+=1
			if a==b: continue
			var allowed=false
			var light=false
			for i in Harbor.POWERPLANT_NEON_REGIONS.size():
				if Harbor.POWERPLANT_NEON_REGIONS[i].has_point(p): neon_counts[i]+=1;allowed=true;light=true
			for rect in Harbor.POWERPLANT_REFLECTION_REGIONS:
				if rect.has_point(p): reflected+=1;allowed=true;light=true
			for rect in Harbor.POWERPLANT_CROWD_REGIONS:
				if rect.has_point(p): crowd_changes+=1;allowed=true
			if not allowed: outside+=1
			if Rect2(0,588,1672,12).has_point(p) or Rect2(0,671,1672,11).has_point(p): rail_changes+=1
			if light: delta+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	check(neon_counts.all(func(n):return n>50),"All four venue signs have a subtle neon flicker")
	check(reflected>1000,"Small reflected-light patches change on the pavement")
	check(outside==0,"Buildings and props outside crowd/light masks stay pixel-identical")
	check(styled>25000,"Entire front crowd receives Eutaw's finer pixel treatment")
	check(crowd_changes>5000,"Front crowd has a subtle two-frame group cheer")
	check(rail_changes==0,"Both horizontal barricade rails remain completely fixed")
	var changed=reflected
	for n in neon_counts: changed+=n
	var mean=delta/maxi(1,changed)/3.0
	check(mean<.025,"Neon and reflected-light changes stay subtle")
	print("POWER PLANT PIXELS signs=",neon_counts," reflected=",reflected," outside=",outside," crowd=",crowd_changes," styled=",styled," rails=",rail_changes," mean=",mean)
	first.save_png("res://tests/visual/powerplant-frame-1.png");second.save_png("res://tests/visual/powerplant-frame-2.png")
	layer.queue_free();stage=null;await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false);game.selected_mode=1;game.begin_match();game.stage.set_stage(4)
	game.sim.phase="fight";game.sim.time_left=98*60;game.clock=.30;game.queue_redraw()
	var fight=await capture();fight.save_png("res://tests/visual/powerplant-match.png")
	game.paused=true;game.set_physics_process(true);game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	var paused=await capture()
	await create_timer(.30).timeout;game.queue_redraw();var after=await capture()
	paused.save_png("res://tests/visual/powerplant-paused-before.png");after.save_png("res://tests/visual/powerplant-paused-after.png")
	check(paused.get_data()==after.get_data(),"Pause freezes the two-frame neon state and gameplay")
	game.queue_free();await process_frame
	print("POWER PLANT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
