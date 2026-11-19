extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name:String):
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/oriole/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual/oriole")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	game.clock=0
	game.stage.history_path="res://.runtime/oriole-stage-test.cfg"
	game.unlocks.path="res://.runtime/oriole-unlock-test.cfg"
	game.unlocks.all_unlocked=false
	game.unlocks.unlocked=[]
	var bird:Dictionary=game.sim.data.fighters[12]
	check(bird.id=="orioles-mascot" and not game.unlocks.available(bird),"Bird is registered and locked before REL")
	check(game.unlocks.redeem("REL")=="ORIOLE BIRD UNLOCKED" and game.unlocks.available(bird),"REL unlocks the playable mascot")
	check(not bird.id in game.unlocks.registry.deferred_characters,"Mascot no longer reports a deferred design")
	check(game.art.regions[12].size()==18 and game.art.throw_atlases["12"].regions.size()==4,"All 22 poses are registered")
	check(game.art.presentation_scale(12)==game.art.presentation_scale(8),"Bird uses Stan's presentation scale")
	check(absf(game.art.sprite_frame(12,0).size.y-game.art.sprite_frame(8,0).size.y)<2,"Rendered idle height matches Stan")
	check(game.art.sprite_frame(12,16).source!=game.art.sprite_frame(12,11).source,"Neutral jump has separate art from jump kick")
	var ko=game.art.regions[12][15]
	check(ko[2]>ko[3]*2,"Dedicated face-up KO art is horizontal")
	var fits=true
	for kind in game.sim.data.fighters.size():
		var rect:Rect2=game.select_portrait_rect(kind)
		fits=fits and rect.end.y<620 and rect.position.x>330 and rect.end.x<950
	check(game.select_columns()==7 and fits,"Thirteen portraits fit two rows clear of confirmation controls")
	game.selected_mode=1
	game.selection=[8,8]
	game.screen="select"
	game.action("fighter12")
	check(game.selection[0]==12,"Click action selects complete two-digit fighter index")
	await capture("bird-stan-select")
	game.action("confirm")
	game.action("fighter8")
	game.action("confirm")
	check(game.sim.fighters[0].kind==12 and game.sim.fighters[1].kind==8,"Bird and Stan enter a real match")
	game.stage.set_stage(3)
	game.sim.phase="fight"
	game.sim.time_left=98*60
	await capture("bird-stan-match")
	var f:Dictionary=game.sim.fighters[0]
	game.sim.start_move(f,"hp")
	f.frame=bird.moves.hp.startup+1
	await capture("bird-wing-punch")
	f.move=""
	f.state="ko"
	await capture("bird-face-up-ko")
	for back in [false,true]:
		game.sim.new_match(12,8)
		game.sim.phase="fight"
		var a:Dictionary=game.sim.fighters[0]
		var b:Dictionary=game.sim.fighters[1]
		a.x=500
		b.x=591
		game.sim.step([{"command":"throw","back":back},{"back":true}])
		var held=false
		var tossed=false
		for frame in 100:
			game.sim.step([{},{}])
			held=held or b.grabbed_by==0
			tossed=tossed or b.throw_flight
		check(held and tossed and b.health==1000-int(bird.moves.throw.damage),"Wing throw grabs, releases and damages once: back="+str(back))
	game.sim.new_match(12,8)
	game.sim.phase="results"
	game.sim.winner=0
	game.sim.wins=[2,0]
	await capture("bird-wins")
	game.sim.new_match(8,12)
	game.sim.phase="results"
	game.sim.winner=0
	game.sim.wins=[2,0]
	await capture("bird-loses")
	check(game.results_portraits.frames.has(24) and game.results_portraits.frames.has(25),"Dedicated victory and defeat portraits both render")
	game.queue_free()
	await process_frame
	for path in ["res://.runtime/oriole-stage-test.cfg","res://.runtime/oriole-unlock-test.cfg"]:
		DirAccess.remove_absolute(path)
	print("ORIOLE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
