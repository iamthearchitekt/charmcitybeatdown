extends RefCounted
## Authored native-resolution cuts of the fighter's own approved sprite art.
const PIXEL=.9
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
	if not move.has("style_fx") or f.frame<move.startup or f.frame>=move.startup+move.active: return
	var phase=int(f.frame-move.startup)
	match move.style_fx:
		"palms":
			for i in 3:
				var x=53.0+(phase+i*5)%13
				var y=-140.0+i*20.0+(phase+i)%4
				canvas.draw_rect(Rect2(x,y,25-i*3,1.8),Color("c0acaa"))
		"rush":
			for i in 6:
				var x=-65.0+((phase*3+i*11)%31)
				canvas.draw_rect(Rect2(x,-14.0-i*12.0,12.0+i*2.0,1.8),Color("a38b76"))
		"lariat":
			sweep(canvas,Vector2(4,-105),Vector2(94,19),.05+phase*.24,Color("e6cfab"))
		"bicycle":
			sweep(canvas,Vector2(39,-82),Vector2(48,35),-1.1+phase*.24,Color("ffc69a"))
		"spin":
			sweep(canvas,Vector2(5,-55),Vector2(102,25),.2+phase*.21,Color("d0a9f0"))
		"flash_kick":
			sweep(canvas,Vector2(9,-73),Vector2(90,98),-.15-phase*.14,Color("e6c5ff"))
		"knee":
			sweep(canvas,Vector2(26,-62),Vector2(47,59),-.7-phase*.11,Color("ffc589"))

func sweep(canvas:Node2D,center:Vector2,radii:Vector2,angle:float,color:Color):
	for i in 20:
		var t=angle-float(i)*.055
		var point=(center+Vector2(cos(t),sin(t))*radii).snapped(Vector2(PIXEL,PIXEL))
		var size=3.6 if i<9 else 1.8
		canvas.draw_rect(Rect2(point-Vector2(1.8,1.8),Vector2(size+1.8,size+1.8)),color.darkened(.70))
		canvas.draw_rect(Rect2(point,Vector2(size,size)),color.lightened(.10 if i<5 else 0.0))
