extends Node2D
const Combat=preload("res://scripts/combat.gd")
const Commands=preload("res://scripts/commands.gd")
const Stage=preload("res://scripts/harbor_stage.gd")
const FighterArt=preload("res://scripts/fighter_sprites.gd")
const CPU=preload("res://scripts/cpu.gd")
const SfxBank=preload("res://scripts/sfx_bank.gd")
const ControllerBindings=preload("res://scripts/controller_bindings.gd")
const Announcer=preload("res://scripts/announcer.gd")
var announcer
var pads=ControllerBindings.new()
var controller_setup=false
var setup_device=-1
var setup_step=-1
var setup_bindings:Dictionary={}
var setup_release:Dictionary={}
var setup_message=""
var sim=Combat.new()
var stage=Stage.new()
var art=FighterArt.new()
var cpu=CPU.new()
var commands=[Commands.new(),Commands.new()]
var screen="title"
var selected_mode=0
var difficulty=1
var selection=[0,1]
var select_slot=0
var paused=false
var debug_boxes=false
var muted=false
var music_enabled=true
var clock=0.0
var pressed=[[],[]]
var effects:Array=[]
var shake=0.0
var logo:Texture2D=load("res://assets/logo.png")
var font:Font=preload("res://assets/fonts/UpheavalPro.ttf")
var sfx:SfxBank
var music:AudioStreamPlayer
var menu_music:AudioStreamPlayer
var match_end_audio:AudioStreamPlayer
var match_end_played=false
var ko_slowmo_frames=0
var simulation_accumulator=0.0
var buttons:Array=[]
var menu_cooldown=0
var last_pad_direction=""
var capture_path=""
var capture_ticks=0
var auto_demo=false
const BLUE=Color("65d5e6")
const GOLD=Color("efbc6d")
const WHITE=Color("e8efec")
const MUTED=Color("8199a7")
const RED=Color("f55e63")
const KEYS=[[KEY_Z,KEY_X,KEY_C,KEY_V,KEY_B],[KEY_F,KEY_G,KEY_H,KEY_J,KEY_R]]
const ATTACKS=["lp","hp","lk","hk","throw"]

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	stage.attach(self)
	setup_audio()
	for id in Input.get_connected_joypads(): controller_connection(id,true)
	Input.joy_connection_changed.connect(controller_connection)
	for arg in OS.get_cmdline_user_args():
		if arg=="--show-match":
			selected_mode=2
			begin_match()
		if arg=="--show-select": screen="select"
		if arg=="--demo":
			auto_demo=true
			selected_mode=2
			begin_match()
		if arg.begins_with("--capture="): capture_path=arg.trim_prefix("--capture=")
	sync_match_end_audio()
	queue_redraw()

func setup_audio():
	announcer=Announcer.new()
	add_child(announcer)
	sfx=SfxBank.new()
	add_child(sfx)
	music=AudioStreamPlayer.new()
	add_child(music)
	var stream=load("res://audio/go-straight.mp3") as AudioStreamMP3
	stream.loop=true
	music.stream=stream
	music.volume_db=-13
	menu_music=AudioStreamPlayer.new()
	add_child(menu_music)
	var menu_stream=load("res://audio/never-return-alive.mp3") as AudioStreamMP3
	menu_stream.loop=true
	menu_music.stream=menu_stream
	menu_music.volume_db=-13
	match_end_audio=AudioStreamPlayer.new()
	add_child(match_end_audio)
	match_end_audio.stream=load("res://audio/level-complete.mp3")
	match_end_audio.volume_db=-9
	# Match music stays beneath combat sounds; KO voices retain normal pitch/speed.

func sync_match_end_audio():
	var at_results=screen=="match" and sim.phase=="results"
	var during_fight=screen=="match" and sim.phase in ["intro","fight"]
	var in_menu=screen in ["title","select"]
	if screen!="match": announcer.clear()
	# Stop outgoing tracks before starting the next screen's audio.
	if not in_menu or not music_enabled: menu_music.stop()
	if not during_fight or not music_enabled: music.stop()
	if not at_results:
		match_end_audio.stop()
		match_end_played=false
	if music_enabled and during_fight:
		if not music.playing and not music.stream_paused: music.play()
	if music_enabled and in_menu and not menu_music.playing: menu_music.play()
	music.stream_paused=paused
	music.volume_db=-19 if announcer.playing else -13
	match_end_audio.stream_paused=paused
	announcer.stream_paused=paused
	match_end_audio.volume_db=-17 if announcer.playing or not announcer.pending.is_empty() else -9
	if at_results:
		if not match_end_played:
			match_end_played=true
			match_end_audio.play()
			announcer.say(["you","lose" if selected_mode==0 and sim.winner==1 else "win"])

