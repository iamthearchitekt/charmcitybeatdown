extends RefCounted
const CombatPose=preload("res://scripts/combat_pose.gd")
## Shared fine pixel/dither treatment, with distinct stride/passing and charge/release art.
var entries:Dictionary
var textures:Dictionary={}
var cache:Dictionary={}
func _init():
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/movement-atlases.json"))
func frame_index(f:Dictionary,kit:Dictionary)->int:
	return CombatPose.movement(f,kit)

func sprite(kind:int,frame:int,art)->Dictionary:
	var key=kind*4+frame
	if cache.has(key): return cache[key]
	var entry=entries[str(kind)]
	if not textures.has(entry.path): textures[entry.path]=art.raw_texture(entry.path)
	var r=entry.regions[frame]
	var source=Rect2(r[0],r[1],r[2],r[3])
	var units=160.0/entry.height*art.presentation_scale(kind)
	# Stride and passing heads stay at the same height. Cast stances keep their crouch.
	if frame<2 and not entry.get("uniform_scale",false): units=160.0/source.size.y*art.presentation_scale(kind)
	var texture=art.fighter_texture(textures[entry.path],source,source.size*units,kind,"movement:"+str(frame))
	var result={"texture":texture,"size":Vector2(texture.get_size())*art.PIXEL_UNIT,"anchor":snappedf(entry.anchors[frame]*units,art.PIXEL_UNIT),"source":source,"sheet":textures[entry.path]}
	cache[key]=result
	return result
