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
	var jeff=game.sim.data.fighters[10]
	check(jeff.id=="jeff" and game.unlocks.available(jeff),"Jeff is available immediately")
	var tallest=true
	for kind in 10: tallest=tallest and game.art.sprite_frame(10,0).size.y>game.art.sprite_frame(kind,0).size.y
	check(tallest,"Jeff is the tallest fighter")
	check(jeff.speed==6.4 and jeff.speed==game.sim.data.fighters[5].speed,"Jeff is quick at Vivian's pace without an excessive speed boost")
	check(jeff.moves.hp.damage==game.sim.data.fighters[2].moves.hp.damage and game.sim.make_fighter(10,0).health==1000,"Jeff retains normal damage and health")
	check(game.art.regions[10].size()==18 and game.art.throw_atlases['10'].regions.size()==4,"Jeff has complete attacks, jumps, KO and throws")
	check(game.select_columns()==6,"Eleven portraits fit two rows")
	game.selected_mode=1;game.screen="select";game.selection=[10,8];game.select_slot=0
	await snap("jeff-stan-select")
	game.action("fighter10");game.action("confirm");game.action("fighter8");game.action("confirm")
	check(game.sim.fighters[0].kind==10 and game.sim.fighters[1].kind==8,"Jeff can enter a match against Stan")
	game.sim.phase="fight";game.sim.time_left=98*60;await snap("jeff-stan-match")
	game.sim.fighters[0].state="ko";game.sim.fighters[0].health=0;await snap("jeff-face-up-ko")
	game.queue_free();await process_frame
	print("JEFF RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
