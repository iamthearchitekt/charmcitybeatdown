extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var failures=0
var report:Array=[]

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	report.append(("PASS " if ok else "FAIL ")+label)
	print(report[-1])
	if not ok: failures+=1

func capture()->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run():
	var layer=Node2D.new()
	root.add_child(layer)
	var harbor=Harbor.new()
	harbor.attach(layer)
	harbor.water_material.set_shader_parameter("water_frame",0)
	var a=await capture()
	harbor.water_material.set_shader_parameter("water_frame",1)
	var b=await capture()
	harbor.water_material.set_shader_parameter("water_frame",0)
	var a_again=await capture()
	check(a.get_data()==a_again.get_data(),"Two-frame backdrop returns to a pixel-identical first frame")
	var inside=0
	var outside=0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y)!=b.get_pixel(x,y):
				if Rect2i(77,387,856,58).has_point(Vector2i(x,y)): inside+=1
				else: outside+=1
	check(inside>500,"Water visibly changes between the two background frames")
	check(outside==0,"Skyline, boat, dock, lamps, bollards and chains remain pixel-identical")
	layer.queue_free()
	await process_frame
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.selected_mode=2
	main.begin_match()
	main.sim.fighters[0].y=490
	main.sim.fighters[0].vy=-9
	main.paused=true
	main.queue_redraw()
	var paused_a=await capture()
	await create_timer(.65).timeout
	main.queue_redraw()
	var paused_b=await capture()
	check(paused_a.get_data()==paused_b.get_data(),"Pause is pixel-identical across time, including fighters and rain")
	main.paused=false
	await create_timer(.15).timeout
	main.paused=true
	main.queue_redraw()
	var resumed=await capture()
	check(resumed.get_data()!=paused_b.get_data(),"Resuming advances the fighters and weather again")
	main.queue_free()
	await process_frame
	var file=FileAccess.open("res://tests/visual-regressions.txt",FileAccess.WRITE)
	file.store_string("\n".join(report)+"\nFailures: "+str(failures))
	quit(1 if failures>0 else 0)
