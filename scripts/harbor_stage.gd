extends RefCounted
const HarborRat=preload("res://scripts/harbor_rat.gd")
const GraveyardCrows=preload("res://scripts/graveyard_crows.gd")
const PAN=56.0
const VIEW_WIDTH=1280.0
const VIEW_HEIGHT=720.0
const FIGHT_FLOOR=622.0
var panoramic=false
var crows=GraveyardCrows.new()
var crow_start_time=-1.0
var rat=HarborRat.new()
var rat_start_time=-1.0
const STAGE_NAMES=["INNER HARBOR DOCKS","DUNDALK DOCKS","GRAFFITI ALLEY","EUTAW STREET / CAMDEN YARDS","POWER PLANT LIVE!","WESTMINSTER / POE'S GRAVE","BREWERS HILL"]
const GRAFFITI_WINDOW_REGIONS=[Rect2(715,365,77,79),Rect2(625,378,46,104),Rect2(1006,415,77,31),Rect2(1132,400,43,46)]
const CAMDEN_CROWD_REGIONS=[Rect2(44,478,222,116),Rect2(366,499,168,95),Rect2(534,466,702,128),Rect2(1327,499,34,47),Rect2(1498,499,114,95)]
const POWERPLANT_NEON_REGIONS=[Rect2(687,126,537,87),Rect2(47,278,331,147),Rect2(479,350,311,105),Rect2(1250,283,332,157)]
const POWERPLANT_REFLECTION_REGIONS=[Rect2(8,735,210,94),Rect2(450,751,316,98),Rect2(1198,751,348,94)]
const POWERPLANT_CROWD_REGIONS=[Rect2(0,498,1672,198)]
const DUNDALK_SIGN_REGION=Rect2(1164,335,155,94)
var background:Texture2D=load("res://assets/harbor.png")
var water_material:ShaderMaterial
var docks_material:ShaderMaterial
var docks:Texture2D=preload("res://assets/seagirt.png")
var graffiti:Texture2D
var graffiti_material:ShaderMaterial
var camden:Texture2D
var camden_material:ShaderMaterial
var powerplant:Texture2D
var powerplant_material:ShaderMaterial
var backdrop:Sprite2D
var at_seagirt=false
var at_graffiti=false
var at_camden=false
var at_powerplant=false
var at_graveyard=false
var graveyard:Texture2D
var graveyard_material:ShaderMaterial
var last_stage=-1
var history_loaded=false
var history_path="user://stage-history.cfg"
var first_match_pending=true
var at_bonus=false
var bonus_texture:Texture2D
var bonus_material:ShaderMaterial
var bonus_kind="car"
var at_brewers=false
var brewers:Texture2D
var brewers_material:ShaderMaterial

func set_bonus(enabled:bool,kind:String="car"):
	bonus_kind=kind
	if enabled and kind!="car": set_stage(6 if kind=="kegs" else 1)
	at_bonus=enabled
	if enabled and kind=="car":
		backdrop.texture=bonus_texture
		backdrop.material=bonus_material
		layout_backdrop()

func stage_name()->String:
	if at_bonus: return {"car":"FELLS POINT / CAR CRUSH","kegs":"BREWERS HILL / KEG BREAK","boxes":"DUNDALK / BOX BREAK"}[bonus_kind]
	if at_brewers: return STAGE_NAMES[6]
	if at_graveyard: return STAGE_NAMES[5]
	return STAGE_NAMES[4] if at_powerplant else (STAGE_NAMES[3] if at_camden else (STAGE_NAMES[2] if at_graffiti else (STAGE_NAMES[1] if at_seagirt else STAGE_NAMES[0])))

func current_index()->int:
	if at_brewers: return 6
	if at_graveyard: return 5
	if at_powerplant: return 4
	if at_camden: return 3
	if at_graffiti: return 2
	return 1 if at_seagirt else 0

