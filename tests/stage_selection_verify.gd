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
	var textures=[stage.background,stage.docks,stage.graffiti,stage.camden,stage.powerplant,stage.graveyard,stage.brewers,stage.bonus_texture,stage.stadium,stage.pimlico,stage.warehouse]
	var materials=[stage.water_material,stage.docks_material,stage.graffiti_material,stage.camden_material,stage.powerplant_material,stage.graveyard_material,stage.brewers_material,stage.bonus_material,stage.stadium_material,stage.pimlico_material,stage.warehouse_material]
	for i in 144:
		stage.select_random()
		if i==0: check(stage.last_stage==0,"First match after launch opens on Inner Harbor")
		seen[stage.stage_name()]=true
		if stage.last_stage==previous: no_repeats=false
		previous=stage.last_stage
		if stage.backdrop.texture!=textures[stage.last_stage] or stage.backdrop.material!=materials[stage.last_stage]: correct_art=false
	check(no_repeats,"Automatic stage rotation never repeats the preceding stage")
	check(seen.size()==Harbor.STAGE_NAMES.size(),"All eleven fight stages appear")
	check(correct_art and stage.pimlico.get_size()==stage.camden.get_size() and stage.warehouse.get_size()==stage.camden.get_size(),"All eleven stages use matching art and animation")
	var restarted=Harbor.new()
	restarted.history_path=history_path
	restarted.attach(layer)
	restarted.select_random()
	check(restarted.last_stage==0,"A fresh application session opens on Inner Harbor even with saved stage history")
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.stage.history_path=history_path
	game.action("mode1")
	game.action("confirm")
	game.action("confirm")
	check(game.screen=="stage_select","Local Versus opens stage select after both fighters lock in")
	game.action("stage10")
	game.action("confirm")
	check(game.screen=="match" and game.stage.current_index()==Harbor.WAREHOUSE,"Live Versus starts on the stage selected by the players")
	var first=game.stage.stage_name()
	game.sim.reset_round()
	check(game.stage.stage_name()==first,"Stage stays fixed between rounds")
	game.sim.phase="results"
	game.sim.winner=0;game.sim.wins=[2,0]
	game.action("rematch")
	check(game.stage.stage_name()==first,"Versus rematch keeps the selected stage")
	game.action("title");game.action("mode2");game.action("confirm");game.action("confirm")
	check(game.screen=="match" and game.sim.training and game.stage.stage_name()!=first,"Training still enters a stage automatically")
	game.queue_free()
	layer.queue_free()
	stage=null
	restarted=null
	await process_frame
	DirAccess.remove_absolute(history_path)
	quit(1 if failures else 0)
