extends SceneTree
const Bonus=preload("res://scripts/car_bonus.gd")
const Player=preload("res://tests/bonus_controls.gd")
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func break_first_keg():
	for frame in 90:
		if game.sim.objects[0].hp<=0: break
		game.sim.step([Player.control(game.sim,game.sim.objects[0]),{}]);game.sync_match_end_audio()
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.stage.history_path="res://.runtime/bonus-score-stage.cfg"
	game.bonus_rewards.path="res://.runtime/bonus-score-rewards.cfg";game.bonus_rewards.earned=[]
	game.arcade.scores_path="res://.runtime/bonus-score-highs.cfg"
	game.selected_mode=0;game.begin_match();game.arcade.score=12345
	game.begin_bonus("kegs");game.sim.phase="fight"
	game.sim.objects=[game.sim.make_object(640,622,0)];game.sim.spawned=1
	game.sim.fighters[0].x=445
	break_first_keg()
	check(game.sim.broken==1 and game.sim.score==2250,"Real strikes at keg height earn1250 damage points plus1000 for breaking it")
	check(game.arcade.score==14595,"Keg points immediately increase the cumulative arcade score")
	var total=game.arcade.score
	for i in 12: game.sync_match_end_audio();game.account_completed_stage()
	check(game.arcade.score==total,"Repeated bookkeeping never credits the same points twice")
	# Finish the remaining real-time incoming kegs through ordinary controls.
	game.bonus_accounted=false
	for frame in game.sim.time_left:
		if game.sim.phase=="results": break
		var f=game.sim.fighters[0];var target={};var nearest=INF
		for o in game.sim.objects:
			if o.hp>0 and absf(o.x-f.x)<nearest: target=o;nearest=absf(o.x-f.x)
		game.sim.step([Player.control(game.sim,target),{}]);game.sync_match_end_audio()
	check(game.sim.success and game.sim.score>57000,"A complete keg challenge includes destruction and completion/time rewards")
	total=12345+game.sim.score
	check(game.arcade.score==total,"The full keg payout reaches the arcade total exactly once")
	game.action("confirm")
	check(not game.sim is Bonus and game.arcade.score==total,"The next fight retains the complete keg award")
	game.begin_bonus("kegs");game.sim.phase="fight"
	game.sim.objects=[game.sim.make_object(640,622,0)];game.sim.spawned=1;game.sim.fighters[0].x=445
	break_first_keg()
	game.sim.time_left=1;game.sim.step([{},{}]);game.sync_match_end_audio()
	check(not game.sim.success and game.arcade.score==total+2250,"A failed challenge still retains points earned from destroyed kegs")
	total=game.arcade.score;game.action("confirm")
	check(game.arcade.score==total,"Partial bonus points survive return to the ladder")
	game.arcade.active=false;game.arcade.score=0;game.begin_bonus("kegs")
	check(game.arcade.active,"A standalone bonus initializes a score-bearing Arcade run")
	game.sim.score=2250;game.sim.phase="results";game.sync_match_end_audio();game.action("confirm")
	check(game.arcade.score==2250,"Standalone bonus points cannot be erased by initialization of the next fight")
	game.arcade.active=false;game.queue_free();await process_frame
	for p in ["res://.runtime/bonus-score-stage.cfg","res://.runtime/bonus-score-rewards.cfg","res://.runtime/bonus-score-highs.cfg"]: DirAccess.remove_absolute(p)
	print("BONUS SCORING RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
