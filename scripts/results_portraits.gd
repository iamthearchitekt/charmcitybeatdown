extends RefCounted
# Shared victory and defeat art. Roster tiles and HUD use separate portraits.
var entries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/results-portraits.json"))
var sheets:Dictionary={}
var frames:Dictionary={}
const QUOTES=[
	"HARBOR RULES. STAND YOUR GROUND.",
	"CUTE SMILE. MEAN RIGHT HOOK.",
	"KEEP YOUR GUARD UP.",
	"BETTER LUCK NEXT ROUND.",
	"YOU BLINKED. I DIDN'T.",
	"FAST FEET. HEAVY CONSEQUENCES.",
	"SOME LIKE IT HOT.",
	"FULL THROTTLE. NO BRAKES.",
	"THAT'S HOW YOU FINISH A RACE.",
	"CONSIDER THIS YOUR FINAL WARNING.",
	"YOU NEVER SAW THAT COMING.",
	"THE FINAL CHAPTER IS MINE.",
	"THIS IS BIRDLAND.",
	"TOO QUICK FOR YOU."
]

func portrait_frame(art,kind:int,victory:bool)->Texture2D:
	var key=kind*2+(0 if victory else 1)
	if frames.has(key): return frames[key]
	var entry:Dictionary=entries[str(kind)]
	if not sheets.has(entry.path): sheets[entry.path]=art.raw_texture(entry.path)
	var bounds:Array=entry.victory if victory else entry.defeat
	var source=Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	var units=246.0/maxf(source.size.x,source.size.y)
	# The shared fine pixel/dither pipeline keeps enlarged faces in the game style.
	var texture:Texture2D=art.pixel_texture(sheets[entry.path],source,source.size*units,true)
	frames[key]=texture
	return texture

func draw(canvas:Node2D,art,kind:int,victory:bool,bounds:Rect2,flipped:bool=false):
	var texture=portrait_frame(art,kind,victory)
	var size=Vector2(texture.get_size())
	size*=minf(bounds.size.x/size.x,bounds.size.y/size.y)
	var rect=Rect2(Vector2(roundf(bounds.get_center().x-size.x*.5),roundf(bounds.end.y-size.y)),size.round())
	# Jeff is almost frontal; retain readable BSE embroidery on either side.
	if flipped and kind!=10:
		canvas.draw_set_transform(Vector2(rect.end.x,rect.position.y),0,Vector2(-1,1))
		canvas.draw_texture_rect(texture,Rect2(Vector2.ZERO,rect.size),false)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect(texture,rect,false)

func quote(kind:int)->String:
	return QUOTES[kind]
