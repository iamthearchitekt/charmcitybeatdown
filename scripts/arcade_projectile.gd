extends RefCounted
# Original low-resolution blue fireball: round leading mass and ragged flame tail.
var frames:Array=[]
var fire_frames:Array=[]
var violet_frames:Array=[]
var pulse_frames:Dictionary={}
const BLADE_RECTS={"shear":Rect2(-44,-15,94,30),"tower":Rect2(-40,-16,83,32),"tower-low":Rect2(-42,-13,88,26)}
func _init():
	for phase in 4:
		var image=Image.create(46,28,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in 28:
			for x in 46:
				var p=Vector2(x,y)-Vector2(31,13.5)
				var distance=Vector2(p.x/11.0,p.y/11.8).length()
				var edge=1.0+sin(float(y)*1.9+phase*1.7)*.035
				var color=Color.TRANSPARENT
				if distance<edge:
					color=Color("2450b4")
					if distance<.85: color=Color("2998e8")
					if distance<.66: color=Color("83e0ff")
					if Vector2((p.x-2)/6.4,p.y/7.6).length()<1: color=Color("e6fcff")
				# Three asymmetric tongues connect the tail directly to the ball.
				if x<31:
					for tongue in 3:
						var origin_y=7.0+tongue*6.0
						var wave=sin(float(x)*.4+phase*1.6+tongue)*1.25
						var start=3.0+float((phase+tongue*3)%4)*2.0+tongue*2
						var width=clampf((x-start)/5.0,0,3.0)
						if x>start and absf(y-origin_y-wave)<width:
							color=Color("2998e8") if tongue!=1 else Color("83e0ff")
							if absf(y-origin_y-wave)<width*.37 and x>17: color=Color("e6fcff")
				# Small dark-blue breaks give the rotating flame a keyed sprite feel.
				if color.a>0 and distance>.55 and x>25 and x<38 and (x*3+y+phase*3)%17==0: color=Color("4bbcff")
				image.set_pixel(x,y,color)
		frames.append(ImageTexture.create_from_image(image))
		var violet=Image.create(46,28,false,Image.FORMAT_RGBA8)
		var blue=[Color("2450b4"),Color("2998e8"),Color("83e0ff"),Color("e6fcff"),Color("4bbcff")]
		var uv=[Color("35116f"),Color("7724d9"),Color("b665ff"),Color("f5dcff"),Color("9640ee")]
		for y in 28:
			for x in 46:
				var c=image.get_pixel(x,y)
				var index=blue.find(c)
				violet.set_pixel(x,y,uv[index] if index>=0 else Color.TRANSPARENT)
		violet_frames.append(ImageTexture.create_from_image(violet))
	for phase in 4:
		var fire_image=Image.new()
		fire_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/spike-fire-"+str(phase)+".png"))
		fire_frames.append(ImageTexture.create_from_image(fire_image))
	pulse_frames[""]=build_pulse_frames(frames,Color("f4fcff"))
	pulse_frames["fire"]=build_pulse_frames(fire_frames,Color("fff3c8"))
	pulse_frames["violet"]=build_pulse_frames(violet_frames,Color("fae7ff"))
	for skin in BLADE_RECTS:
		var cuts:Array=[]
		for phase in 4: cuts.append(blade_frame(skin,phase))
		pulse_frames[skin]=build_pulse_frames(cuts,Color("fff7d0"))

func blade_frame(skin:String,phase:int)->Texture2D:
	var image=Image.create(49,18,false,Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var u=(x-24.0)/24.0
			var curve=sin(u*2.5+phase*.58)*1.9 if skin=="shear" else -u*1.55
			var distance=absf(y-8.0-curve)
			var width=(1.0-absf(u))*(5.35 if skin=="shear" else 6.0)
			if distance>=width+.10 or width<=0: continue
			var color=Color("2b6879") if skin=="shear" else (Color("682975") if skin=="tower-low" else Color("87412c"))
			if distance<width-1.0: color=Color("faac39") if skin!="tower-low" else Color("d07ae3")
			if distance<width*.58: color=Color("ffeb78") if skin!="tower-low" else Color("ffc7aa")
			if distance<width*.24: color=Color("fff8cf")
			if skin=="shear" and x<25 and y<8 and (x+phase*2)%7==0: color=Color("9aebcd")
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

func build_pulse_frames(source:Array,highlight:Color)->Array:
	var result:Array=[]
	for texture in source:
		var original:Image=texture.get_image()
		var dim:Image=original.duplicate()
		var flash:Image=original.duplicate()
		for y in original.get_height():
			for x in original.get_width():
				var pixel=original.get_pixel(x,y)
				if pixel.a<=0: continue
				dim.set_pixel(x,y,Color(pixel.r*.68,pixel.g*.68,pixel.b*.76,pixel.a))
				var brightness=smoothstep(.12,.92,pixel.get_luminance())
				var lit=pixel.lerp(highlight,.06+.33*brightness)
				lit.a=pixel.a
				flash.set_pixel(x,y,lit)
		result.append(ImageTexture.create_from_image(flash))
		result.append(ImageTexture.create_from_image(dim))
	return result

func pulse_texture(skin:String,tick:int)->Texture2D:
	var chosen:Array=pulse_frames.get(skin,pulse_frames[""])
	return chosen[posmod(tick,chosen.size())]

func draw(canvas:Node2D,p:Dictionary,tick:int):
	var skin=p.get("m",{}).get("projectile_skin","")
	var texture=pulse_texture(skin,tick+int(p.get("owner",0)))
	canvas.draw_set_transform(Vector2(roundf(p.x/2.0)*2,roundf(p.y/2.0)*2),0,Vector2(p.facing,1))
	canvas.draw_texture_rect(texture,BLADE_RECTS.get(skin,Rect2(-74 if skin=="fire" else -62,-28,92,56)),false)
	canvas.draw_set_transform(Vector2.ZERO)
