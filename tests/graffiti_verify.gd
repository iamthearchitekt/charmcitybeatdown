extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var failures=0
var checks=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func capture()->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run():
	var layer=Node2D.new();root.add_child(layer)
	var stage=Harbor.new();stage.attach(layer);stage.set_stage(2)
	check(stage.stage_name()=="GRAFFITI ALLEY" and stage.graffiti.get_size()==Vector2(1672,941),"New alley stage loads the full detailed painting")
	stage.graffiti_material.set_shader_parameter("water_frame",0)
	var first=await capture()
	stage.graffiti_material.set_shader_parameter("water_frame",1)
	var second=await capture()
	stage.graffiti_material.set_shader_parameter("water_frame",0)
	var repeat=await capture()
	check(first.get_data()==repeat.get_data(),"Two-frame loop repeats a pixel-identical first frame")
	var clock_pixels=0
	var reflection_pixels=0
	var window_pixels=0
	var outside=0
	var delta=0.0
	for y in first.get_height():
		for x in first.get_width():
			var a=first.get_pixel(x,y)
			var b=second.get_pixel(x,y)
			if a==b: continue
			var p=Vector2(x+.5,y+.5)*Vector2(1672.0/first.get_width(),941.0/first.get_height())
			if Rect2(864,224,114,76).has_point(p): clock_pixels+=1
			elif Rect2(815,778,208,54).has_point(p): reflection_pixels+=1
			else:
				var window=false
				for rect in Harbor.GRAFFITI_WINDOW_REGIONS:
					if rect.has_point(p): window=true;break
				if window: window_pixels+=1
				else: outside+=1
			delta+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	check(clock_pixels>500,"Only clock illumination changes at the tower")
	check(reflection_pixels>20,"Small blue puddle highlights alternate")
	check(window_pixels>500,"More existing skyscraper windows visibly twinkle in the second frame")
	check(outside==0,"Graffiti, architecture, cables and floor stay fixed outside the allowed light regions")
	var mean=delta/maxi(1,clock_pixels+reflection_pixels+window_pixels)/3.0
	check(mean>.015 and mean<.065,"Light changes are visible without a full-scene flash")
	print("ALLEY PIXELS clock=",clock_pixels," reflection=",reflection_pixels," windows=",window_pixels," outside=",outside," mean=",mean)
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	first.save_png("res://tests/visual/graffiti-frame-1.png")
	second.save_png("res://tests/visual/graffiti-frame-2.png")
	layer.queue_free();stage=null;await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false);game.selected_mode=2;game.begin_match()
	game.stage.set_stage(2);game.sim.phase="fight";game.sim.time_left=98*60
	game.paused=false;game.clock=.30
	game.queue_redraw()
	var fight=await capture()
	fight.save_png("res://tests/visual/graffiti-match.png")
	check(game.sim.fighters[0].y==622 and game.stage.at_graffiti,"Fighters use the established floor and scale on the new stage")
	game.paused=true;game.set_physics_process(true);game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	var paused=await capture()
	await create_timer(.30).timeout
	game.queue_redraw()
	var still_paused=await capture()
	check(paused.get_data()==still_paused.get_data(),"Pause freezes both the alley light state and fighter poses")
	game.queue_free();await process_frame
	print("GRAFFITI RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
