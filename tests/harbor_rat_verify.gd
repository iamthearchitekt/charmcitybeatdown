extends SceneTree
const Rat=preload("res://scripts/harbor_rat.gd")
const Combat=preload("res://scripts/combat.gd")
var checks=0
var failures=0
var game
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	check(Rat.sample(1).running and Rat.sample(1.4).x>Rat.sample(1).x,"Rat scuttles along the dock")
	check(not Rat.sample(3.2).running and Rat.sample(3.2).x==Rat.sample(4.5).x,"First pause holds position")
	check(Rat.sample(5).running and Rat.sample(6).x>Rat.sample(5).x,"Rat resumes running after its pause")
	check(Rat.sample(8).x==Rat.sample(9).x and not Rat.sample(8).running,"Second pause remains stationary")
	check(not Rat.sample(14).visible,"Rat exits before reversing direction")
	check(Rat.sample(17).direction==-1 and Rat.sample(17.5).x<Rat.sample(17).x,"Return pass faces and runs left")
	var seen={}
	for i in 10: seen[Rat.sample(1+i*.1).frame]=true
	check(seen.size()==2 and Rat.sample(3.5).frame==1,"Exactly two scuttle frames; pause holds the gathered-paw pose")
	check(Rat.group(2).size()==1 and Rat.group(Rat.CYCLE+2).size()==2 and Rat.group(Rat.CYCLE*2+2).size()==1,"Most passes are solo, with occasional pairs")
	check(Rat.group(Rat.CYCLE+3.5).all(func(p): return not p.running),"The lead and trailing rats both pause")
	check(not Rat.sample(Rat.CYCLE+3.2).running and Rat.sample(Rat.CYCLE+3.2,true).running,"The trailing rat keeps moving while the lead pauses")
	check(not Rat.sample(Rat.CYCLE+4.55).running and Rat.sample(Rat.CYCLE+4.55,true).running,"The trailing rat resumes before the lead")
	check(not Rat.sample(Rat.CYCLE+14.6,true).visible,"The trailing rat clears the stage before the next pass")
	check(Rat.group(Rat.CYCLE+2).all(func(p): return p.y<=Combat.FLOOR-36),"Both rats run well behind the fighters' foot line")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.stage.history_path="res://.runtime/rat-stage-test.cfg"
	game.selected_mode=1;game.begin_match();game.sim.phase="fight";game.sim.time_left=98*60
	check(game.stage.last_stage==0,"First live fight uses Inner Harbor")
	game.stage.rat.load_art()
	check(game.stage.rat.frames.size()==2 and game.stage.rat.frames[0].get_image().get_data()!=game.stage.rat.frames[1].get_image().get_data(),"Both distinct transparent rat sprites decode")
	game.stage.rat_start_time=0;game.clock=1.5;await snap("harbor-rat-running")
	game.clock=3.5;await snap("harbor-rat-paused")
	game.paused=true;var before=game.clock;game._physics_process(1.0/60)
	check(game.clock==before,"Game pause freezes rat movement and pose clock")
	game.paused=false;game.stage.set_stage(1);game.clock=0;await snap("dundalk-rat-start")
	game.clock=Rat.CYCLE+2;await snap("dundalk-rat-pair")
	check(is_zero_approx(game.stage.rat_start_time),"Regular Dundalk uses the same rat clock as Inner Harbor")
	game.begin_bonus("boxes");await snap("dundalk-bonus-no-rats")
	check(game.stage.rat_start_time<0,"Dundalk bonus never starts the rat clock")
	check(is_equal_approx(game.art.presentation_scale(8),1.07*1.05),"Stan is exactly five percent larger than the previous scale")
	check(game.sfx.config.cues.menu_move.files==["5B_zap_1.wav"] and game.sfx.config.cues.menu_confirm.files==["5E_zap_3.wav"],"Short electronic selection and distinct confirm replace the metallic clink")
	game.queue_free();await process_frame;DirAccess.remove_absolute("res://.runtime/rat-stage-test.cfg")
	print("HARBOR RAT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
