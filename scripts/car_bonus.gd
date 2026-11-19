extends "res://scripts/combat.gd"
const Car=preload("res://scripts/bonus_car.gd")
const DURATION=30*60
const BONUS_JUMP_SPEED=20.4
const BONUS_JUMP_GRAVITY=.79
const AIR_SPEED=10.2
var car=Car.new()
var score=0
var success=false
var reward_code=""
var reward_name=""
var reward_deferred=false
var reward_saved=false

func begin(kind:int):
	new_match(kind,kind,false)
	fighters[0].x=286.0
	fighters[1].x=1800.0
	phase="intro";phase_timer=150;time_left=DURATION
	car=Car.new();score=0;success=false

func step(controls:Array):
	events.clear();tick+=1;car.step_effects()
	var f=fighters[0]
	if freeze==0: f.pose_tick+=1
	if phase=="results":
		update_fighter(f,{})
		return
	if phase=="intro":
		phase_timer-=1
		if phase_timer<=0:
			phase="fight";events.append({"type":"fight"})
		return
	# Real time continues through small impact pauses; pause is owned by main.gd.
	time_left=maxi(0,time_left-1)
	var control:Dictionary=controls[0].duplicate()
	control.back=false # Both directions WALK in this non-defensive challenge.
	if control.get("command","")!="":
		f.queued=control.command;f.buffer=7
	if freeze>0:
		freeze-=1
	else:
		if f.move=="": f.facing=1 if f.x<640 else -1
		var previous_x=float(f.x)
		if f.y<FLOOR-1 and control.get("dx",0)!=0: f.vx=control.dx*AIR_SPEED
		update_fighter(f,control)
		for event in events:
			if event.type=="jump":
				f.vy=-BONUS_JUMP_SPEED+BONUS_JUMP_GRAVITY;f.y=FLOOR-BONUS_JUMP_SPEED
				f.air_gravity=BONUS_JUMP_GRAVITY
				f.vx=control.get("dx",0)*AIR_SPEED
		# This stage's wider leap clears the car; normal combat movement is unchanged.
		if f.y<FLOOR-1 and control.get("dx",0)!=0:
			f.x+=control.dx*AIR_SPEED-f.vx
			f.vx=control.dx*AIR_SPEED
		resolve_car_obstacle(f,previous_x)
		if is_active(f) and not f.hit:
			var m=move_data(f)
			if m.level!="throw":
				var zone=-1
				var impact=Vector2.ZERO
				for part in attackboxes(f,m):
					zone=car.target(-1 if f.x<640 else 1,part,f.move)
					if zone>=0:
						impact=part.intersection(car.hitbox(zone)).get_center()
						break
				if zone>=0:
					f.hit=true;f.connected=true
					var broken=car.damage(zone,int(m.damage),impact)
					score+=100+(1000 if broken else 0)
					freeze=mini(3,int(m.hitstop))
					events.append({"type":"hit","move":f.move,"fighter":f.kind,"owner":0,"x":impact.x,"y":impact.y,"heavy":m.damage>=100,"combo":0})
					events.append({"type":"car_hit","zone":zone,"broken":broken,"final":car.destroyed()})
	if car.destroyed(): finish(true)
	elif time_left<=0: finish(false)

func resolve_car_obstacle(f:Dictionary,previous_x:float):
	if car.destroyed(): return
	# Jumping feet must clear the roof. No walking through or landing inside the car.
	# The narrow windshield/roof is higher than the outer fenders, allowing a
	# natural arc instead of requiring an exaggerated leap over a tall rectangle.
	var roof=FLOOR-(222.0 if f.x>498 and f.x<782 else 141.0)
	if f.y<=roof: return
	var left=Car.BODY.position.x-34.0
	var right=Car.BODY.end.x+34.0
	if f.x>left and f.x<right:
		if previous_x<=left: f.x=left
		elif previous_x>=right: f.x=right
		else: f.x=left if f.x<640 else right

func finish(won:bool):
	if phase=="results": return
	success=won;phase="results";winner=0 if won else -1
	if won: score+=30000+ceili(time_left/60.0)*100
	fighters[0].queued="";fighters[0].buffer=0
	events.append({"type":"bonus_complete","success":won})
