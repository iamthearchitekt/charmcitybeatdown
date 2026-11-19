extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var checks=0
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func capture()->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func in_crowd(p:Vector2)->bool:
	for rect in Harbor.CAMDEN_CROWD_REGIONS:
		if rect.has_point(p): return true
	return false

func run():
	var layer=Node2D.new();root.add_child(layer)
	var stage=Harbor.new();stage.attach(layer);stage.set_stage(3)
	check(stage.at_camden and "EUTAW STREET" in stage.stage_name() and stage.camden.get_size()==Vector2(1672,941),"Eutaw Street loads the daytime warehouse painting")
	stage.backdrop.material=null
	var raw=await capture()
	stage.backdrop.material=stage.camden_material
	stage.camden_material.set_shader_parameter("water_frame",0)
	var first=await capture()
	stage.camden_material.set_shader_parameter("water_frame",1)
	var second=await capture()
	stage.camden_material.set_shader_parameter("water_frame",0)
	var repeat=await capture()
	check(first.get_data()==repeat.get_data(),"Cheering uses exactly two repeatable frames")
	var styled=0
	var cheering=0
	var outside=0
	var raw_colors={}
	var pixel_colors={}
	var moved_groups=[]
	for rect in Harbor.CAMDEN_CROWD_REGIONS: moved_groups.append(false)
	for y in first.get_height():
		for x in first.get_width():
			var p=Vector2(x+.5,y+.5)*Vector2(1672.0/first.get_width(),941.0/first.get_height())
			var a=first.get_pixel(x,y)
			var b=second.get_pixel(x,y)
			var original=raw.get_pixel(x,y)
			if in_crowd(p):
				raw_colors[original.to_rgba32()]=true
				pixel_colors[a.to_rgba32()]=true
				if a!=original: styled+=1
				if a!=b:
					cheering+=1
					for i in Harbor.CAMDEN_CROWD_REGIONS.size():
						if Harbor.CAMDEN_CROWD_REGIONS[i].has_point(p): moved_groups[i]=true
			elif a!=b or a!=original: outside+=1
	check(styled>5000 and pixel_colors.size()<raw_colors.size()*.95,"All fan groups use the finer two-pixel, detail-preserving treatment")
	check(cheering>1000 and moved_groups.all(func(v):return v),"All spectator groups perform the subtle second-frame cheer")
	check(outside==0,"Warehouse, gates, BBQ carts, smoke, plaques and paving remain pixel-identical")
	print("CAMDEN PIXELS styled=",styled," cheering=",cheering," outside=",outside," colors=",raw_colors.size()," -> ",pixel_colors.size())
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	first.save_png("res://tests/visual/camden-frame-1.png")
	second.save_png("res://tests/visual/camden-frame-2.png")
	layer.queue_free();stage=null;await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.selected_mode=1;game.begin_match();game.stage.set_stage(3)
	game.sim.phase="fight";game.sim.time_left=98*60;game.clock=.30
	game.queue_redraw()
	var fight=await capture()
	fight.save_png("res://tests/visual/camden-match.png")
	check(game.sim.fighters[0].y==622 and game.stage.at_camden,"Fighters retain the established size and floor alignment")
	game.paused=true;game.set_physics_process(true);game.queue_redraw()
	var paused=await capture()
	await create_timer(.30).timeout
	game.queue_redraw()
	var paused_again=await capture()
	check(paused.get_data()==paused_again.get_data(),"Pause freezes crowd cheering and fighter animation")
	game.queue_free();await process_frame
	print("CAMDEN RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
