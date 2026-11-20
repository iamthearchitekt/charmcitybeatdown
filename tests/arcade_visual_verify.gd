extends SceneTree
var game
var destination="res://tests/visual/arcade"
var captures={}
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var pixels=root.get_texture().get_image();pixels.save_png(destination+"/"+name+".png")
	captures[name]=pixels;print("CAPTURE ",name)
func run():
	DirAccess.make_dir_recursive_absolute(destination)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.arcade.scores_path="res://.runtime/arcade-visual-scores.cfg";game.arcade.high_scores=[]
	game.stage.history_path="res://.runtime/arcade-visual-stage.cfg"
	game.screen="title";await snap("title")
	game.selected_mode=0;game.begin_match();game.sim.phase="fight";game.sim.time_left=97*60
	game.sim.fighters[0].x=420;game.sim.fighters[1].x=850
	game.sim.begin_dizzy(game.sim.fighters[1]);game.clock=0;await snap("dizzy-0")
	game.sim.fighters[1].dizzy_age=24;await snap("dizzy-1")
	check(game.art.pose(game.sim.fighters[1],0) in [0,13],"Dizzy has an upright keyed pose and outlined orbiting stars")
	game.sim.clear_dizzy(game.sim.fighters[1]);game.sim.fighters[1].state="idle"
	game.effects=[{"x":640,"y":455,"type":"projectile_clash","life":7,"heavy":false}];await snap("clash")
	game.effects=[];game.begin_bonus("kegs");game.sim.phase="fight";game.sim.fighters[0].x=-1000
	game.clock=0;await snap("brewers-0")
	game.clock=.25;await snap("brewers-1")
	var a:Image=captures["brewers-0"];var b:Image=captures["brewers-1"]
	var sign_changes=0;var outside=0;var overall=0
	for y in 720:
		for x in 1280:
			if a.get_pixel(x,y)==b.get_pixel(x,y): continue
			overall+=1
			if Rect2i(740,28,150,130).has_point(Vector2i(x,y)): sign_changes+=1
			elif not Rect2i(630,510,380,210).has_point(Vector2i(x,y)): outside+=1
	check(sign_changes>100 and outside==0,"Brewers Hill has exactly two frames changing only Natty Boh's tubes and red pavement reflection")
	print("Brewers diff: sign=",sign_changes," overall=",overall," outside=",outside)
	game.clock=.5;game.sim.fighters[0].x=400
	game.sim.objects=[game.sim.make_object(640,622,5)];game.sim.spawned=1
	await snap("kegs-intact")
	game.sim.objects[0].hp=50;await snap("kegs-damaged")
	game.begin_bonus("boxes");game.sim.phase="fight";await snap("boxes-intact")
	for i in 5: game.sim.objects[i].hp=0
	for i in 35: game.sim.update_objects()
	await snap("boxes-damaged")
	game.sim=game.Combat.new();game.selected_mode=0;game.arcade.active=false;game.begin_match()
	game.sim.winner=0;game.sim.wins=[2,0];game.sim.phase="results";game.sim.scores=[56789,0]
	game.sim.round_rewards=[{"owner":0,"time":9000,"health":7500,"perfect":10000}]
	game.account_completed_stage();await snap("results")
	game.start_continue();await snap("continue")
	game.screen="scores";game.arcade.high_scores=[{"name":"ALEX","score":123456,"clear":true,"continues":0},{"name":"LAMAR JACKSON","score":98765,"clear":false,"continues":2}]
	await snap("scores")
	game.arcade.cursor=game.arcade.opponents.size()
	game.arcade.score=612570
	game.begin_finale()
	game.finale_age=17;await snap("campaign-impact")
	game.finale_age=72;await snap("campaign")
	check(captures["campaign-impact"].get_data()!=captures["campaign"].get_data(),"The Arcade finale animates from the stamp impact to the final score")
	game.screen="challenger";await snap("challenger")
	game.arcade.active=false;game.queue_free();await process_frame
	for path in ["res://.runtime/arcade-visual-stage.cfg"]: DirAccess.remove_absolute(path)
	print("ARCADE VISUAL RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
