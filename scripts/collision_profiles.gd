extends RefCounted
## Prebaked sprite-local regions; no image loading or GPU work in simulation.
const Pose=preload("res://scripts/combat_pose.gd")
static var profiles:Dictionary={}
var local_cache:Dictionary={}

func _init():
	if profiles.is_empty():
		profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/collision-profiles.json")).fighters

func pose(f:Dictionary,m:Dictionary)->Dictionary:
	return profiles[str(f.kind)][Pose.key(f,m)]

func local_parts(f:Dictionary,m:Dictionary,attack:bool)->Array:
	var key=str(f.kind)+"/"+Pose.key(f,m)+("/"+f.move if attack else "/hurt")
	if local_cache.has(key): return local_cache[key]
	var profile=pose(f,m)
	var raw=profile.attacks.get(m.get("pose_move",f.move),[]) if attack else profile.hurt
	var parts:Array=[]
	for r in raw: parts.append(Rect2(r[0],r[1],r[2],r[3]))
	local_cache[key]=parts
	return parts

func world_parts(f:Dictionary,m:Dictionary,scale:float,attack:bool=false)->Array:
	var parts:Array=[]
	var origin=Vector2(f.x+(-4*f.facing if f.state=="hit" else 0),f.y)
	var transform=Transform2D(0,Vector2(f.facing*scale,scale),0,origin)
	var tossed=(f.get("throw_flight",false) or f.get("grabbed_by",-1)>=0) and f.get("grapple_role","")==""
	var offset=Vector2.ZERO
	if tossed:
		var profile=pose(f,m)
		origin.y-=float(profile.size[1])*.5*scale
		transform=Transform2D(float(f.get("throw_rotation",0.0)),Vector2(f.facing*scale,scale),0,origin)
		offset=Vector2(float(profile.anchor)-float(profile.size[0])*.5,float(profile.size[1])*.5-float(profile.ground_gap))
	for r in local_parts(f,m,attack):
		var shifted:Rect2=Rect2(r.position+offset,r.size)
		parts.append(transform*shifted)
	return parts

static func overlap(a:Array,b:Array)->Rect2:
	for left in a:
		for right in b:
			if left.intersects(right): return left.intersection(right)
	return Rect2()

static func bounds(parts:Array)->Rect2:
	if parts.is_empty(): return Rect2()
	var box:Rect2=parts[0]
	for i in range(1,parts.size()): box=box.merge(parts[i])
	return box
