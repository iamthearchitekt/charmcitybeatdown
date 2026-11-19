extends RefCounted
const GrappleArt=preload("res://scripts/grapple_art.gd")
var grapple_art=GrappleArt.new()
const SignatureArt=preload("res://scripts/signature_art.gd")
var signature_art=SignatureArt.new()
const DizzyStars=preload("res://scripts/dizzy_stars.gd")
var dizzy_stars=DizzyStars.new()
const MovementArt=preload("res://scripts/movement_art.gd")
var movement_art=MovementArt.new()
const CombatPose=preload("res://scripts/combat_pose.gd")
const Combat=preload("res://scripts/combat.gd")
const GroundShadow=preload("res://scripts/ground_shadow.gd")
const ElementEffects=preload("res://scripts/element_effects.gd")
const StylePoseArt=preload("res://scripts/style_pose_art.gd")
var element_effects=ElementEffects.new()
var style_art=StylePoseArt.new()
## Rendered art and collision share the deterministic simulation pose.
var sheets:Array=[]
var move_tables:Dictionary
var pose_cutouts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/pose-cutouts.json"))
var warm_progress:Dictionary={}
var regions:Array=[]
var anchors:Array=[]
var ground_sheet:Texture2D
var ground_regions:Array=[]
var jump_sheet:Texture2D
var jump_regions:Array=[]
var high_kick_sheet:Texture2D
var high_kick_region:Rect2
var female_jump_sheet:Texture2D
var female_jump_regions:Array=[]
var jump_overrides:Dictionary={}
# Every pose uses the same logical pixel size, including the larger KO source art.
# Retain facial/clothing detail at ~178 native pixels tall, with light ordered
# dithering rather than using large pixels to manufacture an arcade appearance.
const PIXEL_UNIT=0.9
const PALETTE_STEPS=23.0
const DITHER_STRENGTH=0.8
const BAYER_4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
var pixel_frames:Dictionary={}
var pixel_portraits:Dictionary={}
var throw_atlases:Dictionary={}
var throw_frames:Dictionary={}
const BASE_HEIGHTS=[281.0,285.0,284.0,306.0]
const PORTRAITS=[Rect2(99,22,111,115),Rect2(103,22,121,118),Rect2(115,22,107,112),Rect2(107,0,125,125)]
var portrait_regions=PORTRAITS.duplicate()
var base_heights=BASE_HEIGHTS.duplicate()
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
	var kick_image=Image.new()
	kick_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/marcus-high-kick.png"))
	high_kick_region=Rect2(kick_image.get_used_rect())
	high_kick_sheet=ImageTexture.create_from_image(kick_image)
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
	# Updated women retain the same combat identities and shared pixel pipeline.
	var revised=JSON.parse_string(FileAccess.get_file_as_string("res://data/female-atlases.json"))
	for kind in [1,2,3]:
		var identity={1:"brook-lynne",2:"alex",3:"lauren"}[kind]
		if not revised.has(identity): continue
		var entry=revised[identity]
		sheets[kind]=raw_texture(entry.path)
		regions[kind]=entry.regions
		anchors[kind]=entry.anchors
		base_heights[kind]=entry.regions[0][3]
		var r=entry.portrait
		portrait_regions[kind]=Rect2(r[0],r[1],r[2],r[3])
		if entry.regions.size()>=18:
			jump_overrides[kind]={"sheet":sheets[kind],"neutral":entry.regions[16],"punch":entry.regions[17]}
	for identity in ["chelsea","vivian","spike","eric","stan","rachel","jeff","edgar-allan-poe","orioles-mascot","lamar-jackson"]:
		if not revised.has(identity): continue
		var entry=revised[identity]
		sheets.append(raw_texture(entry.path))
		regions.append(entry.regions)
		anchors.append(entry.anchors)
		base_heights.append(entry.regions[0][3])
		var r=entry.portrait
		portrait_regions.append(Rect2(r[0],r[1],r[2],r[3]))
		if entry.regions.size()>=18:
			jump_overrides[sheets.size()-1]={"sheet":sheets[-1],"neutral":entry.regions[16],"punch":entry.regions[17]}
	if revised.has("jumps"):
		female_jump_sheet=raw_texture(revised.jumps.path)
		female_jump_regions=revised.jumps.regions
	for set_name in ["jumps","bonus-jumps"]:
		if not revised.has(set_name): continue
		var entry=revised[set_name]
		var texture=raw_texture(entry.path)
		var kinds=[1,3] if set_name=="jumps" else [4,5]
		for i in 2:
			jump_overrides[kinds[i]]={"sheet":texture,"neutral":entry.regions[i],"punch":entry.regions[i+2]}
	move_tables=Combat.load_move_tables()
	var refined_jumps=JSON.parse_string(FileAccess.get_file_as_string("res://data/refined-jumps.json"))
	for key in refined_jumps:
		var entry=refined_jumps[key].duplicate(true)
		entry.sheet=raw_texture(entry.path)
		jump_overrides[int(key)]=entry
	throw_atlases=JSON.parse_string(FileAccess.get_file_as_string("res://data/throw-atlases.json"))
	for key in throw_atlases:
		throw_atlases[key].sheet=raw_texture(throw_atlases[key].path)
	element_effects.prepare(self)

