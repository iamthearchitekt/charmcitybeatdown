extends RefCounted
## Two keyed scuttle poses. The shared stage clock makes pause deterministic.
const CYCLE=15.3
const SPEED=150.0
const WIDTH=96.0
const FLOOR=650.0
var frames:Array=[]

func load_art():
	if not frames.is_empty(): return
	for frame in 2:
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/harbor-rat-"+str(frame)+".png"))
		frames.append(ImageTexture.create_from_image(image))

static func sample(elapsed:float)->Dictionary:
	var time=maxf(0,elapsed)
	var cycle=int(floor(time/CYCLE))
	var phase=fposmod(time,CYCLE)
	var distance=0.0
	var running=true
	if phase<3.0: distance=phase*SPEED
	elif phase<4.7: distance=450.0;running=false
	elif phase<7.7: distance=450.0+(phase-4.7)*SPEED
	elif phase<9.3: distance=900.0;running=false
	elif phase<12.9: distance=900.0+(phase-9.3)*SPEED
	else: distance=1440.0;running=false
	var direction=1 if cycle%2==0 else -1
	var x=-90.0+distance if direction==1 else 1370.0-distance
	return {"x":x,"y":FLOOR,"direction":direction,"running":running,
		"frame":int(floor(phase*10))%2 if running else 1,"visible":x>-WIDTH*.5 and x<1280+WIDTH*.5}

func draw(canvas:Node2D,elapsed:float):
	var pose=sample(elapsed)
	if not pose.visible: return
	load_art()
	if frames.size()!=2: return
	var texture:Texture2D=frames[pose.frame]
	canvas.draw_rect(Rect2(roundf(pose.x+18*pose.direction-21),FLOOR-1,42,2),Color(0,0,0,.16))
	canvas.draw_set_transform(Vector2(roundf(pose.x),FLOOR),0,Vector2(pose.direction,1))
	canvas.draw_texture_rect(texture,Rect2(-WIDTH*.5,-20,WIDTH,20),false)
	canvas.draw_set_transform(Vector2.ZERO)
