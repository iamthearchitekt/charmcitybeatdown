extends RefCounted
const CombatPose=preload("res://scripts/combat_pose.gd")
var entries:Dictionary={}
var sheets:Dictionary={}
var cache:Dictionary={}

func _init():
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/signature-atlases.json"))

func animation_frame(f:Dictionary,m:Dictionary)->int:
	return CombatPose.signature(f,m)

func sprite(f:Dictionary,m:Dictionary,art)->Dictionary:
	var frame=animation_frame(f,m)
	if frame<0 or not entries.has(str(f.kind)): return {}
	var key=str(f.kind)+":"+str(frame)
	if cache.has(key): return cache[key]
	var entry=entries[str(f.kind)]
	if not sheets.has(str(f.kind)): sheets[str(f.kind)]=art.raw_texture(entry.path)
	var r=entry.regions[frame]
	var source=Rect2(r[0],r[1],r[2],r[3])
	var units=160.0/float(entry.height)*art.presentation_scale(f.kind)
	var texture=art.pixel_texture(sheets[str(f.kind)],source,source.size*units,true)
	var result={"texture":texture,"size":Vector2(texture.get_size())*art.PIXEL_UNIT,
		"anchor":snappedf(float(entry.anchors[frame])*units,art.PIXEL_UNIT),"sheet":sheets[str(f.kind)],"source":source}
	cache[key]=result
	return result