func warm_next(kind:int)->bool:
	var index=int(warm_progress.get(kind,0))
	var movement_count:int=movement_art.entries[str(kind)].regions.size()
	var style_keys:Array=style_art.keys_for(kind)
	if index>=29+movement_count+style_keys.size(): return false
	if index<18: sprite_frame(kind,index)
	elif index<22: throw_frame(kind,index-18)
	elif index<28: grapple_art.sprite(kind,index-22,self)
	elif index<28+movement_count: movement_art.sprite(kind,index-28,self)
	elif index==28+movement_count: element_effects.prepare_reaction(kind,self)
	else: style_art.sprite(style_keys[index-29-movement_count])
	warm_progress[kind]=index+1
	return true

func raw_texture(path:String)->Texture2D:
	var image=Image.new()
	var decoded=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if decoded!=OK: push_error("Could not decode sprite sheet: "+path)
	return ImageTexture.create_from_image(image)

func pose(f:Dictionary,t:float)->int:
	var m=move_tables.fighters[f.kind].moves.get(f.move,{})
	return CombatPose.base(f,m,float(f.get("pose_tick",int(t*60)))/60.0)

func fighter_texture(sheet:Texture2D,source:Rect2,size:Vector2,kind:int,pose_key:String)->Texture2D:
	var cutout:Array=pose_cutouts.get(str(kind),{}).get(pose_key,[])
	return pixel_texture(sheet,source,size,true,cutout)

func pixel_texture(sheet:Texture2D,source:Rect2,size:Vector2,neutral_lighting:bool=false,cutout:Array=[])->Texture2D:
	var pixels=sheet.get_image().get_region(Rect2i(source))
	# Filter only while reducing the original artwork; enlargement stays nearest.
	pixels.resize(maxi(1,roundi(size.x/PIXEL_UNIT)),maxi(1,roundi(size.y/PIXEL_UNIT)),Image.INTERPOLATE_LANCZOS)
	# Audited atlas leftovers, in final raster coordinates. Check the frame
	# dimensions so the cleanup cannot shift to an unrelated crop.
	if not cutout.is_empty() and pixels.get_size()==Vector2i(cutout[0],cutout[1]):
		for rect in cutout[2]:
			pixels.fill_rect(Rect2i(rect[0],rect[1],rect[2],rect[3]),Color.TRANSPARENT)
	if neutral_lighting: remove_colored_rims(pixels)
	# A fixed, sprite-local pattern preserves shaded detail without animated noise.
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c=pixels.get_pixel(x,y)
			var d=((float(BAYER_4[(y%4)*4+x%4])+0.5)/16.0-0.5)*DITHER_STRENGTH
			pixels.set_pixel(x,y,Color(clampf(roundf(c.r*PALETTE_STEPS+d)/PALETTE_STEPS,0,1),clampf(roundf(c.g*PALETTE_STEPS+d)/PALETTE_STEPS,0,1),clampf(roundf(c.b*PALETTE_STEPS+d)/PALETTE_STEPS,0,1),1.0) if c.a>=0.5 else Color.TRANSPARENT)
	return ImageTexture.create_from_image(pixels)

