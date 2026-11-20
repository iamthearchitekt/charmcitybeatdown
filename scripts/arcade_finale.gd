extends RefCounted

const ActionFX=preload("res://scripts/action_fx.gd")
const SCREEN_SIZE=Vector2(1280,720)
const TITLE_TICK=12
const DETAILS_TICK=44
const BURSTS=[
	[Vector2(125,128),137,20,150.0,"gold"],
	[Vector2(1103,168),173,29,172.0,"violet"],
	[Vector2(278,77),151,68,106.0,"orange"],
	[Vector2(1160,318),191,98,126.0,"rose"],
]

var skyline:Texture2D

func draw_backdrop(canvas:Node2D,age:int):
	if skyline==null:
		var pixels=Image.new()
		var result=pixels.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/arcade-finale.png"))
		assert(result==OK,"Unable to load Arcade finale backdrop")
		skyline=ImageTexture.create_from_image(pixels)
	var reveal=smoothstep(0.0,40.0,float(age))
	var size=SCREEN_SIZE*(1.0+.026*(1.0-reveal))
	canvas.draw_texture_rect(skyline,Rect2((SCREEN_SIZE-size)*.5,size),false)
	canvas.draw_rect(Rect2(Vector2.ZERO,SCREEN_SIZE),Color(.022,.018,.044,lerpf(.60,.25,reveal)))
	for burst in BURSTS:
		var life=posmod(age-int(burst[2]),int(burst[1]))
		if life>=29: continue
		var phase=mini(3,int(life/7))
		var spread=lerpf(.43,1.16,float(life)/29.0)
		var diameter=float(burst[3])*spread
		var size_of_burst=Vector2(diameter,diameter).round()
		var position=Vector2(burst[0])-size_of_burst*.5
		canvas.draw_texture_rect(ActionFX.frame("clash",phase,burst[4]),Rect2(position.round(),size_of_burst),false,Color(1,1,1,1.0-smoothstep(9.0,29.0,float(life))))
