extends SceneTree
var failures=0
var checks=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func run():
	seed(1703)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.unlocks.all_unlocked=true
	game.arcade.scores_path="res://.runtime/solo-scores-test.cfg"
	game.stage.history_path="res://.runtime/solo-stage-test.cfg"
	game.selected_mode=0
	game.action("confirm")
	check(game.screen=="select" and game.select_slot==0,"Arcade opens player fighter selection")
	game.action("fighter2")
	game.action("confirm")
	check(game.screen=="match" and game.sim.fighters[0].kind==2,"One confirmation launches Arcade with the selected player fighter")
	check(game.selection[1]!=2 and game.sim.fighters[1].kind==game.selection[1],"CPU is chosen automatically from the other fighters")
	var cpu_kind=game.sim.fighters[1].kind
	game.sim.reset_round()
	check(game.sim.fighters[1].kind==cpu_kind,"CPU identity stays fixed between rounds")
	for player in game.sim.data.fighters.size():
		game.selection[0]=player
		game.arcade.active=false
		game.begin_match()
		var seen={}
		var valid=true
		for cpu in game.arcade.opponents:
			seen[cpu]=true
			valid=valid and cpu!=player and cpu>=0 and cpu<game.sim.data.fighters.size() and game.sim.fighters[0].kind==player
		check(valid,"Every solo match preserves player choice and excludes self: "+str(player))
		check(seen.size()==game.sim.data.fighters.size()-1,"Each eligible opponent appears once in the ladder: "+str(player))
	game.unlocks.all_unlocked=false;game.unlocks.unlocked=[];game.selection[0]=0
	game.arcade.active=false;game.begin_match()
	var locked_pool={}
	for kind in game.arcade.opponents: locked_pool[kind]=true
	check(locked_pool.has(4) and locked_pool.has(5) and locked_pool.has(6),"Chelsea, Vivian and Spike are eligible with no codes")
	check(not locked_pool.has(11) and not locked_pool.has(12) and not locked_pool.has(13),"Secret fighters remain outside the ladder until unlocked")
	for mode in [1,2]:
		game.action("title")
		game.selected_mode=mode
		game.action("confirm")
		game.action("fighter2");game.action("confirm")
		check(game.screen=="select" and game.select_slot==1,"Manual opponent selection remains for mode "+str(mode))
		game.action("fighter3");game.action("confirm")
		check(game.sim.fighters[0].kind==2 and game.sim.fighters[1].kind==3,"Manual matchup is preserved for mode "+str(mode))
	game.queue_free();await process_frame
	DirAccess.remove_absolute("res://.runtime/solo-stage-test.cfg")
	DirAccess.remove_absolute("res://.runtime/solo-scores-test.cfg")
	print("SOLO OPPONENT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
