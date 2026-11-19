extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_physics_process(false)
	game.unlocks.all_unlocked=false;game.unlocks.unlocked=[]
	var r=game.sim.data.fighters[9]
	check(r.id=="rachel" and r.boss and game.unlocks.available(r),"Rachel is a playable boss with no unlock code")
	var strongest=true
	for kind in [1,3,4,5]:
		for move in r.moves:
			strongest=strongest and r.moves[move].damage>game.sim.data.fighters[kind].moves[move].damage
	check(strongest,"Rachel deals the highest damage among all women for every move")
	check(game.sim.make_fighter(9,0).health==1000 and r.speed==6.2,"Boss strength does not inflate her health or body")
	check(game.SfxBank.female(9),"Rachel uses female block and final KO voices")
	check(game.art.regions[9].size()==18 and game.art.throw_atlases['9'].regions.size()==4,"Rachel has all ordinary, jump and throw poses")
	game.selected_mode=1;game.screen="select";game.selection=[9,5];game.select_slot=0
	await snap("rachel-tactical-select")
	game.action("fighter9");game.action("confirm");game.action("fighter5");game.action("confirm")
	check(game.sim.fighters[0].kind==9 and game.sim.fighters[1].kind==5,"Rachel and Vivian can enter a match")
	game.sim.phase="fight";game.sim.time_left=98*60;await snap("rachel-vivian-match")
	game.sim.fighters[0].state="ko";game.sim.fighters[0].health=0
	await snap("rachel-face-up-ko")
	game.queue_free();await process_frame
	print("RACHEL RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
