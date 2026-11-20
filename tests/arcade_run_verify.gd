extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/arcade_run.gd")
const Bonus=preload("res://scripts/car_bonus.gd")
const Props=preload("res://scripts/breakables_bonus.gd")
const Stage=preload("res://scripts/harbor_stage.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func won(game,points=1234):
	game.sim.winner=0;game.sim.wins=[2,0];game.sim.scores=[points,0];game.sim.phase="results"
	game.account_completed_stage()
func run():
	var s=Combat.new();s.phase="fight";s.time_left=50*60;s.fighters[1].health=0
	s.end_round()
	check(s.scores[0]==25000 and s.round_rewards[-1].perfect==10000,"Round scoring adds time, remaining health and perfect bonuses")
	var score=s.scores[0];s.end_round()
	check(s.scores[0]==score,"Ending a round twice cannot duplicate its reward")
	s.reset_round();check(s.scores[0]==score,"Round changes retain match score")
	s.phase="fight";s.fighters[0].health=400;s.fighters[1].health=0;s.time_left=0;s.end_round()
	check(s.round_rewards[-1].perfect==0 and s.round_rewards[-1].total==4000,"An imperfect round receives only its actual health/time bonus")
	s.new_match(0,1,true);s.phase="fight";s.fighters[1].health=0;s.end_round()
	check(s.scores==[0,0],"Training cannot generate arcade points")
	var roster=s.data.fighters
	var r=Run.new()
	var homes=[1,4,10,0,2,7,6,9,9,1,0,5,3,8]
	for i in roster.size(): check(Stage.home_stage(roster[i].id)==homes[i],"Home stage mapped for "+roster[i].name)
	for player in roster.size():
		r.begin(player,roster)
		var seen={}
		for enemy in r.opponents: seen[enemy]=true
		check(r.opponents.size()==13 and seen.size()==13 and not seen.has(player),"Full ladder excludes mirrors and repeats for fighter "+str(player))
		check(r.opponents[-1]==(9 if player!=9 else 10),"Final boss is Rachel, or Jeff when playing Rachel: "+str(player))
		check(r.opponents[-2]==(6 if player!=6 else 8),"Penultimate boss is Spike, or Stan when playing Spike: "+str(player))
		check(Stage.home_stage(roster[r.opponents[0]].id)==Stage.INNER_HARBOR,"Arcade opens against a Harbor fighter: "+str(player))
	r.begin(0,roster)
	check([11,12,13].all(func(i):return i in r.opponents),"Secret fighters appear as full-roster Arcade opponents")
	var sequence=[]
	for i in 6: sequence.append(r.next_bonus())
	check(sequence==["car","kegs","boxes","","",""] and not r.has_bonus(),"Bonus selection stops after the three distinct challenges")
	r.scores_path="user://test-arcade-unit-scores.cfg";r.high_scores=[]
	for i in 12:
		r.submitted=false;r.score=100+i;r.continues=i;r.submit("TEST "+str(i),i%2==0)
	check(r.high_scores.size()==10 and r.high_scores[0].score==111 and r.high_scores[-1].score==102,"Saved high scores retain the ten highest results in descending order")
	var count=r.high_scores.size();r.submit("DUPLICATE",true)
	check(r.high_scores.size()==count and r.high_scores[0].name=="TEST 11","Run score is submitted only once")
	var loaded=Run.new();loaded.scores_path=r.scores_path;loaded.load_scores()
	check(loaded.high_scores==r.high_scores and loaded.high_scores[0].continues==11,"Score, clear status and continue count survive reloading")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.arcade.scores_path="user://test-arcade-integration-scores.cfg";game.arcade.high_scores=[]
	game.bonus_rewards.path="user://test-arcade-integration-rewards.cfg";game.bonus_rewards.earned=[]
	game.stage.history_path="user://test-arcade-integration-stages.cfg"
	game.unlocks.all_unlocked=false;game.unlocks.unlocked=[];game.selected_mode=0;game.selection[0]=2;game.begin_match()
	check(game.stage.current_index()==0 and game.arcade.opponents.size()==13,"A fresh ladder starts at Inner Harbor with every other fighter")
	check(not game.unlocks.available(roster[13]) and 13 in game.arcade.opponents,"Secret opponents stay locked on the player-select roster")
	var original=game.sim.fighters[1].kind
	game.sim.winner=1;game.sim.phase="results";game.sim.scores=[200,900];game.account_completed_stage();game.action("confirm")
	check(game.screen=="continue" and game.continue_timer==600 and game.arcade.cursor==0,"A loss opens a ten-second continue without advancing the ladder")
	game.action("confirm")
	check(game.sim.fighters[1].kind==original and game.arcade.continues==1 and game.arcade.score==200,"Continuing retries the same opponent and retains earned score")
	game.sim.phase="fight";game.sim.fighters[0].health=678
	var previous_sim=game.sim;var previous_stage=game.stage.current_index()
	var join=InputEventKey.new();join.pressed=true;join.physical_keycode=KEY_2
	game._input(join)
	check(game.screen=="challenger" and not game.challenge_resume.is_empty(),"A second player interrupts Arcade with a challenger splash")
	for i in 90: game._physics_process(1.0/60)
	check(game.screen=="select" and game.select_slot==1,"The challenger selects their fighter after the splash")
	game.action("confirm")
	check(game.selected_mode==1 and game.screen=="match" and game.sim!=previous_sim,"The interruption launches an independent local Versus fight")
	game.sim.winner=1;game.sim.phase="results";game.action("confirm")
	check(game.selected_mode==0 and game.sim==previous_sim and game.sim.fighters[0].health==678 and game.stage.current_index()==previous_stage and game.arcade.cursor==0,"After Versus, Arcade resumes the suspended fight and ladder exactly")
	var expected=["car","kegs","boxes"];var played=[]
	for encounter in 13:
		var home=Stage.home_stage(roster[game.sim.fighters[1].kind].id)
		check(game.stage.current_index()==home and not game.stage.at_bonus,"Arcade loads the opponent's regular fight stage: "+roster[game.sim.fighters[1].kind].name)
		var before=game.arcade.cursor;won(game);game.account_completed_stage()
		check(game.arcade.cursor==before+1,"A finished opponent advances once: "+str(before+1))
		if encounter==12:
			game.result_hold=1
			game._physics_process(1.0/60)
		else: game.action("confirm")
		if encounter<12: check(game.screen=="match","The finale waits until all thirteen opponents are defeated: "+str(encounter+1))
		if game.sim is Bonus and game.screen=="match":
			var kind=game.sim.challenge if game.sim is Props else "car";played.append(kind)
			check(game.stage.stage_name()=={"car":"FELLS POINT / CAR CRUSH","kegs":"BREWERS HILL / KEG BREAK","boxes":"DUNDALK / BOX BREAK"}[kind],"Bonus uses the requested Baltimore location: "+kind)
			var cleared=kind!="kegs"
			game.sim.finish(cleared);game.sync_match_end_audio()
			var subtotal=game.arcade.score;game.account_completed_stage()
			check(game.arcade.score==subtotal and game.sim.reward_code.length()==(3 if cleared else 0),"Bonus score and reward are handled once: "+kind)
			game.action("confirm")
	check(played==expected,"A complete run offers each bonus once, even after a failed challenge")
	check(game.screen=="campaign" and not game.arcade.active and game.arcade.high_scores[0].clear,"Defeating the final boss completes the campaign and saves the score")
	var skyline=Image.new()
	var loaded_art=skyline.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/arcade-finale.png"))
	check(game.finale_age==0 and game.round_callouts.regions.has("won") and loaded_art==OK and game.finale_fanfare.stream.get_length()>2,
		"The final match starts the dedicated animated YOU WON finale and fanfare")
	game.action("confirm")
	check(game.screen=="campaign" and game.finale_age==game.ArcadeFinale.DETAILS_TICK,"Confirm during the finale reveal shows the results first")
	game.action("confirm")
	check(game.screen=="scores","The finale can continue to the saved high scores")
	game.action("back");game.selected_mode=0;game.action("confirm");game.action("confirm")
	game.sim.phase="results";game.sim.winner=1;game.sim.scores[0]=456;game.account_completed_stage();game.start_continue()
	for i in 600: game._physics_process(1.0/60)
	check(game.screen=="game_over" and not game.arcade.active and game.continue_timer==0,"Letting the continue timer expire ends the run")
	game.action("title");game.action("scores")
	check(game.screen=="scores","High scores are accessible directly from the main menu")
	game.dispatch_combat_event({"type":"prop_hit","kind":"boxes","broken":true,"x":0,"y":0})
	check(game.sfx.playback_log[-1].cue=="box_break","Boxes play the supplied wood-break sound")
	game.dispatch_combat_event({"type":"prop_hit","kind":"kegs","broken":true,"x":0,"y":0})
	check(game.sfx.playback_log[-1].cue=="car_break","Destroyed kegs play the supplied metal-break sound")
	game.queue_free();await process_frame
	for path in [r.scores_path,"user://test-arcade-integration-scores.cfg","user://test-arcade-integration-rewards.cfg","user://test-arcade-integration-stages.cfg"]: DirAccess.remove_absolute(path)
	print("ARCADE RUN RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
