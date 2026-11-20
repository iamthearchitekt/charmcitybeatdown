extends RefCounted

const MAX_HEALTH=preload("res://scripts/combat.gd").MAX_HEALTH
const RAIL_WIDTH=242
const PIXEL=2
var atlas:Texture2D
var tiles:Dictionary={}

func prepare():
	if atlas!=null: return
	var image=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/fight-hud.png"))!=OK: return
	atlas=ImageTexture.create_from_image(image)
	var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://data/fight-hud.json"))
	for key in metadata:
		var rect=metadata[key]
		tiles[key]=Rect2(rect[0],rect[1],rect[2],rect[3])

static func fill_rect(health:float,right:bool)->Rect2:
	var width=roundf(RAIL_WIDTH*clampf(health/MAX_HEALTH,0.0,1.0))
	return Rect2(354.0 if right else 286.0-width,29.0,width,12.0)

func tile(canvas:Node2D,key:String,x:float,y:float,align:int=0,tint:Color=Color.WHITE):
	var source:Rect2=tiles[key]
	canvas.draw_texture_rect_region(atlas,scaled(Rect2(Vector2(roundf(x-source.size.x*align*.5),y),source.size)),source,tint)

func print_small(canvas:Node2D,label:String,x:float,y:float,align:int=0):
	var advance=8
	var left=roundf(x-label.length()*advance*align*.5)
	for i in label.length():
		var key="small-"+label[i]
		if tiles.has(key): tile(canvas,key,left+i*advance+advance*.5,y,1)

func draw(canvas:Node2D,sim,mode:int,points:Array,round_label:String):
	prepare()
	if atlas==null: return
	tile(canvas,"base",0,0)
	for i in 2:
		var right=i==1
		var fighter:Dictionary=sim.fighters[i]
		var fill=fill_rect(fighter.health,right)
		if fill.has_area():
			var source:Rect2=tiles.life
			source.size.x=fill.size.x
			canvas.draw_texture_rect_region(atlas,scaled(fill),source)
			if fill.size.x<RAIL_WIDTH:
				var leading=fill.end.x-1 if right else fill.position.x
				canvas.draw_rect(scaled(Rect2(leading,29,1,11)),Color("fff1b5"))
		tile(canvas,"name-%d" % fighter.kind,594 if right else 45,47,2 if right else 0)
		var role="1P" if not right else ["CPU","2P","TRAINING","2P"][mode]
		tile(canvas,role,594 if right else 45,14,2 if right else 0)
		var score_edge=594-tiles[role].size.x-5 if right else 69
		print_small(canvas,str(points[i]).pad_zeros(7),score_edge,14,2 if right else 0)
		for index in 2:
			draw_win(canvas,281-11*index,right,sim.wins[i]>index)
	var time="--" if sim.training else str(clampi(ceili(sim.time_left/60.0),0,99)).pad_zeros(2)
	tile(canvas,"timer-"+time,320,24,1)
	print_small(canvas,round_label,320,53,1)

func scaled(rect:Rect2)->Rect2:
	return Rect2(rect.position*PIXEL,rect.size*PIXEL)

func draw_win(canvas:Node2D,x:float,right:bool,earned:bool):
	var edge=PackedVector2Array([Vector2(x-3,50),Vector2(x+4,50),Vector2(x+1,57),Vector2(x-6,57)])
	var center=PackedVector2Array([Vector2(x-2,51),Vector2(x+2,51),Vector2(x,55),Vector2(x-4,55)])
	for i in edge.size():
		if right:
			edge[i].x=639-edge[i].x
			center[i].x=639-center[i].x
		edge[i]*=PIXEL
		center[i]*=PIXEL
	canvas.draw_colored_polygon(edge,Color("09080d"))
	canvas.draw_colored_polygon(center,Color("f6cd71") if earned else Color("504343"))
