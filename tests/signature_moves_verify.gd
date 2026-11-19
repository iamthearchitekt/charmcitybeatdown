extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func perform(kind:int,name:String,facing:int=1,guard:bool=false,ko:bool=false)->Dictionary:
	var sim=Combat.new();sim.new_match(kind,0);sim.phase="fight"
	sim.fighters[0].x=500 if facing==1 else 740
	sim.fighters[1].x=640 if facing==1 else 600
	sim.fighters[0].facing=facing;sim.fighters[1].facing=-facing
	sim.fighters[1].backstep_used=true
	if ko: sim.fighters[1].health=20;sim.wins=[1,0]
	sim.start_move(sim.fighters[0],name)
	var hits=0;var blocks=0;var frame_list=[]
	for frame in 180:
		sim.step([{}, {"back":guard}])
		for event in sim.events:
			if event.type=="hit" and event.owner==0: hits+=1;frame_list.append(sim.tick)
			if event.type=="block": blocks+=1
	return {"sim":sim,"hits":hits,"blocks":blocks,"frames":frame_list}
func run():
	var base=Combat.new()
	var alex=base.data.fighters[2].moves
	var viv=base.data.fighters[5].moves
	var brook=base.data.fighters[1].moves
	for facing in [-1,1]:
		var reader=Commands.new()
		reader.sample(Commands.relative_direction(0,true,false,facing),[],alex)
		reader.sample(Commands.relative_direction(-facing,true,false,facing),[],alex)
		check(reader.sample(Commands.relative_direction(-facing,false,false,facing),["hk"],alex)=="special3","Hurricane quarter-circle back works facing "+str(facing))
	for kit in [viv,brook]:
		var reader=Commands.new();var result=""
		for frame in 17: result=reader.sample(5,["lk"] if frame in [0,8,16] else [],kit)
		check(result=="special3","Three distinct kick taps trigger a flurry")
		reader.reset()
		reader.sample(5,["lk"],kit)
		for frame in 30: result=reader.sample(5,[],kit)
		check(result=="","Holding a kick cannot auto-trigger a flurry")
	var reader=Commands.new()
	for frame in 40: reader.sample(2,[],viv)
	check(reader.sample(8,["hk"],viv)=="special4","Vivian down-charge then up+kick triggers the spinning kick")
	reader.reset()
	for frame in 20: reader.sample(2,[],viv)
	check(reader.sample(8,["hk"],viv)=="hk","A short crouch retains ordinary jump kick input")
	reader.reset()
	for frame in 40: reader.sample(2,[],viv)
	for frame in 12: reader.sample(5,[],viv)
	check(reader.sample(8,["hk"],viv)=="hk","Expired charge cannot trigger an accidental spin")
	var charged=Combat.new();charged.new_match(5,0);charged.phase="fight"
	charged.step([{"command":"special4","up":true},{}])
	check(charged.fighters[0].move=="special4" and charged.fighters[0].y==Combat.FLOOR,"Charge command starts the spin instead of an ordinary jump")
	for frame in 12: charged.step([{},{}])
	check(charged.fighters[0].y>=Combat.FLOOR-50,"Spinning kick stays at its controlled hover height")
	var mashed=Combat.new();mashed.new_match(5,0);mashed.phase="fight"
	reader.reset()
	for frame in 35:
		var command=reader.sample(5,["lk"] if frame in [0,8,16] else [],viv)
		mashed.step([{"command":command},{}])
	check(mashed.fighters[0].move=="special3","Three actual kick taps buffer into the flurry through normal recovery")
	var marcus_moves=base.data.fighters[0].moves
	check(marcus_moves.has_all(["lp","mp","hp","lk","mk","hk","special1","special2","special3","special5","special6","throw","command_grab"]),"Marcus keeps the six attacks, earlier specials, and command grab alongside the lariat and charge punches")
	for entry in [[1,"special3"],[2,"special3"],[5,"special3"],[5,"special4"]]:
		var kind=int(entry[0]);var name=String(entry[1])
		var result=perform(kind,name)
		var m=result.sim.data.fighters[kind].moves[name]
		var maximum=ceili(float(m.active)/m.rehit_interval)
		check(result.hits>=2 and result.hits<=maximum,"Bounded multi-hit attack: "+str(kind)+" "+name+" hits="+str(result.hits))
		check(result.sim.fighters[0].move=="" and result.sim.fighters[0].y==Combat.FLOOR,"Attack finishes recovery and lands: "+str(kind)+" "+name)
		var mirrored=perform(kind,name,-1)
		check(mirrored.hits>=2,"Multi-hit collision works facing left: "+str(kind)+" "+name)
		var guarded=perform(kind,name,1,true)
		check(guarded.blocks>=1 and guarded.hits==0 and guarded.sim.fighters[1].health>=1000-maximum*3,"Guard defeats the flurry with bounded chip: "+str(kind)+" "+name)
		var decisive=perform(kind,name,1,false,true)
		check(decisive.sim.winner==0 and decisive.sim.fighters[0].y==Combat.FLOOR,"KO preserves follow-through then grounds winner: "+str(kind)+" "+name)
	print("SIGNATURE MOVES RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