func sound(name:String):
	if not muted: sfx.play(name)

func toggle_pause():
	paused=not paused
	clear_controls()
	sfx.set_paused(paused)
	sync_match_end_audio()
	sound("pause")

func _input(event):
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller_event(event)
		return
	if controller_setup:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_F4]:
			controller_setup=false
			clear_controls()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var p=get_global_mouse_position()
		for b in buttons:
			if b.rect.has_point(p): action(b.action); return
	if event is InputEventKey and event.pressed and not event.echo:
		var key=event.physical_keycode
		if key==0: key=event.keycode
		if key==KEY_F4:
			open_controller_setup()
			return
		if key==KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if key==KEY_M:
			muted=not muted
			AudioServer.set_bus_mute(0,muted)
			return
		if key==KEY_N:
			music_enabled=not music_enabled
			sync_match_end_audio()
			return
		if screen=="match" and sim.phase!="results":
			if key==KEY_ESCAPE:
				toggle_pause()
				return
			if paused:
				if key==KEY_Q: action("title")
				return
			if key==KEY_F1: debug_boxes=not debug_boxes
			if key==KEY_F2 and sim.training: sim.dummy=(sim.dummy+1)%4
			if key==KEY_F3 and sim.training:
				sim.reset_round()
				for reader in commands: reader.reset()
			for i in 2:
				if key in KEYS[i]: pressed[i].append(ATTACKS[KEYS[i].find(key)])
		else:
			if key in [KEY_ENTER,KEY_SPACE]: action("confirm")
			if key==KEY_ESCAPE: action("back")
			if key in [KEY_UP,KEY_W]: action("up")
			if key in [KEY_DOWN,KEY_S]: action("down")
			if key in [KEY_LEFT,KEY_A]: action("left")
			if key in [KEY_RIGHT,KEY_D]: action("right")

func clear_controls():
	pressed=[[],[]]
	for reader in commands: reader.reset()
	last_pad_direction=""
	menu_cooldown=0

func controller_connection(id:int,connected:bool):
	if connected:
		pads.connect_device(id,Input.get_joy_guid(id)+"|"+Input.get_joy_name(id))
	else:
		var slot=pads.disconnect_device(id)
		clear_controls()
		if slot>=0 and screen=="match" and sim.phase!="results" and not paused: toggle_pause()
		if controller_setup and id==setup_device:
			setup_device=-1;setup_step=-1;setup_bindings.clear();setup_release.clear()
			setup_message="CONTROLLER DISCONNECTED. RECONNECT TO TRY AGAIN."

func open_controller_setup():
	if screen=="match" and sim.phase!="results" and not paused: toggle_pause()
	controller_setup=true
	setup_device=-1;setup_step=-1;setup_bindings={};setup_release={};setup_message=""
	clear_controls()

func controller_event(event:InputEvent):
	var slot=pads.slots.find(event.device)
	var bindings=pads.mapping(event.device)
	var before={}
	for name in ControllerBindings.STEPS: before[name]=pads.active(event.device,bindings[name])
	pads.ingest(event)
	if slot<0: return
	if controller_setup:
		capture_controller_binding(event)
		return
	var triggered=[]
	for name in ControllerBindings.STEPS:
		if not before[name] and pads.active(event.device,bindings[name]): triggered.append(name)
	if "pause" in triggered and screen=="match" and sim.phase!="results":
		toggle_pause();return
	if screen!="match" or sim.phase=="results" or paused:
		if "confirm" in triggered: action("confirm")
		elif "back" in triggered: action("back")
	else:
		for name in ATTACKS:
			if name in triggered: pressed[slot].append(name)

