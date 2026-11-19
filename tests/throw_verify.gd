extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func setup(kind:int)->RefCounted:
	var s=Combat.new();s.new_match(kind,(kind+1)%14);s.phase="fight";s.fighters[0].x=500;s.fighters[1].x=591
	return s
func run():
	for kind in 14:
		for back in [false,true]:
			var s=setup(kind);var a=s.fighters[0];var b=s.fighters[1]
			s.step([{"command":"throw","back":back},{"back":true}])
			var held=false;var paired=false;var rotated=false
			for i in 100:
				s.step([{},{}]);held=held or b.grabbed_by==0;paired=paired or b.grapple_role=="victim";rotated=rotated or absf(b.throw_rotation)>.5
			check(held and paired and not rotated,"Authored paired grab and release without rotating a standing body: fighter "+str(kind)+" back="+str(back))
			check(b.health==1000-int(s.data.fighters[kind].moves.throw.damage),"Throw damages exactly once through guard")
			check(b.grabbed_by<0 and a.throw_target<0 and b.y==Combat.FLOOR,"Pair releases and lands normally")
			check((b.x<a.x) if back else (b.x>a.x),"Throw direction selects landing side")
			check(b.facing==(1 if back else -1),"Landing pose keeps the head away from opponent")
		var s=setup(kind);s.wins=[1,0];s.fighters[1].health=1
		s.step([{"command":"throw"},{}])
		for i in 100: s.step([{},{}])
		check(s.fighters[1].state=="ko" and s.fighters[1].y==Combat.FLOOR and not s.fighters[1].throw_flight and s.fighters[0].throw_target<0,"KO throw finishes and lands face-up: "+str(kind))
	for mode in ["range","air","wake"]:
		var s=setup(0)
		if mode=="range": s.fighters[1].x=900
		if mode=="air": s.fighters[1].y=Combat.FLOOR-150;s.fighters[1].vy=-10
		if mode=="wake": s.fighters[1].wake_safe=20
		s.step([{"command":"throw"},{}])
		for i in 12: s.step([{},{}])
		check(s.fighters[1].health==1000,"Throw cannot grab opponent in "+mode)
	print("THROW RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
