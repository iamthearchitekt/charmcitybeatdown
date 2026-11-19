extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/arcade_run.gd")
const Bonus=preload("res://scripts/car_bonus.gd")
const Props=preload("res://scripts/breakables_bonus.gd")
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
	var roster=s.data.fighters;var eligible=[]
	for i in roster.size(): eligible.append(i)
	var r=Run.new()
	for player in roster.size():
		r.begin(player,roster,eligible)
		var seen={}
		for enemy in r.opponents: seen[enemy]=true
		check(r.opponents.size()==13 and seen.size()==13 and not seen.has(player),"Full ladder excludes mirrors and repeats for fighter "+str(player))
		check(r.opponents[-1]==(9 if player!=9 else 10),"Final boss is Rachel, or Jeff when playing Rachel: "+str(player))
		check(r.opponents[-2]==(6 if player!=6 else 8),"Penultimate boss is Spike, or Stan when playing Spike: "+str(player))
	r.begin(0,roster,range(11))
	check(r.opponents.size()==10 and r.opponents.all(func(i):return i<11),"Locked secret fighters are excluded from a fresh run")
	var sequence=[]
	for i in 6: sequence.append(r.next_bonus())
	check(sequence==["car","kegs","boxes","car","kegs","boxes"],"Every-two-win bonuses rotate car, kegs, boxes")
	r.scores_path="res://.runtime/arcade-unit-scores.cfg";r.high_scores=[]
	for i in 12:
		r.submitted=false;r.score=100+i;r.continues=i;r.submit("TEST "+str(i),i%2==0)
	check(r.high_scores.size()==10 and r.high_scores[0].score==111 and r.high_scores[-1].score==102,"Saved high scores retain the ten highest results in descending order")
	var count=r.high_scores.size();r.submit("DUPLICATE",true)
	check(r.high_scores.size()==count and r.high_scores[0].name=="TEST 11","Run score is submitted only once")
	var loaded=Run.new();loaded.scores_path=r.scores_path;loaded.load_scores()
	check(loaded.high_scores==r.high_scores and loaded.high_scores[0].continues==11,"Score, clear status and continue count survive reloading")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.arcade.scores_path="res://.runtime/arcade-integration-scores.cfg";game.arcade.high_scores=[]
	game.bonus_rewards.path="res://.runtime/arcade-integration-rewards.cfg";game.bonus_rewards.earned=[]
	game.stage.history_path="res://.runtime/arcade-integration-stages.cfg"
	game.unlocks.all_unlocked=true;game.selected_mode=0;game.selection[0]=2;game.begin_match()
	check(game.stage.current_index()==0 and game.arcade.opponents.size()==13,"A new ladder starts at Inner Harbor with all eligible opponents")
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
	var expected=["car","kegs","boxes","car","kegs","boxes"];var played=[]
	for encounter in 13:
		var before=game.arcade.cursor;won(game);game.account_completed_stage()
		check(game.arcade.cursor==before+1,"A finished opponent advances once: "+str(before+1))
		game.action("confirm")
		if game.sim is Bonus and game.screen=="match":
			var kind=game.sim.challenge if game.sim is Props else "car";played.append(kind)
			check(game.stage.stage_name()=={"car":"FELLS POINT / CAR CRUSH","kegs":"BREWERS HILL / KEG BREAK","boxes":"DUNDALK / BOX BREAK"}[kind],"Bonus uses the requested Baltimore location: "+kind)
			game.sim.finish(true);game.sync_match_end_audio()
			var subtotal=game.arcade.score;game.account_completed_stage()
			check(game.arcade.score==subtotal and game.sim.reward_code.length()==3,"Bonus points and secret code are awarded exactly once")
			game.action("confirm")
	check(played==expected,"A complete 13-fight run alternates all six scheduled bonus rounds")
	check(game.screen=="campaign" and not game.arcade.active and game.arcade.high_scores[0].clear,"Defeating the final boss completes the campaign and saves the score")
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
	for path in [r.scores_path,"res://.runtime/arcade-integration-scores.cfg","res://.runtime/arcade-integration-rewards.cfg","res://.runtime/arcade-integration-stages.cfg"]: DirAccess.remove_absolute(path)
	print("ARCADE RUN RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
