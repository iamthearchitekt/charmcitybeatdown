extends RefCounted
## Two keyed scuttle poses. The shared stage clock makes pause deterministic.
const CYCLE=15.3
const LEAD_SPEED=150.0
const COMPANION_SPEED=136.0
const COMPANION_DELAY=.72
const LEAD_PAUSES=[Vector2(3.0,4.7),Vector2(7.7,9.3)]
const COMPANION_PAUSES=[Vector2(2.65,3.75),Vector2(7.1,8.05)]
const TRACK_LENGTH=1440.0
const WIDTH=96.0
const PATH_Y=584.0
var frames:Array=[]

func load_art():
	if not frames.is_empty(): return
	for frame in 2:
		var image=Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/harbor-rat-"+str(frame)+".png"))
		frames.append(ImageTexture.create_from_image(image))

static func sample(elapsed:float,companion:bool=false)->Dictionary:
	var time=maxf(0,elapsed)
	var cycle=int(floor(time/CYCLE))
	var phase=fposmod(time,CYCLE)
	if companion: phase-=COMPANION_DELAY
	var pauses=COMPANION_PAUSES if companion else LEAD_PAUSES
	var speed=COMPANION_SPEED if companion else LEAD_SPEED
	var paused_for=0.0
	var running=phase>=0.0
	for window in pauses:
		paused_for+=clampf(phase-window.x,0.0,window.y-window.x)
		if phase>=window.x and phase<window.y: running=false
	var distance=clampf((phase-paused_for)*speed,0.0,TRACK_LENGTH)
	running=running and distance<TRACK_LENGTH
	var direction=1 if cycle%2==0 else -1
	var x=-90.0+distance if direction==1 else 1370.0-distance
	return {"x":x,"y":PATH_Y-6.0 if companion else PATH_Y,"direction":direction,"running":running,
		"frame":int(floor(phase*10))%2 if running else 1,"visible":x>-WIDTH*.5 and x<1280+WIDTH*.5}

static func group(elapsed:float)->Array:
	var poses:Array=[]
	var cycle=int(maxf(0,elapsed)/CYCLE)%5
	if cycle in [1,3]:
		var companion=sample(elapsed,true)
		if companion.visible: poses.append(companion)
	var lead=sample(elapsed)
	if lead.visible: poses.append(lead)
	return poses

func draw(canvas:Node2D,elapsed:float):
	var poses=group(elapsed)
	if poses.is_empty(): return
	load_art()
	if frames.size()!=2: return
	for pose in poses:
		var scale=.77 if pose.y<PATH_Y else .88
		canvas.draw_rect(Rect2(roundf(pose.x+18*pose.direction-21),pose.y-1,42*scale,2),Color(0,0,0,.16))
		canvas.draw_set_transform(Vector2(roundf(pose.x),pose.y),0,Vector2(pose.direction,1)*scale)
		canvas.draw_texture_rect(frames[pose.frame],Rect2(-WIDTH*.5,-20,WIDTH,20),false)
		canvas.draw_set_transform(Vector2.ZERO)
