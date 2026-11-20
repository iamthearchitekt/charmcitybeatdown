extends RefCounted
## Sprite-local palette flashes and pixel effects; never alter stage lighting.
const Combat=preload("res://scripts/combat.gd")
const ActionFX=preload("res://scripts/action_fx.gd")
const PIXEL_UNIT=.9
var palettes:Dictionary={}
var flame_frames:Array=[]
var electric_frames:Array=[]
static var reaction_atlas:Texture2D
static var reaction_poses:Dictionary={}

static func active(f:Dictionary,m:Dictionary)->bool:
	return f.move!="" and m.has("element") and f.frame>=m.startup and f.frame<m.startup+m.active

static func palette(f:Dictionary,m:Dictionary)->String:
	if active(f,m) and m.element=="electric":
		var phase=int(f.frame-m.startup)%8
		return "cyan" if phase<2 else ("gold" if phase<4 else "")
	if f.get("element_timer",0)>0 and f.element_hit=="electric" and f.element_timer%6>=2: return "electric"
	return ""

func tinted(texture:Texture2D,mode:String)->Texture2D:
	if mode=="": return texture
	var key=str(texture.get_instance_id())+":"+mode
	if palettes.has(key): return palettes[key]
	var pixels=texture.get_image()
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c=pixels.get_pixel(x,y)
			if c.a<.5: continue
			var l=c.r*.299+c.g*.587+c.b*.114
			var col=Color.WHITE
			match mode:
				"cyan": col=Color(.14+.25*l,.61+.36*l,.8+.2*l)
				"gold": col=Color(1,.56+.33*l,.08+.21*l)
				"electric": col=Color(.12+.52*l,.25+.7*l,.55+.45*l)
			col.a=c.a;pixels.set_pixel(x,y,col)
	var result=ImageTexture.create_from_image(pixels)
	palettes[key]=result
	return result

func prepare(art):
	var sheet=art.raw_texture("res://assets/flame-burst.png")
	for frame in 4:
		flame_frames.append(fire_palette(art.pixel_texture(sheet,Rect2(frame*543+4,174,535,356),Vector2(108,70.2))))
	var electricity=art.raw_texture("res://assets/electric-arcs.png")
	for frame in 4:
		var bolts=art.pixel_texture(electricity,Rect2(frame*362+20,260,325,560),Vector2(108,176.4))
		electric_frames.append(ImageTexture.create_from_image(ActionFX.colorize(bolts.get_image(),"blue",.93)))
	var moves=art.move_tables.fighters[6].moves.special3
	for frame in [0,8,12,44]:
		var sprite=art.signature_art.sprite({"kind":6,"frame":frame},moves,art)
		for mode in ["cyan","gold"]: tinted(sprite.texture,mode)

func prepare_reaction(kind:int,art):
	load_reaction_atlas()
	tinted(art.sprite_frame(kind,13).texture,"electric")

func load_reaction_atlas():
	if reaction_atlas!=null: return
	var atlas=Image.new()
	if atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/element-reactions.png"))!=OK: return
	reaction_atlas=ImageTexture.create_from_image(atlas)
	reaction_poses=JSON.parse_string(FileAccess.get_file_as_string("res://data/element-reactions.json"))

static func effect_age(f:Dictionary,duration:int)->int:
	return maxi(0,duration-int(f.get("element_timer",0)))

func draw_reaction(canvas:Node2D,f:Dictionary,pose_key:String,rect:Rect2,body:Texture2D):
	if f.get("element_timer",0)<=0: return
	load_reaction_atlas()
	var entry:Dictionary=reaction_poses.get("%d:%s" % [f.kind,pose_key],{})
	if entry.is_empty() or Vector2(entry.size[0],entry.size[1])!=body.get_size(): return
	var region:Array
	var opacity=1.0
	var tint=Color.WHITE
	if f.element_hit=="electric" and entry.has("xray") and effect_age(f,Combat.ELECTRIC_REACTION_TICKS)%9<5:
		region=entry.xray
		tint=Color("56dcff")
	elif f.element_hit=="fire":
		var age=effect_age(f,Combat.FIRE_REACTION_TICKS)
		region=entry.fire[int(age/3)%entry.fire.size()]
		opacity=clampf(float(f.element_timer)/6.0,0.0,1.0)
	else: return
	var source=Rect2(region[0],region[1],region[2],region[3])
	var target=Rect2(rect.position+Vector2(region[4],region[5])*PIXEL_UNIT,source.size*PIXEL_UNIT)
	tint.a=opacity
	canvas.draw_texture_rect_region(reaction_atlas,target,source,tint)

func fire_palette(texture:Texture2D)->Texture2D:
	# Deliberate arcade color clusters replace smooth source-art gradients.
	# Resolution and opaque pixel grid remain identical to fighter textures.
	var colors=[Color("9b2106"),Color("cf3705"),Color("ed5908"),Color("ff850d"),Color("ffa919"),Color("ffd53d"),Color("ffdf57")]
	var pixels=texture.get_image()
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c=pixels.get_pixel(x,y)
			if c.a<.5: continue
			if c.get_luminance()>=.91:
				pixels.set_pixel(x,y,Color.WHITE)
				continue
			var best=colors[0];var distance=10.0
			for candidate in colors:
				var delta=Vector3(c.r-candidate.r,c.g-candidate.g,c.b-candidate.b).length_squared()
				if delta<distance: distance=delta;best=candidate
			pixels.set_pixel(x,y,best)
	return ImageTexture.create_from_image(pixels)

func draw_aura(canvas:Node2D,f:Dictionary,m:Dictionary,rect:Rect2,texture:Texture2D):
	if f.get("element_timer",0)>0 and f.element_hit=="electric":
		var age=effect_age(f,Combat.ELECTRIC_REACTION_TICKS)
		var size=Vector2(clampf(rect.size.x+5.4,97.2,153.0),rect.size.y+10.8)
		var offset=Vector2(rect.get_center().x-size.x*.5,rect.end.y-size.y+1.8).snapped(Vector2(PIXEL_UNIT,PIXEL_UNIT))
		canvas.draw_texture_rect(electric_frames[int(age/2)%4],Rect2(offset,size),false)
	if not active(f,m) or m.element!="electric": return
	var glow=tinted(texture,"gold" if int(f.frame/2)%2==0 else "cyan")
	for offset in [Vector2(-1.8,0),Vector2(1.8,0),Vector2(0,-1.8)]:
		canvas.draw_texture_rect(glow,Rect2(rect.position+offset,rect.size),false,Color(1,1,1,.85))

func draw_front(canvas:Node2D,f:Dictionary,m:Dictionary,rect:Rect2):
	if active(f,m):
		if m.element=="electric":
			var index=int((f.frame-m.startup)/2)%4
			canvas.draw_texture_rect(electric_frames[index],Rect2(-54,-174.6,108,176.4),false)
		elif m.element=="fire":
			var index=int((f.frame-m.startup)/3)%4
			canvas.draw_texture_rect(flame_frames[index],Rect2(37.8,-145.8,108,70.2),false)
