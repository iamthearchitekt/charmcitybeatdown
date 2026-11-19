extends RefCounted
const GroundShadow=preload("res://scripts/ground_shadow.gd")
## Three independent targets on EACH side: all six are required.
const BODY=Rect2(432,362,416,260)
const MAX_HP=[350,400,350,350,400,350]
const LABELS=["L GLASS","L HOOD","L BUMPER","R GLASS","R HOOD","R BUMPER"]
var hp:Array=[350,400,350,350,400,350]
var textures:Array=[]
var hit_flash=[0,0,0,0,0,0]
var debris:Array=[]

func load_art():
	if not textures.is_empty(): return
	for frame in 4:
		var image=Image.new()
		var path="res://assets/bonus-car-"+str(frame)+".png"
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK:
			textures.append(ImageTexture.create_from_image(image))

func destroyed()->bool:
	return hp.all(func(value): return value<=0)

func side_destroyed(side:int)->bool:
	var start=0 if side<0 else 3
	return hp[start]<=0 and hp[start+1]<=0 and hp[start+2]<=0

func target(side:int,attack:Rect2,move:String="")->int:
	var start=0 if side<0 else 3
	if move!="":
		var band=-1
		if move in ["lp","mp","hp","hk","air_lp","air_mp","air_hp","air_lk","air_mk","air_hk","special2"]: band=0
		elif move in ["c_lp","c_mp","c_hp"]: band=1
		elif move in ["c_lk","c_mk","c_hk"]: band=2
		if band<0: return -1
		var zone=start+band
		return zone if hp[zone]>0 and attack.intersects(hitbox(zone)) else -1
	var best=-1
	var best_area=0.0
	for zone in range(start,start+3):
		if hp[zone]<=0: continue
		var overlap=attack.intersection(hitbox(zone))
		if overlap.has_area() and overlap.get_area()>best_area:
			best=zone;best_area=overlap.get_area()
	return best

func hitbox(zone:int)->Rect2:
	# Punch/high kick -> glass; crouching jab -> hood; crouching kick -> bumper.
	# Each bank is reachable exclusively from its corresponding physical side.
	var tops=[332.0,446.5,528.4]
	var bottoms=[446.5,528.4,622.0]
	return Rect2(BODY.position.x if zone<3 else BODY.get_center().x,tops[zone%3],BODY.size.x*.5,bottoms[zone%3]-tops[zone%3])

func damage(zone:int,amount:int,position:Vector2)->bool:
	if zone<0 or hp[zone]<=0: return false
	var before=int(hp[zone])
	hp[zone]=maxi(0,before-amount)
	hit_flash[zone]=5
	for i in (12 if hp[zone]==0 else 5):
		var angle=float(i)*2.4+zone
		debris.append({"p":position,"v":Vector2(cos(angle)*3.8,-3.0-absf(sin(angle))*4),"life":35,"glass":i%3==0})
	return before>0 and hp[zone]==0

func step_effects():
	for zone in 6: hit_flash[zone]=maxi(0,hit_flash[zone]-1)
	for piece in debris:
		piece.p+=piece.v;piece.v.y+=.34;piece.life-=1
	debris=debris.filter(func(p): return p.life>0 and p.p.y<635)

func damage_frame(zone:int)->int:
	if hp[zone]<=0: return 3
	var ratio=float(hp[zone])/MAX_HP[zone]
	return 0 if ratio>.67 else (1 if ratio>.34 else 2)

func draw(canvas:Node2D,tick:int):
	load_art()
	if textures.size()!=4: return
	GroundShadow.draw(canvas,Vector2(BODY.get_center().x,BODY.end.y-4),BODY.size.x*.46,11.0,.22)
	# The subtly angled frontal sprite has three target bands in each half.
	# Equal source canvases preserve registration throughout independent damage.
	var rows=[0.0,.325,.64,1.0]
	# Requested facing: reveal the side on screen LEFT. Mirror the artwork,
	# but swap source banks so world-left damage stays on world-left targets.
	canvas.draw_set_transform(Vector2(BODY.get_center().x*2,0),0,Vector2(-1,1))
	for zone in 6:
		var tex=textures[damage_frame(zone)]
		var shift=Vector2((1 if tick%2==0 else -1)*2,0) if hit_flash[zone]>0 else Vector2.ZERO
		var row=zone%3
		var x=.5 if zone<3 else 0.0
		var normalized=Rect2(x,rows[row],.5,rows[row+1]-rows[row])
		var dest=Rect2(BODY.position+normalized.position*BODY.size+shift,normalized.size*BODY.size)
		var source=Rect2(normalized.position*tex.get_size(),normalized.size*tex.get_size())
		canvas.draw_texture_rect_region(tex,dest,source,Color(1.12,1.12,1.12) if hit_flash[zone]>0 else Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
	for piece in debris:
		canvas.draw_rect(Rect2(piece.p.round(),Vector2(3,2)),Color("a9dfdf") if piece.glass else Color("8c9299"))
