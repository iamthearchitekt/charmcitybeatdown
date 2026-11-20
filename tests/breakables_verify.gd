extends SceneTree
const Bonus=preload("res://scripts/breakables_bonus.gd")
const Player=preload("res://tests/bonus_controls.gd")
const Combat=preload("res://scripts/combat.gd")
const Props=preload("res://scripts/stage_props.gd")
const Stage=preload("res://scripts/harbor_stage.gd")
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
	check(s.objects.slice(4).all(func(o):return is_equal_approx(s.crate_support_y(o),o.y)),"Every upper crate starts in contact with a lid")
	check(s.object_frames.size()==4 and s.object_frames.all(func(f):return f.texture.get_image().get_used_rect().has_area()),"Box sprites have four nonempty damage states")
	var bonus_crate=s.object_box(s.objects[0])
	check(bonus_crate.size.y>=137.0 and bonus_crate.size.distance_to(s.object_frames[0].size)<2.0,"The larger bonus crate uses its visible size for hit detection")
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
	check(s.time_left==42*60 and Bonus.KEG_SPAWN_INTERVAL>=160,"Keg bonus leaves time for the slower drop cadence")
	frames(s,20)
	check(s.spawned==1 and s.objects[0].y<Bonus.FLOOR and s.objects[0].vx>0,"First keg drops in from the left")
	var survivor=s.objects[0]
	var first_peak=Bonus.FLOOR
	for frame in Bonus.KEG_SPAWN_INTERVAL:
		s.step([{},{}])
		if survivor.bounces==1: first_peak=minf(first_peak,survivor.y)
	check(s.spawned==2 and s.objects[1].vx<0,"Next keg enters from the opposite side")
	check(survivor.bounces==3 and first_peak<Bonus.FLOOR-80.0 and absf(survivor.vx)<3.0,"Kegs travel slowly and make three readable bounces")
	s.damage_object(survivor,s.data.fighters[0].moves.hp,"hp")
	check(survivor.hp==0,"A clean heavy punch breaks an intact keg")
	s=setup(0,"kegs")
	var kicked=false
	for frame in 145:
		var control={}
		if not s.objects.is_empty() and s.objects[0].bounces>0:
			control=Player.control(s,s.objects[0])
		s.step([control,{}])
		if s.broken==1:
			kicked=s.fighters[0].move in ["hk","c_hk","air_hk"] and s.objects[0].bounces>0
			break
	check(kicked,"A normal heavy kick can break the first keg after it bounces")
	s=setup(0,"kegs")
	var f=s.fighters[0]
	var close_keg=s.make_object(f.x+65,Bonus.FLOOR,0)
	s.objects=[close_keg];s.spawned=1
	s.step([{},{}])
	check(f.stun==Bonus.KEG_STUN_TICKS and f.health==960,"A body collision with a keg causes a brief stumble")
	s.step([{"command":"hk"},{}])
	frames(s,2)
	check(f.move=="hk" and f.stun==0,"A kick tap starts the recovery kick within three ticks of input")
	frames(s,30)
	check(close_keg.hp==0 and f.health==960,"A recovery kick can break the same keg that hit the fighter")
	s=setup(0,"kegs")
	s.spawned=12
	s.objects=[s.make_object(s.fighters[0].x,Bonus.FLOOR,0)]
	frames(s,90)
	check(s.fighters[0].health==960 and s.fighters[0].stun==0,"An overlapping keg can damage and stun the player only once")
	# Attack the moving kegs through normal command/move windows; no direct damage.
	for kind in 14:
		s=setup(kind,"kegs")
		for frame in Bonus.KEG_DURATION:
			if s.phase=="results": break
			var target={};var nearest=INF
			for o in s.objects:
				if o.hp>0 and absf(o.x-s.fighters[0].x)<nearest: target=o;nearest=absf(o.x-s.fighters[0].x)
			s.step([Player.control(s,target),{}])
		check(s.success and s.broken==12,"All twelve kegs can be broken through real attacks: fighter "+str(kind)+" broken="+str(s.broken)+" missed="+str(s.missed))
	s=setup(0,"kegs");s.fighters[0].x=640
	for frame in Bonus.KEG_DURATION:
		if s.phase=="results": break
		s.step([{},{}])
	check(not s.success and s.missed>0 and s.spawned==12,"Missed kegs fail the objective rather than granting a false clear")
	s=setup(0,"kegs");s.objects=[s.make_object(640,Bonus.FLOOR,0)];s.spawned=1
	s.fighters[0].x=640;s.fighters[0].y=Bonus.FLOOR-220
	s.step([{},{}])
	check(s.fighters[0].health==1000,"Jumping above a keg avoids contact damage")
	var fight=Combat.new();fight.new_match(0,2);fight.phase="fight"
	var props=Props.new();props.reset(2)
	var can=props.objects[0]
	var fighter=fight.fighters[0]
	fighter.x=can.x-70
	var motion=props.capture_pushback(fight)
	fighter.x+=5
	check(props.step(fight,motion).is_empty() and can.hp==180,"Walking into a stage prop does not smash it")
	fighter.y=Combat.FLOOR-270;fighter.state="knockdown";fighter.vx=8.5
	motion=props.capture_pushback(fight);fighter.x+=8.5
	check(props.step(fight,motion).is_empty() and can.hp==180,"Knockback above a prop does not make contact")
	fighter.y=Combat.FLOOR-50
	motion=props.capture_pushback(fight);fighter.x+=8.5
	var impacts=props.step(fight,motion)
	check(impacts.size()==1 and impacts[0].broken and can.hp==0 and can.wreck>0,"A knockback collision breaks a prop in one impact")
	check(props.step(fight,motion).is_empty(),"A destroyed prop cannot break again")
	props.reset(1)
	var drum_bounds=props.box(props.objects[1])
	var crate_bounds=props.box(props.objects[0])
	check(crate_bounds.size.y>=165.0 and not crate_bounds.intersects(drum_bounds),"Dundalk's larger foreground crate stands clear of the drum")
	var atlas=Props.props_atlas.get_image()
	var heights:Array=[]
	for frame in 4:
		var bounds=atlas.get_region(Rect2i(Vector2i(frame,Props.DRUM)*Vector2i(Props.CELL),Vector2i(Props.CELL))).get_used_rect()
		heights.append(bounds.size.y)
		check(bounds.has_area() and bounds.end.y==int(Props.CELL.y)-1,"Painted drum damage frame shares the pavement baseline: "+str(frame))
	check(heights[0]==heights[1] and heights[2]<heights[1] and heights[3]<heights[2],"Drum dents first, buckles, then collapses into scrap")
	for stage_id in Props.SETS:
		props.reset(stage_id)
		check(props.objects.all(func(prop): return prop.x<=265.0 or prop.x>=1015.0),"Stage prop centers leave the fighting lane open: "+str(stage_id))
		var mirrored=props.objects.all(func(prop): return props.objects.any(func(peer): return peer.kind==prop.kind and is_equal_approx(peer.x,1280.0-prop.x)))
		check(not mirrored,"Stage breakables use a lopsided placement: "+str(stage_id))
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.arcade.begin(0,game.sim.data.fighters)
	game.arcade.cursor=game.arcade.opponents.find(2)
	game.begin_match()
	check(game.stage.current_index()==Stage.WAREHOUSE and game.sim.data.fighters[game.sim.fighters[1].kind].id=="alex","Arcade sends Alex’s fight to the Warehouse")
	var boxes:Array=game.stage_props.objects
	check(boxes.size()==2 and boxes.all(func(prop):return prop.kind==Props.BOX and prop.hp==180) and Props.props_atlas!=null,"Warehouse spawns two intact foreground box sprites")
	game.sim.phase="fight"
	var inner_box:Dictionary=boxes[1]
	game.sim.fighters[0].x=inner_box.x+220.0
	game.sim.fighters[1].x=Combat.LEFT
	game.selected_mode=1
	for i in 5:
		game.step_match({"command":"lk","down":true},{})
		for frame in 40: game.step_match({"down":true},{})
		if inner_box.hp==0: break
	check(inner_box.hp==0 and boxes[0].hp==180,"An ordinary crouching kick breaks the contacted Warehouse box independently")
	game.begin_match(true)
	check(game.stage_props.objects.size()==2 and game.stage_props.objects.all(func(prop):return prop.hp==180),"A fresh Warehouse match restores both boxes")
	game.queue_free()
	await process_frame
	print("BREAKABLES RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
