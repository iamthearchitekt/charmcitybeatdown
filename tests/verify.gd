extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
const CPU=preload("res://scripts/cpu.gd")
var checks:Array=[]
var failures:int=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks.append(("PASS " if ok else "FAIL ")+label)
	print(checks[-1])
	if not ok: failures+=1

func neutral()->Dictionary:
	return {"dx":0,"down":false,"up":false,"back":false,"command":""}

func setup(a=0,b=1):
	var s=Combat.new()
	s.new_match(a,b)
	s.phase="fight"
	s.fighters[0].x=500.0
	s.fighters[1].x=568.0
	return s

func frames(s,count:int,a:Dictionary={},b:Dictionary={}):
	for i in count: s.step([a,b])

func attack(s,name:String,defense:Dictionary={},count:int=55):
	s.step([{"command":name},defense])
	frames(s,count,{},defense)

func run():
	var s=setup()
	check(s.data.fighters.size()==4,"Four selectable fighter appearances with two editable move sets")
	for fd in s.data.fighters:
		var complete=true
		for name in ["lp","hp","lk","hk","c_lp","c_hp","c_lk","c_hk","air_lp","air_hp","air_lk","air_hk","throw","special1","special2"]:
			complete=complete and fd.moves.has(name)
			for field in ["startup","active","recovery","damage","hitstun","blockstun","pushback","hitstop","cancel_start","cancel_end","box"]:
				complete=complete and fd.moves[name].has(field)
		check(complete,fd.name+" full move kit and frame data")
	for facing in [1,-1]:
		var cmd=Commands.new()
		cmd.sample(Commands.relative_direction(0,true,false,facing),[])
		cmd.sample(Commands.relative_direction(facing,true,false,facing),[])
		var result=cmd.sample(Commands.relative_direction(facing,false,false,facing),["lp"])
		check(result=="special1","QCF priority, facing "+str(facing))
		cmd.reset()
		cmd.sample(Commands.relative_direction(facing,false,false,facing),[])
		cmd.sample(2,[])
		result=cmd.sample(Commands.relative_direction(facing,true,false,facing),["hp"])
		check(result=="special2","Dragon punch priority, facing "+str(facing))
	var cmd=Commands.new()
	cmd.sample(2,[]);cmd.sample(3,[])
	for i in 30: cmd.sample(5,[])
	check(cmd.sample(6,["lp"])=="lp","Expired motion does not trigger a special")
	s=setup()
	attack(s,"lp")
	check(s.fighters[1].health==955,"One active hitbox deals damage only once")
	s=setup()
	attack(s,"lp",{"back":true})
	check(s.fighters[1].health==1000,"Standing guard blocks mid")
	s=setup()
	attack(s,"hk",{"back":true})
	check(s.fighters[1].health==1000,"Standing guard blocks overhead")
	s=setup()
	s.fighters[0].crouch=true
	s.start_move(s.fighters[0],"c_lk")
	frames(s,50,{}, {"back":true})
	check(s.fighters[1].health<1000,"Low attack defeats standing guard")
	s=setup()
	attack(s,"lp",{"back":true,"down":true})
	check(s.fighters[1].health==1000,"Crouching guard blocks mid")
	s=setup()
	s.start_move(s.fighters[0],"c_lk")
	frames(s,50,{}, {"back":true,"down":true})
	check(s.fighters[1].health==1000,"Crouching guard blocks low")
	s=setup()
	attack(s,"hk",{"back":true,"down":true})
	check(s.fighters[1].health<1000,"Overhead defeats crouching guard")
	s=setup()
	s.fighters[1].x=552.0
	attack(s,"throw",{"back":true})
	check(s.fighters[1].health==845,"Throw defeats guard")
	s=setup(0,0)
	s.step([{"command":"lp"},{"command":"lp"}])
	frames(s,30)
	check(s.fighters[0].health==955 and s.fighters[1].health==955,"Simultaneous active contacts trade")
	s=setup()
	s.start_move(s.fighters[0],"hp")
	frames(s,int(s.data.fighters[0].moves.hp.startup)-1)
	check(s.fighters[1].health==1000,"Heavy punch has readable startup")
	s=setup()
	s.fighters[1].x=900.0
	attack(s,"hp")
	check(s.fighters[1].health==1000,"Whiffing attacks do not hit at a distance")
	s=setup()
	s.fighters[0].x=1148.0;s.fighters[1].x=1196.0
	frames(s,60,{"dx":1},{"dx":-1})
	check(s.fighters[1].x<=1196 and absf(s.fighters[0].x-s.fighters[1].x)>=Combat.PUSH_WIDTH-.01,"Corner boundaries and pushbox separation")
	s=setup()
	s.fighters[0].x=500.0;s.fighters[1].x=620.0
	s.step([{"dx":1,"up":true},{}])
	frames(s,43,{"dx":1})
	check(s.fighters[0].x>s.fighters[1].x and s.fighters[0].facing==-1 and s.fighters[1].facing==1,"Jump-over side switch updates facing")
	s=setup()
	s.fighters[1].x=850.0
	attack(s,"special1",{},90)
	check(s.fighters[1].health==890,"Harbor Current projectile travels and hits once")
	s=setup()
	s.fighters[1].y=480.0
	s.fighters[1].vy=0.0
	attack(s,"special2",{},30)
	check(s.fighters[1].health<1000,"Rising special catches airborne opponent")
	s=setup(1,0)
	s.fighters[1].x=700.0
	var before=s.fighters[0].x
	attack(s,"special1")
	check(s.fighters[0].x>before+40 and s.fighters[1].health<1000,"Redline advancing special closes distance and hits")
	s=setup()
	s.step([{"command":"lp"},{}])
	while s.fighters[1].health==1000: s.step([{},{}])
	var stopped_x=s.fighters[0].x
	var stopped_frame=s.fighters[0].frame
	s.step([{"dx":1,"command":"hp"},{}])
	check(s.fighters[0].x==stopped_x and s.fighters[0].frame==stopped_frame,"Hitstop freezes simulation while accepting buffered input")
	frames(s,7)
	check(s.fighters[0].move=="hp","Buffered normal cancel comes out after hitstop")
	frames(s,14)
	check(s.fighters[1].combo>=2,"LP into HP is a true short combo")
	s=setup()
	s.fighters[1].health=1
	attack(s,"lp",{},15)
	check(s.phase=="round_end" and s.wins[0]==1,"KO awards the first round")
	frames(s,300)
	check(s.phase=="fight" and s.round_number==2 and s.fighters[1].health==1000,"Round transition restores health and resumes")
	s.fighters[0].x=500.0;s.fighters[1].x=568.0;s.fighters[1].health=1
	attack(s,"lp",{},15)
	frames(s,135)
	check(s.phase=="results" and s.wins[0]==2,"Decisive round goes directly to results")
	frames(s,245)
	check(s.phase=="results","Results remain stable without any finisher phase")
	s.new_match(1,0)
	check(s.phase=="intro" and s.wins==[0,0] and s.fighters[0].kind==1,"Rematch clears score and preserves selected matchup")
	cmd.reset();cmd.sample(2,[]);cmd.sample(5,[])
	var fin=cmd.sample(2,["hp"])
	check(fin=="hp","Down-release-down plus HP remains a normal punch")
	# Airborne KOs used to freeze permanently when round-end stopped gravity.
	s=setup()
	s.fighters[0].y=Combat.FLOOR-170.0;s.fighters[0].vy=-8.0
	s.fighters[1].y=Combat.FLOOR-90.0;s.fighters[1].vy=-12.0
	s.fighters[1].health=0
	s.end_round()
	frames(s,65)
	check(s.fighters[1].state=="ko" and s.fighters[1].y==Combat.FLOOR and s.fighters[1].vy==0,"Airborne loser falls and settles on the dock after KO")
	check(s.fighters[0].y==Combat.FLOOR and s.fighters[0].vy==0,"Airborne winner also lands during round-end")
	s=setup()
	s.fighters[0].health=0;s.fighters[1].health=0
	s.fighters[0].y=400;s.fighters[1].y=430
	s.end_round();frames(s,55)
	check(s.fighters[0].state=="ko" and s.fighters[1].state=="ko" and s.fighters[0].y==Combat.FLOOR and s.fighters[1].y==Combat.FLOOR,"Double KO grounds both defeated fighters")
	for direction in [4,6]:
		cmd.reset();cmd.sample(direction,[]);cmd.sample(5,[])
		check(cmd.sample(direction,[])==("dash_forward" if direction==6 else "dash_back"),"Double-tap "+str(direction)+" recognizes dash")
	s=setup();s.fighters[1].x=1000
	var dash_start=s.fighters[0].x
	s.step([{"command":"dash_forward"},{}]);frames(s,8)
	check(s.fighters[0].x-dash_start>=90,"Forward dash travels faster than walking")
	s=setup();s.fighters[1].x=590
	dash_start=s.fighters[0].x
	s.step([{"command":"dash_back"},{}]);frames(s,8)
	check(dash_start-s.fighters[0].x>=90,"Backdash creates room from close pressure")
	s=setup()
	s.time_left=1;s.fighters[0].health=800
	s.step([{},{}])
	check(s.phase=="round_end" and s.winner==1 and s.last_result=="TIME UP","Timeout awards round to higher health")
	s=setup(0,0)
	s.fighters[0].health=20;s.fighters[1].health=20
	s.step([{"command":"lp"},{"command":"lp"}]);frames(s,10)
	check(s.winner==-1 and s.wins==[0,0] and s.last_result=="DOUBLE KO","Double KO replays without awarding either player")
	s=setup();s.training=true
	s.fighters[1].health=1
	s.fighters[1].last_hit=s.tick
	attack(s,"lp",{},20)
	check(s.phase=="fight" and s.fighters[1].health==1000,"Training regenerates health and never ends match")
	var cpu=CPU.new()
	s=setup()
	var legal=true
	var started_health=s.fighters[0].health
	var cpu_dealt_damage=false
	for i in 1000:
		var control=cpu.control(s,1,2)
		if control.command!="" and not s.data.fighters[s.fighters[1].kind].moves.has(control.command): legal=false
		s.step([{},control])
		cpu_dealt_damage=cpu_dealt_damage or s.fighters[0].health<started_health
	check(legal and cpu_dealt_damage,"CPU selects legal moves and successfully fights across round resets")
	cpu=CPU.new();s=setup();s.training=true
	s.fighters[0].x=400;s.fighters[1].x=570
	var retreats=0
	var crowded_forward=0
	for i in 700:
		var control=cpu.control(s,1,1)
		var distance=absf(s.fighters[1].x-s.fighters[0].x)
		if control.dx==-s.fighters[1].facing: retreats+=1
		if distance<155 and control.dx==s.fighters[1].facing: crowded_forward+=1
		s.step([{"dx":-1,"back":true},control])
	check(retreats>10 and crowded_forward==0,"Normal CPU backs off and never walks into close pushbox pressure")
	# Full scene smoke and real Godot input-event path (headless, no hardware required).
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for kind in 4:
		var atlas=main.art.sheets[kind].get_image()
		var valid=atlas.detect_alpha()!=Image.ALPHA_NONE
		for region in main.art.regions[kind]:
			var rect=Rect2i(region[0],region[1],region[2],region[3])
			valid=valid and Rect2i(Vector2i.ZERO,atlas.get_size()).encloses(rect) and atlas.get_region(rect).get_used_rect().has_area()
		check(valid,"Fighter "+str(kind+1)+" atlas: 16 nonempty in-bounds transparent sprite regions")
	main.selected_mode=1
	main.begin_match()
	main.sim.phase="fight"
	main.sim.fighters[0].x=500.0;main.sim.fighters[1].x=568.0
	var key=InputEventKey.new()
	key.physical_keycode=KEY_Z;key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await physics_frame
	await physics_frame
	check(main.sim.fighters[0].move=="lp","P1 keyboard light punch reaches live scene combat")
	main.sim.fighters[0].x=300.0
	main.sim.fighters[1].x=900.0
	key=InputEventKey.new();key.physical_keycode=KEY_G;key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await physics_frame
	await physics_frame
	check(main.sim.fighters[1].move=="hp","P2 keyboard heavy punch reaches live scene combat")
	main.sim.reset_round();main.sim.phase="fight"
	key=InputEventKey.new();key.physical_keycode=KEY_RIGHT;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	var start_x=main.sim.fighters[0].x
	await physics_frame;await physics_frame;await physics_frame
	check(main.sim.fighters[0].x>start_x,"Right arrow moves Player 1 right")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	key=InputEventKey.new();key.physical_keycode=KEY_LEFT;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	start_x=main.sim.fighters[0].x
	await physics_frame;await physics_frame;await physics_frame
	check(main.sim.fighters[0].x<start_x,"Left arrow moves Player 1 left")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	key=InputEventKey.new();key.physical_keycode=KEY_DOWN;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	await physics_frame;await physics_frame
	check(main.sim.fighters[0].crouch,"Down arrow crouches Player 1")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	key=InputEventKey.new();key.physical_keycode=KEY_UP;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	await physics_frame;await physics_frame
	check(main.sim.fighters[0].y<Combat.FLOOR,"Up arrow jumps Player 1")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	check(main.music_enabled and main.music.playing and main.music.volume_db==-13,"User-supplied match music plays at the requested increased level")
	main.paused=true
	var paused_tick=main.sim.tick
	var paused_clock=main.clock
	var paused_positions=[main.sim.fighters[0].x,main.sim.fighters[0].y,main.sim.fighters[1].x,main.sim.fighters[1].y]
	await physics_frame;await physics_frame
	check(main.sim.tick==paused_tick,"Pause stops combat simulation")
	check(main.clock==paused_clock,"Pause freezes animation, rain, water and effects clock")
	check(paused_positions==[main.sim.fighters[0].x,main.sim.fighters[0].y,main.sim.fighters[1].x,main.sim.fighters[1].y],"Pause freezes both fighters' positions even in midair")
	var poses_ok=true
	var idle_f=main.sim.make_fighter(0,0)
	for sample in 24:
		if main.art.pose(idle_f,float(sample)/12) not in [0,2]: poses_ok=false
	check(poses_ok,"Idle animation stays in hands-up boxing stances")
	check(main.stage.water_frame(0.0)==0 and main.stage.water_frame(.20)==0 and main.stage.water_frame(.30)==1 and main.stage.water_frame(.50)==0,"Water background alternates exactly two frames at 4 fps")
	print("GAMEPADS DETECTED: ",Input.get_connected_joypads())
	checks.append("Gamepad hardware: "+str(Input.get_connected_joypads()))
	main.queue_free()
	await process_frame
	await create_timer(.15).timeout
	var report="CHARM CITY BEATDOWN - verification\n"+"\n".join(checks)+"\nFailures: "+str(failures)+"\n"
	var file=FileAccess.open("res://tests/verification.txt",FileAccess.WRITE)
	file.store_string(report)
	print("RESULT: ",checks.size()-1-failures," checks passed; ",failures," failed.")
	quit(1 if failures>0 else 0)