func set_stage(index:int):
	rat_start_time=-1.0
	crow_start_time=-1.0
	at_bonus=false
	at_seagirt=index==1
	at_graffiti=index==2
	at_camden=index==3
	at_powerplant=index==4
	at_graveyard=index==5
	at_brewers=index==6
	backdrop.texture=graveyard if at_graveyard else (powerplant if at_powerplant else (camden if at_camden else (graffiti if at_graffiti else (docks if at_seagirt else background))))
	backdrop.material=graveyard_material if at_graveyard else (powerplant_material if at_powerplant else (camden_material if at_camden else (graffiti_material if at_graffiti else (docks_material if at_seagirt else water_material))))
	if at_brewers: backdrop.texture=brewers;backdrop.material=brewers_material
	layout_backdrop()

func set_panorama(enabled:bool):
	if panoramic==enabled: return
	panoramic=enabled
	layout_backdrop()

func layout_backdrop():
	# Uniform overscan leaves real stage art on both sides without changing shader UVs.
	# Keep one extra pixel of sampling room at either end of camera travel.
	var margin=PAN+1.0 if panoramic else 0.0
	var scale_factor=1.0+2.0*margin/VIEW_WIDTH
	backdrop.position=Vector2(-margin,FIGHT_FLOOR*(1.0-scale_factor))
	backdrop.scale=Vector2(VIEW_WIDTH,VIEW_HEIGHT)*scale_factor/backdrop.texture.get_size()

static func camera_target(left:float,right:float)->float:
	var center=(left+right)*.5-VIEW_WIDTH*.5
	var travel=signf(center)*clampf((absf(center)-64.0)*.32,0.0,PAN)
	# Preserve space at the screen edge when the fighters spread apart.
	return clampf(travel,maxf(-PAN,right-VIEW_WIDTH+68.0),minf(PAN,left-68.0))

func select_random():
	# One Harbor opener per application session; returning to menus never resets it.
	var history=ConfigFile.new()
	if not history_loaded:
		if history.load(history_path)==OK:
			last_stage=int(history.get_value("stages","last_stage",-1))
		history_loaded=true
	var choices=[]
	for index in STAGE_NAMES.size():
		if index!=last_stage: choices.append(index)
	var next_stage=0 if first_match_pending else int(choices.pick_random())
	first_match_pending=false
	last_stage=next_stage
	history.set_value("stages","last_stage",last_stage)
	var saved=history.save(history_path)
	if saved!=OK: push_warning("Could not save stage history: "+error_string(saved))
	set_stage(next_stage)

static func water_frame(t:float)->int:
	return int(floor(t*4.0))%2

func draw_ambient(canvas:Node2D,t:float):
	if at_graveyard and not at_bonus:
		if crow_start_time<0: crow_start_time=t
		crows.draw(canvas,t-crow_start_time)
		return
	if at_bonus or at_seagirt or at_graffiti or at_camden or at_powerplant or at_brewers: return
	if rat_start_time<0: rat_start_time=t
	rat.draw(canvas,t-rat_start_time)

