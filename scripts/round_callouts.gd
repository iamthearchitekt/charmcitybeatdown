extends RefCounted
## Painted announcements use the simulation clock so pauses and hitstop hold the pose.
const ActionFX=preload("res://scripts/action_fx.gd")
const CENTER=Vector2(640,215)
const GAP=11.0
const FIGHT_TICKS=42
const FIGHT_ENTRY=[1.28,1.19,1.1,.98,.96,1.04,1.01,1.0]
var atlas:Texture2D
var regions:Dictionary={}

func _init():
	var pixels=Image.new()
	var result=pixels.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/round-callouts.png"))
	assert(result==OK,"Unable to load round callout art")
	atlas=ImageTexture.create_from_image(pixels)
	var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/round-callouts.json"))
	for key in layout:
		var rect:Array=layout[key]
		regions[key]=Rect2(rect[0],rect[1],rect[2],rect[3])

func draw_round(canvas:Node2D,number:int,deciding:bool,age:int,duration:int):
	var labels:Array[String]=[]
	labels.append("final" if deciding else "round")
	if not deciding:
		labels.append_array(digits(number))
	draw_stamp(canvas,labels,65.0 if deciding else 69.0,age,duration,false)

func draw_fight(canvas:Node2D,age:int):
	draw_stamp(canvas,["fight"],103.0,age,FIGHT_TICKS,true)

func draw_ko(canvas:Node2D,age:int,duration:int):
	draw_stamp(canvas,["ko"],85.0,age,duration,true)

func draw_outcome(canvas:Node2D,loss:bool,age:int):
	var labels:Array[String]=[]
	labels.append("lose" if loss else "win")
	draw_stamp(canvas,labels,50.0,age,0,loss,Vector2(640,47))

func draw_finale(canvas:Node2D,age:int):
	var source:Rect2=regions["won"]
	var height=minf(146.0,738.0*source.size.y/source.size.x)
	draw_stamp(canvas,["won"],height,age,0,true,Vector2(640,144))

func draw_combo(canvas:Node2D,count:int,age:int,center_at:Vector2):
	var labels=digits(count)
	labels.append("hits")
	draw_stamp(canvas,labels,31.0,age,0,true,center_at)

static func digits(number:int)->Array[String]:
	var labels:Array[String]=[]
	for digit in str(number): labels.append(digit)
	return labels

func draw_stamp(canvas:Node2D,labels:Array[String],height:float,age:int,duration:int,impact:bool,center_at:Vector2=CENTER):
	if age<0 or (duration>0 and age>=duration): return
	var arrival=smoothstep(0.0,9.0,float(age))
	var scale=float(FIGHT_ENTRY[mini(age,FIGHT_ENTRY.size()-1)]) if impact else lerpf(.88,1.0,arrival)
	var motion_scale=minf(height/69.0,1.0)
	var center=center_at+Vector2(lerpf(13.0 if impact else -38.0,0.0,arrival)*motion_scale,0.0)
	var opacity=clampf(float(duration-age)/8.0,0.0,1.0) if duration>0 else 1.0
	var gap=GAP*scale*motion_scale
	var extents:Array[float]=[]
	var width=gap*float(labels.size()-1)
	for label in labels:
		var source:Rect2=regions[label]
		var extent=height*scale*source.size.x/source.size.y
		extents.append(extent)
		width+=extent
	var left=center.x-width*.5
	if age<8:
		var streak=ActionFX.frame("streak",int(age/2),"orange" if impact else "gold")
		var trail=Rect2(roundf(left-(90-40*arrival)*motion_scale),roundf(center.y+height*.27),152*motion_scale,22*motion_scale)
		canvas.draw_texture_rect(streak,trail,false,Color(1,1,1,.65*(1.0-arrival)))
	var top=center.y-height*scale*.5
	for index in labels.size():
		var destination=Rect2(roundf(left),roundf(top),roundf(extents[index]),roundf(height*scale))
		canvas.draw_texture_rect_region(atlas,destination,regions[labels[index]],Color(1,1,1,opacity))
		left+=extents[index]+gap