func capture_controller_binding(event:InputEvent):
	if setup_step>=ControllerBindings.STEPS.size(): return
	if setup_device<0:
		if event is InputEventJoypadButton and event.pressed:
			setup_device=event.device;setup_step=0
			setup_release=pads.binding_from_event(event)
		return
	if event.device!=setup_device: return
	if not setup_release.is_empty():
		if not pads.active(setup_device,setup_release): setup_release={}
		return
	var binding=pads.binding_from_event(event)
	if binding.is_empty(): return
	# Require neutral between steps and distinct gameplay controls; menu buttons may reuse attacks.
	if setup_step<10:
		for existing in setup_bindings.values():
			if existing==binding:
				setup_message="ALREADY USED. CHOOSE A DIFFERENT CONTROL."
				setup_release=binding
				return
	setup_bindings[ControllerBindings.STEPS[setup_step]]=binding
	setup_release=binding
	setup_message=""
	setup_step+=1
	if setup_step==ControllerBindings.STEPS.size():
		var error=pads.save_mapping(setup_device,setup_bindings)
		setup_message="SAVED. ESC TO RETURN." if error==OK else "COULD NOT SAVE. ESC TO RETURN AND TRY AGAIN."
		clear_controls()

func controller_menu_tick():
	if controller_setup or (screen=="match" and sim.phase!="results" and not paused): return
	var direction=""
	for id in pads.slots:
		if id<0: continue
		var d=pads.directions(id)
		if d.dx!=0: direction="left" if d.dx<0 else "right"
		elif d.up: direction="up"
		elif d.down: direction="down"
		if direction!="": break
	menu_cooldown=maxi(0,menu_cooldown-1)
	if direction!="" and (direction!=last_pad_direction or menu_cooldown==0):
		action(direction)
		menu_cooldown=18 if direction!=last_pad_direction else 7
	last_pad_direction=direction

func action(which:String):
	if which=="controllers":
		open_controller_setup()
		return
	if which=="title": sfx.stop_all()
	if which in ["up","down","left","right","difficulty"] or which.begins_with("fighter"):
		sound("menu_move")
	elif which in ["back","title"]: sound("menu_back")
	else: sound("menu_confirm")
	if which=="title":
		announcer.clear()
		screen="title"
		paused=false
		sync_match_end_audio()
		return
	if paused:
		if which in ["back","confirm","resume"]:
			paused=false
			sfx.set_paused(false)
		return
	if screen=="title":
		if which=="up": selected_mode=posmod(selected_mode-1,3)
		if which=="down": selected_mode=(selected_mode+1)%3
		if which in ["left","right"]: difficulty=posmod(difficulty+(-1 if which=="left" else 1),3)
		if which.begins_with("mode"):
			selected_mode=int(which[-1])
			which="confirm"
		if which=="difficulty": difficulty=(difficulty+1)%3
		if which=="confirm":
			screen="select"
			select_slot=0
	elif screen=="select":
		if which in ["left","right"]: selection[select_slot]=posmod(selection[select_slot]+(-1 if which=="left" else 1),sim.data.fighters.size())
		if which.begins_with("fighter"):
			selection[select_slot]=int(which[-1])
		if which=="back":
			if select_slot==1: select_slot=0
			else: screen="title"
		if which=="confirm":
			if select_slot==0:
				select_slot=1
				selection[1]=(selection[0]+1)%sim.data.fighters.size()
			else: begin_match()
	elif screen=="match" and sim.phase=="results":
		if which in ["confirm","rematch"]: begin_match()
		if which=="back":
			screen="title"
			sync_match_end_audio()

func begin_match():
	announcer.clear()
	screen="match"
	paused=false
	ko_slowmo_frames=0
	simulation_accumulator=0.0
	sfx.stop_all()
	sfx.set_paused(false)
	sound("menu_confirm")
	pressed=[[],[]]
	effects.clear()
	for reader in commands: reader.reset()
	sim.new_match(selection[0],selection[1],selected_mode==2)
	sync_match_end_audio()
	cpu=CPU.new()

