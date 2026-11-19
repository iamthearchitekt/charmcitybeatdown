extends SceneTree
const Bonus=preload("res://scripts/car_bonus.gd")
const Car=preload("res://scripts/bonus_car.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func play_attack(s,move:String,low:bool):
	s.step([{"command":move,"down":low},{}])
	for frame in 34: s.step([{"down":low},{}])

func break_bank(s,start:int):
	for zone in range(start,start+3):
		var tries=0
		while s.car.hp[zone]>0 and s.phase=="fight" and tries<30:
			play_attack(s,["lp","lp","lk"][zone%3],zone%3>0)
			tries+=1

func run():
	var c=Car.new()
	check(c.hp.size()==6 and not c.destroyed(),"Six independent zones: three on each side")
	var before=c.hp.duplicate()
	c.damage(0,100,Vector2(448,420))
	check(c.hp[0]==before[0]-100 and c.hp.slice(1)==before.slice(1),"Hitting one zone never damages the other five")
	check(c.target(-1,Rect2(448,370,150,60))==0 and c.target(1,Rect2(640,370,150,60))==3,"Glass hit zones route to the correct physical side")
	check(c.target(-1,Rect2(448,480,150,30))==1 and c.target(-1,Rect2(448,560,150,40))==2,"Mid and low strikes select hood and bumper")
	check(c.target(-1,Rect2(448,370,150,230),"hp")==0 and c.target(-1,Rect2(448,370,150,230),"c_lp")==1 and c.target(-1,Rect2(448,370,150,230),"c_lk")==2,"Punch, crouch jab and crouch kick use the exact requested zones")
	c.hp[0]=0
	check(c.target(-1,Rect2(448,370,150,230),"hk")==-1,"High kick cannot spill into the middle or lower target")
	for zone in 5: c.damage(zone,9999,Vector2.ZERO)
	check(not c.destroyed(),"Five broken zones cannot win")
	c.damage(5,9999,Vector2.ZERO)
	check(c.destroyed(),"Only all six broken zones complete the car")
	var roster_size=Bonus.new().data.fighters.size()
	for kind in roster_size:
		var s=Bonus.new();s.begin(kind);s.phase="fight";s.fighters[0].x=Car.BODY.position.x-34
		break_bank(s,0)
		check(s.car.side_destroyed(-1) and s.car.hp.slice(3)==[350,400,350],"Three left zones break without affecting right: fighter "+str(kind))
		var total_before=s.time_left
		for frame in 60: s.step([{"dx":1,"up":frame==0},{}])
		check(s.fighters[0].x>=Car.BODY.end.x+34 and s.fighters[0].y==s.FLOOR,"Normal up+direction clears car and lands opposite: fighter "+str(kind))
		s.fighters[0].x=Car.BODY.end.x+34
		break_bank(s,3)
		check(s.success and s.phase=="results" and s.time_left>0,"All six zones can be destroyed within 30 seconds: fighter "+str(kind))
		check(total_before<Bonus.DURATION,"Time elapses during attacks and hitstop")
	var s=Bonus.new();s.begin(0);s.phase="fight";s.fighters[0].x=Car.BODY.position.x-34
	s.step([{"dx":1},{}]);check(s.fighters[0].x==Car.BODY.position.x-34,"Grounded walking cannot pass through the car")
	s.fighters[0].x=Car.BODY.end.x+34
	for frame in 60: s.step([{"dx":-1,"up":frame==0},{}])
	check(s.fighters[0].x<=Car.BODY.position.x-34,"Jump-over works right to left as well")
	s.begin(0);s.phase="fight";s.time_left=1;s.step([{},{}])
	check(s.phase=="results" and not s.success and s.reward_code=="","Timeout awards no code and ends cleanly")
	s.begin(0);s.phase="fight";s.fighters[0].x=Car.BODY.position.x-34
	var m=s.data.fighters[0].moves.lp
	s.start_move(s.fighters[0],"lp");s.fighters[0].frame=m.startup
	for frame in m.active: s.step([{},{}])
	check(s.car.hp[0]==350-int(m.damage),"One move damages only one zone once across all active frames")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false)
	game.stage.history_path="res://.runtime/car-stage-test.cfg"
	game.bonus_rewards.path="res://.runtime/car-rewards-test.cfg";game.bonus_rewards.earned=[]
	for cue in ["car_clang","car_glass","car_break","car_destroyed"]:
		check(game.sfx.config.cues.has(cue),"Car-specific supplied sound cue is available: "+cue)
	game.begin_bonus();game.sfx.stop_all()
	game.dispatch_combat_event({"type":"car_hit","zone":0,"broken":true})
	check(game.sfx.playback_log[-1].cue=="car_glass","Destroyed upper zone plays supplied glass break")
	game.dispatch_combat_event({"type":"car_hit","zone":1,"broken":true})
	check(game.sfx.playback_log[-1].cue=="car_break","Destroyed middle zone plays metal break")
	game.dispatch_combat_event({"type":"car_hit","zone":2,"broken":false})
	check(game.sfx.playback_log[-1].cue=="car_clang","Ordinary car impact plays metal clang")
	game.sfx.stop_all();game.dispatch_combat_event({"type":"bonus_complete","success":true})
	check(game.sfx.playback_log.size()==2 and game.sfx.playback_log.all(func(p): return p.cue=="car_destroyed" and p.db<=-20),"Final wreck uses one restrained metal-and-glass layer")
	game.selected_mode=0;game.begin_match()
	for win in 4:
		game.sim.winner=0;game.sim.phase="results";game.account_completed_stage();game.account_completed_stage()
		check(game.arcade_wins==win+1,"Completed fight counted exactly once: "+str(win+1))
		if win%2==1:
			game.action("confirm")
			check(game.sim is Bonus and game.stage.at_bonus,"Bonus appears after every second won fight")
			game.sim.finish(true);game.sync_match_end_audio()
			var code=game.sim.reward_code
			check(code.length()==3 and game.unlocks.registry.character_codes.has(code),"Success reveals a valid existing character password")
			var earned=game.bonus_rewards.earned.size();game.sync_match_end_audio()
			check(earned==game.bonus_rewards.earned.size() and earned==win/2+1,"A reward is saved once and new codes are preferred")
		game.action("confirm")
		check(not game.sim is Bonus and not game.stage.at_bonus,"Continue returns to a randomized normal fight")
	game.selected_mode=1;game.begin_match();game.sim.phase="results";game.sim.winner=0
	var count=game.arcade_wins;game.account_completed_stage()
	check(game.arcade_wins==count,"Versus does not advance solo bonus progression")
	game.begin_bonus();game.sim.phase="fight";game.toggle_pause()
	var time=game.sim.time_left;var clock=game.clock;game._physics_process(1.0/60)
	check(time==game.sim.time_left and clock==game.clock,"Pause freezes bonus timer and two-frame background")
	game.action("title");game.queue_free();await process_frame
	for path in ["res://.runtime/car-stage-test.cfg","res://.runtime/car-rewards-test.cfg"]: DirAccess.remove_absolute(path)
	print("CAR BONUS RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
