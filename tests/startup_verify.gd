extends SceneTree
var checks=0
var failures=0
var output=""
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func shot(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	frame.save_png(output.path_join(name+".png"))
	return frame
func run():
	var start_msec=Time.get_ticks_msec()
	output=ProjectSettings.globalize_path("res://../work/startup-review")
	var skip=false
	var keyboard=false
	var early=false
	for arg in OS.get_cmdline_user_args():
		if arg=="test-skip": skip=true
		if arg=="test-keyboard-skip": skip=true;keyboard=true
		if arg=="test-early-skip": skip=true;early=true
		if arg.begins_with("capture="): output=arg.trim_prefix("capture=")
	DirAccess.make_dir_recursive_absolute(output)
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://startup.tscn","Developer intro is the actual launch scene")
	var intro=load("res://startup.tscn").instantiate()
	root.add_child(intro);current_scene=intro
	check(intro.video.stream!=null and intro.video.is_playing(),"Packaged developer video opens and starts")
	check(not intro.has_node("CharmCityBeatdown"),"Game audio cannot overlap developer video")
	intro.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	intro.size=Vector2(1000,1000);intro.fit_video()
	check(is_equal_approx(intro.video.size.x/intro.video.size.y,16.0/9.0) and intro.video.position.y>0,"Square window keeps full image with correct aspect ratio")
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);intro.fit_video()
	if skip:
		if not early: await create_timer(.35).timeout
		var release=InputEventJoypadButton.new();release.button_index=JOY_BUTTON_A;release.pressed=false
		intro._input(release)
		check(not intro.finishing,"Controller release does not skip")
		var key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;key.echo=true
		intro._input(key);check(not intro.finishing,"Key repeat does not skip")
		if keyboard:
			key.echo=false;intro._input(key)
		else:
			var button=InputEventJoypadButton.new();button.button_index=JOY_BUTTON_START if early else JOY_BUTTON_A;button.pressed=true
			intro._input(button)
		if early:
			check(intro.skip_requested and not intro.finishing,"An immediate Start press is queued during the first frames")
			await create_timer(.24).timeout
		check(not is_instance_valid(intro) or (intro.finishing and not intro.video.is_playing()),"Keyboard/controller press skips and stops intro audio")
	else:
		await create_timer(2.5).timeout
		check(is_instance_valid(intro) and intro.video.stream_position>1.0,"Video advances before automatic transition")
		var frame=await shot("bsod-video")
		var corrupt_pixels=0;var cyan_pixels=0;var samples=0
		for y in range(0,frame.get_height(),4):
			for x in range(0,frame.get_width(),4):
				var c=frame.get_pixel(x,y);samples+=1
				if (c.r>.3 and c.r>c.g*1.4) or (c.g>.3 and c.g>c.b*1.6): corrupt_pixels+=1
				if c.g>.15 and c.b>.15 and c.r<c.g*.8: cyan_pixels+=1
		check(corrupt_pixels<samples*.005 and cyan_pixels>100,"BSOD cyan branding renders without magenta/green decode corruption")
	var elapsed=0.0
	while current_scene==intro and elapsed<30:
		await create_timer(.1).timeout;elapsed+=.1
	check(current_scene!=intro and current_scene!=null,"Intro transitions automatically to game")
	print("Startup through title: ",Time.get_ticks_msec()-start_msec," ms")
	if current_scene!=intro and current_scene!=null:
		var game=current_scene
		check(game.screen=="title" and game.title_cursor==0,"Skip never leaks into title menu selection")
		check(game.menu_music.playing,"Title music begins after developer intro")
		await shot("bsod-title-after-skip" if skip else "bsod-title-after-video")
		game.queue_free();current_scene=null;await process_frame
	print("STARTUP RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
