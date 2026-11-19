extends SceneTree
const Bindings=preload("res://scripts/controller_bindings.gd")
const CarBonus=preload("res://scripts/car_bonus.gd")
var failures=0
var checks=0
var game

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func tap(index:int,slot:int=71):
	for down in [true,false]:
		var event=InputEventJoypadButton.new()
		event.device=slot;event.button_index=index;event.pressed=down
		game.controller_event(event)

func axis(index:int,value:float,slot:int=71):
	var event=InputEventJoypadMotion.new()
	event.device=slot;event.axis=index;event.axis_value=value
	game.controller_event(event)

func navigate(index:int,count:int=1):
	for step in count:
		var event=InputEventJoypadButton.new()
		event.device=71;event.button_index=index;event.pressed=true
		game.controller_event(event);game.controller_menu_tick()
		event.pressed=false
		game.controller_event(event);game.controller_menu_tick()

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	game.pads=Bindings.new();game.pads.profiles={}
	game.pads.connect_device(71,"generic-xinput-primary")
	game.pads.connect_device(72,"Xbox second pad")
	game.selected_mode=1;game.begin_match();game.sim.phase="fight"
	for pair in [[JOY_BUTTON_X,"lp"],[JOY_BUTTON_Y,"mp"],[JOY_BUTTON_A,"lk"],[JOY_BUTTON_B,"mk"]]:
		game.clear_controls();tap(pair[0])
		check(game.read_control(0).command==pair[1],"Primary Retro-Bit face button routes "+pair[1])
	game.clear_controls();axis(JOY_AXIS_TRIGGER_RIGHT,1)
	check(game.read_control(0).command=="hk","Physical Sega C (right trigger) routes high kick")
	axis(JOY_AXIS_TRIGGER_RIGHT,1)
	check(game.read_control(0).command=="","Holding Sega C does not repeat the attack")
	axis(JOY_AXIS_TRIGGER_RIGHT,0);axis(JOY_AXIS_TRIGGER_RIGHT,1)
	check(game.read_control(0).command=="hk","Releasing and pressing Sega C permits another high kick")
	axis(JOY_AXIS_TRIGGER_RIGHT,0)
	game.clear_controls();axis(JOY_AXIS_TRIGGER_LEFT,1)
	check(game.read_control(0).command=="hp","Physical Sega Z (left trigger) routes heavy punch")
	axis(JOY_AXIS_TRIGGER_LEFT,0)
	for bumper in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		game.clear_controls();tap(bumper)
		check(game.read_control(0).command=="throw","Each shoulder triggers grapple: "+str(bumper))
	game.pads.profiles["generic-xinput-primary"]={"left":{"axis":JOY_AXIS_LEFT_X,"sign":-1},"lp":{"button":JOY_BUTTON_LEFT_SHOULDER}}
	check(game.pads.mapping(71).left.has("axis") and game.pads.mapping(71).mp.button==JOY_BUTTON_Y and game.pads.mapping(71).throw.button==JOY_BUTTON_LEFT_SHOULDER,"Legacy profiles retain direction calibration and acquire the six-button layout")
	game.pads.profiles.clear()
	game.clear_controls();tap(JOY_BUTTON_START)
	check(game.paused,"Start still pauses")
	tap(JOY_BUTTON_START);check(not game.paused,"Start still resumes")
	game.clear_controls()
	axis(JOY_AXIS_LEFT_Y,1);game.read_control(0)
	axis(JOY_AXIS_LEFT_X,1);game.read_control(0)
	axis(JOY_AXIS_LEFT_Y,0);tap(JOY_BUTTON_Y)
	check(game.read_control(0).command=="special1","Medium punch can trigger a quarter-circle special")
	axis(JOY_AXIS_LEFT_X,0)
	game.clear_controls();tap(JOY_BUTTON_X,72)
	check(game.read_control(1).command=="lp","Second standard pad retains its Xbox layout")
	game.pads.profiles["generic-xinput-primary"]=game.pads.defaults()
	game.clear_controls();tap(JOY_BUTTON_X)
	check(game.read_control(0).command=="lp","Explicit saved custom mappings take precedence")
	game.action("title");game.pads.profiles={}
	tap(JOY_BUTTON_A);check(game.screen=="select","Sega A still confirms menus")
	tap(JOY_BUTTON_B);check(game.screen=="title","Sega B still goes back in menus")
	navigate(JOY_BUTTON_DPAD_DOWN,3);tap(JOY_BUTTON_A)
	check(game.screen=="cheats","D-pad reaches the cheat-code menu")
	navigate(JOY_BUTTON_DPAD_UP);axis(JOY_AXIS_TRIGGER_RIGHT,1);axis(JOY_AXIS_TRIGGER_RIGHT,0)
	check(game.cheat_slots[0]=="","C clears a selected cheat slot")
	for slot in 3:
		navigate(JOY_BUTTON_DPAD_UP,[16,15,5][slot])
		navigate(JOY_BUTTON_DPAD_RIGHT)
	game.unlocks.path="user://sega-code-test.cfg"
	tap(JOY_BUTTON_A)
	check("edgar-allan-poe" in game.unlocks.unlocked and game.cheat_message.ends_with("UNLOCKED"),"D-pad and A redeem a complete code")
	tap(JOY_BUTTON_B)
	navigate(JOY_BUTTON_DPAD_DOWN);tap(JOY_BUTTON_A)
	check(game.screen=="scores","D-pad reaches high scores")
	tap(JOY_BUTTON_B)
	navigate(JOY_BUTTON_DPAD_DOWN);tap(JOY_BUTTON_A)
	check(game.options_open,"Controller opens Settings from the title")
	tap(JOY_BUTTON_A);check(game.difficulty==2,"CPU difficulty is adjusted in Settings")
	navigate(JOY_BUTTON_DPAD_DOWN);tap(JOY_BUTTON_A)
	check(game.turbo,"Controller enables Turbo Mode")
	navigate(JOY_BUTTON_DPAD_DOWN,4)
	tap(JOY_BUTTON_A);check(game.controller_setup,"Controller enters setup from Options")
	tap(JOY_BUTTON_B);check(not game.controller_setup and game.options_open,"B returns from setup to Options")
	navigate(JOY_BUTTON_DPAD_UP,2);tap(JOY_BUTTON_A)
	check(not game.music_enabled,"Controller can toggle music")
	tap(JOY_BUTTON_A);tap(JOY_BUTTON_B)
	game.selected_mode=2;game.begin_match();game.sim.phase="fight";tap(JOY_BUTTON_START)
	navigate(JOY_BUTTON_DPAD_RIGHT);tap(JOY_BUTTON_A)
	check(game.paused and game.options_open,"Controller can focus and activate pause Options")
	navigate(JOY_BUTTON_DPAD_DOWN,6);tap(JOY_BUTTON_A)
	check(game.sim.dummy==1,"Controller can change the training dummy")
	tap(JOY_BUTTON_B);navigate(JOY_BUTTON_DPAD_RIGHT);tap(JOY_BUTTON_A)
	check(game.screen=="title" and not game.paused,"Controller can focus Main Menu and exit a match")
	game.begin_bonus("car");game.sim.finish(true);tap(JOY_BUTTON_B)
	check(game.screen=="match" and game.sim.phase=="results","B cannot leave a bonus result")
	tap(JOY_BUTTON_A)
	check(not game.sim is CarBonus,"A continues from the bonus result")
	game.selected_mode=0;game.begin_match();game.sim.phase="fight";tap(JOY_BUTTON_START,72)
	check(game.screen=="challenger","Player two can join the arcade run with Start")
	game.challenger_timer=1;game._physics_process(1.0/60)
	tap(JOY_BUTTON_B,72)
	check(game.screen=="match" and game.selected_mode==0,"B cancels challenger selection and returns to the arcade match")
	game.start_continue();tap(JOY_BUTTON_A)
	check(game.screen=="match" and game.arcade.continues==1,"A accepts an arcade continue")
	game.start_continue();tap(JOY_BUTTON_B)
	check(game.screen=="game_over","B ends the run from the continue screen")
	tap(JOY_BUTTON_A);check(game.screen=="scores","A opens scores from Game Over")
	tap(JOY_BUTTON_B);check(game.screen=="title","B closes scores after an arcade run")
	check(game.KEYS==[[KEY_Z,KEY_X,KEY_C,KEY_V,KEY_B],[KEY_F,KEY_G,KEY_H,KEY_J,KEY_R]],"Both keyboard layouts remain separate and unchanged")
	game.queue_free();await process_frame
	DirAccess.remove_absolute("user://sega-code-test.cfg")
	print("RETRO-BIT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
