extends SceneTree
const Bindings=preload("res://scripts/controller_bindings.gd")
var main
var failures=0
var count=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	count+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func button(index:int,down:bool=true,id:int=71):
	var e=InputEventJoypadButton.new();e.device=id;e.button_index=index;e.pressed=down
	main._input(e)
func axis(index:int,value:float,id:int=71):
	var e=InputEventJoypadMotion.new();e.device=id;e.axis=index;e.axis_value=value
	main._input(e)
func tap(index:int,id:int=71): button(index,true,id);button(index,false,id)
func key(code:int,down:bool=true):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
	Input.parse_input_event(e)
func run():
	main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
	main.set_physics_process(false)
	main.pads=Bindings.new();main.pads.profiles={};main.pads.path="user://controller-test.cfg"
	main.pads.connect_device(71,"test-sega");main.pads.connect_device(72,"test-second")
	main.begin_match();main.sim.phase="fight"
	check(main.KEYS==[[KEY_Z,KEY_X,KEY_C,KEY_V,KEY_B],[KEY_F,KEY_G,KEY_H,KEY_J,KEY_R]],"Original keyboard attacks unchanged")
	tap(JOY_BUTTON_X);check(main.read_control(0).command=="lp","Default Xbox mapping preserved")
	axis(JOY_AXIS_LEFT_X,.2);check(main.read_control(0).dx==0,"Stick deadzone ignores drift")
	axis(JOY_AXIS_LEFT_X,-1);check(main.read_control(0).dx==-1,"Default analog movement")
	axis(JOY_AXIS_LEFT_X,0)
	main.open_controller_setup();check(main.paused,"Controller setup pauses the match")
	tap(8)
	check(main.setup_step==0 and main.setup_device==71,"First button selects target pad without binding it")
	# Capture axis D-pad and arbitrary Sega button indices, including an axis-backed button.
	axis(0,-1);axis(0,0);axis(0,1);axis(0,0);axis(1,-1);axis(1,0);axis(1,1);axis(1,0)
	button(4);button(4)
	check(main.setup_step==5,"Held button cannot fill multiple wizard steps")
	button(4,false);tap(4)
	check(main.setup_step==5,"Duplicate gameplay bindings rejected")
	tap(5);tap(0);axis(4,1);axis(4,0);tap(6);tap(7);tap(0);tap(1)
	check(main.setup_step==12 and main.pads.profiles.has("test-sega"),"Complete Sega mapping saves")
	var stored=ConfigFile.new();stored.load(main.pads.path)
	check(stored.get_value("controllers","profiles",{}).get("test-sega",{})==main.setup_bindings,"Saved bindings round-trip to disk")
	key(KEY_ESCAPE);await process_frame;key(KEY_ESCAPE,false)
	check(not main.controller_setup and main.paused,"Closing setup leaves match paused")
	tap(7);check(not main.paused,"Mapped Start resumes")
	for entry in [[4,"lp"],[5,"hp"],[0,"lk"],[6,"throw"]]:
		main.clear_controls();tap(entry[0]);check(main.read_control(0).command==entry[1],"Custom button routes "+entry[1])
	main.clear_controls();axis(4,1);check(main.read_control(0).command=="hk","Axis-backed attack works")
	check(main.pressed[0].is_empty(),"Held attack does not repeat")
	axis(4,0)
	for facing in [1,-1]:
		main.sim.fighters[0].facing=facing;main.clear_controls()
		axis(1,1);main.read_control(0);axis(0,facing);main.read_control(0);axis(1,0);tap(4)
		check(main.read_control(0).command=="special1","Controller QCF from facing "+str(facing))
		axis(0,0);main.clear_controls()
		axis(0,facing);main.read_control(0);axis(0,0);axis(1,1);main.read_control(0);axis(0,facing);tap(4)
		check(main.read_control(0).command=="special2","Controller DP from facing "+str(facing))
		axis(0,0);axis(1,0)
	main.clear_controls();key(KEY_Z);await process_frame
	check(main.read_control(0).command=="lp","P1 keyboard attack unaffected by Sega profile");key(KEY_Z,false)
	main.clear_controls();key(KEY_F);await process_frame
	check(main.read_control(1).command=="lp","P2 keyboard attack unaffected by Sega profile");key(KEY_F,false)
	key(KEY_RIGHT);await process_frame;check(main.read_control(0).dx==1,"Arrow keys still move P1");key(KEY_RIGHT,false)
	key(KEY_W);await process_frame;check(main.read_control(1).up,"W still jumps P2");key(KEY_W,false)
	main.clear_controls();tap(JOY_BUTTON_Y,72);check(main.read_control(1).command=="hp","Second pad keeps independent default mapping")
	main.controller_connection(71,false)
	check(main.paused and main.pads.slots==[-1,72],"Disconnect pauses without reassigning P2")
	main.pads.connect_device(73,"test-sega")
	check(main.pads.slots==[73,72] and main.pads.mapping(73).lp.button==4,"Reconnect restores player slot and saved profile")
	main.action("title");axis(1,1,73);main.controller_menu_tick()
	check(main.selected_mode==1,"Custom axis D-pad navigates menu")
	axis(1,0,73);main.controller_menu_tick();tap(0,73)
	check(main.screen=="select","Custom confirm opens character select")
	tap(1,73);check(main.screen=="title","Custom back returns to title")
	main.open_controller_setup();tap(8,73);tap(3,73)
	key(KEY_ESCAPE);await process_frame;key(KEY_ESCAPE,false)
	check(main.pads.mapping(73).left.has("axis"),"Cancelling setup preserves previous saved mapping")
	main.open_controller_setup()
	main.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/controller-setup.png")
	DirAccess.remove_absolute(main.pads.path)
	print("CONTROLLER CHECKS: ",count,"; FAILURES: ",failures)
	main.queue_free();await process_frame
	quit(1 if failures else 0)
