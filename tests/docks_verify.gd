extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func capture()->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run():
	var layer=Node2D.new()
	root.add_child(layer)
	var stage=Harbor.new()
	stage.attach(layer)
	stage.at_seagirt=true
	stage.backdrop.texture=stage.docks
	stage.backdrop.scale=Vector2(1280.0/stage.docks.get_width(),720.0/stage.docks.get_height())
	stage.backdrop.material=stage.docks_material
	stage.docks_material.set_shader_parameter("water_frame",0)
	var a=await capture()
	stage.docks_material.set_shader_parameter("water_frame",1)
	var b=await capture()
	stage.docks_material.set_shader_parameter("water_frame",0)
	var repeat=await capture()
	check(a.get_data()==repeat.get_data(),"Two frames repeat exactly")
	var water=0
	var smoke=0
	var sign=0
	var outside=0
	var delta=0.0
	for y in a.get_height():
		for x in a.get_width():
			var first=a.get_pixel(x,y)
			var second=b.get_pixel(x,y)
			if first!=second:
				var p=Vector2(x+.5,y+.5)*Vector2(1672.0/a.get_width(),941.0/a.get_height())
				if Rect2(440,520,1025,116).has_point(p): water+=1
				elif Rect2(974,258,218,97).has_point(p): smoke+=1
				elif Harbor.DUNDALK_SIGN_REGION.has_point(p): sign+=1
				else: outside+=1
				delta+=abs(first.r-second.r)+abs(first.g-second.g)+abs(first.b-second.b)
	check(water>500,"Water changes visibly")
	check(smoke>100,"Stack smoke changes visibly")
	check(sign>300,"Domino Sugars sign has a second-frame warm glow")
	check(outside==0,"Everything outside water, smoke and sign glow is pixel-identical")
	check(delta/maxi(1,water+smoke+sign)/3.0<0.035,"Average change stays subtle")
	print("Changed pixels: water=",water," smoke=",smoke," sign=",sign," outside=",outside," average RGB change=",delta/maxi(1,water+smoke+sign)/3.0)
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	a.save_png("res://tests/visual/dundalk-frame-1.png")
	b.save_png("res://tests/visual/dundalk-frame-2.png")
	layer.queue_free()
	await process_frame
	quit(1 if failures else 0)
