extends RefCounted
## Authored native-resolution cuts of the fighter's own approved sprite art.
const ActionFX=preload("res://scripts/action_fx.gd")
const PIXEL=.9
const TRAILS={
	"palms":["streak",Rect2(43,-146,48,20)],
	"rush":["streak",Rect2(-86,-70,64,25)],
	"lariat":["sweep",Rect2(-38,-130,132,42)],
	"bicycle":["rise",Rect2(24,-138,65,75)],
	"spin":["sweep",Rect2(-64,-81,150,44)],
	"flash_kick":["rise",Rect2(0,-161,97,119)],
	"knee":["rise",Rect2(32,-113,50,70)],
}
var entries:Dictionary={}
var by_fighter:Dictionary={}
var sprites:Dictionary={}
var atlas:Image

func _init():
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/style-poses.json"))
	for key in entries:
		var kind=int(entries[key].kind)
		if not by_fighter.has(kind): by_fighter[kind]=[]
		by_fighter[kind].append(key)

func keys_for(kind:int)->Array:
	return by_fighter.get(kind,[])

func sprite(key:String)->Dictionary:
	if sprites.has(key): return sprites[key]
	if atlas==null:
		atlas=Image.new()
		atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/style-poses.png"))
	var item:Dictionary=entries[key]
	var r:Array=item.region
	var source=Rect2i(r[0],r[1],r[2],r[3])
	var texture=ImageTexture.create_from_image(atlas.get_region(source))
	var result={"texture":texture,"size":Vector2(source.size)*PIXEL,"anchor":float(item.anchor)}
	sprites[key]=result
	return result

func draw_trail(canvas:Node2D,f:Dictionary,move:Dictionary):
	var style:String=move.get("style_fx","")
	if not TRAILS.has(style) or f.frame<move.startup or f.frame>=move.startup+move.active: return
	var age=int(f.frame-move.startup)
	var trail:Array=TRAILS[style]
	var destination:Rect2=trail[1]
	var phase=mini(3,int(4.0*age/move.active))
	if style=="palms":
		destination.position.y+=[0,13,5,17][mini(3,int(age/6))]
		phase=[0,1,1,2,3,3][age%6]
	var texture=ActionFX.frame(trail[0],phase,ActionFX.palette_for(f.kind))
	canvas.draw_texture_rect(texture,destination,false,Color(1,1,1,.76))
