extends RefCounted
## Shared atlas and hand-selected ramps for the roster's action sprites.
const ROSTER=["blue","orange","teal","lilac","leaf","rose","ember","gold","red","indigo","gold","violet","orange","violet"]
const RAMPS={
	"blue":[Color("142b84"),Color("218ef4"),Color("67dfff")],
	"orange":[Color("792612"),Color("fb741d"),Color("ffb443")],
	"teal":[Color("113c58"),Color("139699"),Color("6be9cf")],
	"lilac":[Color("54288d"),Color("9e52eb"),Color("d993ff")],
	"leaf":[Color("264f16"),Color("60ad26"),Color("c2ee5b")],
	"rose":[Color("8c3457"),Color("eb5894"),Color("ff8cc4")],
	"ember":[Color("781d0c"),Color("f45120"),Color("ffc34b")],
	"red":[Color("791e2b"),Color("e9364a"),Color("ff806b")],
	"indigo":[Color("262366"),Color("5553ce"),Color("aa90ff")],
	"gold":[Color("884716"),Color("eea525"),Color("ffd554")],
	"violet":[Color("431376"),Color("9842f1"),Color("cf85ff")],
}
static var atlas:Image
static var layout:Dictionary
static var cache:Dictionary={}

static func palette_for(kind:int)->String:
	return ROSTER[kind] if kind>=0 and kind<ROSTER.size() else "blue"

static func frame(row:String,index:int,palette:String)->Texture2D:
	var key="%s/%d/%s" % [row,index,palette]
	if cache.has(key): return cache[key]
	if atlas==null:
		atlas=Image.new()
		var loaded=atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/action-fx.png"))
		assert(loaded==OK,"Unable to load action effect sprites")
		layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/action-fx.json"))
	var region:Array=layout.regions[row]
	var pixels=atlas.get_region(Rect2i(index*int(layout.cell),int(region[0]),int(region[1]),int(region[2])))
	var texture=ImageTexture.create_from_image(colorize(pixels,palette))
	cache[key]=texture
	return texture

static func colorize(pixels:Image,palette:String,core_threshold:float=.96)->Image:
	var ramp:Array=RAMPS[palette]
	for y in pixels.get_height():
		for x in pixels.get_width():
			var source=pixels.get_pixel(x,y)
			if source.a==0: continue
			var brightness=source.get_luminance()
			var color:Color=ramp[0].lerp(ramp[1],smoothstep(.12,.66,brightness))
			color=color.lerp(ramp[2],smoothstep(.66,core_threshold,brightness))
			if brightness>=core_threshold: color=Color.WHITE
			color.a=source.a
			pixels.set_pixel(x,y,color)
	return pixels
