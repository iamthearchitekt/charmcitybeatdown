extends SceneTree
const Harbor=preload("res://scripts/harbor_stage.gd")
var failures=0
var history_path="res://.runtime/stage-selection-test.cfg"

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func run():
	var layer=Node2D.new()
	root.add_child(layer)
	if FileAccess.file_exists(history_path): DirAccess.remove_absolute(history_path)
	var stage=Harbor.new()
	stage.history_path=history_path
	stage.attach(layer)
	var seen={}
	var previous=-1
	var no_repeats=true
	var correct_art=true
	for i in 40:
		stage.select_random()
		if i==0: check(stage.last_stage==0,"First match after launch opens on Inner Harbor")
		seen[stage.stage_name()]=true
		if stage.last_stage==previous: no_repeats=false
		previous=stage.last_stage
		if stage.backdrop.texture!=[stage.background,stage.docks,stage.graffiti,stage.camden,stage.powerplant,stage.graveyard,stage.brewers][stage.last_stage]: correct_art=false
		if stage.backdrop.material!=[stage.water_material,stage.docks_material,stage.graffiti_material,stage.camden_material,stage.powerplant_material,stage.graveyard_material,stage.brewers_material][stage.last_stage]: correct_art=false
	check(no_repeats,"40 new matches never repeat the preceding stage")
	check(seen.size()==7,"All seven Baltimore fight stages appear")
	check(correct_art,"All seven stages use matching art and animation")
	var restarted=Harbor.new()
	restarted.history_path=history_path
	restarted.attach(layer)
	restarted.select_random()
	check(restarted.last_stage==0,"A fresh application session opens on Inner Harbor even with saved stage history")
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.stage.history_path=history_path
	game.begin_match()
	check(game.stage.last_stage==0,"Live game begins its first fight on Inner Harbor")
	var first=game.stage.stage_name()
	game.sim.reset_round()
	check(game.stage.stage_name()==first,"Stage stays fixed between rounds")
	game.sim.phase="results"
	game.sim.winner=0;game.sim.wins=[2,0]
	game.action("rematch")
	check(game.stage.stage_name()!=first,"Results rematch switches stages")
	var previous_menu=game.stage.stage_name()
	game.action("title");game.action("confirm");game.action("confirm")
	check(not game.stage.first_match_pending and game.stage.stage_name()!=previous_menu,"Returning to menu continues randomized stage rotation")
	game.queue_free()
	layer.queue_free()
	stage=null
	restarted=null
	await process_frame
	DirAccess.remove_absolute(history_path)
	quit(1 if failures else 0)
