extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Art=preload("res://scripts/fighter_sprites.gd")
var failures=0
var checks=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func run():
	var art=Art.new()
	check(art.sprite_frame(0,0).texture.get_height()>=160,"Standing sprites retain at least 160 native pixels of detail")
	var flat=Image.create(64,64,false,Image.FORMAT_RGBA8)
	flat.fill(Color(.5,.5,.5,1))
	var texture=ImageTexture.create_from_image(flat)
	var dither=art.pixel_texture(texture,Rect2(0,0,64,64),Vector2(57.6,57.6)).get_image()
	var tones={}
	var total=0.0
	for y in dither.get_height():
		for x in dither.get_width():
			var color=dither.get_pixel(x,y)
			tones[color.r8]=true
			total+=color.r
	check(tones.size()>1 and absf(total/(dither.get_width()*dither.get_height())-.5)<.01,"Dithering adds fine texture while preserving the average shade")
	for kind in art.sheets.size():
		var consistent=true
		var opaque=true
		for frame in 18:
			var sprite=art.sprite_frame(kind,frame)
			var image=sprite.texture.get_image()
			consistent=consistent and sprite.size==Vector2(image.get_size())*Art.PIXEL_UNIT
			for y in image.get_height():
				for x in image.get_width():
					var a=image.get_pixel(x,y).a
					opaque=opaque and (a==0 or a==1)
		check(consistent,"All 18 poses share one pixel density: fighter "+str(kind))
		check(opaque,"All 18 poses have hard pixel edges: fighter "+str(kind))
		var ko=art.sprite_frame(kind,15)
		check(ko.source==Rect2(art.ground_regions[kind][0],art.ground_regions[kind][1],art.ground_regions[kind][2],art.ground_regions[kind][3]) if kind==0 else ko.source==Rect2(art.regions[kind][15][0],art.regions[kind][15][1],art.regions[kind][15][2],art.regions[kind][15][3]),"Uses verified face-up KO artwork: fighter "+str(kind))
		for facing in [-1,1]:
			var sim=Combat.new()
			sim.new_match((kind+1)%art.sheets.size(),kind)
			sim.phase="fight"
			var victim=sim.fighters[1]
			victim.facing=facing
			victim.health=0
			victim.x=640
			victim.y=400
			victim.vy=-8
			victim.vx=-facing*12.6
			victim.bounce_speed=4.2
			sim.end_round()
			check(art.pose(victim,0)==13,"Airborne KO uses falling pose: "+str(kind)+" facing "+str(facing))
			var bounces=0
			for i in 110:
				sim.step([{},{}])
				for e in sim.events:
					if e.type=="bounce": bounces+=1
			check(victim.y==Combat.FLOOR and victim.vy==0 and art.pose(victim,0)==15 and victim.facing==facing and bounces==1,"KO settles face-up with one bounce and locked direction: "+str(kind)+" facing "+str(facing))
	var sim=Combat.new()
	sim.phase="fight"
	sim.fighters[0].x=450
	var back={"dx":-1,"back":true}
	for i in 8: sim.step([back,{}])
	var stopped=sim.fighters[0].x
	for i in 60: sim.step([back,{}])
	check(is_equal_approx(stopped,414) and sim.fighters[0].x==stopped and sim.fighters[0].guard,"Holding back takes one 36-unit step then holds stationary guard")
	sim.step([{},{}]);sim.step([back,{}])
	check(sim.fighters[0].x<stopped,"Releasing and pressing back permits another step")
	check(art.pixel_frames.size()==art.sheets.size()*18,"All roster poses are cached, including all available fighters")
	if DisplayServer.get_name()!="headless":
		var game=load("res://main.tscn").instantiate()
		root.add_child(game)
		game.set_process_input(false)
		game.set_physics_process(false)
		game.selected_mode=1
		game.begin_match()
		game.sim.phase="fight"
		game.sim.time_left=98*60
		for pair in [[0,1],[2,3]]:
			game.sim.new_match(pair[0],pair[1])
			game.sim.phase="fight"
			for f in game.sim.fighters:
				f.state="ko";f.health=0
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/visual/pixel-ko-"+str(pair[0])+".png")
		game.sim.new_match(0,3);game.sim.phase="fight"
		game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/visual/pixel-standing.png")
		game.queue_free();await process_frame
	print("PIXEL/KO RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
