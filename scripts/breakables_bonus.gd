extends "res://scripts/car_bonus.gd"
const GroundShadow=preload("res://scripts/ground_shadow.gd")
## Independent challenge objects; no opponent, health bars or instruction panels.
var challenge="kegs"
var objects:Array=[]
var debris:Array=[]
var spawned=0
var broken=0
var missed=0
var elapsed=0
var target_count=12
var object_frames:Array=[]
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
const KEG_SPEED=3.8
const KEG_SPAWN_INTERVAL=105

func begin_challenge(kind:int,type:String):
	begin(kind);challenge=type;objects=[];debris=[];spawned=0;broken=0;missed=0;elapsed=0
	projectiles.clear();fighters[0].x=300.0
	target_count=12 if challenge=="kegs" else 10
	if challenge=="boxes":
		for row in 4:
			for column in 4-row:
				objects.append(make_object(475.0+row*55.0+column*110.0,FLOOR-row*110.0,0.0))
		spawned=target_count
	load_frames()

func make_object(x:float,y:float,vx:float)->Dictionary:
	var health=125 if challenge=="kegs" else 150
	return {"id":objects.size(),"x":x,"y":y,"vx":vx,"vy":0.0,"hp":health,"max_hp":health,"flash":0,"wreck":45,"bounced":false}

func object_box(o:Dictionary)->Rect2:
	return Rect2(o.x-(68 if challenge=="kegs" else 50),o.y-(190 if challenge=="kegs" else 110),136 if challenge=="kegs" else 100,190 if challenge=="kegs" else 110)

func step(controls:Array):
	events.clear();tick+=1
	if freeze==0: fighters[0].pose_tick+=1
	if phase=="results": update_fighter(fighters[0],{});return
	if phase=="intro":
		phase_timer-=1
		if phase_timer<=0: phase="fight";events.append({"type":"fight"})
		return
	time_left=maxi(0,time_left-1)
	if freeze>0: freeze-=1
	else:
		elapsed+=1
		update_objects()
		var f=fighters[0]
		var control:Dictionary=controls[0].duplicate();control.back=false
		if control.get("command","")!="": f.queued=control.command;f.buffer=7
		if f.move=="" and f.stun==0:
			if control.get("dx",0)!=0: f.facing=signi(int(control.dx))
			elif challenge=="kegs":
				var nearest={};var distance=INF
				for o in objects:
					if o.hp>0 and absf(o.x-f.x)<distance: nearest=o;distance=absf(o.x-f.x)
				if not nearest.is_empty(): f.facing=1 if nearest.x>=f.x else -1
		var previous_x=float(f.x)
		update_fighter(f,control)
		if challenge=="boxes": resolve_boxes(f,previous_x)
		if is_active(f) and not f.hit:
			var m=move_data(f)
			if m.get("projectile",false):
				projectiles.append(make_projectile(f,m))
				f.hit=true;events.append({"type":"projectile_spawn","owner":0,"fighter":f.kind})
			elif m.level!="throw":
				var target=nearest_parts(attackboxes(f,m),f.x)
				if not target.is_empty():
					damage_object(target,m,f.move)
					f.hit=true;f.connected=true;f.next_hit_frame=f.frame+int(m.get("rehit_interval",0))
		for p in projectiles:
			p.x+=p.facing*projectile_speed(p);p.life-=1
			var target=nearest_contact(projectile_rect(p),p.x)
			if not target.is_empty(): damage_object(target,p.m,p.move);p.life=0
		projectiles=projectiles.filter(func(p):return p.life>0 and p.x>LEFT-80 and p.x<RIGHT+80)
		if challenge=="kegs" and f.stun==0:
			for o in objects:
				if o.hp>0 and hazard_touches(object_box(o),f):
					f.health=maxi(1,f.health-40);f.stun=12;f.state="hit";f.move="";f.vx=signf(o.vx)*3
					events.append({"type":"hit","owner":1,"fighter":f.kind,"move":"lk","x":f.x,"y":f.y-75,"heavy":false,"combo":0})
					break
	for particle in debris:
		particle.p+=particle.v;particle.v.y+=.35;particle.life-=1
	debris=debris.filter(func(p):return p.life>0 and p.p.y<635)
	if broken==target_count: finish(true)
	elif time_left<=0 or (spawned==target_count and not objects.any(func(o):return o.hp>0)): finish(false)

func hazard_touches(box:Rect2,f:Dictionary)->bool:
	# A prop hurts on body contact, not just because a striking fist/boot touches it.
	# Keep the original body-contact width while following the visible crouch/air pose.
	var parts=hurtboxes(f)
	var body=CollisionProfiles.bounds(parts)
	var core=box.intersection(Rect2(f.x-PUSH_WIDTH*.5,body.position.y,PUSH_WIDTH,body.size.y))
	return core.has_area() and regions_overlap([core],parts).has_area()

func nearest_contact(box:Rect2,x:float)->Dictionary:
	return nearest_parts([box],x)

func nearest_parts(parts:Array,x:float)->Dictionary:
	var nearest={};var distance=INF
	for o in objects:
		if o.hp>0 and regions_overlap(parts,[object_box(o)]).has_area() and absf(o.x-x)<distance: nearest=o;distance=absf(o.x-x)
	return nearest

