extends RefCounted
## Original painted sprite atlases. Animation never controls combat collision.
var sheets:Array=[]
var move_tables:Dictionary
var regions:Array=[]
var anchors:Array=[]
var ground_sheet:Texture2D
var ground_regions:Array=[]
var jump_sheet:Texture2D
var jump_regions:Array=[]
const BASE_HEIGHTS=[281.0,285.0,284.0,306.0]
const PORTRAITS=[Rect2(99,22,111,115),Rect2(103,22,121,118),Rect2(115,22,107,112),Rect2(107,0,125,125)]
const RECTS=[
	[[52,28,197,281],[367,15,194,294],[680,33,196,276],[982,24,234,285],
	[39,349,261,273],[346,349,273,273],[659,327,258,296],[954,325,279,298],
	[60,716,168,203],[343,728,245,190],[606,739,331,177],[950,645,296,213],
	[44,976,211,267],[359,988,196,255],[649,943,206,300],[909,1171,341,73]],
	[[43,24,231,285],[383,9,183,300],[690,9,191,299],[983,18,221,290],
	[43,324,262,298],[334,325,291,296],[662,320,256,301],[950,320,282,301],
	[70,689,167,222],[347,712,249,197],[616,713,321,196],[965,633,283,249],
	[64,948,195,296],[329,965,245,279],[657,926,177,319],[858,1160,384,75]]
]
const ANCHORS=[
	[98,94,89,109,102,98,70,82,85,88,94,76,98,88,96,159],
	[115,91,82,100,100,98,72,88,82,90,93,79,92,115,85,192]
]

func _init():
	sheets=[load("res://assets/breakwater-atlas.png"),load("res://assets/redline-atlas.png"),load("res://assets/alex-atlas.png"),load("res://assets/emma-atlas.png")]
	ground_sheet=load("res://assets/supine-ko.png")
	jump_sheet=load("res://assets/jump-poses.png")
	jump_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/jump-poses.json"))
	var mapped=JSON.parse_string(FileAccess.get_file_as_string("res://data/appearance-atlases.json"))
	regions=RECTS.duplicate(true)
	regions.append(mapped["alex-atlas"]);regions.append(mapped["emma-atlas"])
	ground_regions=mapped["supine-ko"]
	anchors=ANCHORS.duplicate(true)
	for kind in [2,3]:
		var points=[]
		for frame in 16:
			points.append(float(ANCHORS[kind%2][frame])/RECTS[kind%2][frame][2]*regions[kind][frame][2])
		anchors.append(points)
	move_tables=JSON.parse_string(FileAccess.get_file_as_string("res://data/moves.json"))

func pose(f:Dictionary,t:float)->int:
	if f.state=="ko": return 13 if f.y<621.5 else 15
	if f.state=="knockdown": return 13
	if f.state=="down": return 15
	if f.state=="getup": return 8 if f.down_timer>5 else 12
	if f.state=="hit": return 13
	if f.state=="block" or (f.guard and f.move==""): return 8 if f.crouch else 12
	if f.move!="":
		var m=move_tables.fighters[f.kind].moves[f.move]
		var aerial=f.move.begins_with("air_")
		if f.frame<m.startup*.65: return 16 if aerial else (8 if f.crouch else 2)
		if f.frame>m.startup+m.active+float(m.recovery)*.60: return 16 if aerial else (8 if f.crouch else 2)
		match f.move:
			"air_lp","air_hp": return 17
			"air_lk","air_hk": return 11
			"lp": return 4
			"hp","throw","special1": return 5
			"lk": return 6
			"hk": return 7
			"c_lp","c_hp": return 9
			"c_lk","c_hk": return 10
			"special2": return 14
			_: return 11
	if f.crouch: return 8
	if f.y<620: return 16
	if absf(f.walk)>0: return [3,0,3,2][int(t*10)%4]
	# Both idle frames keep the hands up, chin tucked and knees flexed.
	return [2,2,0,2][int(t*6)%4]

func draw(canvas:Node2D,f:Dictionary,t:float,scale:float=1.0,portrait_mode:bool=false):
	var frame=pose(f,t)
	if portrait_mode: frame=[2,2,0,2][int(t*4)%4]
	var a=jump_regions[f.kind+(4 if frame==17 else 0)] if frame>=16 else regions[f.kind][frame]
	var sheet:Texture2D=sheets[f.kind]
	if frame>=16: sheet=jump_sheet
	if frame==15 and f.kind<2:
		a=ground_regions[f.kind]
		sheet=ground_sheet
	var source=Rect2(a[0],a[1],a[2],a[3])
	var units=160.0/BASE_HEIGHTS[f.kind]
	if frame<=3: units=160.0/a[3]
	if frame==15 and f.kind<2: units=190.0/a[2]
	if frame>=16: units=128.0/jump_regions[f.kind][3]
	var size=Vector2(a[2],a[3])*units
	var anchor=size.x*.5
	if frame<15: anchor=anchors[f.kind][frame]*units
	if frame==17: anchor=size.x*[.36,.34,.36,.34][f.kind]
	var top=-size.y
	if not portrait_mode:
		canvas.draw_set_transform(Vector2(f.x,626),0,Vector2(1,.17))
		canvas.draw_circle(Vector2.ZERO,54*scale*maxf(.45,1-(622-f.y)/400),Color(0,0,0,.54))
		canvas.draw_set_transform(Vector2(f.x,630),0,Vector2(f.facing*scale,-scale*.21))
		canvas.draw_texture_rect_region(sheet,Rect2(-anchor,top,size.x,size.y),source,Color(.36,.48,.56,.10))
	var recoil=-4 if f.state=="hit" else 0
	# Knockdowns use fixed keyed poses; only position follows the fall arc.
	canvas.draw_set_transform(Vector2(f.x+recoil*f.facing,f.y),0,Vector2(f.facing*scale,scale))
	canvas.draw_texture_rect_region(sheet,Rect2(-anchor,top,size.x,size.y),source)
	canvas.draw_set_transform(Vector2.ZERO)

func portrait(canvas:Node2D,kind:int,rect:Rect2,flipped:bool=false):
	var r=PORTRAITS[kind]
	if flipped:
		canvas.draw_set_transform(Vector2(rect.end.x,rect.position.y),0,Vector2(-1,1))
		canvas.draw_texture_rect_region(sheets[kind],Rect2(Vector2.ZERO,rect.size),r)
		canvas.draw_set_transform(Vector2.ZERO)
	else: canvas.draw_texture_rect_region(sheets[kind],rect,r)
