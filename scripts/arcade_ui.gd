extends RefCounted
# Fixed, two-pixel surface grain and stepped arcade frames. No animated noise.
var grain:Texture2D
var gold:Texture2D
func _init():
	var image=Image.create(640,360,false,Image.FORMAT_RGBA8)
	for y in 360:
		for x in 640:
			var pattern=(x*19+y*31+(x*y)%13)%23
			image.set_pixel(x,y,Color(0,0,0,.06) if pattern<3 else (Color(1,1,1,.022) if pattern>20 else Color.TRANSPARENT))
	grain=ImageTexture.create_from_image(image)
	var bar=Image.create(228,11,false,Image.FORMAT_RGBA8)
	var palette=[Color("fff2a8"),Color("ffdd73"),Color("f0c04b"),Color("dda039"),Color("ad6c25")]
	for y in 11:
		for x in 228:
			var band=0 if y<1 else (1 if y<3 else (2 if y<7 else (3 if y<10 else 4)))
			if y in [2,6,9] and (x+y)%2==0: band=mini(4,band+1)
			var color:Color=palette[band]
			if (x*11+y*7)%37==0: color=color.darkened(.09)
			bar.set_pixel(x,y,color)
	gold=ImageTexture.create_from_image(bar)

func texture_surface(canvas:Node2D,rect:Rect2):
	canvas.draw_texture_rect_region(grain,rect,Rect2(rect.position*.5,rect.size*.5))

func frame(canvas:Node2D,rect:Rect2,color:Color):
	canvas.draw_rect(rect.grow(3),Color("050810"),false,2)
	canvas.draw_rect(rect,color.darkened(.48),false,2)
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,2)),color)
	canvas.draw_rect(Rect2(rect.position,Vector2(2,rect.size.y)),color.lightened(.14))
	canvas.draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,2)),color.darkened(.18))
	# Square-cut corner chips, aligned to the same two-pixel grid as the surfaces.
	for corner in [rect.position,rect.position+Vector2(rect.size.x-2,0),rect.end-Vector2(2,2),rect.position+Vector2(0,rect.size.y-2)]:
		canvas.draw_rect(Rect2(corner,Vector2(2,2)),Color("080c18"))

func surface(canvas:Node2D,rect:Rect2,fill:Color,border:Color):
	canvas.draw_rect(rect,fill)
	texture_surface(canvas,rect)
	frame(canvas,rect,border)

func life(canvas:Node2D,rect:Rect2):
	if rect.size.x<=0: return
	canvas.draw_texture_rect_region(gold,rect,Rect2(Vector2.ZERO,Vector2(rect.size.x*.5,11)))