func read_control(slot:int)->Dictionary:
	var move_keys=[KEY_LEFT,KEY_RIGHT,KEY_DOWN,KEY_UP] if slot==0 else [KEY_A,KEY_D,KEY_S,KEY_W]
	var dx=int(Input.is_physical_key_pressed(move_keys[1]))-int(Input.is_physical_key_pressed(move_keys[0]))
	var down=Input.is_physical_key_pressed(move_keys[2])
	var up=Input.is_physical_key_pressed(move_keys[3])
	if pads.slots[slot]>=0:
		var direction=pads.directions(pads.slots[slot])
		if direction.dx!=0: dx=direction.dx
		down=down or direction.down
		up=up or direction.up
	var facing=int(sim.fighters[slot].facing)
	var direction=Commands.relative_direction(dx,down,up,facing)
	var command=commands[slot].sample(direction,pressed[slot])
	pressed[slot]=[]
	return {"dx":dx,"down":down,"up":up,"back":dx*facing<0,"command":command}

func combat_time_scale()->float:
	if ko_slowmo_frames>24: return 0.25
	if ko_slowmo_frames>0: return 0.5
	return 1.0

func dispatch_combat_event(event:Dictionary):
	if event.type=="fight": announcer.say(["fight"])
	if event.type=="ko":
		announcer.clear()
		# Cut the track before starting the defeat scream on this same frame.
		music.stop()
		if not sim.training and sim.winner>=0 and sim.wins[sim.winner]>=2 and sim.fighters[1-sim.winner].health<=0:
			ko_slowmo_frames=72
			simulation_accumulator=0.0
	if not muted: sfx.combat_event(event,sim)

func _physics_process(delta):
	controller_menu_tick()
	sfx.set_paused(paused)
	if not paused and not controller_setup:
		var time_scale=combat_time_scale()
		clock+=delta*time_scale
		ko_slowmo_frames=maxi(0,ko_slowmo_frames-1)
		for effect in effects: effect.life-=1
		effects=effects.filter(func(e): return e.life>0)
		shake=maxf(0,shake-.9)
		if screen=="match":
			var p1=read_control(0)
			var p2=read_control(1)
			if selected_mode==0: p2=cpu.control(sim,1,difficulty)
			if sim.training:
				p2={"dx":0,"down":sim.dummy in [1,3],"up":false,"back":sim.dummy in [2,3],"command":""}
			if auto_demo:
				p1=cpu.control(sim,0,2)
			simulation_accumulator+=time_scale
			if simulation_accumulator>=1.0:
				simulation_accumulator-=1.0
				sim.step([p1,p2])
			else: sim.events.clear()
			for event in sim.events:
				dispatch_combat_event(event)
				if event.type in ["hit","block"]:
					effects.append({"x":event.x,"y":event.y,"life":13,"type":event.type,"heavy":event.heavy})
					if event.type=="hit": shake=4 if event.heavy else 2
	sync_match_end_audio()
	capture_ticks+=1
	queue_redraw()
	if capture_path!="" and capture_ticks==12:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("SCREENSHOT ",capture_path)

