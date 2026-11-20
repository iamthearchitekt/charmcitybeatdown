extends RefCounted
## Data-only pose selection shared by drawing and collision. Gameplay ticks stop in hitstop.
const MARCUS_ATTACKER_GRAPPLES={0:"throw:0",1:"throw:1",2:"throw:2",5:"throw:1"}
const LAMAR_WALK_FRAMES=[0,1,4,5,6,7]

static func grapple_key(kind:int,frame:int)->String:
	var key="grapple:"+str(frame)
	return MARCUS_ATTACKER_GRAPPLES.get(frame,key) if kind==0 else key

static func impact_shear(f:Dictionary)->float:
	return float(f.get("impact_recoil",0.0)) if f.state=="hit" else 0.0

static func base(f:Dictionary,m:Dictionary,t:float)->int:
	if f.state=="ko": return 13 if f.y<622.0 or f.vy<0 else 15
	if f.state=="knockdown": return 13
	if f.state=="down": return 15
	if f.state=="getup": return 8 if f.down_timer>5 else 12
	if f.state=="dizzy": return 13 if int(f.dizzy_age/12)%2==0 else 0
	if f.state=="hit": return 13
	if f.state=="block" or (f.guard and f.move==""): return 8 if f.crouch else 12
	if f.move!="":
		var aerial=f.move.begins_with("air_")
		if f.frame<m.startup*.65 or f.frame>m.startup+m.active+float(m.recovery)*.60:
			return 16 if aerial else (8 if f.crouch else 2)
		match m.get("pose_move",f.move):
			"air_lp","air_hp": return 17
			"air_lk","air_hk": return 11
			"lp": return 4
			"hp","throw","special1": return 5
			"lk": return 6
			"hk": return 7
			"c_lp","c_hp": return 9
			"c_lk","c_hk": return 10
			"special2": return 14
			_: return 11
	if f.crouch: return 8
	if f.y<620: return 16
	if f.get("backstep_pose",-1)>=0: return [0,3,12][f.backstep_pose]
	if absf(f.walk)>0: return [3,0,3,2][int(t*10)%4]
	return [2,2,0,2][int(t*6)%4]

static func movement(f:Dictionary,m:Dictionary)->int:
	if f.move=="special1" and m.get("projectile",false):
		if f.frame>=m.startup+m.active+int(m.recovery*.60): return -1
		return 2 if f.frame<m.startup else 3
	if f.move=="" and f.state=="idle" and f.y>=621 and f.dash==0 and f.get("backstep_pose",-1)<0 and absf(f.walk)>0:
		var phase=float(f.get("walk_phase",0.0))
		if f.kind==13: return LAMAR_WALK_FRAMES[int(phase*2.0)%LAMAR_WALK_FRAMES.size()]
		return int(phase)%2
	return -1

static func signature(f:Dictionary,m:Dictionary)->int:
	var active_frame=maxi(0,f.frame-int(m.startup))
	var recovering=f.frame>=m.startup+m.active
	match m.get("animation",""):
		"spike-shock","chelsea-flame":
			if f.frame<m.startup: return 0
			if recovering: return 3
			return 1+int(active_frame/4)%2
		"vivian-flurry": return [0,1,2,3][int(active_frame/3)%4]
		"brook-flurry": return [0,1,2,3,4,5][int(active_frame/3)%6]
		"alex-hurricane":
			if f.frame<m.startup: return 0 if f.frame<m.startup*.5 else 1
			if recovering: return 6 if f.frame<m.startup+m.active+m.recovery*.5 else 7
			return [2,3,4,5][int(active_frame/4)%4]
		"vivian-spin":
			if f.frame<m.startup: return 4 if f.frame<m.startup*.5 else 5
			if recovering: return 10 if f.frame<m.startup+m.active+m.recovery*.5 else 11
			return [6,7,9,7][int(active_frame/4)%4]
	return -1

static func key(f:Dictionary,m:Dictionary)->String:
	# A grounded KO always uses the authored supine, arms-at-sides pose,
	# including the impact/recovery frames of a finishing grapple.
	if f.state=="ko" and f.y>=622.0 and f.vy>=0: return "base:15"
	if f.get("grapple_role","")!="":
		if f.get("grapple_pose",-1)==-2: return "base:13"
		if f.get("grapple_pose",-1)>=0: return grapple_key(f.kind,f.grapple_pose)
	if m.get("grapple",false): return grapple_key(f.kind,0)
	if f.get("grabbed_by",-1)>=0 or f.get("throw_flight",false): return "throw:3"
	if m.has("pose_sequence"):
		var sequence:Dictionary=m.pose_sequence
		var age=int(f.frame)-int(m.startup)
		if age<0: return sequence.startup
		var extension=7 if m.get("projectile",false) else 0
		if age>=int(m.active)+extension: return sequence.recovery
		return sequence.active[int(age/int(sequence.cadence))%sequence.active.size()]
	if m.has("animation"):
		var frame=signature(f,m)
		if frame>=0: return "signature:"+str(frame)
	elif f.move=="throw":
		var stage=0
		if f.get("throw_target",-1)>=0: stage=0 if f.grab_frame<5 else (1 if f.grab_frame<13 else 2)
		elif f.connected: stage=2
		return "throw:"+str(stage)
	else:
		var frame=movement(f,m)
		if frame>=0: return "movement:"+str(frame)
	return "base:"+str(base(f,m,float(f.get("pose_tick",0))/60.0))
