extends SceneTree

var game
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func wait_steps(count:int):
	for i in count: game.step_match({},{})

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.training_guide_enabled=true
	game.selected_mode=2;game.selection=[6,0];game.begin_match()
	var guide=game.training_guide
	check(game.sim.training and guide.current().move=="lp","Training starts with a playable light-punch drill")
	game.step_match({"command":"lk"},{})
	wait_steps(46)
	check(guide.index==0,"Incorrect moves do not advance the drill")
	game.step_match({"command":"lp"},{})
	wait_steps(70)
	check(guide.current().move=="c_lk","Actual light punch advances to low kick")
	game.step_match({"down":true,"command":"lk"},{})
	wait_steps(72)
	check(guide.current().move=="air_hk","A crouching kick advances to the airborne kick")
	game.step_match({"up":true},{})
	game.step_match({"command":"hk"},{})
	wait_steps(78)
	check(guide.current().move=="throw","A jump kick advances to the close-range grapple")
	game.step_match({"command":"throw"},{})
	wait_steps(70)
	check(guide.current().move=="throw","A grapple outside contact range does not complete the drill")
	game.sim.fighters[0].x=510;game.sim.fighters[1].x=615
	game.step_match({"command":"throw"},{})
	wait_steps(98)
	check(guide.current().move=="special1","Landing the grapple advances to Spike's move set")
	check(guide.lessons.any(func(lesson):return lesson.name=="LIVE WIRE"),"Spike's guide includes his fighter-specific special")
	game.toggle_pause();game.action("moves")
	check(game.pause_move_slots()==[0] and game.pause_moves_open,"Only the player appears in the Training Moves List")
	var before=game.sim.tick
	game._physics_process(1.0/60.0)
	check(game.sim.tick==before,"The Moves List keeps training simulation paused")
	game.action("back");game.action("options");game.action("training_guide")
	check(not game.training_guide_enabled and game.settings.get_value("gameplay","guided_practice",true)==false,"Guided Practice can be disabled for free practice")
	game.action("back");game.action("resume")
	game.selected_mode=1;game.begin_match();game.toggle_pause();game.action("moves")
	check(game.pause_move_slots()==[0,1],"Versus Moves List includes both selected fighters")
	game.queue_free()
	await process_frame
	print("TRAINING RESULT: ",failures," failed")
	quit(1 if failures else 0)
