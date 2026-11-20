extends SceneTree

const Stage=preload("res://scripts/harbor_stage.gd")
const FLAG_PATCHES=[Rect2(440,67,144,78),Rect2(890,105,131,78),Rect2(1245,151,119,70)]

func _initialize(): call_deferred("run")

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
	stage.set_stage(Stage.PIMLICO)
	assert(stage.backdrop.texture==stage.pimlico and stage.pimlico.get_size()==Vector2(1672,941))
	stage.draw(layer,0.0)
	var first=await frame()
	stage.draw(layer,.25)
	var second=await frame()
	stage.draw(layer,.50)
	assert(first.get_data()==(await frame()).get_data(),"Pimlico repeats the same two poses")
	var changed=[0,0,0]
	var outside=0
	for y in first.get_height():
		for x in first.get_width():
			if first.get_pixel(x,y)==second.get_pixel(x,y): continue
			var point=Vector2(x+.5,y+.5)*stage.pimlico.get_size()/Vector2(first.get_size())
			var patch=-1
			for i in FLAG_PATCHES.size():
				if FLAG_PATCHES[i].has_point(point): patch=i
			if patch>=0: changed[patch]+=1
			else: outside+=1
	assert(changed.all(func(count):return count>200) and outside==0,"All three flags move while the venue stays fixed")
	layer.queue_free()
	await process_frame
	print("PIMLICO RESULT: three two-frame flags, ",changed," changed pixels")
	quit()