func damage_object(o:Dictionary,m:Dictionary,move:String):
	if o.hp<=0: return
	var before=int(o.hp)
	o.hp=maxi(0,o.hp-int(m.damage));o.flash=5
	var destroyed=o.hp==0
	score+=(before-int(o.hp))*10+(1000 if destroyed else 0)
	if destroyed: broken+=1
	freeze=mini(3,int(m.hitstop))
	events.append({"type":"prop_hit","kind":challenge,"broken":destroyed,"x":o.x,"y":o.y-70})
	events.append({"type":"hit","owner":0,"fighter":fighters[0].kind,"move":move,"x":o.x,"y":o.y-70,"heavy":m.damage>=100,"combo":0})
	for i in (10 if destroyed else 3):
		debris.append({"p":Vector2(o.x,o.y-65),"v":Vector2(cos(i*2.4)*4,-3-absf(sin(i*2.4))*5),"life":30})

func update_objects():
	if challenge=="kegs" and spawned<target_count and elapsed>=20+spawned*KEG_SPAWN_INTERVAL:
		var right=spawned%2==1
		var o=make_object(RIGHT+65 if right else LEFT-65,310.0,-KEG_SPEED if right else KEG_SPEED)
		objects.append(o);spawned+=1
	if challenge=="boxes": objects.sort_custom(func(a,b):return a.y>b.y)
	for o in objects:
		o.flash=maxi(0,o.flash-1)
		if o.hp<=0: o.wreck-=1
		if challenge=="kegs":
			if o.hp>0: o.x+=o.vx
			o.y+=o.vy;o.vy+=.9
			if o.y>=FLOOR:
				o.y=FLOOR
				if not o.bounced and o.hp>0: o.vy=-7.0;o.bounced=true
				else: o.vy=0.0
			if o.hp>0 and (o.x<LEFT-90 or o.x>RIGHT+90): o.hp=0;o.wreck=0;missed+=1
		else:
			var floor_y=FLOOR
			if o.hp>0:
				for support in objects:
					if support.id!=o.id and support.hp>0 and support.y>o.y+20 and absf(support.x-o.x)<104: floor_y=minf(floor_y,support.y-110)
			if o.y<floor_y: o.vy+=.8;o.y=minf(floor_y,o.y+o.vy)
			else: o.y=floor_y;o.vy=0.0

func resolve_boxes(f:Dictionary,previous_x:float):
	for o in objects:
		if o.hp<=0 or f.y<=object_box(o).position.y+2: continue
		var left=o.x-74;var right=o.x+74
		if f.x>left and f.x<right:
			if previous_x<=left: f.x=left
			elif previous_x>=right: f.x=right
			else: f.x=left if f.x<o.x else right

func load_frames():
	object_frames=[]
	var image=Image.new();image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/breakables-atlas.png"))
	var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://data/breakables-atlas.json"))[challenge]
	var factor=(190.0 if challenge=="kegs" else 110.0)/metadata.source_height
	for r in metadata.regions:
		var pixels=image.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		var size=Vector2(pixels.get_size())*factor
		pixels.resize(maxi(1,roundi(size.x/.9)),maxi(1,roundi(size.y/.9)),Image.INTERPOLATE_LANCZOS)
		for y in pixels.get_height():
			for x in pixels.get_width():
				var c=pixels.get_pixel(x,y)
				var d=((BAYER[(y%4)*4+x%4]+.5)/16.0-.5)*.8
				pixels.set_pixel(x,y,Color(clampf(roundf(c.r*23+d)/23,0,1),clampf(roundf(c.g*23+d)/23,0,1),clampf(roundf(c.b*23+d)/23,0,1),1) if c.a>=.5 else Color.TRANSPARENT)
		object_frames.append({"texture":ImageTexture.create_from_image(pixels),"size":Vector2(pixels.get_size())*.9})

func draw_objects(canvas:Node2D):
	for o in objects:
		if o.hp<=0 and o.wreck<=0: continue
		var frame=3 if o.hp<=0 else (0 if o.hp==o.max_hp else (1 if o.hp>o.max_hp*.5 else 2))
		var sprite=object_frames[frame]
		var position=Vector2(roundf(o.x),roundf(o.y))
		if challenge=="kegs" or position.y>=FLOOR-1:
			var height_ratio=clampf((FLOOR-position.y)/180.0,0,1)
			GroundShadow.draw(canvas,Vector2(position.x,FLOOR),sprite.size.x*.47,lerpf(4.5,6.5,height_ratio),lerpf(.28,.08,height_ratio))
		if o.flash>0: position.x+=2 if o.flash%2==0 else -2
		canvas.draw_texture_rect(sprite.texture,Rect2(position-Vector2(sprite.size.x*.5,sprite.size.y),sprite.size),false)
	for particle in debris:
		canvas.draw_rect(Rect2(particle.p.snapped(Vector2(2,2)),Vector2(4,3)),Color("b18b51") if challenge=="boxes" else Color("9ca8b2"))