func remove_colored_rims(pixels:Image):
	# Work only on saturated exterior lighting, borrowing adjacent interior material
	# color. Shape, alpha, skin detail and the interior costume palette are retained.
	var original=Image.create_from_data(pixels.get_width(),pixels.get_height(),false,pixels.get_format(),pixels.get_data())
	var directions=[Vector2i(-6,0),Vector2i(6,0),Vector2i(0,-6),Vector2i(0,6),Vector2i(-4,-4),Vector2i(4,-4),Vector2i(-4,4),Vector2i(4,4)]
	var bounds=Rect2i(Vector2i.ZERO,pixels.get_size())
	for y in pixels.get_height():
		for x in pixels.get_width():
			var p=Vector2i(x,y)
			var c=original.get_pixelv(p)
			if c.a<.5: continue
			var cyan=c.b>c.r*1.25 and c.g>c.r*1.15 and c.b-c.r>.045
			# Bright baked neon is removable; darker red fabric and berry lipstick
			# are intentional material colors and must survive this pass.
			var red=c.r>.78 and c.r-c.g>.5 and c.g<.12 and c.b<.16 and c.r>c.b*1.8
			if not cyan and not red: continue
			var total=Color(0,0,0,0)
			var count=0
			for direction in directions:
				var outside=p+direction
				if bounds.has_point(outside) and original.get_pixelv(outside).a>=.5: continue
				var inside=p-direction
				if not bounds.has_point(inside): continue
				var material=original.get_pixelv(inside)
				if material.a<.95: continue
				total+=material;count+=1
			if count>0:
				var material=total/float(count)
				# Broad tinted rims can reach the first interior sample as well.
				# Keep its shading, but remove that residual colored illumination.
				if (cyan and material.b>material.r*1.25 and material.g>material.r*1.15) or (red and material.r>.78 and material.r-material.g>.5 and material.g<.12 and material.b<.16):
					var shade=material.r*.299+material.g*.587+material.b*.114
					material=Color(shade,shade,shade,material.a)
				material.a=c.a
				pixels.set_pixelv(p,material)

func sprite_frame(kind:int,frame:int)->Dictionary:
	var key=kind*18+frame
	if pixel_frames.has(key): return pixel_frames[key]
	var a=regions[kind][mini(frame,15)]
	var sheet:Texture2D=sheets[kind]
	if frame>=16:
		if jump_overrides.has(kind):
			a=jump_overrides[kind].punch if frame==17 else jump_overrides[kind].neutral
			sheet=jump_overrides[kind].sheet
		else:
			a=jump_regions[kind+(4 if frame==17 else 0)]
			sheet=jump_sheet
	if frame==15 and kind==0:
		a=ground_regions[kind]
		sheet=ground_sheet
	var source=Rect2(a[0],a[1],a[2],a[3])
	if kind==0 and frame==7:
		sheet=high_kick_sheet
		source=high_kick_region
		a=[source.position.x,source.position.y,source.size.x,source.size.y]
	var units=160.0/base_heights[kind]
	if frame<=3: units=160.0/a[3]
	if frame==15 and kind!=2: units=190.0/a[2]
	if frame>=16:
		units=128.0/(jump_overrides[kind].neutral[3] if jump_overrides.has(kind) else jump_regions[kind][3])
		if jump_overrides.has(kind) and jump_overrides[kind].has("reference_height"):
			units=160.0/float(jump_overrides[kind].reference_height)
	if kind==0 and frame==7: units=170.0/a[3]
	var size=Vector2(a[2],a[3])*units
	var anchor=size.x*.5
	if frame<15: anchor=anchors[kind][frame]*units
	if frame==17: anchor=size.x*(.36 if kind in [0,2] else .34)
	if kind==0 and frame==7: anchor=size.x*.225
	var body_scale=presentation_scale(kind)
	size*=body_scale;anchor*=body_scale
	var pose_key="base:"+str(frame)
	var texture=fighter_texture(sheet,source,size,kind,pose_key)
	if frame==12:
		# Standing guard keeps the fighter's apparent size. Crouch guard uses
		# pose 8 and retains its lower silhouette.
		var idle:Texture2D=sprite_frame(kind,2).texture
		var target_height=ceili(idle.get_image().get_used_rect().size.y*.97)
		var guard_height=texture.get_image().get_used_rect().size.y
		if guard_height>0 and guard_height<target_height:
			var correction=float(target_height)/guard_height
			size*=correction
			anchor*=correction
			texture=fighter_texture(sheet,source,size,kind,pose_key)
	size=Vector2(texture.get_size())*PIXEL_UNIT
	anchor=snappedf(anchor,PIXEL_UNIT)
	var result={"texture":texture,"size":size,"anchor":anchor,"source":source,"sheet":sheet}
	pixel_frames[key]=result
	return result

