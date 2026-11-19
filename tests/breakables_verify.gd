extends SceneTree
const Bonus=preload("res://scripts/breakables_bonus.gd")
const Player=preload("res://tests/bonus_controls.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func setup(kind=0,type="boxes"):
	var s=Bonus.new();s.begin_challenge(kind,type);s.phase="fight";return s
func frames(s,count,a={}):
	for i in count: s.step([a,{}])
func run():
	var s=setup()
	check(s.objects.size()==10 and s.target_count==10,"Dundalk starts with ten independently breakable boxes")
	check(s.object_frames.size()==4 and s.object_frames.all(func(f):return f.texture.get_image().get_used_rect().has_area()),"Box sprites have four nonempty damage states")
	var untouched=s.objects[1].hp;s.damage_object(s.objects[0],s.data.fighters[0].moves.lp,"lp")
	check(s.objects[0].hp==105 and s.objects[1].hp==untouched,"Each hit damages only its contacted object")
	var before=s.score;s.damage_object(s.objects[0],s.data.fighters[0].moves.hk,"hk")
	check(s.objects[0].hp==0 and s.broken==1 and s.score>before,"Breaking a box increments the destroyed count and score")
	before=s.score;s.damage_object(s.objects[0],s.data.fighters[0].moves.hk,"hk")
	check(s.score==before and s.broken==1,"Destroyed objects cannot award points twice")
	s=setup();var top=s.objects[-1];var initial_y=top.y
	for o in s.objects:
		if o.y==Bonus.FLOOR: o.hp=0
	for i in 55: s.update_objects()
	check(top.y>initial_y,"Unsupported box stacks fall after their supports break")
	s=setup();s.fighters[0].x=401;frames(s,4,{"dx":1})
	check(s.fighters[0].x<=401,"Grounded fighters cannot walk through stacked boxes")
	s=setup();s.time_left=1;s.step([{},{}])
	check(s.phase=="results" and not s.success and s.reward_code=="","A box timeout ends cleanly without a secret code")
	# Complete both challenges using only movement/button controls, never teleports.
	for kind in 14:
		s=setup(kind)
		for frame in 1800:
			if s.phase=="results": break
			var target={};var nearest=INF
			for o in s.objects:
				if o.hp>0 and o.x<nearest: target=o;nearest=o.x
			if target.is_empty(): break
			s.step([Player.control(s,target),{}])
		check(s.success and s.phase=="results" and s.broken==10,"All boxes can be destroyed within the timer: fighter "+str(kind))
	s=setup(0,"kegs")
	check(s.object_frames.size()==4 and s.objects.is_empty(),"Brewers Hill starts empty and loads four keg damage states")
	frames(s,20)
	check(s.spawned==1 and s.objects[0].y<Bonus.FLOOR and s.objects[0].vx>0,"First keg drops in from the left")
	frames(s,Bonus.KEG_SPAWN_INTERVAL)
	check(s.spawned==2 and s.objects[1].vx<0,"Next keg enters from the opposite side")
	check(s.objects[0].bounced,"Kegs bounce once before crossing the lane")
	# Attack the moving kegs through normal command/move windows; no direct damage.
	for kind in 14:
		s=setup(kind,"kegs")
		for frame in 1800:
			if s.phase=="results": break
			var target={};var nearest=INF
			for o in s.objects:
				if o.hp>0 and absf(o.x-s.fighters[0].x)<nearest: target=o;nearest=absf(o.x-s.fighters[0].x)
			s.step([Player.control(s,target),{}])
		check(s.success and s.broken==12,"All twelve kegs can be broken through real attacks: fighter "+str(kind)+" broken="+str(s.broken)+" missed="+str(s.missed))
	s=setup(0,"kegs");s.fighters[0].x=640
	for frame in 1800:
		if s.phase=="results": break
		s.step([{},{}])
	check(not s.success and s.missed>0 and s.spawned==12,"Missed kegs fail the objective rather than granting a false clear")
	s=setup(0,"kegs");s.objects=[s.make_object(640,Bonus.FLOOR,0)];s.spawned=1
	s.fighters[0].x=640;s.fighters[0].y=Bonus.FLOOR-220
	s.step([{},{}])
	check(s.fighters[0].health==1000,"Jumping above a keg avoids contact damage")
	print("BREAKABLES RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