func attach(parent:Node2D):
	var brewers_image=Image.new()
	brewers_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/brewers-hill.png"))
	brewers=ImageTexture.create_from_image(brewers_image)
	var brewers_shader=Shader.new()
	brewers_shader.code="""
shader_type canvas_item;
uniform int water_frame=0;
void fragment() {
    vec4 base=texture(TEXTURE,UV);
    // One fixed painting: only Natty Boh's existing red tubes and reflection flicker.
    float sign=step(.586,UV.x)*step(UV.x,.683)*step(.050,UV.y)*step(UV.y,.207);
    float red=smoothstep(.16,.38,base.r-max(base.g,base.b))*smoothstep(.40,.72,base.r);
    float reflection=step(.72,UV.y)*step(.50,UV.x)*step(UV.x,.78);
    base.rgb*=1.0-float(water_frame)*red*max(sign*.14,reflection*.055);
    COLOR=base;
}
"""
	brewers_material=ShaderMaterial.new();brewers_material.shader=brewers_shader
	var graveyard_image=Image.new()
	graveyard_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/poe-graveyard.png"))
	graveyard=ImageTexture.create_from_image(graveyard_image)
	var graveyard_shader=Shader.new()
	graveyard_shader.code="""
shader_type canvas_item;
uniform int water_frame=0;
void fragment() {
    vec4 base=texture(TEXTURE,UV);
    // Two matching storm-cloud light states; graves, trees and church stay fixed.
    float gray=1.0-smoothstep(.035,.12,max(base.r,max(base.g,base.b))-min(base.r,min(base.g,base.b)));
    float clouds=(1.0-smoothstep(.105,.145,UV.y))*smoothstep(.12,.28,base.r)*gray;
    base.rgb+=float(water_frame)*clouds*.024;
    COLOR=base;
}
"""
	graveyard_material=ShaderMaterial.new()
	graveyard_material.shader=graveyard_shader
	var bonus_image=Image.new()
	bonus_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/fells-point.png"))
	bonus_texture=ImageTexture.create_from_image(bonus_image)
	var bonus_shader=Shader.new()
	bonus_shader.code="""
shader_type canvas_item;
uniform int water_frame=0;
float person(vec2 p,vec2 head,vec2 torso,vec2 body_radius) {
    float face=1.0-step(1.0,length((p-head)/vec2(15.0,19.0)));
    float body=1.0-step(1.0,length((p-torso)/body_radius));
    return max(face,body);
}
void fragment() {
    vec4 base=texture(TEXTURE,UV);
    vec2 p=UV*vec2(1672.0,941.0);
    float warm=smoothstep(.10,.30,base.r-base.b)*smoothstep(.35,.75,base.r);
    // Architecture and sign lettering remain fixed across both states.
    float windows=1.0-step(410.0,p.y);
    float street=step(690.0,p.y)*step(.68,fract(p.y*.19));
    base.rgb+=float(water_frame)*warm*max(windows*.045,street*.027)*vec3(1.0,.64,.24);
    // Two source pixels of upper-body cheer; feet and the stone curb stay fixed.
    float fans=person(p,vec2(104.0,439.0),vec2(102.0,507.0),vec2(43.0,67.0));
    fans=max(fans,person(p,vec2(489.0,440.0),vec2(486.0,506.0),vec2(32.0,64.0)));
    fans=max(fans,person(p,vec2(553.0,451.0),vec2(551.0,517.0),vec2(28.0,63.0)));
    fans=max(fans,person(p,vec2(610.0,444.0),vec2(611.0,514.0),vec2(29.0,66.0)));
    fans=max(fans,person(p,vec2(1180.0,491.0),vec2(1177.0,547.0),vec2(39.0,42.0)));
    fans=max(fans,person(p,vec2(1288.0,454.0),vec2(1286.0,518.0),vec2(29.0,65.0)));
    fans=max(fans,person(p,vec2(1343.0,454.0),vec2(1341.0,519.0),vec2(28.0,65.0)));
    // Small patrons behind the pub windows move too; fixed window mullions do not.
    float inside=person(p,vec2(182.0,445.0),vec2(182.0,478.0),vec2(18.0,20.0));
    inside=max(inside,person(p,vec2(230.0,450.0),vec2(230.0,478.0),vec2(19.0,20.0)));
    inside=max(inside,person(p,vec2(282.0,451.0),vec2(282.0,478.0),vec2(18.0,20.0)));
    inside=max(inside,person(p,vec2(695.0,440.0),vec2(696.0,463.0),vec2(12.0,16.0)));
    inside=max(inside,person(p,vec2(723.0,442.0),vec2(724.0,463.0),vec2(12.0,16.0)));
    inside=max(inside,person(p,vec2(1090.0,455.0),vec2(1090.0,482.0),vec2(13.0,16.0)));
    inside=max(inside,person(p,vec2(1124.0,456.0),vec2(1124.0,482.0),vec2(13.0,16.0)));
    float iron=step(base.r+.03,base.g)*step(base.b+.02,base.g);
    fans=max(fans,inside*(1.0-iron));
    float lift=2.0*(1.0-smoothstep(553.0,583.0,p.y));
    vec4 people=texture(TEXTURE,UV+vec2(0.0,float(water_frame)*lift/941.0));
    COLOR=mix(base,people,fans);
}
"""
	bonus_material=ShaderMaterial.new();bonus_material.shader=bonus_shader
	# Decode source bytes directly so the Windows pack includes the new art without
	# requiring an editor-generated PNG import alongside the existing resources.
	var image=Image.new()
	var decoded=image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/graffiti-alley.png"))
	if decoded!=OK: push_error("Could not load Graffiti Alley: "+error_string(decoded))
	graffiti=ImageTexture.create_from_image(image)
	var camden_image=Image.new()
	var camden_decoded=camden_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/eutaw-street.png"))
	if camden_decoded!=OK: push_error("Could not load Eutaw Street: "+error_string(camden_decoded))
	camden=ImageTexture.create_from_image(camden_image)
	var powerplant_image=Image.new()
	var powerplant_decoded=powerplant_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/power-plant-live.png"))
	if powerplant_decoded!=OK: push_error("Could not load Power Plant Live: "+error_string(powerplant_decoded))
	powerplant=ImageTexture.create_from_image(powerplant_image)
	backdrop=Sprite2D.new()
	backdrop.texture=background
	backdrop.centered=false
	backdrop.scale=Vector2(1280.0/background.get_width(),720.0/background.get_height())
	backdrop.z_index=-20
	backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var shader=Shader.new()
	shader.code="""
shader_type canvas_item;
uniform int water_frame = 0;
void fragment() {
    vec2 p = UV;
    vec2 pixel = UV * vec2(1280.0,720.0);
    // Mask only unobstructed water; bollards, chains, boat and lamps stay fixed.
    float water = smoothstep(78.0,86.0,pixel.x)*(1.0-smoothstep(920.0,931.0,pixel.x));
    water *= smoothstep(388.0,394.0,pixel.y)*(1.0-smoothstep(436.0,443.0,pixel.y));
    // Exactly two fixed samples, alternating every quarter-second. No TIME warp.
    p.x += float(water_frame)*sin(UV.y*800.0)*0.0014*water;
    COLOR = texture(TEXTURE,p);
}
"""
	water_material=ShaderMaterial.new()
	water_material.shader=shader
	# Both poses sample the same painting. Only water and stack smoke move.
	var docks_shader=Shader.new()
	docks_shader.code="""
shader_type canvas_item;
uniform int water_frame = 0;
float neon(vec3 color) {
    return smoothstep(0.12,0.4,color.r-color.b)*smoothstep(0.45,0.85,color.r);
}
void fragment() {
    vec2 pixel = UV * vec2(1672.0, 941.0);
    // River surface inside the quays; exclude the foreground bollards.
    float left_edge = mix(648.0, 448.0, clamp((pixel.y-521.0)/113.0, 0.0, 1.0));
    float water = smoothstep(left_edge, left_edge+8.0, pixel.x);
    water *= (1.0-smoothstep(1455.0, 1463.0, pixel.x));
    water *= smoothstep(522.0, 529.0, pixel.y)*(1.0-smoothstep(628.0, 635.0, pixel.y));
    float bollard = smoothstep(1334.0, 1343.0, pixel.x)*(1.0-smoothstep(1410.0, 1419.0, pixel.x));
    bollard *= smoothstep(576.0, 582.0, pixel.y);
    water *= 1.0-bollard;
    // Narrow diagonal mask around the plume, ending above the chimney mouth.
    float plume_center = 348.0-(pixel.x-984.0)*0.32;
    float smoke = (1.0-smoothstep(12.0, 23.0, abs(pixel.y-plume_center)));
    smoke *= smoothstep(976.0, 990.0, pixel.x)*(1.0-smoothstep(1150.0, 1190.0, pixel.x));
    smoke *= 1.0-smoothstep(348.0, 353.0, pixel.y);
    vec2 offset = vec2(sin(pixel.y*0.57)*1.35*water, 0.0);
    offset += vec2(-1.1, 0.65)*smoke;
    // A single binary parameter, no continuous TIME animation or scene redraw.
    vec4 base=texture(TEXTURE, UV + float(water_frame)*offset/vec2(1672.0, 941.0));
    // The Domino Sugars lettering stays fixed; its warm halo brightens in frame 2.
    float sign_region=step(1164.0,pixel.x)*step(pixel.x,1319.0)*step(335.0,pixel.y)*step(pixel.y,429.0);
    if (sign_region>0.0) {
        vec2 texel=vec2(1.0/1672.0,1.0/941.0);
        float halo=neon(texture(TEXTURE,UV+vec2(3.0,0.0)*texel).rgb);
        halo=max(halo,neon(texture(TEXTURE,UV-vec2(3.0,0.0)*texel).rgb));
        halo=max(halo,neon(texture(TEXTURE,UV+vec2(0.0,3.0)*texel).rgb));
        halo=max(halo,neon(texture(TEXTURE,UV-vec2(0.0,3.0)*texel).rgb));
        float glow=max(neon(base.rgb),halo*.38);
        base.rgb+=float(water_frame)*sign_region*glow*vec3(.085,.033,.004);
    }
    COLOR = base;
}
"""
	docks_material=ShaderMaterial.new()
	docks_material.shader=docks_shader
	var graffiti_shader=Shader.new()
	graffiti_shader.code="""
shader_type canvas_item;
uniform int water_frame = 0;
float window_region(vec2 p, vec4 r) {
    return step(r.x,p.x)*step(p.x,r.z)*step(r.y,p.y)*step(p.y,r.w);
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec2 pixel = UV * vec2(1672.0, 941.0);
    // Clock faces, hands and every scene feature stay in the same pixel position.
    float front = 1.0-smoothstep(0.78, 1.0, length((pixel-vec2(901.0,262.0))/vec2(33.0,36.0)));
    float side = 1.0-smoothstep(0.78, 1.0, length((pixel-vec2(963.0,263.0))/vec2(12.0,31.0)));
    float clock_mask = max(front,side)*smoothstep(0.06,0.30,base.b-base.r);
    // A small blue reflection below the tower changes brightness, not geometry.
    float puddle = 1.0-smoothstep(0.55,1.0,length((pixel-vec2(919.0,805.0))/vec2(102.0,25.0)));
    puddle *= smoothstep(0.015,0.10,base.b-max(base.r,base.g));
    puddle *= step(0.1,sin(pixel.y*0.72));
    float mask = max(clock_mask,puddle*0.65);
    base.rgb += float(water_frame)*mask*vec3(0.008,0.035,0.080);
    // Sparse existing skyscraper windows brighten in the second fixed frame.
    // Window placement and the buildings themselves never move.
    float windows = window_region(pixel,vec4(715.0,365.0,792.0,444.0));
    windows = max(windows,window_region(pixel,vec4(625.0,378.0,671.0,482.0)));
    windows = max(windows,window_region(pixel,vec4(1006.0,415.0,1083.0,446.0)));
    windows = max(windows,window_region(pixel,vec4(1132.0,400.0,1175.0,446.0)));
    vec2 cell=floor(pixel/vec2(15.0,12.0));
    float selected=step(0.65,fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453));
    float lit=smoothstep(0.35,0.65,max(base.r,max(base.g,base.b)));
    // Complementary existing windows visibly brighten/dim in the second state.
    float twinkle=selected-(1.0-selected)*.65;
    base.rgb += float(water_frame)*windows*twinkle*lit*vec3(0.200,0.165,0.095);
    // Only two fixed light states. No TIME, scrolling, displacement or new art.
    COLOR = base;
}
"""
	graffiti_material=ShaderMaterial.new()
	graffiti_material.shader=graffiti_shader
	var camden_shader=Shader.new()
	camden_shader.code="""
shader_type canvas_item;
uniform int water_frame=0;
float crowd_region(vec2 p,vec4 r) {
    return step(r.x,p.x)*step(p.x,r.z)*step(r.y,p.y)*step(p.y,r.w);
}
float head_region(vec2 p,vec2 center,vec2 radius) {
    return 1.0-step(1.0,length((p-center)/radius));
}
void fragment() {
    vec2 dimensions=vec2(1672.0,941.0);
    vec2 pixel=UV*dimensions;
    vec4 base=texture(TEXTURE,UV);
    float bounds=crowd_region(pixel,vec4(44.0,478.0,266.0,594.0));
    bounds=max(bounds,crowd_region(pixel,vec4(366.0,499.0,534.0,594.0)));
    bounds=max(bounds,crowd_region(pixel,vec4(534.0,466.0,1236.0,594.0)));
    bounds=max(bounds,crowd_region(pixel,vec4(1327.0,499.0,1361.0,546.0)));
    bounds=max(bounds,crowd_region(pixel,vec4(1498.0,499.0,1612.0,594.0)));
    // Torso band plus individual cap/head shapes: avoid a rectangular strip
    // through the warehouse masonry above the spectators.
    float crowd=step(518.0,pixel.y);
    for(int i=0;i<22;i++) {
        float head_x=548.0+float(i)*32.5;
        crowd=max(crowd,head_region(pixel,vec2(head_x,526.0),vec2(16.0,26.0)));
    }
    for(int i=0;i<7;i++) {
        crowd=max(crowd,head_region(pixel,vec2(61.0+float(i)*34.0,526.0),vec2(15.0,25.0)));
    }
    for(int i=0;i<5;i++) {
        crowd=max(crowd,head_region(pixel,vec2(381.0+float(i)*33.0,525.0),vec2(15.0,24.0)));
        crowd=max(crowd,head_region(pixel,vec2(1528.0+float(i)*33.0,526.0),vec2(15.0,25.0)));
    }
    crowd=max(crowd,head_region(pixel,vec2(721.0,493.0),vec2(13.0,26.0)));
    crowd=max(crowd,head_region(pixel,vec2(844.0,497.0),vec2(12.0,24.0)));
    crowd=max(crowd,head_region(pixel,vec2(104.0,500.0),vec2(12.0,22.0)));
    crowd=max(crowd,head_region(pixel,vec2(1343.0,525.0),vec2(15.0,25.0)));
    crowd*=bounds;
    float carts=crowd_region(pixel,vec4(270.0,492.0,369.0,594.0));
    carts=max(carts,crowd_region(pixel,vec4(372.0,546.0,511.0,594.0)));
    carts=max(carts,crowd_region(pixel,vec4(1236.0,491.0,1327.0,594.0)));
    carts=max(carts,crowd_region(pixel,vec4(1354.0,546.0,1503.0,594.0)));
    carts=max(carts,crowd_region(pixel,vec4(1471.0,512.0,1505.0,555.0)));
    float smoke=crowd_region(pixel,vec4(478.0,430.0,548.0,546.0));
    smoke=max(smoke,crowd_region(pixel,vec4(1477.0,430.0,1532.0,546.0)));
    smoke*=step(0.6,min(base.r,min(base.g,base.b)))*(1.0-step(0.12,max(base.r,max(base.g,base.b))-min(base.r,min(base.g,base.b))));
    crowd*=1.0-max(carts,smoke);
    // Preserve the green iron railings and poles wherever they cross the crowd.
    float iron=step(base.r+0.015,base.g)*step(base.b+0.015,base.g);
    crowd*=1.0-iron;
    // One native crowd pixel of upper-body lift. Lower torsos settle at the rail.
    float cheer=2.0*(1.0-smoothstep(554.0,594.0,pixel.y));
    vec2 sample_pixel=pixel+vec2(0.0,float(water_frame)*cheer);
    sample_pixel=floor(sample_pixel/2.0)*2.0+vec2(1.5);
    vec4 fans=texture(TEXTURE,sample_pixel/dimensions);
    fans.rgb=floor(fans.rgb*31.0+0.5)/31.0;
    // Both states reuse the same painted people. No regenerated background frame.
    COLOR=mix(base,fans,crowd);
}
"""
	camden_material=ShaderMaterial.new()
	camden_material.shader=camden_shader
	var powerplant_shader=Shader.new()
	powerplant_shader.code="""
shader_type canvas_item;
uniform int water_frame=0;
float area(vec2 p,vec4 r) {
    return step(r.x,p.x)*step(p.x,r.z)*step(r.y,p.y)*step(p.y,r.w);
}
void fragment() {
    vec4 base=texture(TEXTURE,UV);
    vec2 p=UV*vec2(1672.0,941.0);
    float signs=area(p,vec4(687.0,126.0,1224.0,213.0));
    signs=max(signs,area(p,vec4(47.0,278.0,378.0,425.0)));
    signs=max(signs,area(p,vec4(479.0,350.0,790.0,455.0)));
    signs=max(signs,area(p,vec4(1250.0,283.0,1582.0,440.0)));
    float saturation=max(base.r,max(base.g,base.b))-min(base.r,min(base.g,base.b));
    signs*=smoothstep(0.18,0.40,saturation)*smoothstep(0.35,0.65,max(base.r,max(base.g,base.b)));
    float reflections=1.0-smoothstep(0.5,1.0,length((p-vec2(113.0,782.0))/vec2(105.0,47.0)));
    reflections=max(reflections,1.0-smoothstep(0.5,1.0,length((p-vec2(608.0,800.0))/vec2(158.0,49.0))));
    reflections=max(reflections,1.0-smoothstep(0.5,1.0,length((p-vec2(1372.0,798.0))/vec2(174.0,47.0))));
    reflections*=smoothstep(0.12,0.35,saturation);
    // Exactly two fixed glow intensities. Lettering and architecture stay fixed.
    base.rgb*=1.0+float(water_frame)*max(signs*0.045,reflections*0.035);
    // The front crowd uses the same fine grid, palette and two-pixel cheer as Eutaw.
    float bounds=area(p,vec4(0.0,498.0,1672.0,696.0));
    float crowd=step(550.0,p.y);
    float head_x=14.0+floor((p.x-14.0)/34.0+.5)*34.0;
    vec2 head=(p-vec2(head_x,541.0))/vec2(18.0,29.0);
    crowd=max(crowd,1.0-step(1.0,length(head)));
    crowd=max(crowd,1.0-step(1.0,length((p-vec2(514.0,523.0))/vec2(18.0,28.0))));
    crowd=max(crowd,1.0-step(1.0,length((p-vec2(1295.0,523.0))/vec2(18.0,28.0))));
    crowd*=bounds;
    // Pots, planters, fixed rails and the central lamp pole do not cheer.
    float props=area(p,vec4(222.0,590.0,331.0,696.0));
    props=max(props,area(p,vec4(677.0,590.0,779.0,696.0)));
    props=max(props,area(p,vec4(1177.0,590.0,1295.0,696.0)));
    props=max(props,area(p,vec4(1578.0,590.0,1672.0,696.0)));
    props=max(props,area(p,vec4(1189.0,498.0,1202.0,696.0)));
    props=max(props,area(p,vec4(0.0,588.0,1672.0,600.0)));
    props=max(props,area(p,vec4(0.0,671.0,1672.0,682.0)));
    float steel=(1.0-step(.16,saturation))*step(.3,max(base.r,max(base.g,base.b)))*step(580.0,p.y);
    crowd*=1.0-max(props,steel);
    float cheer=2.0*(1.0-smoothstep(560.0,588.0,p.y));
    vec2 sample_pixel=p+vec2(0.0,float(water_frame)*cheer);
    sample_pixel=floor(sample_pixel/2.0)*2.0+vec2(1.5);
    vec4 fans=texture(TEXTURE,sample_pixel/vec2(1672.0,941.0));
    fans.rgb=floor(fans.rgb*31.0+.5)/31.0;
    COLOR=mix(base,fans,crowd);
}
"""
	powerplant_material=ShaderMaterial.new()
	powerplant_material.shader=powerplant_shader
	backdrop.material=water_material
	parent.add_child(backdrop)

func draw(canvas:Node2D,t:float):
	if at_bonus and bonus_kind=="car":
		bonus_material.set_shader_parameter("water_frame",water_frame(t))
		return
	if water_material: water_material.set_shader_parameter("water_frame",water_frame(t))
	if docks_material: docks_material.set_shader_parameter("water_frame",water_frame(t))
	if graffiti_material: graffiti_material.set_shader_parameter("water_frame",water_frame(t))
	if camden_material: camden_material.set_shader_parameter("water_frame",water_frame(t))
	if powerplant_material: powerplant_material.set_shader_parameter("water_frame",water_frame(t))
	if graveyard_material: graveyard_material.set_shader_parameter("water_frame",water_frame(t))
	if brewers_material: brewers_material.set_shader_parameter("water_frame",water_frame(t))
	# The alley is a strict two-frame light loop, without continuous rain overlays.
	if at_graffiti or at_camden or at_powerplant or at_brewers: return
	for i in 58:
		var x=fposmod(i*73.7-t*95,1360)-40
		var y=fposmod(i*51.3+t*350,720)
		canvas.draw_line(Vector2(x,y),Vector2(x-3,y+13),Color(.65,.78,.85,.10),1)
