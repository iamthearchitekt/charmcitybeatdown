extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
const Pose=preload("res://scripts/combat_pose.gd")
var sim=Combat.new()
var checks=0
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1

func read_input(kind:int,motion:Array,button:String,facing:int,hold:int=0)->String:
	var reader=Commands.new()
	var kit=sim.data.fighters[kind].moves
	for i in range(motion.size()-1):
		var d:int=motion[i]
		for frame in (hold if i==0 and hold>0 else 1):
			reader.sample(relative(d,facing),[],kit)
	return reader.sample(relative(motion[-1],facing),[button],kit)

func relative(code:int,facing:int)->int:
	var dx=(code-1)%3-1
	return Commands.relative_direction(dx*facing,code<=3,code>=7,facing)

func practice(kind:int,move_id:String,distance:float,facing:int,guard:bool=false,crouch:bool=false)->Dictionary:
	sim.new_match(kind,0)
	sim.phase="fight"
	var fighter=sim.fighters[0]
	var target=sim.fighters[1]
	fighter.x=620-distance*.5*facing
	target.x=620+distance*.5*facing
	fighter.facing=facing
	target.facing=-facing
	target.backstep_used=true
	sim.start_move(fighter,move_id)
	var hits=0
	var blocks=0
	var height=-1.0
	var pose_keys={}
	for frame in 145:
		sim.step([{}, {"back":guard,"down":crouch}])
		if not sim.projectiles.is_empty() and height<0:
			height=sim.projectiles[0].y
		if fighter.move==move_id:
			pose_keys[Pose.key(fighter,sim.move_data(fighter))]=true
		for event in sim.events:
			if event.type=="hit" and event.owner==0: hits+=1
			if event.type=="block" and event.owner==0: blocks+=1
	return {"hits":hits,"blocks":blocks,"height":height,"poses":pose_keys.size(),"grounded":fighter.y==Combat.FLOOR and fighter.move==""}

func run():
	for facing in [-1,1]:
		for punch in ["lp","mp","hp"]:
			check(read_input(7,[4,6],punch,facing,40)=="special1","Eric charged blade reads all punches in facing %d" % facing)
			check(read_input(0,[4,6],punch,facing,40)=="special5","Marcus charged straight reads all punches")
			check(read_input(10,[2,1,4],punch,facing)=="special3","Jeff's long arm reads the back quarter circle")
		for kick in ["lk","mk","hk"]:
			check(read_input(10,[2,3,6],kick,facing)=="special5","Jeff's floor shot reads all kicks")
			check(read_input(0,[4,6],kick,facing,40)=="special6","Marcus charged body blow reads all kicks")
			check(read_input(0,[2,1,4],kick,facing)=="special3","Marcus lariat has its own command")
			check(read_input(3,[2,1,4],kick,facing)=="special3","Lauren's spin reads the back quarter circle")
			check(read_input(3,[2,8],kick,facing,40)=="special4","Lauren's arc reads down charge then up")
	check(read_input(7,[2,3,6],"hp",1)=="hp" and read_input(7,[4,6],"hp",1,20)=="hp","Eric's blade needs an actual back charge")
	var reader=Commands.new()
	var input_result=""
	for i in 19:
		input_result=reader.sample(5,["mp"] if i in [0,9,18] else [],sim.data.fighters[8].moves)
	check(input_result=="special3","Three separate punch presses activate Stan's palms")
	for entry in [[8,"special3",160],[7,"special1",350],[10,"special1",350],[10,"special5",350],
		[10,"special2",153],[10,"special3",313],[0,"special5",228],[0,"special6",209],
		[0,"special3",160],[1,"special3",154],[3,"special3",160],[3,"special4",140]]:
		var kind:int=entry[0]
		var move:String=entry[1]
		var dist:float=entry[2]
		var m=sim.data.fighters[kind].moves[move]
		var max_hits=ceili(m.active/float(m.rehit_interval)) if m.has("rehit_interval") else 1
		var name=m.name
		for direction in [-1,1]:
			var hit=practice(kind,move,dist,direction)
			check(hit.hits>=1 and hit.hits<=max_hits and hit.grounded and hit.poses>=2,
				"%s connects and recovers, facing %d, hits %d" % [name,direction,hit.hits])
			var guard=practice(kind,move,dist,direction,true,m.level=="low")
			check(guard.blocks>=1 and guard.hits==0,"%s can be blocked, facing %d" % [name,direction])
	var high=practice(10,"special1",350,1,false,true)
	var low=practice(10,"special5",350,1)
	check(high.height<low.height-100 and high.hits==0 and low.hits==1,
		"Jeff's high shot can be ducked and the low shot separately covers the floor (%s / %s)" % [high,low])
	check(practice(10,"special5",350,1,true,false).hits==1,"Standing guard loses to the low shot")
	print("STYLE SPECIALS RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
