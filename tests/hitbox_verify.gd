extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Pose=preload("res://scripts/combat_pose.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func same(a:Rect2,b:Rect2)->bool:
	return a.position.distance_to(b.position)<.01 and a.size.distance_to(b.size)<.01
func run():
	var s=Combat.new()
	var pose_count=0
	for kind in s.data.fighters.size():
		var profiles=s.collision.profiles[str(kind)]
		pose_count+=profiles.size()
		var contained=true
		for profile in profiles.values():
			var source=Rect2(-profile.anchor,-profile.size[1]+profile.ground_gap,profile.size[0],profile.size[1])
			for r in profile.hurt:
				contained=contained and source.grow(.01).encloses(Rect2(r[0],r[1],r[2],r[3]))
		check(contained,"All body parts stay inside rendered pose bounds: "+str(kind))
		var f=s.make_fighter(kind,0)
		var stand=s.hurtbox(f)
		f.crouch=true
		check(s.hurtbox(f).size.y<stand.size.y*.85,"Crouch follows shorter pose: "+str(kind))
		var active=true;var mirror=true;var timing=true
		for name in s.data.fighters[kind].moves:
			f=s.make_fighter(kind,0);s.start_move(f,name)
			if name.begins_with("c_"): f.crouch=true
			if name.begins_with("air_"): f.y=450.0
			var m=s.move_data(f)
			timing=timing and s.attackboxes(f,m).is_empty()
			for frame in range(int(m.startup),int(m.startup+m.active)):
				f.frame=frame
				var right=s.attackboxes(f,m)
				active=active and (not right.is_empty() or m.get("projectile",false))
				f.facing=-1
				var left=s.attackboxes(f,m)
				mirror=mirror and right.size()==left.size()
				for j in right.size():
					var r:Rect2=right[j]
					mirror=mirror and same(left[j],Rect2(f.x*2-r.end.x,r.position.y,r.size.x,r.size.y))
				f.facing=1
			f.frame=int(m.startup+m.active)
			timing=timing and s.attackboxes(f,m).is_empty()
		check(active,"Every active melee frame has limb/grab regions: "+str(kind))
		check(mirror,"Both facings mirror every active region exactly: "+str(kind))
		check(timing,"No strike contact during startup or recovery: "+str(kind))
		f=s.make_fighter(kind,0);f.walk=1;f.walk_phase=0
		var first=s.hurtboxes(f);f.walk_phase=1
		check(Pose.key(f,{})=="movement:1" and first!=s.hurtboxes(f),"Walking updates collision on actual stride frame: "+str(kind))
		var connects=true
		for name in ["lp","mp","hp","lk","mk","hk","c_lp","c_mp","c_lk","c_mk"]:
			s.new_match(kind,(kind+1)%14);s.phase="fight"
			s.fighters[0].x=500;s.fighters[1].x=605
			var low=name.begins_with("c_")
			s.step([{"command":name.trim_prefix("c_"),"down":low},{}])
			for frame in 42: s.step([{"down":low},{}])
			connects=connects and s.fighters[1].health<1000
		check(connects,"Standing normals and crouching medium attacks connect at close range: "+str(kind))
	var styles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/style-poses.json"))
	var style_coverage=true
	for key in styles:
		style_coverage=style_coverage and s.collision.profiles[str(int(styles[key].kind))].has("style:"+key)
	check(pose_count==471+styles.size() and style_coverage,"All original poses and every added style pose have collision profiles")
	var alex=s.make_fighter(2,0);var jeff=s.make_fighter(10,0)
	check(s.hurtbox(jeff).size.y>s.hurtbox(alex).size.y*1.1,"Tall Jeff and mid-sized Alex have different body geometry")
	var f=s.make_fighter(0,0)
	var parts=s.hurtboxes(f);var bounds=s.hurtbox(f);var gap=Rect2()
	for y in range(int(bounds.position.y+30),int(bounds.end.y-5),3):
		for x in range(int(bounds.position.x+3),int(bounds.end.x-3),3):
			var candidate=Rect2(x,y,2,2)
			if not s.regions_overlap([candidate],parts).has_area(): gap=candidate;break
		if gap.has_area(): break
	check(gap.has_area() and bounds.intersects(gap) and not s.touches_body(gap,f),"Empty space inside the old rectangular body cannot be hit")
	f.crouch=true
	check(not s.touches_body(Rect2(f.x-10,f.y-275,20,20),f),"A shot above a crouched head whiffs")
	f.crouch=false;f.y-=150
	check(not s.touches_body(Rect2(f.x-10,600,20,20),f),"Ground attacks cannot hit empty space below an airborne fighter")
	f.state="down";check(s.hurtboxes(f).is_empty(),"Existing grounded knockdown invulnerability preserved")
	f.state="getup";check(s.hurtboxes(f).is_empty(),"Existing get-up invulnerability preserved")
	f.state="idle";f.wake_safe=4;check(s.hurtboxes(f).is_empty(),"Existing wake safety preserved")
	f.wake_safe=0;f.grabbed_by=1;check(s.hurtboxes(f).is_empty(),"Held target cannot receive a second contact")
	f.grabbed_by=-1;f.throw_flight=true;f.throw_rotation=.9
	check(s.hurtboxes(f).size()>4 and s.hurtbox(f).get_center().distance_to(Vector2(f.x,f.y-125))<200,"Thrown body's parts follow rendered rotation")
	for kind in [1,2,5]:
		for name in s.data.fighters[kind].moves:
			var m=s.data.fighters[kind].moves[name]
			if not m.has("animation"): continue
			f=s.make_fighter(kind,0);s.start_move(f,name)
			var keys={};var shapes={}
			for frame in range(int(m.startup),int(m.startup+m.active)):
				f.frame=frame;keys[Pose.key(f,m)]=true;shapes[str(s.attackboxes(f,m))]=true
			check(keys.size()>1 and shapes.size()>1,"Signature limb regions change with rotation/flurry frames: "+m.animation)
	s.new_match(0,1);s.phase="fight";s.fighters[0].x=500;s.fighters[1].x=591
	s.start_move(s.fighters[0],"lp");s.fighters[0].frame=4;s.freeze=3
	var key=Pose.key(s.fighters[0],s.move_data(s.fighters[0]));var age=s.fighters[1].pose_tick
	s.step([{},{}])
	check(key==Pose.key(s.fighters[0],s.move_data(s.fighters[0])) and age==s.fighters[1].pose_tick,"Hitstop freezes both collision pose and neutral animation")
	var bonus=load("res://scripts/breakables_bonus.gd").new()
	bonus.begin_challenge(0,"kegs");f=bonus.fighters[0]
	bonus.start_move(f,"hp");f.frame=bonus.move_data(f).startup
	var fist=bonus.attackbox(f,bonus.move_data(f))
	check(not bonus.hazard_touches(Rect2(fist.end.x-8,fist.position.y,8,8),f),"A glove contacting a prop does not count as a body collision")
	check(bonus.hazard_touches(Rect2(f.x-10,f.y-90,20,20),f),"Keg contact with the visible body still hurts")
	print("HITBOX RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