func draw(canvas:Node2D,f:Dictionary,t:float,scale:float=1.0,portrait_mode:bool=false):
	var frame=pose(f,t)
	if portrait_mode: frame=[2,2,0,2][int(t*4)%4]
	var sprite=sprite_frame(f.kind,frame)
	var held=f.get("grabbed_by",-1)>=0
	var tossed=f.get("throw_flight",false)
	var pose_key="base:"+str(frame)
	if not portrait_mode:
		var m=move_tables.fighters[f.kind].moves.get(f.move,{})
		pose_key=CombatPose.key(f,m)
		var selected=pose_key.split(":")
		match selected[0]:
			"base": sprite=sprite_frame(f.kind,int(selected[1]))
			"grapple": sprite=grapple_art.sprite(f.kind,int(selected[1]),self)
			"throw": sprite=throw_frame(f.kind,int(selected[1]))
			"signature": sprite=signature_art.sprite(f,m,self)
			"movement": sprite=movement_art.sprite(f.kind,int(selected[1]),self)
			"style": sprite=style_art.sprite(selected[1])
	var size:Vector2=sprite.size
	var anchor:float=sprite.anchor
	var sheet:Texture2D=sprite.texture
	var source=Rect2(Vector2.ZERO,sheet.get_size())
	var top=-size.y
	cache_ground_contacts(sprite)
	if not portrait_mode:
		draw_contact_shadow(canvas,f,sprite,scale,held or tossed)
	var recoil=-4 if f.state=="hit" else 0
	# Knockdowns use fixed keyed poses; only position follows the fall arc.
	var origin=Vector2(f.x+recoil*f.facing,f.y)
	# Source crops occasionally contain a transparent bottom row. Align the opaque
	# soles to the simulation floor instead of letting the crop margin lift them.
	var paired_pose=f.get("grapple_role","")!=""
	if paired_pose or (not held and not tossed): origin.y+=float(sprite.ground_gap)*scale
	var rotation=0.0
	if (held or tossed) and not paired_pose:
		origin.y-=size.y*.5*scale
		top=-size.y*.5
		anchor=size.x*.5
		rotation=f.get("throw_rotation",0.0)
	canvas.draw_set_transform(origin,rotation,Vector2(f.facing*scale,scale))
	var rect=Rect2(-anchor,top,size.x,size.y)
	var element_move=move_tables.fighters[f.kind].moves.get(f.move,{}) if not portrait_mode else {}
	if not portrait_mode:
		style_art.draw_trail(canvas,f,element_move)
		element_effects.draw_aura(canvas,f,element_move,rect,sheet)
	var displayed=element_effects.tinted(sheet,ElementEffects.palette(f,element_move)) if not portrait_mode else sheet
	canvas.draw_texture_rect_region(displayed,rect,source)
	if not portrait_mode:
		element_effects.draw_reaction(canvas,f,pose_key,rect,sheet)
		element_effects.draw_front(canvas,f,element_move,rect)
	canvas.draw_set_transform(Vector2.ZERO)
	if not portrait_mode and f.state=="dizzy":
		dizzy_stars.draw(canvas,f,f.y-sprite_frame(f.kind,0).size.y*scale-22.0)

