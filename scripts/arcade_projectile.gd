extends RefCounted
## Painted projectile frames use the caster's palette and the shared pulse clock.
const ActionFX=preload("res://scripts/action_fx.gd")
const PLASMA_SCALE=1.20
const SKIN_PALETTES={"fire":"ember","violet":"violet","yellow":"gold","shear":"gold"}
var frames:Array=[]
var fire_frames:Array=[]
var pulse_frames:Dictionary={}

func _init():
	for phase in 4:
		frames.append(ActionFX.frame("plasma",phase,"blue"))
		var fire_image=Image.new()
		fire_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/spike-fire-"+str(phase)+".png"))
		fire_frames.append(ImageTexture.create_from_image(ActionFX.colorize(fire_image,"ember",.89)))

func build_pulse_frames(source:Array,highlight:Color)->Array:
	var result:Array=[]
	for texture in source:
		var original:Image=texture.get_image()
		var dim:Image=original.duplicate()
		var flash:Image=original.duplicate()
		for y in original.get_height():
			for x in original.get_width():
				var pixel=original.get_pixel(x,y)
				if pixel.a<=0 or (pixel.v>.98 and pixel.s<.025): continue
				dim.set_pixel(x,y,Color(pixel.r*.69,pixel.g*.69,pixel.b*.69,pixel.a))
				var brightness=smoothstep(.12,.92,pixel.get_luminance())
				var lit=pixel.lerp(highlight,.06+.33*brightness)
				lit.a=pixel.a
				flash.set_pixel(x,y,lit)
		result.append(ImageTexture.create_from_image(flash))
		result.append(ImageTexture.create_from_image(dim))
	return result

func pulse_texture(skin:String,tick:int,fighter:int=-1)->Texture2D:
	var palette:String=SKIN_PALETTES.get(skin,ActionFX.palette_for(fighter))
	var key=skin+"/"+palette
	if not pulse_frames.has(key):
		var source:Array=[]
		if skin=="fire":
			source=fire_frames
		elif palette=="blue" and skin!="shear":
			source=frames
		else:
			var row="shear" if skin=="shear" else "plasma"
			for phase in 4: source.append(ActionFX.frame(row,phase,palette))
		var highlight:Color=ActionFX.RAMPS[palette][2]
		pulse_frames[key]=build_pulse_frames(source,highlight)
	var sequence:Array=pulse_frames[key]
	return sequence[posmod(tick,sequence.size())]

func draw(canvas:Node2D,p:Dictionary,tick:int):
	var skin=p.get("m",{}).get("projectile_skin","")
	var texture=pulse_texture(skin,tick+int(p.get("owner",0)),int(p.get("fighter",-1)))
	canvas.draw_set_transform(Vector2(roundf(p.x/2.0)*2,roundf(p.y/2.0)*2),0,Vector2(p.facing,1))
	var rect=Rect2(-44,-15,94,30) if skin=="shear" else Rect2(Vector2(-74 if skin=="fire" else -62,-28)*PLASMA_SCALE,Vector2(92,56)*PLASMA_SCALE)
	canvas.draw_texture_rect(texture,rect,false)
	canvas.draw_set_transform(Vector2.ZERO)
