extends RefCounted
## Two wing poses, intermittent flights, and long quiet gaps on the stage clock.
const WINDOWS=[18.0,24.0,27.0]
var frames:Array=[]

func load_art():
	if not frames.is_empty(): return
	var sheet=Image.new()
	sheet.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/graveyard-crows.png"))
	for frame in 2:
		var left=roundi(frame*sheet.get_width()/2.0)
		var right=roundi((frame+1)*sheet.get_width()/2.0)
		var image=sheet.get_region(Rect2i(left,0,right-left,sheet.get_height()))
		image.resize(64,64,Image.INTERPOLATE_LANCZOS)
		for y in 64:
			for x in 64:
				var c=image.get_pixel(x,y)
				image.set_pixel(x,y,Color(roundf(c.r*23)/23,roundf(c.g*23)/23,roundf(c.b*23)/23,1) if c.a>=.5 else Color.TRANSPARENT)
		frames.append(ImageTexture.create_from_image(image))

static func sample(elapsed:float)->Array:
	var time=maxf(0,elapsed)
	var supercycle=int(floor(time/69.0))
	var phase=fposmod(time,69.0)
	var window=0
	while phase>=WINDOWS[window]:
		phase-=WINDOWS[window]
		window+=1
	var cycle=supercycle*3+window
	var direction=1 if cycle%2==0 else -1
	var count=[1,3,2][window]
	var speed=[205.0,225.0,190.0][window]
	var birds:Array=[]
	for bird in count:
		var age=phase-3.0-bird*.42
		if age<0: continue
		var distance=age*speed
		var x=-70.0+distance if direction==1 else 1350.0-distance
		if x< -64 or x>1344: continue
		birds.append({"x":roundf(x),"y":roundf(174.0+(cycle*29+bird*37)%93+sin(age*1.7)*4),
			"direction":direction,"frame":int(floor(age*8+bird*.5))%2,"size":64.0-bird*8.0})
	return birds

func draw(canvas:Node2D,elapsed:float):
	var birds=sample(elapsed)
	if birds.is_empty(): return
	load_art()
	for bird in birds:
		canvas.draw_set_transform(Vector2(bird.x,bird.y),0,Vector2(bird.direction,1))
		canvas.draw_texture_rect(frames[bird.frame],Rect2(-bird.size*.5,-bird.size*.5,bird.size,bird.size),false)
		canvas.draw_set_transform(Vector2.ZERO)