func cache_ground_contacts(sprite:Dictionary):
	if sprite.has("ground_contacts"): return
	var image:Image=sprite.texture.get_image()
	var used=image.get_used_rect()
	sprite.ground_gap=(image.get_height()-used.end.y)*PIXEL_UNIT
	sprite.ground_extent=Vector2(used.position.x,used.end.x)*PIXEL_UNIT
	var spans=[]
	var first=-1
	var last=-1
	var band=maxi(4,roundi(image.get_height()*.035))
	for x in image.get_width():
		var occupied=false
		for y in range(maxi(0,used.end.y-band),used.end.y):
			if image.get_pixel(x,y).a>=.5: occupied=true;break
		if occupied:
			if first<0: first=x
			last=x
		elif first>=0 and x-last>3:
			if last-first>=2: spans.append(Vector2(first,last+1)*PIXEL_UNIT)
			first=-1
	if first>=0: spans.append(Vector2(first,last+1)*PIXEL_UNIT)
	sprite.ground_contacts=spans

func draw_contact_shadow(canvas:Node2D,f:Dictionary,sprite:Dictionary,scale:float,airborne_pose:bool):
	var height=maxf(0,Combat.FLOOR-f.y)
	if height>2 or airborne_pose:
		var distance=clampf(height/280.0,0,1)
		var radius=lerpf(33.0,43.0,distance)*scale
		GroundShadow.draw(canvas,Vector2(f.x,Combat.FLOOR+1),radius,lerpf(4.5,7.0,distance),lerpf(.18,.06,distance))
		return
	var recoil=-4 if f.state=="hit" else 0
	var ground_x:float=f.x+recoil*f.facing
	var spans:Array=sprite.ground_contacts
	if spans.is_empty(): return
	var lying_down=f.state in ["down","ko"]
	var extent:Vector2=sprite.ground_extent if lying_down else Vector2(spans[0].x,spans[-1].y)
	var footprint=(extent.x+extent.y)*.5
	var footprint_x=ground_x+(footprint-float(sprite.anchor))*f.facing*scale
	var footprint_radius=(extent.y-extent.x)*.5*scale
	GroundShadow.draw(canvas,Vector2(footprint_x,Combat.FLOOR),footprint_radius+10,6.0 if lying_down else 5.0,.19 if lying_down else .12)
	for span in spans:
		var offset=(float(span.x+span.y)*.5-float(sprite.anchor))*f.facing*scale
		var radius=maxf(5,(span.y-span.x)*.5*scale+3)
		GroundShadow.draw(canvas,Vector2(ground_x+offset,Combat.FLOOR),radius,3.5,.35)

func throw_frame(kind:int,frame:int)->Dictionary:
	var key=kind*4+frame
	if throw_frames.has(key): return throw_frames[key]
	var entry=throw_atlases[str(kind)]
	var r=entry.regions[frame]
	var source=Rect2(r[0],r[1],r[2],r[3])
	var units=138.0*presentation_scale(kind)/entry.height
	var texture=fighter_texture(entry.sheet,source,source.size*units,kind,"throw:"+str(frame))
	var result={"texture":texture,"size":Vector2(texture.get_size())*PIXEL_UNIT,"anchor":snappedf(entry.anchors[frame]*units,PIXEL_UNIT),"sheet":entry.sheet,"source":source}
	throw_frames[key]=result
	return result

func presentation_scale(kind:int)->float:
	return {2:.95,7:.985,8:1.1235,10:1.16,12:1.1235,13:1.04}.get(kind,1.0)

func portrait(canvas:Node2D,kind:int,rect:Rect2,flipped:bool=false):
	if not pixel_portraits.has(kind):
		pixel_portraits[kind]=pixel_texture(sheets[kind],portrait_regions[kind],Vector2(64,64),true)
	var texture:Texture2D=pixel_portraits[kind]
	var r=Rect2(Vector2.ZERO,texture.get_size())
	if flipped:
		canvas.draw_set_transform(Vector2(rect.end.x,rect.position.y),0,Vector2(-1,1))
		canvas.draw_texture_rect_region(texture,Rect2(Vector2.ZERO,rect.size),r)
		canvas.draw_set_transform(Vector2.ZERO)
	else: canvas.draw_texture_rect_region(texture,rect,r)