func txt(value:String,x:float,y:float,size:int=20,color:Color=WHITE,_mono:bool=false):
	draw_string(font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(value:String,y:float,size:int=20,color:Color=WHITE):
	var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	txt(value,(1280-width)*.5,y,size,color)

func panel(rect:Rect2,color:Color=Color(.025,.048,.074,.94),border:Color=Color(.18,.29,.35,.75)):
	draw_rect(rect,color)
	draw_rect(rect,border,false,1)

func button(label:String,rect:Rect2,command:String,active:bool=false):
	var p=rect.position
	var end=rect.end
	if active:
		draw_colored_polygon(PackedVector2Array([p+Vector2(14,0),Vector2(end.x,p.y),end-Vector2(14,0),Vector2(p.x,end.y)]),Color(.42,.055,.07,.90))
		draw_line(p+Vector2(14,0),Vector2(end.x,p.y),GOLD,2)
		draw_line(Vector2(p.x,end.y),end-Vector2(14,0),Color(.42,.23,.12),2)
	var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
	arcade_text(label,p.x+(rect.size.x-width)*.5,p.y+rect.size.y*.5+9,25,GOLD if active else WHITE)
	buttons.append({"rect":rect,"action":command})

func _draw():
	buttons.clear()
	stage.draw(self,clock)
	if screen=="title": draw_title()
	elif screen=="select": draw_select()
	else:
		draw_match()
		if paused: draw_pause()
	if controller_setup: draw_controller_setup()
	# Subtle film-line texture, kept out of contrast-critical fighter details.
	for y in range(0,720,4): draw_line(Vector2(0,y),Vector2(1280,y),Color(0,0,0,.035),1)

func draw_title():
	draw_rect(Rect2(0,0,1280,720),Color(.005,.008,.025,.49))
	draw_texture_rect(logo,Rect2(270,35,740,284),false)
	for i in 3:
		button(["ARCADE","VERSUS","TRAINING"][i],Rect2(472,399+i*49,336,43),"mode"+str(i),selected_mode==i)
	button("CPU  "+["EASY","NORMAL","HARD"][difficulty],Rect2(472,564,336,35),"difficulty")
	centered("PRESS ENTER",636,22,Color(1,.9,.65,.65+.35*sin(clock*3)))
	button("CONTROLLER SETUP / F4",Rect2(448,652,384,30),"controllers")
	centered("ARROWS SELECT   /   ENTER CONFIRM   /   F11 FULLSCREEN",701,13,MUTED)

func draw_select():
	draw_rect(Rect2(0,0,1280,720),Color(.005,.008,.025,.72))
	centered("SELECT YOUR FIGHTER",80,49,GOLD)
	centered(("PLAYER 1" if select_slot==0 else ("PLAYER 2" if selected_mode==1 else "OPPONENT"))+"  /  LEFT OR RIGHT TO CHOOSE",115,16,WHITE)
	for i in sim.data.fighters.size():
		var active=selection[select_slot]==i
		var x=160+i*320
		var fd=sim.data.fighters[i]
		var color=Color(fd.color)
		if active:
			draw_colored_polygon(PackedVector2Array([Vector2(x-100,170),Vector2(x+145,170),Vector2(x+100,582),Vector2(x-145,582)]),Color(color,.12))
			draw_line(Vector2(x-145,582),Vector2(x+100,582),GOLD,4)
		var f=sim.make_fighter(i,i)
		f.x=x;f.y=570;f.facing=1 if i%2==0 else -1
		art.draw(self,f,clock,2.15,true)
		var width=font.get_string_size(fd.name,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
		arcade_text(fd.name,x-width*.5,614,34,color)
		var role="CONTROL / ANTI-AIR" if fd.style==0 else "SPEED / PRESSURE"
		var role_width=font.get_string_size(role,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		txt(role,x-role_width*.5,638,13,WHITE)
		buttons.append({"rect":Rect2(x-147,150,294,490),"action":"fighter"+str(i)})
	button("CONFIRM / ENTER",Rect2(475,654,330,48),"confirm",true)
	txt("ESC BACK",33,701,14,MUTED,true)

func draw_match():
	if sim.phase=="results":
		draw_results()
		return
	for f in sim.fighters: art.draw(self,f,clock,Combat.FIGHTER_SCALE)
	for p in sim.projectiles:
		for i in range(5,0,-1): draw_circle(Vector2(p.x-i*p.facing*8,p.y),14-i*1.7,Color(.3,.8,.96,.11*(6-i)))
		draw_circle(Vector2(p.x,p.y),17,Color(.2,.77,.95,.3))
		draw_arc(Vector2(p.x,p.y),16,clock*20,clock*20+4.8,20,BLUE,4,true)
		draw_circle(Vector2(p.x,p.y),7,WHITE)
	for e in effects:
		var color=BLUE if e.type=="block" else GOLD
		var ratio=float(e.life)/13
		for i in 8:
			var angle=i*TAU/8+.2
			var a=Vector2(e.x,e.y)+Vector2.from_angle(angle)*(10+(1-ratio)*22)
			var b=a+Vector2.from_angle(angle)*(8+ratio*16)
			draw_line(a,b,Color(color,ratio),3,true)
	if debug_boxes:
		for f in sim.fighters:
			draw_rect(sim.hurtbox(f),Color(0,1,.3,.19))
			draw_rect(sim.pushbox(f),Color(.3,.6,1,.6),false,2)
			if sim.is_active(f): draw_rect(sim.attackbox(f,sim.move_data(f)),Color(1,.2,.2,.4))
	draw_hud()
	if sim.phase=="intro":
		if sim.phase_timer>55:
			banner("INNER HARBOR DOCKS","BALTIMORE, MD",GOLD)
		else: banner("ROUND "+str(sim.round_number),"MAKE IT COUNT",WHITE)
	elif sim.phase=="fight" and not sim.training and sim.time_left>99*60-42:
		centered("FIGHT",310,74,GOLD)
	elif sim.phase=="round_end": banner(sim.last_result,"DRAW — REPLAY ROUND" if sim.winner<0 else sim.data.fighters[sim.fighters[sim.winner].kind].name+" TAKES THE ROUND",WHITE)
	elif sim.phase=="results": draw_results()
	if sim.training:
		draw_rect(Rect2(26,146,338,94),Color(.005,.01,.02,.68))
		txt("TRAINING / "+["STAND","CROUCH","STAND GUARD","CROUCH GUARD"][sim.dummy],41,171,17,GOLD)
		txt("F2 DUMMY   F3 RESET   F1 BOXES",41,195,13,MUTED,true)
		txt("INPUT  "+" ".join(commands[0].display.slice(0,8)),41,224,14,WHITE,true)
		
	for i in 2:
		var f=sim.fighters[i]
		if f.combo>=2:
			txt(str(f.combo)+" HITS",935 if i==0 else 244,200,30,GOLD)
	txt("P1  ARROWS + Z X C V / B",30,707,13,MUTED,true)
	txt("ESC PAUSE / MOVES",530,707,13,MUTED,true)
	txt("P2  WASD + F G H J / R",948,707,13,MUTED,true)

func draw_hud():
	# Portraits, beveled life meters, and outlined names float over the stage.
	for i in 2:
		var f=sim.fighters[i]
		var x=112 if i==0 else 713
		var portrait_x=27 if i==0 else 1171
		draw_rect(Rect2(portrait_x-3,27,84,84),Color("090b12"))
		draw_rect(Rect2(portrait_x-3,27,84,84),GOLD,false,2)
		art.portrait(self,f.kind,Rect2(portrait_x,30,78,78),i==1)
		var p=Vector2(x,41)
		var w=455.0
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-3),p+Vector2(w+7,-3),p+Vector2(w-3,30),p+Vector2(0,30)]),Color("06070c"))
		draw_rect(Rect2(x,41,w,25),Color("641a22"))
		var health=w*float(f.health)/1000
		var hx=x if i==0 else x+w-health
		for line in 21:
			var shade=Color("ffe7a2").lerp(Color("c98930"),float(line)/21)
			draw_rect(Rect2(hx,43+line,health,1),shade)
		draw_line(Vector2(x,39),Vector2(x+w+6,39),Color("ede1c3"),2)
		draw_line(Vector2(x,68),Vector2(x+w,68),Color("8a5d35"),2)
		var name=sim.data.fighters[f.kind].name
		var name_x=x if i==0 else x+w-font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x
		arcade_text(name,name_x,98,27,WHITE)
		var color=Color(sim.data.fighters[f.kind].color)
		arcade_text("1P" if i==0 else (["CPU","2P","TRAINING"][selected_mode]),x if i==0 else x+w-65,28,15,color)
		for j in 2:
			var center=Vector2(x+14+j*25 if i==0 else x+w-14-j*25,117)
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-6),center+Vector2(6,0),center+Vector2(0,6),center+Vector2(-6,0)]),GOLD if sim.wins[i]>j else Color("3b3330"))
	arcade_text("KO",621,29,19,RED)
	var timer="--" if sim.training else str(maxi(0,ceili(sim.time_left/60.0))).pad_zeros(2)
	var tw=font.get_string_size(timer,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
	arcade_text(timer,640-tw*.5,89,64,GOLD)
	centered("ROUND "+str(sim.round_number),115,13,WHITE)

func banner(title:String,subtitle:String,color:Color):
	var w=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
	arcade_text(title,(1280-w)*.5,324,64,color)
	var sw=font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	arcade_text(subtitle,(1280-sw)*.5,362,20,WHITE)

func draw_results():
	draw_rect(Rect2(0,0,1280,720),Color(.005,.015,.035,.78))
	draw_texture_rect(logo,Rect2(445,65,390,150),false)
	var name=sim.data.fighters[sim.fighters[sim.winner].kind].name
	for line in [[name,297,57,GOLD],["WINS",373,71,WHITE],[str(sim.wins[0])+" : "+str(sim.wins[1]),438,34,GOLD]]:
		var width=font.get_string_size(line[0],HORIZONTAL_ALIGNMENT_LEFT,-1,line[2]).x
		arcade_text(line[0],640-width*.5,line[1],line[2],line[3])
	button("REMATCH / ENTER",Rect2(440,517,400,51),"rematch",true)
	button("MAIN MENU / ESC",Rect2(440,580,400,47),"title")

func draw_pause():
	draw_rect(Rect2(0,0,1280,720),Color(.005,.012,.025,.91))
	txt("PAUSED / MOVE LIST",45,62,35,GOLD)
	txt("Directions are relative: 6 forward, 4 back, 2 down, 8 up. P = LP or HP.",46,91,16,MUTED,true)
	for i in 2:
		var x=46+i*620
		var d=sim.data.fighters[sim.fighters[i].kind]
		panel(Rect2(x,117,587,319))
		txt(d.name,x+20,152,28,Color(d.color))
		var lines=["236 + P    "+d.moves.special1.name,"623 + P    "+d.moves.special2.name,"THROW      "+d.moves.throw.name,"Throws beat guard","LP > HP > 236 P","c.LK > 236 P" if d.style==0 else "LP > HP > 236 P > 623 P","Jump + button: overhead / Down + kick: low"]
		for j in lines.size(): txt(lines[j],x+20,187+j*32,15,WHITE if j<4 else MUTED,true)
	txt("PLAYER 1",47,474,20,BLUE)
	txt("Arrows move | Z LP  X HP  C LK  V HK  B throw",47,505,15,WHITE,true)
	txt("PLAYER 2",668,474,20,RED)
	txt("WASD move | F LP  G HP  H LK  J HK  R throw",668,505,15,WHITE,true)
	txt("GAMEPAD: D-pad / stick move. Default: X LP / Y HP / A LK / B HK / LB throw. F4 remaps pad only.",47,548,14,MUTED,true)
	txt("Hold BACK to guard. DOWN + BACK guards lows. Throws beat guard. N music / M mute / F11 fullscreen.",47,579,14,MUTED,true)
	txt("Double-tap forward/back to DASH. Training: F2 dummy / F3 reset / F1 boxes.",47,609,13,MUTED,true)
	button("RESUME / ESC",Rect2(47,642,380,48),"resume",true)
	button("MAIN MENU / Q",Rect2(856,642,378,48),"title")
	button("CONTROLLER / F4",Rect2(442,642,398,48),"controllers")

func draw_controller_setup():
	buttons.clear()
	draw_rect(Rect2(0,0,1280,720),Color(.008,.02,.04,.98))
	centered("CONTROLLER SETUP",93,44,GOLD)
	centered("KEYBOARD CONTROLS STAY UNCHANGED",134,18,BLUE)
	var y=192
	for slot in 2:
		var id=pads.slots[slot]
		var name=Input.get_joy_name(id) if id>=0 else "NOT CONNECTED"
		if name.length()>65: name=name.left(62)+"..."
		txt("P"+str(slot+1)+"  "+name,110,y,18,WHITE)
		y+=34
	if setup_device<0:
		centered("PRESS ANY BUTTON ON THE PAD TO CONFIGURE",349,25,GOLD)
		centered("PAIR IN WINDOWS BLUETOOTH SETTINGS FIRST",395,19,MUTED)
	elif setup_step<ControllerBindings.STEPS.size():
		centered("PLAYER "+str(pads.slots.find(setup_device)+1)+"  /  STEP "+str(setup_step+1)+" OF 12",302,20,BLUE)
		centered(ControllerBindings.LABELS[setup_step],368,33,GOLD)
		centered("RELEASE, THEN PRESS THE CONTROL YOU WANT TO USE",418,18,WHITE)
	else:
		centered("CONTROLLER READY",352,34,GOLD)
	centered(setup_message,487,18,RED if setup_message.begins_with("COULD") else WHITE)
	centered("SEGA: X / Z PUNCHES    A / C KICKS    Y THROW    START PAUSE",565,18,MUTED)
	centered("ESC / F4 TO CLOSE  /  INCOMPLETE CHANGES ARE NOT SAVED",641,17,MUTED)

func arcade_text(value:String,x:float,y:float,size:int,color:Color=WHITE):
	draw_string_outline(font,Vector2(x+3,y+4),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,7,Color(0,0,0,.9))
	draw_string_outline(font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color("110f13"))
	draw_string(font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
