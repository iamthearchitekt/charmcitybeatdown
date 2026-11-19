extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
const Grapples=preload("res://scripts/grapple_sequences.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func setup(kind:int,face:int=1):
	var s=Combat.new();s.new_match(kind,(kind+1)%14);s.phase="fight"
	s.fighters[0].x=500 if face==1 else 740;s.fighters[1].x=s.fighters[0].x+face*100
	s.fighters[0].facing=face;s.fighters[1].facing=-face
	return s
func run():
	for kind in 14:
		for face in [-1,1]:
			for back in [false,true]:
				var s=setup(kind,face);var a=s.fighters[0];var b=s.fighters[1]
				s.step([{"command":"throw","back":back},{"back":true}])
				var grabbed=false;var deferred=true;var hits=0;var total=0;var damage_frame=-1;var poses={}
				for tick in 125:
					s.step([{},{}])
					if b.grabbed_by==0:
						grabbed=true;poses[str(b.grapple_pose)]=true
						if a.grab_frame<10: deferred=deferred and b.health==1000
					for e in s.events:
						if e.type=="hit" and e.get("grapple",false):
							hits+=1;damage_frame=a.grab_frame
					total=1000-b.health
				var is_hold=Grapples.NORMAL[kind]=="hold"
				check(grabbed and deferred,"Grip owns pair without premature damage: "+str(kind)+" face="+str(face)+" back="+str(back))
				check(total==int(s.data.fighters[kind].moves.throw.damage) and hits==(3 if is_hold else 1),"Impact/pulse damage exactly once with capped total: "+str(kind))
				check(a.throw_target<0 and b.grabbed_by<0 and b.y==s.FLOOR and b.throw_rotation==0,"Keyed throw releases/lands without rotating a standing sprite: "+str(kind))
				check((b.x<a.x) if a.throw_dir<0 else (b.x>a.x),"Chosen landing side is preserved: "+str(kind))
	for kind in [0,6,8,9]:
		for face in [-1,1]:
			var s=setup(kind,face);var reader=Commands.new();var kit=s.data.fighters[kind].moves
			for d in [4,1,2,3]: reader.sample(d,[],kit)
			check(reader.sample(6,["throw"],kit)=="command_grab","Half-circle+Y recognizes command grab, fighter "+str(kind)+" facing "+str(face))
			s.step([{"command":"command_grab"},{"back":true}])
			for i in 115:s.step([{},{}])
			check(s.fighters[1].health==1000-int(kit.command_grab.damage),"Command grab beats guard with impact-timed damage: "+str(kind))
	for kind in [4,5,10,13]:
		var s=setup(kind);s.fighters[0].y=430;s.fighters[1].y=440
		s.step([{"command":"throw"},{}])
		var grabbed=false
		for i in 110:
			s.step([{},{}]);grabbed=grabbed or s.fighters[0].throw_target==1
		check(grabbed and s.fighters[1].health==1000-int(s.data.fighters[kind].moves.air_throw.damage),"Selected air Y throw catches airborne opponent: "+str(kind))
		s=setup(kind);s.fighters[0].y=430
		s.step([{"command":"throw"},{}]);for i in 15:s.step([{},{}])
		check(s.fighters[1].health==1000,"Air throw cannot seize grounded opponent: "+str(kind))
	for kind in [7,12]:
		var s=setup(kind);s.step([{"command":"throw"},{}]);var escaped=false
		for i in 100:
			s.step([{}, {"dx":1 if int(i/4)%2==0 else -1,"command":"lp" if i%4==0 else ""}])
			for e in s.events: escaped=escaped or (e.type=="grab_release" and e.escaped)
		check(escaped and s.fighters[1].health>1000-int(s.data.fighters[kind].moves.throw.damage),"Defender can struggle out of a hold before all pulses: "+str(kind))
	var s=setup(0);s.fighters[1].health=1;s.wins=[1,0]
	s.step([{"command":"throw"},{}]);var ko_at=-1
	for i in 110:
		s.step([{},{}])
		if s.phase=="round_end" and ko_at<0:ko_at=s.fighters[0].grab_frame
	check(ko_at==Grapples.profile(0,"throw").impact and s.fighters[1].state=="ko" and s.fighters[1].y==s.FLOOR,"Final throw KO happens on impact and finishes face-up on floor")
	print("GRAPPLE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
