extends SceneTree

const Stage=preload("res://scripts/harbor_stage.gd")
var failures=0

func _initialize(): call_deferred("run")

func check(value:bool,message:String):
	print(("PASS " if value else "FAIL ")+message)
	if not value: failures+=1

func frame()->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run():
	root.size=Vector2i(1280,720)
	var layer=Node2D.new()
	root.add_child(layer)
	var stage=Stage.new()
	stage.attach(layer)
	stage.set_stage(Stage.STADIUM)
	check(stage.stadium.get_size()==stage.camden.get_size() and stage.backdrop.texture==stage.stadium,"Stadium uses Camden's native raster dimensions")
	stage.draw(layer,0.0)
	var first=await frame()
	stage.draw(layer,.25)
	var second=await frame()
	stage.draw(layer,.50)
	var repeat=await frame()
	check(first.get_data()==repeat.get_data(),"Crowd returns to an identical first pose")
	var gesture_sheet=stage.stadium_material.get_shader_parameter("gestures") as Texture2D
	var gestures=gesture_sheet.get_image()
	check(gestures.get_size()==Vector2i(1672,941),"Cheer art is registered to the original stadium pixels")
	var changed=0
	var outside=0
	for y in first.get_height():
		for x in first.get_width():
			if first.get_pixel(x,y)==second.get_pixel(x,y): continue
			changed+=1
			var source=Vector2i(Vector2(x+.5,y+.5)*Vector2(gestures.get_size())/Vector2(first.get_size()))
			if gestures.get_pixelv(source).a==0.0: outside+=1
	check(changed>1000,"Second frame visibly raises hands, cups, and towels")
	check(outside==0,"Every pixel outside the painted gestures stays fixed")
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():
		DirAccess.make_dir_recursive_absolute(args[0])
		first.save_png(args[0].path_join("stadium-frame-1.png"))
		second.save_png(args[0].path_join("stadium-frame-2.png"))
	layer.queue_free()
	await process_frame
	print("STADIUM RESULT: ",failures," failed; ",changed," animated pixels")
	quit(1 if failures else 0)
