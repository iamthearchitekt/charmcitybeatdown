extends SceneTree
const Crows=preload("res://scripts/graveyard_crows.gd")
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name:String)->Image:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	image.save_png("res://tests/visual/poe/"+name+".png")
	return image
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual/poe")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	game.stage.history_path="res://.runtime/poe-stage-test.cfg"
	game.unlocks.path="res://.runtime/poe-unlock-test.cfg"
	game.unlocks.all_unlocked=false
	game.unlocks.unlocked=[]
	var poe:Dictionary=game.sim.data.fighters[11]
	check(poe.id=="edgar-allan-poe" and not game.unlocks.available(poe),"Poe is a real fighter locked until his code is entered")
	check(game.unlocks.redeem("POE")=="EDGAR ALLAN POE UNLOCKED" and game.unlocks.available(poe),"Existing POE code now unlocks playable Poe")
	check(not poe.id in game.unlocks.registry.deferred_characters,"Poe is no longer labeled as a future design")
	check(game.art.regions[11].size()==18 and game.art.throw_atlases["11"].regions.size()==4,"All 22 Poe poses are registered")
	check(game.art.presentation_scale(11)==game.art.presentation_scale(6),"Poe has Spike's presentation height")
	check(absf(game.art.sprite_frame(11,0).size.y-game.art.sprite_frame(6,0).size.y)<2,"Rendered idle height matches Spike")
	var standing=game.art.regions[11][1]
	check(float(standing[2])/standing[3]<.6,"Poe retains a lean upright silhouette")
	var ko=game.art.regions[11][15]
	check(ko[2]>ko[3]*2,"Dedicated face-up KO art lies horizontal")
	game.selected_mode=1
	game.selection=[11,6]
	game.screen="select"
	game.clock=0
	await capture("poe-select")
	game.begin_match()
	game.stage.set_stage(5)
	game.sim.phase="fight"
	game.sync_match_end_audio()
	check(game.stage.at_graveyard and game.stage.stage_name()=="WESTMINSTER / POE'S GRAVE","Poe graveyard selects the correct backdrop")
	check(game.music.playing and game.music.stream.resource_name=="never-return-alive.ogg","Graveyard has continuous level music")
	var first=await capture("graveyard-frame-1")
	game.clock=.25
	var second=await capture("graveyard-frame-2")
	game.clock=0
	var repeat=await capture("graveyard-repeat")
	check(first.get_data()!=second.get_data() and first.get_data()==repeat.get_data(),"Backdrop has exactly two repeating fixed light states")
	check(Crows.sample(0).is_empty() and Crows.sample(14).is_empty(),"Crows leave quiet intervals before and after flyovers")
	var birds=Crows.sample(6)
	check(not birds.is_empty() and birds[0].x>0 and birds[0].x<1280,"Crows cross overhead during scheduled flyovers")
	check(Crows.sample(6)==Crows.sample(6),"Crow positions and wing frames are stable when the clock is frozen")
	check(Crows.sample(6)[0].frame!=Crows.sample(6.125)[0].frame,"Exactly two distinct wing poses alternate")
	check(Crows.sample(24)[0].direction==-1,"Later flyovers reverse direction")
	game.clock=6
	await capture("crows-overhead")
	game.toggle_pause()
	var clock:float=game.clock
	game._physics_process(1.0/60)
	check(game.clock==clock,"Pause freezes the stage and crow clock together")
	game.paused=false
	game.sim.fighters[0].state="ko"
	await capture("poe-face-up-ko")
	game.sim.fighters[0].state="idle"
	game.sim.new_match(11,9)
	game.sim.phase="results"
	game.sim.winner=0
	game.sim.wins=[2,0]
	await capture("poe-wins")
	check(game.results_portraits.frames.has(22),"Poe receives the same dedicated result portrait rendering")
	game.stage.set_stage(0)
	check(not game.stage.at_graveyard and game.stage.crow_start_time<0,"Crows reset when leaving the graveyard")
	game.queue_free()
	await process_frame
	for path in ["res://.runtime/poe-stage-test.cfg","res://.runtime/poe-unlock-test.cfg"]:
		DirAccess.remove_absolute(path)
	print("POE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
