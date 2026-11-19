extends RefCounted
## Small outlined pixel stars orbit using simulation time, including pause/hitstop.
var texture:Texture2D

func _init():
	var mask=["000010000","000010000","000111000","111111111","011111110","001111100","001101100","011000110","010000010"]
	var image=Image.create(11,11,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 9:
		for x in 9:
			if mask[y][x]!="1": continue
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				image.set_pixelv(Vector2i(x+1,y+1)+offset,Color("171119"))
	for y in 9:
		for x in 9:
			if mask[y][x]=="1": image.set_pixel(x+1,y+1,Color("fff1aa") if y<4 else Color("e9ad42"))
	texture=ImageTexture.create_from_image(image)

func draw(canvas:Node2D,f:Dictionary,head_y:float):
	for i in 3:
		var angle=float(f.dizzy_age)*.075+i*TAU/3.0
		var center=Vector2(f.x+cos(angle)*38.0,head_y+sin(angle)*15.0)
		var pos=Vector2(roundf(center.x/2.0)*2,roundf(center.y/2.0)*2)
		canvas.draw_texture_rect(texture,Rect2(pos-Vector2(11,11),Vector2(22,22)),false)
