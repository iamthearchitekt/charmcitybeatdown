extends SceneTree
const Bonus=preload("res://scripts/car_bonus.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.stage.history_path="res://.runtime/bonus-exit-stage.cfg"
	game.arcade.scores_path="res://.runtime/bonus-exit-scores.cfg"
	game.bonus_rewards.path="res://.runtime/bonus-exit-rewards.cfg";game.bonus_rewards.earned=[]
	game.selected_mode=0;game.begin_match()
	for challenge in ["car","kegs","boxes"]:
		for success in [false,true]:
			game.begin_bonus(challenge);game.sim.finish(success);game.sync_match_end_audio()
			var bonus=game.sim;var points=game.arcade.score
			for action in ["back","title","quit"]:
				game.action(action)
				check(game.screen=="match" and game.sim==bonus and game.arcade.score==points,"Bonus result ignores accidental exit: "+challenge+" "+action+" success="+str(success))
			game.action("confirm")
			check(game.screen=="match" and not game.sim is Bonus and game.arcade.score==points,"Continue resumes ladder with points: "+challenge+" success="+str(success))
	game.arcade.active=false;game.queue_free();await process_frame
	for path in ["res://.runtime/bonus-exit-stage.cfg","res://.runtime/bonus-exit-scores.cfg","res://.runtime/bonus-exit-rewards.cfg"]: DirAccess.remove_absolute(path)
	print("BONUS EXIT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
