extends RefCounted
var entries:Dictionary
var textures:Dictionary={}
var cache:Dictionary={}
func _init(): entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/grapple-atlases.json"))
func sprite(kind:int,frame:int,art)->Dictionary:
	var key=kind*6+frame
	if cache.has(key): return cache[key]
	var e=entries[str(kind)]
	if not textures.has(e.path): textures[e.path]=art.raw_texture(e.path)
	var r=e.regions[frame];var source=Rect2(r[0],r[1],r[2],r[3])
	var units=160.0/float(e.height)*art.presentation_scale(kind)
	var texture=art.pixel_texture(textures[e.path],source,source.size*units,true)
	var result={"texture":texture,"size":Vector2(texture.get_size())*art.PIXEL_UNIT,"anchor":snappedf(float(e.anchors[frame])*units,art.PIXEL_UNIT),"sheet":textures[e.path],"source":source}
	cache[key]=result
	return result
