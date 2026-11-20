extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func movement(kind:int,command:String="")->float:
	var sim=Combat.new()
	sim.new_match(kind,0)
	sim.phase="fight"
	sim.fighters[0].x=400
	sim.fighters[1].x=1090
	if command!="": sim.step([{"command":command},{}])
	for frame in 20:
		sim.step([{"dx":1} if command=="" else {},{}])
	return sim.fighters[0].x-400.0
func capture(name:String):
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/lamar/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual/lamar")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	game.clock=0
	game.stage.history_path="res://.runtime/lamar-stage-test.cfg"
	game.unlocks.path="res://.runtime/lamar-unlock-test.cfg"
	game.unlocks.all_unlocked=false
	game.unlocks.unlocked=[]
	var lamar:Dictionary=game.sim.data.fighters[13]
	check(lamar.id=="lamar-jackson" and not game.unlocks.available(lamar),"Lamar is locked before LMR")
	check(game.unlocks.redeem("LMR")=="LAMAR JACKSON UNLOCKED" and game.unlocks.available(lamar),"Existing LMR unlock now selects playable Lamar")
	check(game.unlocks.registry.deferred_characters.is_empty(),"All three secret characters have real designs")
	check(game.art.regions[13].size()==18 and game.art.throw_atlases["13"].regions.size()==4,"All 22 Lamar poses are registered")
	check(game.art.sprite_frame(13,16).source!=game.art.sprite_frame(13,11).source,"Neutral jump remains distinct from jump kick")
	var ko=game.art.regions[13][15]
	check(ko[2]>ko[3]*2,"Dedicated face-up KO art lies horizontal")
	var fastest=true
	var distance=movement(13)
	for kind in 13: fastest=fastest and distance>movement(kind)+.01
	check(fastest,"Lamar actually walks farther than every other fighter over the same time")
	check(movement(13,"dash_forward")>movement(0,"dash_forward"),"Forward dash covers more ground")
	check(absf(movement(13,"dash_back"))>absf(movement(0,"dash_back")),"Backward dash gains the same speed benefit")
	var fits=true
	for kind in 14:
		var rect:Rect2=game.select_portrait_rect(kind)
		fits=fits and rect.end.y<620 and rect.position.x>330 and rect.end.x<950
	check(game.select_columns()==7 and fits,"Fourteen fighters fit the two-row character select")
	game.selected_mode=1
	game.selection=[8,8]
	game.screen="select"
	game.action("fighter13")
	check(game.selection[0]==13,"Character-select action selects Lamar's full index")
	await capture("lamar-select")
	game.action("confirm")
	game.action("fighter8")
	game.action("confirm")
	check(game.sim.fighters[0].kind==13 and game.sim.fighters[1].kind==8,"Lamar enters a real match")
	game.sim.phase="fight"
	game.sim.time_left=98*60
	await capture("lamar-match")
	var f:Dictionary=game.sim.fighters[0]
	var walk_textures={}
	for phase in 6:
		f.walk=1
		f.walk_phase=phase*.5
		await capture("lamar-walk-"+str(phase))
		var frame:int=game.art.movement_art.frame_index(f,{})
		if game.art.movement_art.cache.has(Vector2i(13,frame)):
			walk_textures[game.art.movement_art.cache[Vector2i(13,frame)].texture]=true
	check(walk_textures.size()==6,"Lamar draws six distinct walking textures")
	f.walk=0
	game.sim.start_move(f,"hp")
	f.frame=lamar.moves.hp.startup+1
	await capture("lamar-punch")
	f.move=""
	f.state="ko"
	await capture("lamar-face-up-ko")
	for back in [false,true]:
		game.sim.new_match(13,8)
		game.sim.phase="fight"
		var a:Dictionary=game.sim.fighters[0]
		var b:Dictionary=game.sim.fighters[1]
		a.x=500
		b.x=591
		game.sim.step([{"command":"throw","back":back},{"back":true}])
		var held=false
		var released=false
		for frame in 100:
			game.sim.step([{},{}])
			held=held or b.grabbed_by==0
			for event in game.sim.events:
				released=released or event.type=="grab_release"
		check(held and released and b.health==1000-int(lamar.moves.throw.damage),"Throw grabs/releases and damages once: back="+str(back))
	game.sim.new_match(13,8)
	game.sim.phase="results"
	game.sim.winner=0
	game.sim.wins=[2,0]
	await capture("lamar-wins")
	game.sim.new_match(8,13)
	game.sim.phase="results"
	game.sim.winner=0
	game.sim.wins=[2,0]
	await capture("lamar-loses")
	check(game.results_portraits.frames.has(26) and game.results_portraits.frames.has(27),"Victory and defeat portraits both render")
	var defeated:Image=game.results_portraits.frames[27].get_image()
	var top_scan_is_clean=true
	for y in 8:
		var row_width=0
		for x in defeated.get_width():
			if defeated.get_pixel(x,y).a>.5: row_width+=1
		top_scan_is_clean=top_scan_is_clean and row_width<defeated.get_width()/3.0
	check(top_scan_is_clean,"Lamar's defeat portrait starts at his hair with no victory sprite bleed")
	game.queue_free()
	await process_frame
	for path in ["res://.runtime/lamar-stage-test.cfg","res://.runtime/lamar-unlock-test.cfg"]:
		DirAccess.remove_absolute(path)
	print("LAMAR RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
