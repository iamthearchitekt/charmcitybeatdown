extends RefCounted
# Original pixel artwork: a brief contact flash, solid burst, then broken motes.
# Cached low-resolution frames replace the expanding antialiased line wheel.
const LIFE=10
var frames:Dictionary={}

func _init():
	for kind in ["hit","heavy","block","clash"]:
		frames[kind]=[]
		for phase in 4: frames[kind].append(make_frame(kind,phase))

func make_frame(kind:String,phase:int)->Texture2D:
	var image=Image.create(35,35,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var block=kind=="block"
	var edge=Color("183a68") if block else Color("a83819")
	var outer=Color("5397d1") if block else Color("e87829")
	var middle=Color("a5dbed") if block else Color("ffce58")
	var core=Color("f4ffff") if block else Color("fff5c8")
	if kind=="clash":
		edge=Color("183a68");outer=Color("65bedb");middle=Color("ffe39a");core=Color("f4ffff")
	# Unequal points and connected wedges keep the flash compact and directional.
	var shapes=[
		PackedVector2Array([Vector2(-3,-7),Vector2(0,-3),Vector2(5,-5),Vector2(3,-1),Vector2(7,2),Vector2(2,3),Vector2(1,7),Vector2(-2,3),Vector2(-6,5),Vector2(-3,0),Vector2(-7,-2),Vector2(-3,-3)]),
		PackedVector2Array([Vector2(-4,-13),Vector2(0,-5),Vector2(8,-9),Vector2(5,-2),Vector2(13,1),Vector2(5,4),Vector2(7,11),Vector2(0,6),Vector2(-6,13),Vector2(-5,5),Vector2(-13,7),Vector2(-7,0),Vector2(-12,-6),Vector2(-5,-4)]),
		PackedVector2Array([Vector2(-3,-7),Vector2(0,-3),Vector2(6,-5),Vector2(3,0),Vector2(7,3),Vector2(1,3),Vector2(-1,7),Vector2(-3,2),Vector2(-7,3),Vector2(-4,-1),Vector2(-7,-4),Vector2(-3,-3)])
	]
	var scale_factor=1.12 if kind in ["heavy","clash"] else (.74 if block else .88)
	var shape:PackedVector2Array=shapes[mini(phase,2)]
	for y in 35:
		for x in 35:
			var p=(Vector2(x,y)-Vector2(17,17))/scale_factor
			var color=Color.TRANSPARENT
			if phase<3:
				if Geometry2D.is_point_in_polygon(p,shape):
					color=outer
					if Geometry2D.is_point_in_polygon(p*1.55+Vector2(.7,-.4),shape): color=middle
					if Geometry2D.is_point_in_polygon(p*2.7+Vector2(1,-1),shape): color=core
				else:
					for delta in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
						if Geometry2D.is_point_in_polygon(p+delta,shape): color=edge;break
			# Blocks are a smaller, blue-white contact crescent with a hollow center.
			if block and p.x<-1 and p.length()<3.5: color=Color.TRANSPARENT
			if phase>=2:
				for mote in [Vector2(-11,-7),Vector2(9,-10),Vector2(12,6),Vector2(-6,12)]:
					var drift=mote*(1.0 if phase==2 else 1.13)
					if absf(p.x-drift.x)<1.4 and absf(p.y-drift.y)<1.4: color=middle if phase==2 else outer
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

func draw(canvas:Node2D,e:Dictionary):
	var age=clampi(LIFE-int(e.life),0,LIFE-1)
	var phase=0 if age<2 else (1 if age<5 else (2 if age<8 else 3))
	var kind="block" if e.type=="block" else ("heavy" if e.get("heavy",false) else "hit")
	if e.type=="projectile_clash": kind="clash"
	var texture:Texture2D=frames[kind][phase]
	var position=Vector2(roundf(e.x/2.0)*2,roundf(e.y/2.0)*2)-Vector2(34,34)
	canvas.draw_texture_rect(texture,Rect2(position,Vector2(70,70)),false)
