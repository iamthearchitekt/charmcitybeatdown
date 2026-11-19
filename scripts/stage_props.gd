extends RefCounted

const Combat=preload("res://scripts/combat.gd")
const GroundShadow=preload("res://scripts/ground_shadow.gd")
const CELL=Vector2(64,56)
const KEG=0
const BOX=1
const DRUM=2
const CAN=3
const SCALE=[2.65,2.58,3.45,3.0]
const HEIGHTS=[120.0,94.0,139.0,144.0]
const WIDTHS=[88.0,94.0,119.0,105.0]
const PROP_TYPES=["kegs","boxes","barrels","trash_cans"]
const DEBRIS_COLORS=[Color("a8b0b2"),Color("ae814b"),Color("7c7866"),Color("9ba19e")]
const SETS={
	0:[[152.0,CAN]],
	1:[[125.0,BOX],[245.0,DRUM],[1035.0,DRUM],[1155.0,BOX]],
	2:[[156.0,CAN],[1124.0,CAN]],
	4:[[152.0,KEG],[1120.0,KEG]],
	6:[[158.0,KEG],[1126.0,KEG]],
}
static var props_atlas:Texture2D
var objects:Array=[]
var debris:Array=[]
var strikes:Array=[]

func reset(stage_index:int):
	objects=[]
	debris=[]
	strikes=[{"move":"","frame":-1,"hit":[]},{"move":"","frame":-1,"hit":[]}]
	for entry in SETS.get(stage_index,[]):
		objects.append({"id":objects.size(),"x":entry[0],"kind":entry[1],"hp":180,"flash":0,"wreck":0})
	if not objects.is_empty() and props_atlas==null:
		var image=Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stage-breakables.png"))==OK:
			props_atlas=ImageTexture.create_from_image(image)

func box(prop:Dictionary)->Rect2:
	var width:float=WIDTHS[prop.kind]
	var height:float=HEIGHTS[prop.kind]
	return Rect2(prop.x-width*.5,Combat.FLOOR-height,width,height)

func step(sim)->Array:
	var events:Array=[]
	if objects.is_empty(): return events
	for prop in objects:
		prop.flash=maxi(0,prop.flash-1)
		prop.wreck=maxi(0,prop.wreck-1)
	for particle in debris:
		particle.position+=particle.velocity
		particle.velocity.y+=.32
		particle.life-=1
	debris=debris.filter(func(particle): return particle.life>0 and particle.position.y<Combat.FLOOR+4)
	for i in 2:
		var fighter:Dictionary=sim.fighters[i]
		var strike:Dictionary=strikes[i]
		if strike.move!=fighter.move or fighter.frame<strike.frame: strike.hit.clear()
		strike.move=fighter.move
		strike.frame=fighter.frame
		if not sim.is_active(fighter) or fighter.grabbed_by>=0: continue
		var move:Dictionary=sim.move_data(fighter)
		if move.level=="throw" or move.get("projectile",false): continue
		strike_props(sim,sim.attackboxes(fighter,move),strike.hit,move.damage,events)
	for projectile in sim.projectiles:
		if not projectile.has("stage_props_hit"): projectile.stage_props_hit=[]
		var parts=[Combat.projectile_rect(projectile)]
		strike_props(sim,parts,projectile.stage_props_hit,projectile.m.damage,events)
	return events

func strike_props(sim,parts:Array,hit:Array,damage:int,events:Array):
	if parts.is_empty(): return
	for prop in objects:
		if prop.hp<=0 or hit.has(prop.id): continue
		var region:Rect2=sim.regions_overlap(parts,[box(prop)])
		if not region.has_area(): continue
		hit.append(prop.id)
		prop.hp=maxi(0,prop.hp-maxi(1,damage))
		prop.flash=5
		var destroyed=prop.hp==0
		if destroyed: prop.wreck=38
		var center=region.get_center()
		events.append({"type":"prop_hit","kind":PROP_TYPES[prop.kind],"broken":destroyed,"x":center.x,"y":center.y})
		for i in (10 if destroyed else 3):
			var velocity=Vector2(cos(i*2.4)*(2.0+i*.26),-2.5-absf(sin(i*2.4))*4.6)
			debris.append({"position":center,"velocity":velocity,"kind":prop.kind,"life":22})

func draw(canvas:Node2D):
	if props_atlas==null: return
	for prop in objects:
		if prop.hp==0 and prop.wreck==0: continue
		var frame=3 if prop.hp==0 else (0 if prop.hp==180 else (1 if prop.hp>90 else 2))
		var x:float=prop.x
		if prop.flash>0: x+=2.0 if prop.flash%2==0 else -2.0
		GroundShadow.draw(canvas,Vector2(x,Combat.FLOOR),WIDTHS[prop.kind]*.53,4.2,.30)
		var size=CELL*SCALE[prop.kind]
		var target=Rect2(Vector2(roundf(x-size.x*.5),roundf(Combat.FLOOR-size.y+SCALE[prop.kind])),size)
		var source=Rect2(Vector2(frame,prop.kind)*CELL,CELL)
		canvas.draw_texture_rect_region(props_atlas,target,source)
	for particle in debris:
		canvas.draw_rect(Rect2(particle.position.snapped(Vector2(2,2)),Vector2(4,3)),DEBRIS_COLORS[particle.kind])
