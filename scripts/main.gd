extends Node2D
const Combat=preload("res://scripts/combat.gd")
const GameSettings=preload("res://scripts/game_settings.gd")
const CarBonus=preload("res://scripts/car_bonus.gd")
const BreakablesBonus=preload("res://scripts/breakables_bonus.gd")
const ArcadeRun=preload("res://scripts/arcade_run.gd")
var arcade=ArcadeRun.new()
const ArcadeFinale=preload("res://scripts/arcade_finale.gd")
var arcade_finale=ArcadeFinale.new()
var finale_age=0
var result_hold=240
var result_callout_age=-1
var continue_timer=600
var challenger_timer=90
var challenge_resume:Dictionary={}
const BonusRewards=preload("res://scripts/bonus_rewards.gd")
var bonus_rewards=BonusRewards.new()
var bonus_due=false
var fight_accounted=false
var bonus_accounted=false
var bonus_scored=0
const Commands=preload("res://scripts/commands.gd")
const Stage=preload("res://scripts/harbor_stage.gd")
const OnlineVersus=preload("res://scripts/online_versus.gd")
const ONLINE_MODE=3
const FighterArt=preload("res://scripts/fighter_sprites.gd")
const ResultsPortraits=preload("res://scripts/results_portraits.gd")
var results_portraits=ResultsPortraits.new()
const CPU=preload("res://scripts/cpu.gd")
const SfxBank=preload("res://scripts/sfx_bank.gd")
const ControllerBindings=preload("res://scripts/controller_bindings.gd")
const Announcer=preload("res://scripts/announcer.gd")
const CharacterUnlocks=preload("res://scripts/character_unlocks.gd")
const ImpactSparks=preload("res://scripts/impact_sparks.gd")
var impact_sparks=ImpactSparks.new()
const ArcadeProjectile=preload("res://scripts/arcade_projectile.gd")
const ArcadeUI=preload("res://scripts/arcade_ui.gd")
const FightHUD=preload("res://scripts/fight_hud.gd")
const RoundCallouts=preload("res://scripts/round_callouts.gd")
const StageProps=preload("res://scripts/stage_props.gd")
const TrainingGuide=preload("res://scripts/training_guide.gd")
const BaltimoreMap=preload("res://scripts/baltimore_map.gd")
var city_map=BaltimoreMap.new()
var arcade_projectile=ArcadeProjectile.new()
var ui_skin=ArcadeUI.new()
var fight_hud=FightHUD.new()
var round_callouts=RoundCallouts.new()
var stage_props=StageProps.new()
var training_guide=TrainingGuide.new()
var training_guide_enabled=true
var world=Node2D.new()
var camera_x=0.0
var unlocks=CharacterUnlocks.new()
var title_cursor=0
var pause_cursor=0
var pause_moves_open=false
var options_open=false
var options_cursor=0
var settings:ConfigFile
var settings_saved=true
var cheat_slots=["","",""]
var cheat_cursor=0
var cheat_message=""
const CHEAT_SYMBOLS="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
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
var online=OnlineVersus.new(sim.data.fighters.size(),Stage.STAGE_NAMES.size())
var online_match_id=0
var online_code:LineEdit
var online_cursor=0
var online_code_copied=false
var stage_pick=0
var stage_previews:Array[Texture2D]=[]
var art=FighterArt.new()
var cpu=CPU.new()
var commands=[Commands.new(),Commands.new()]
var screen="title"
var selected_mode=0
var difficulty=1
var turbo=false
var selection=[0,1]
var select_slot=0
var paused=false
var debug_boxes=false
var muted=false
var music_enabled=true
var clock=0.0
var projectile_tick=0
var pressed=[[],[]]
var effects:Array=[]
var shake=0.0
var logo:Texture2D=load("res://assets/logo.png")
var font:Font=preload("res://assets/fonts/UpheavalPro.ttf")
var sfx:SfxBank
var music:AudioStreamPlayer
var menu_music:AudioStreamPlayer
var match_end_audio:AudioStreamPlayer
var finale_fanfare:AudioStreamPlayer
var match_end_played=false
var female_taunt_played=false
var music_config:Dictionary={}
var looping_tracks:Dictionary={}
var current_stage_music_path=""
var ko_slowmo_frames=0
var impact_ramp_frames=0
var pending_input=[{},{}]
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
const KEY_ATTACKS=["lp","hp","lk","hk","throw"]
const ATTACKS=["lp","mp","hp","lk","mk","hk","throw"]
const PAUSE_ACTIONS=["resume","options","title","moves"]
const PAUSE_LABELS=["RESUME","SETTINGS","MAIN MENU","MOVES LIST"]
const TITLE_ACTIONS=["mode0","mode1","online","mode2","cheats","scores","options","quit"]
const TITLE_LABELS=["ARCADE","LOCAL VERSUS","ONLINE VERSUS","TRAINING","CHEAT CODE","HIGH SCORES","SETTINGS","QUIT GAME"]
const SELECT_MODES=["ARCADE","LOCAL VERSUS","TRAINING","ONLINE VERSUS"]
const STAGE_COLUMNS=4
const ROOM_ACTIONS=["host_room","join_room","back"]
const DIFFICULTY_LABELS=["EASY","NORMAL","HARD"]
const NORMAL_FIGHT_RATE=1.15
const TURBO_MULTIPLIER=1.15
const TURBO_RATE=NORMAL_FIGHT_RATE*TURBO_MULTIPLIER
const IMPACT_RAMP_TICKS=14
const IMPACT_RAMP_START=.25
const DUMMY_LABELS=["STAND","CROUCH","STAND GUARD","CROUCH GUARD"]

func _ready():
	settings=GameSettings.read()
	training_guide_enabled=bool(settings.get_value("gameplay","guided_practice",true))
	difficulty=clampi(int(settings.get_value("gameplay","difficulty",1)),0,DIFFICULTY_LABELS.size()-1)
	turbo=bool(settings.get_value("gameplay","turbo",false))
	music_enabled=bool(settings.get_value("audio","music",true))
	muted=not bool(settings.get_value("audio","sound",true))
	GameSettings.apply_system_settings(settings)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# Fine raster and ordered dither preserve the original logo lettering/metalwork.
	logo=art.pixel_texture(logo,Rect2(Vector2.ZERO,logo.get_size()),Vector2(460.8,460.8*logo.get_height()/logo.get_width()))
	world.show_behind_parent=true
	world.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	world.draw.connect(draw_world)
	add_child(world)
	stage.attach(world)
	stage_previews=stage.stage_textures()
	setup_online_fields()
	setup_audio()
	for id in Input.get_connected_joypads(): controller_connection(id,true)
	Input.joy_connection_changed.connect(controller_connection)
	for arg in OS.get_cmdline_user_args():
		if arg=="--show-match":
			selected_mode=2
			begin_match()
		if arg=="--show-select": screen="select"
		if arg=="--show-bonus":
			selected_mode=0
			begin_bonus()
		if arg=="--demo":
			auto_demo=true
			selected_mode=2
			begin_match()
		if arg.begins_with("--capture="): capture_path=arg.trim_prefix("--capture=")
	sync_match_end_audio()
	queue_redraw()

func _exit_tree():
	online.leave()
	# Release looping MP3 playback before the audio server shuts down.
	for player in [music,menu_music,match_end_audio,finale_fanfare,announcer]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
	looping_tracks.clear()

func setup_audio():
	announcer=Announcer.new()
	add_child(announcer)
	sfx=SfxBank.new()
	add_child(sfx)
	music=AudioStreamPlayer.new()
	add_child(music)
	music_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))
	# Cache raw MP3s once, including new tracks without editor-generated imports.
	for path in music_config.levels.values(): looping_track(path)
	current_stage_music_path=music_config.levels[stage.stage_name()]
	music.stream=looping_track(current_stage_music_path)
	music.volume_db=float(music_config.get("match_volume_db",-13))
	menu_music=AudioStreamPlayer.new()
	add_child(menu_music)
	menu_music.stream=looping_track(music_config.title)
	menu_music.volume_db=float(music_config.get("menu_volume_db",-11))
	match_end_audio=AudioStreamPlayer.new()
	add_child(match_end_audio)
	match_end_audio.stream=load("res://audio/level-complete.mp3")
	match_end_audio.volume_db=-9
	finale_fanfare=AudioStreamPlayer.new()
	finale_fanfare.stream=SfxBank.raw_wav("res://audio/arcade-finale.wav")
	finale_fanfare.volume_db=-10
	add_child(finale_fanfare)
	# Match music stays beneath combat sounds; KO voices retain normal pitch/speed.

func looping_track(path:String)->AudioStream:
	if not looping_tracks.has(path):
		var stream:AudioStream
		if path.ends_with(".ogg"):
			stream=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(path))
		else:
			stream=AudioStreamMP3.new()
			stream.data=FileAccess.get_file_as_bytes(path)
		stream.loop=true
		stream.resource_name=path.get_file()
		looping_tracks[path]=stream
	return looping_tracks[path]

func sync_match_end_audio():
	var at_bonus=sim is CarBonus and screen=="match"
	if at_bonus: bank_bonus_points()
	if screen=="match" and sim.phase=="results": account_completed_stage()
	var at_results=screen=="match" and sim.phase=="results" and not at_bonus
	var match_decided=sim.winner>=0 and sim.wins[sim.winner]>=2
	var during_fight=screen=="match" and sim.phase!="results" and not (sim.phase=="round_end" and match_decided)
	if screen!="campaign" or not music_enabled: finale_fanfare.stop()
	var in_menu=screen in ["title","select","stage_select","online","cheats","scores","continue","game_over","challenger"]
	in_menu=in_menu or (screen=="campaign" and not finale_fanfare.playing)
	if during_fight:
		var wanted=String(music_config.levels.get(stage.stage_name(),"res://audio/go-straight.mp3"))
		if wanted!=current_stage_music_path:
			music.stop()
			music.stream=looping_track(wanted)
			current_stage_music_path=wanted
	if screen!="match": announcer.clear()
	# Stop outgoing tracks before starting the next screen's audio.
	if not in_menu or not music_enabled: menu_music.stop()
	if not during_fight or not music_enabled: music.stop()
	if not at_results:
		match_end_audio.stop()
		match_end_played=false
		result_callout_age=-1
	if music_enabled and during_fight:
		if not music.playing and not music.stream_paused: music.play()
	if music_enabled and in_menu and not menu_music.playing: menu_music.play()
	music.stream_paused=paused
	music.volume_db=float(music_config.get("match_volume_db",-13))-(6 if announcer.playing else (4 if sfx.has_grunt_audio() else 0))
	match_end_audio.stream_paused=paused
	announcer.stream_paused=paused
	match_end_audio.volume_db=-17 if announcer.playing or not announcer.pending.is_empty() else -9
	if at_results and not sfx.has_final_ko_audio():
		var female_cpu_win=selected_mode==0 and sim.winner==1 and SfxBank.female(sim.fighters[1].kind) and sim.fighters[0].health<=0
		if female_cpu_win and not female_taunt_played:
			female_taunt_played=true
			if not muted: sfx.play("female_victory")
			return
		if not match_end_played:
			match_end_played=true
			result_callout_age=0
			match_end_audio.play()
			announcer.say(["you","lose" if player_lost_match() else "win"])

func player_lost_match()->bool:
	if selected_mode==ONLINE_MODE: return sim.winner==1-online.local_slot
	return selected_mode==0 and sim.winner==1

func sound(name:String):
	if not muted: sfx.play(name)

func toggle_pause():
	paused=not paused
	pause_cursor=0
	pause_moves_open=false
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
			close_controller_setup()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var p=get_global_mouse_position()
		for b in buttons:
			if b.rect.has_point(p): action(b.action); return
	if event is InputEventKey and event.pressed and not event.echo:
		var key=event.physical_keycode
		if key==0: key=event.keycode
		if screen=="online" and online_code.has_focus():
			if key==KEY_ESCAPE:
				online_code.release_focus()
				get_viewport().set_input_as_handled()
			return
		if options_open:
			if key==KEY_ESCAPE: action("back")
			elif key in [KEY_ENTER,KEY_SPACE]: action("confirm")
			elif key==KEY_UP: action("up")
			elif key==KEY_DOWN: action("down")
			elif key==KEY_LEFT: action("left")
			elif key==KEY_RIGHT: action("right")
			return
		if screen=="cheats":
			if key in [KEY_ENTER,KEY_SPACE]: action("confirm")
			elif key==KEY_ESCAPE: action("back")
			elif key==KEY_LEFT: action("left")
			elif key==KEY_RIGHT: action("right")
			elif key==KEY_UP: action("up")
			elif key==KEY_DOWN: action("down")
			elif key==KEY_BACKSPACE: action("cheat_clear")
			elif (key>=KEY_A and key<=KEY_Z) or (key>=KEY_0 and key<=KEY_9):
				cheat_slots[cheat_cursor]=String.chr(key)
				cheat_cursor=mini(2,cheat_cursor+1);cheat_message=""
			return
		if key==KEY_F4:
			open_controller_setup()
			return
		if key==KEY_F11 or (screen=="title" and key==KEY_F):
			toggle_display()
			return
		if key==KEY_M:
			toggle_sound()
			return
		if key==KEY_N:
			toggle_music()
			return
		if key==KEY_2 and can_join_arcade():
			begin_challenger();return
		if screen=="match" and sim.phase!="results":
			if key==KEY_ESCAPE:
				if pause_moves_open: action("back")
				else: toggle_pause()
				return
			if paused:
				if key==KEY_Q: action("title")
				elif key in [KEY_ENTER,KEY_SPACE]: action("confirm")
				elif key in [KEY_LEFT,KEY_UP]: action("left")
				elif key in [KEY_RIGHT,KEY_DOWN]: action("right")
				return
			if key==KEY_F1: debug_boxes=not debug_boxes
			if key==KEY_F2 and sim.training: sim.dummy=(sim.dummy+1)%4
			if key==KEY_F3 and sim.training:
				sim.reset_round()
				training_guide.reset(sim.data.fighters[sim.fighters[0].kind])
				for reader in commands: reader.reset()
			for i in (1 if selected_mode==ONLINE_MODE else 2):
				if key in KEYS[i]: pressed[i].append(KEY_ATTACKS[KEYS[i].find(key)])
		else:
			if key in [KEY_ENTER,KEY_SPACE]: action("confirm")
			if key==KEY_ESCAPE: action("back")
			if key in [KEY_UP,KEY_W]: action("up")
			if key in [KEY_DOWN,KEY_S]: action("down")
			if key in [KEY_LEFT,KEY_A]: action("left")
			if key in [KEY_RIGHT,KEY_D]: action("right")

func clear_controls():
	pressed=[[],[]]
	if selected_mode!=ONLINE_MODE or screen!="match":
		pending_input=[{},{}]
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

func close_controller_setup():
	controller_setup=false
	clear_controls()

func controller_event(event:InputEvent):
	var slot=pads.slots.find(event.device)
	var bindings=pads.mapping(event.device)
	var before={}
	for name in ControllerBindings.ACTIONS: before[name]=pads.active(event.device,bindings[name])
	pads.ingest(event)
	if slot<0: return
	var triggered=[]
	for name in ControllerBindings.ACTIONS:
		if not before[name] and pads.active(event.device,bindings[name]): triggered.append(name)
	if controller_setup:
		var waiting=setup_device<0 or setup_step>=ControllerBindings.STEPS.size()
		if "pause" in triggered or (waiting and "back" in triggered): close_controller_setup()
		elif not waiting or ("confirm" in triggered and setup_device<0): capture_controller_binding(event)
		return
	if selected_mode==ONLINE_MODE and screen=="match" and slot!=0: return
	if "pause" in triggered:
		if options_open: action("back")
		elif screen=="match" and sim.phase!="results":
			if slot==1 and can_join_arcade(): begin_challenger()
			else: toggle_pause()
		else: action("confirm")
		return
	if options_open or screen!="match" or sim.phase=="results" or paused:
		if screen=="cheats" and "cheat_clear" in triggered: action("cheat_clear")
		elif "confirm" in triggered: action("confirm")
		elif "back" in triggered: action("back")
	else:
		for name in ATTACKS:
			if name in triggered or (name=="throw" and "throw_right" in triggered):
				if not pressed[slot].has(name): pressed[slot].append(name)

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
	# Require a fresh press and a distinct control for each physical button.
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
		setup_bindings.pause=pads.mapping(setup_device).pause
		setup_bindings.confirm=setup_bindings.lp
		setup_bindings.back=setup_bindings.mp
		var error=pads.save_mapping(setup_device,setup_bindings)
		setup_message="LAYOUT SAVED" if error==OK else "COULD NOT SAVE. RETURN AND TRY AGAIN."
		clear_controls()

func controller_menu_tick():
	if controller_setup or (screen=="match" and sim.phase!="results" and not paused and not options_open): return
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

func make_online_field(placeholder:String,rect:Rect2,limit:int)->LineEdit:
	var field=LineEdit.new()
	field.position=rect.position
	field.size=rect.size
	field.placeholder_text=placeholder
	field.max_length=limit
	field.add_theme_font_override("font",font)
	field.add_theme_font_size_override("font_size",23)
	var fill=StyleBoxFlat.new()
	fill.bg_color=Color("0d1b32")
	fill.border_color=Color("6b7e9c")
	fill.set_border_width_all(2)
	fill.content_margin_left=12
	field.add_theme_stylebox_override("normal",fill)
	var focus=fill.duplicate()
	focus.border_color=GOLD
	focus.draw_center=false
	field.add_theme_stylebox_override("focus",focus)
	field.hide()
	add_child(field)
	return field

func setup_online_fields():
	online_code=make_online_field("ABCD-EFGH",Rect2(666,347,244,48),16)
	online_code.context_menu_enabled=true
	online_code.text_submitted.connect(func(_text): action("join_room"))

func displayed_room_code()->String:
	return online.room_code.substr(0,4)+"-"+online.room_code.substr(4)

func return_to_online_room():
	online_match_id=0
	online_code_copied=false
	screen="online"
	paused=false
	pause_moves_open=false
	options_open=false
	controller_setup=false
	effects.clear()
	clear_controls()
	sfx.stop_all()
	sfx.set_paused(false)
	sync_match_end_audio()

func online_room_action(which:String):
	if which=="back":
		if online.state=="idle": action("title")
		else: online.leave()
		return
	if online.state=="listening" and which in ["copy_code","confirm"]:
		DisplayServer.clipboard_set(displayed_room_code())
		online_code_copied=true
		return
	if online.state!="idle": return
	if which in ["up","down","left","right"]:
		online_cursor=posmod(online_cursor+(-1 if which in ["up","left"] else 1),ROOM_ACTIONS.size())
		return
	if which=="confirm": which=ROOM_ACTIONS[online_cursor]
	if which=="back": action("title");return
	if which not in ["host_room","join_room"]: return
	online_cursor=ROOM_ACTIONS.find(which)
	online_code_copied=false
	if which=="host_room":
		online.host()
	else:
		if online.join(online_code.text)==ERR_INVALID_PARAMETER: online_code.grab_focus()
	if online.state!="idle": online_code.hide()

func stage_select_action(which:String):
	var networked=selected_mode==ONLINE_MODE
	if which=="back":
		if networked:
			online.leave()
			return_to_online_room()
		else: screen="select"
		return
	if networked and online.local_slot!=0: return
	var index=stage_pick
	if which in ["left","right","up","down"]:
		var offset={"left":-1,"right":1,"up":-STAGE_COLUMNS,"down":STAGE_COLUMNS}
		index=posmod(index+offset[which],Stage.STAGE_NAMES.size())
	elif which.begins_with("stage"):
		index=which.trim_prefix("stage").to_int()
	if index>=0 and index<Stage.STAGE_NAMES.size() and index!=stage_pick:
		stage_pick=index
		if networked: online.choose_stage(stage_pick)
	if which=="confirm":
		if networked: online.start(stage_pick,turbo)
		else: begin_match(false,stage_pick)

func service_online():
	online.poll()
	if screen=="online" and online.state=="select":
		selection=online.picks.duplicate()
		select_slot=online.local_slot
		screen="select"
	if selected_mode==ONLINE_MODE:
		if screen in ["select","stage_select","match"] and online.state=="idle":
			return_to_online_room()
		elif online.state=="select":
			selection=online.picks.duplicate()
			if online.can_start(): screen="stage_select"
			stage_pick=online.stage_index
		elif online.state=="match":
			if online_match_id==online.match_id and sim.phase=="results" and online.local_slot==0 and online.can_start():
				online.start(online.stage_index,online.turbo)
			if online_match_id!=online.match_id:
				online_match_id=online.match_id
				selection=online.picks.duplicate()
				options_open=false
				controller_setup=false
				begin_match(false,online.stage_index)
				online.mark_loaded()
	var show_fields=screen=="online" and online.state=="idle" and not controller_setup and not options_open
	online_code.visible=show_fields

func action(which:String):
	if options_open:
		handle_options(which)
		return
	if pause_moves_open and which!="title":
		if which=="back":
			pause_moves_open=false
			sound("menu_back")
		return
	# Bonus results have one destination: continue the run.
	if screen=="match" and sim is CarBonus and sim.phase=="results" and which in ["back","title","quit"]: return
	if screen=="title" and which in TITLE_ACTIONS:
		title_cursor=TITLE_ACTIONS.find(which)
	if which=="online" and screen=="title":
		selected_mode=ONLINE_MODE
		online_cursor=0
		online.close()
		return_to_online_room()
		sound("menu_confirm")
		return
	if which=="quit" and screen=="title":
		get_tree().quit()
		return
	if which=="cheats":
		screen="cheats";cheat_slots=["","",""];cheat_cursor=0;cheat_message=""
		sound("menu_confirm");sync_match_end_audio();return
	if which=="scores":
		screen="scores";arcade.load_scores();sync_match_end_audio();return
	if which=="controllers":
		open_controller_setup()
		return
	if which=="options":
		options_open=true
		options_cursor=0
		sound("menu_confirm")
		return
	if which=="title": sfx.stop_all()
	if which in ["up","down","left","right"] or which.begins_with("fighter") or which.begins_with("stage"):
		sound("menu_move")
	elif which in ["back","title"]: sound("menu_back")
	else: sound("menu_confirm")
	if which=="title":
		if selected_mode==ONLINE_MODE:
			online.leave()
			selected_mode=1
			online_code.hide()
		if arcade.active: finish_arcade(false)
		challenge_resume.clear()
		announcer.clear()
		screen="title"
		paused=false
		pause_moves_open=false
		sync_match_end_audio()
		return
	if paused:
		if which in ["left","right","up","down"]:
			pause_cursor=posmod(pause_cursor+(-1 if which in ["left","up"] else 1),PAUSE_ACTIONS.size())
		elif which=="confirm": action(PAUSE_ACTIONS[pause_cursor])
		elif which=="moves": pause_moves_open=true
		elif which in ["back","resume"]: toggle_pause()
		return
	if screen=="title":
		if which in ["up","down"]:
			title_cursor=posmod(title_cursor+(-1 if which=="up" else 1),TITLE_ACTIONS.size())
		var menu_action:String=TITLE_ACTIONS[title_cursor]
		if which.begins_with("mode"):
			which="confirm"
		if which=="confirm":
			if not menu_action.begins_with("mode"):
				action(menu_action)
				return
			selected_mode=int(menu_action[-1])
			bonus_due=false;fight_accounted=false
			arcade.active=false;challenge_resume.clear()
			screen="select"
			select_slot=0
	elif screen=="online": online_room_action(which)
	elif screen=="scores":
		if which in ["confirm","back"]: screen="title"
	elif screen=="continue":
		if which in ["confirm","rematch"]:
			arcade.continues+=1;begin_match(true)
		elif which=="back": finish_arcade(false);screen="game_over"
	elif screen in ["game_over","campaign"]:
		if which=="confirm":
			if screen=="campaign" and finale_age<ArcadeFinale.DETAILS_TICK: finale_age=ArcadeFinale.DETAILS_TICK
			else: screen="scores";arcade.load_scores()
		elif which=="back": action("title")
	elif screen=="challenger":
		return
	elif screen=="cheats":
		if which in ["back","title"]: screen="title"
		elif which in ["left","right"]: cheat_cursor=posmod(cheat_cursor+(-1 if which=="left" else 1),3)
		elif which.begins_with("cheat_slot"): cheat_cursor=int(which[-1])
		elif which=="cheat_clear":
			cheat_slots[cheat_cursor]="";cheat_message=""
		elif which in ["up","down"]:
			var current=CHEAT_SYMBOLS.find(cheat_slots[cheat_cursor]) if cheat_slots[cheat_cursor]!="" else (-1 if which=="up" else 0)
			cheat_slots[cheat_cursor]=CHEAT_SYMBOLS.substr(posmod(current+(-1 if which=="down" else 1),CHEAT_SYMBOLS.length()),1)
			cheat_message=""
		elif which in ["confirm","cheat_redeem"]:
			cheat_message=unlocks.redeem("".join(cheat_slots))
	elif screen=="select":
		if not challenge_resume.is_empty() and which=="back": resume_arcade();return
		if selected_mode==ONLINE_MODE and which=="back":
			online.leave()
			return_to_online_room()
			return
		if selected_mode==ONLINE_MODE and online.ready[select_slot]: return
		if which in ["left","right","up","down"]:
			var columns=select_columns()
			var step=-1 if which=="left" else (1 if which=="right" else (-columns if which=="up" else columns))
			var next=posmod(selection[select_slot]+step,sim.data.fighters.size())
			for attempt in sim.data.fighters.size():
				if unlocks.available(sim.data.fighters[next]): break
				next=posmod(next+(-1 if step<0 else 1),sim.data.fighters.size())
			selection[select_slot]=next
		if which.begins_with("fighter"):
			var kind=which.trim_prefix("fighter").to_int()
			if kind>=0 and kind<sim.data.fighters.size() and unlocks.available(sim.data.fighters[kind]): selection[select_slot]=kind
		if selected_mode==ONLINE_MODE:
			if which=="confirm" or selection[select_slot]!=online.picks[select_slot]:
				online.choose(selection[select_slot],which=="confirm")
			return
		if which=="back":
			if select_slot==1: select_slot=0
			else: screen="title"
		if which=="confirm":
			if not challenge_resume.is_empty():
				selected_mode=1;sim=Combat.new();begin_match()
			elif selected_mode==0:
				begin_match()
			elif select_slot==0:
				select_slot=1
				selection[1]=(selection[0]+1)%sim.data.fighters.size()
				while not unlocks.available(sim.data.fighters[selection[1]]):
					selection[1]=(selection[1]+1)%sim.data.fighters.size()
			elif selected_mode==1:
				stage_pick=0
				screen="stage_select"
			else: begin_match()
	elif screen=="stage_select": stage_select_action(which)
	elif screen=="match" and sim.phase=="results":
		if which in ["confirm","rematch"]:
			if selected_mode==ONLINE_MODE:
				online.vote_rematch()
				return
			if not challenge_resume.is_empty(): resume_arcade();return
			account_completed_stage()
			if selected_mode==0 and not sim is CarBonus and sim.winner!=0:
				start_continue()
			elif selected_mode==0 and arcade.complete():
				begin_finale()
			elif bonus_due and not sim is CarBonus: begin_bonus()
			else: begin_match(selected_mode==1)
		if which=="back":
			action("title")

func toggle_display():
	var enabled=not GameSettings.fullscreen()
	GameSettings.set_fullscreen(enabled)
	store_setting("display","fullscreen",enabled)

func toggle_sound():
	muted=not muted
	AudioServer.set_bus_mute(0,muted)
	store_setting("audio","sound",not muted)

func toggle_music():
	music_enabled=not music_enabled
	store_setting("audio","music",music_enabled)
	sync_match_end_audio()

func store_setting(section:String,key:String,value:Variant):
	settings.set_value(section,key,value)
	settings_saved=GameSettings.save(settings)

func option_items()->Array:
	var items=[
		["difficulty","CPU DIFFICULTY",DIFFICULTY_LABELS[difficulty]],
		["turbo","TURBO MODE","ON  +15%" if turbo else "OFF"],
		["display","DISPLAY","FULLSCREEN" if GameSettings.fullscreen() else "WINDOWED"],
		["music","MUSIC","ON" if music_enabled else "OFF"],
		["sound","SOUND","OFF" if muted else "ON"],
		["controllers","CONTROLLER SETUP",""]
	]
	if paused and sim.training:
		items.append_array([["dummy","DUMMY",DUMMY_LABELS[sim.dummy]],["hitboxes","HITBOXES","ON" if debug_boxes else "OFF"],["reset","RESET POSITIONS",""],
			["training_guide","GUIDED PRACTICE","ON" if training_guide_enabled else "OFF"]])
	return items

func handle_options(which:String):
	var items=option_items()
	if which in ["up","down"]:
		options_cursor=posmod(options_cursor+(-1 if which=="up" else 1),items.size())
		sound("menu_move")
		return
	if which=="back":
		options_open=false
		sound("menu_back")
		return
	var direction=-1 if which=="left" else 1
	if which in ["confirm","left","right"]:
		var item:Array=items[options_cursor]
		if which!="confirm" and item[2]=="": return
		which=item[0]
	match which:
		"difficulty":
			difficulty=posmod(difficulty+direction,DIFFICULTY_LABELS.size())
			store_setting("gameplay","difficulty",difficulty)
		"turbo":
			turbo=not turbo
			store_setting("gameplay","turbo",turbo)
		"controllers": open_controller_setup()
		"display": toggle_display()
		"music": toggle_music()
		"sound": toggle_sound()
		"dummy": sim.dummy=posmod(sim.dummy+direction,DUMMY_LABELS.size())
		"training_guide":
			training_guide_enabled=not training_guide_enabled
			store_setting("gameplay","guided_practice",training_guide_enabled)
		"reset":
			sim.reset_round()
			training_guide.reset(sim.data.fighters[sim.fighters[0].kind])
			clear_controls()
			effects.clear()
			reset_combat_clock()
			options_open=false
		"hitboxes": debug_boxes=not debug_boxes
	sound("menu_confirm")
	sync_match_end_audio()

func begin_match(retry:bool=false,synchronized_stage:int=-1):
	if sim is CarBonus or selected_mode==ONLINE_MODE: sim=Combat.new()
	fight_accounted=false
	stage.set_bonus(false)
	if selected_mode==0:
		if not arcade.active or arcade.player!=selection[0]: arcade.begin(selection[0],sim.data.fighters)
		selection[1]=arcade.opponent()
		if not retry: stage.select_match(Stage.home_stage(sim.data.fighters[selection[1]].id))
	elif synchronized_stage>=0: stage.set_stage(synchronized_stage)
	elif not retry: stage.select_random()
	stage_props=StageProps.new()
	stage_props.reset(stage.current_index())
	camera_x=0.0
	announcer.clear()
	screen="match"
	paused=false
	pause_moves_open=false
	reset_combat_clock()
	result_hold=240
	sfx.stop_all()
	female_taunt_played=false
	sfx.set_paused(false)
	sound("menu_confirm")
	clear_controls()
	if selected_mode==ONLINE_MODE:
		pending_input=[{},{}]
		for reader in commands: reader.reset()
	effects.clear()
	sim.new_match(selection[0],selection[1],selected_mode==2)
	if sim.training: training_guide.reset(sim.data.fighters[selection[0]])
	sync_match_end_audio()
	cpu=CPU.new()

func account_completed_stage():
	if selected_mode!=0 or sim.phase!="results": return
	if sim is CarBonus:
		bank_bonus_points()
		if bonus_accounted: return
		bonus_accounted=true
		if sim.success:
			var reward=bonus_rewards.award()
			sim.reward_code=reward.code;sim.reward_name=reward.name
			sim.reward_deferred=reward.deferred;sim.reward_saved=reward.saved
	elif not fight_accounted:
		fight_accounted=true
		if sim.winner==0:
			arcade.won_match(sim.scores[0])
			bonus_due=arcade.cursor%2==0 and arcade.has_bonus() and not arcade.complete()
		else:
			arcade.score+=sim.scores[0]
			bonus_due=false

func begin_bonus(override_kind:String=""):
	bonus_due=false;bonus_accounted=false;bonus_scored=0
	if selected_mode==0 and not arcade.active:
		arcade.begin(selection[0],sim.data.fighters)
	var kind=override_kind if override_kind!="" else arcade.next_bonus()
	if kind=="": return
	if kind=="car": sim=CarBonus.new();sim.begin(selection[0])
	else: sim=BreakablesBonus.new();sim.begin_challenge(selection[0],kind)
	stage.set_bonus(true,kind)
	screen="match";paused=false
	pause_moves_open=false
	update_camera(0.0)
	reset_combat_clock()
	announcer.clear();sfx.stop_all();sfx.set_paused(false)
	clear_controls();effects.clear()
	sync_match_end_audio()

func bank_bonus_points():
	if selected_mode!=0 or not sim is CarBonus: return
	var delta=maxi(0,int(sim.score)-bonus_scored)
	arcade.score+=delta
	bonus_scored+=delta

func start_continue():
	screen="continue";continue_timer=600;paused=false
	clear_controls();sync_match_end_audio()

func finish_arcade(cleared:bool):
	if not arcade.active: return
	cleared=cleared or arcade.complete()
	if screen=="match" and sim is CarBonus: bank_bonus_points()
	if screen=="match" and not fight_accounted and not sim is CarBonus and challenge_resume.is_empty(): arcade.score+=sim.scores[0]
	arcade.submit(sim.data.fighters[arcade.player].name,cleared)
	arcade.active=false

func begin_finale():
	if not arcade.complete(): return
	finish_arcade(true)
	screen="campaign"
	finale_age=0
	clear_controls()
	sfx.stop_all()
	if music_enabled: finale_fanfare.play()
	sync_match_end_audio()

func can_join_arcade()->bool:
	return screen=="match" and selected_mode==0 and not sim is CarBonus and sim.phase=="fight" and not paused and challenge_resume.is_empty()

func begin_challenger():
	if not can_join_arcade(): return
	challenge_resume={"sim":sim,"selection":selection.duplicate(),"stage":stage.current_index(),"cpu":cpu,"clock":clock,"props":stage_props,"camera_x":camera_x,"music_position":music.get_playback_position()}
	screen="challenger";challenger_timer=90
	clear_controls();announcer.clear();sfx.stop_all();sync_match_end_audio()

func resume_arcade():
	if challenge_resume.is_empty(): return
	var saved=challenge_resume
	challenge_resume={}
	sim=saved.sim;selection=saved.selection;cpu=saved.cpu;clock=saved.clock
	stage_props=saved.props;camera_x=saved.camera_x
	stage.set_stage(saved.stage);selected_mode=0;screen="match";paused=false
	fight_accounted=false;result_hold=240
	reset_combat_clock()
	clear_controls();effects.clear();sfx.stop_all();sim.events.clear()
	sync_match_end_audio();music.seek(saved.music_position)

func raw_control(slot:int)->Dictionary:
	var move_keys=[KEY_LEFT,KEY_RIGHT,KEY_DOWN,KEY_UP] if slot==0 else [KEY_A,KEY_D,KEY_S,KEY_W]
	var dx=int(Input.is_physical_key_pressed(move_keys[1]))-int(Input.is_physical_key_pressed(move_keys[0]))
	var down=Input.is_physical_key_pressed(move_keys[2])
	var up=Input.is_physical_key_pressed(move_keys[3])
	if pads.slots[slot]>=0:
		var direction=pads.directions(pads.slots[slot])
		if direction.dx!=0: dx=direction.dx
		down=down or direction.down
		up=up or direction.up
	var taps=pressed[slot]
	pressed[slot]=[]
	return {"dx":dx,"down":down,"up":up,"buttons":taps}

func resolve_fight_control(slot:int,raw:Dictionary)->Dictionary:
	var facing=int(sim.fighters[slot].facing)
	var direction=Commands.relative_direction(raw.dx,raw.down,raw.up,facing)
	var kit:Dictionary=sim.data.fighters[sim.fighters[slot].kind].moves
	var recovering_palms=kit.get(sim.fighters[slot].move,{}).get("input","")=="mash_punch"
	var command=commands[slot].sample(direction,raw.buttons,kit,recovering_palms)
	return {"dx":raw.dx,"down":raw.down,"up":raw.up,"back":raw.dx*facing<0,"command":command,"buttons":raw.buttons}

func read_control(slot:int)->Dictionary:
	return resolve_fight_control(slot,raw_control(slot))

func combat_time_scale()->float:
	if screen!="match": return 1.0
	if ko_slowmo_frames>24: return 0.25
	if ko_slowmo_frames>0: return 0.5
	var pace=1.0
	if sim.phase=="fight" and not sim is CarBonus:
		var fast=online.turbo if selected_mode==ONLINE_MODE else turbo
		pace=TURBO_RATE if fast else NORMAL_FIGHT_RATE
	if impact_ramp_frames>0:
		if sim.freeze>0: return 1.0
		var elapsed=1.0-float(impact_ramp_frames)/IMPACT_RAMP_TICKS
		return pace*lerpf(IMPACT_RAMP_START,1.0,elapsed)
	return pace

func reset_combat_clock():
	ko_slowmo_frames=0
	impact_ramp_frames=0
	simulation_accumulator=0.0

func sample_fight_control(slot:int)->Dictionary:
	return buffer_fight_control(slot,read_control(slot))

func buffer_fight_control(slot:int,control:Dictionary)->Dictionary:
	# Keep real-time direction samples and carry button edges across skipped steps.
	var pending:Dictionary=pending_input[slot]
	if control.command!="": pending.command=control.command
	if control.up: pending.up=true
	if not control.buttons.is_empty():
		if not pending.has("buttons"): pending.buttons=[]
		pending.buttons.append_array(control.buttons)
	control.merge(pending,true)
	return control

func dispatch_combat_event(event:Dictionary):
	if event.type=="prop_hit":
		sound("box_break" if event.kind=="boxes" else ("car_break" if event.broken else "car_clang"))
		return
	if event.type=="car_hit":
		if event.get("final",false): return
		if event.broken: sound("car_glass" if int(event.zone)%3==0 else "car_break")
		else: sound("car_clang")
		return
	if event.type=="bonus_complete":
		if event.success: sound("box_break" if sim is BreakablesBonus and sim.challenge=="boxes" else "car_destroyed")
		return
	if event.type=="fight": announcer.say(["fight"])
	if event.type=="round" and not muted:
		announcer.say(["final","round"] if event.get("final",int(event.number)>9) else ["round",str(event.number)])
	if event.type=="ko":
		impact_ramp_frames=0
		announcer.clear()
		# Only the match-deciding result ends the track; earlier rounds keep playback.
		if sim.winner>=0 and sim.wins[sim.winner]>=2: music.stop()
		if not sim.training and sim.fighters.any(func(fighter): return fighter.health<=0):
			ko_slowmo_frames=72
			simulation_accumulator=0.0
	if sim.phase=="fight" and not sim is CarBonus and event.type in ["hit","block"]:
		impact_ramp_frames=IMPACT_RAMP_TICKS
	if not muted and not (sim is CarBonus and event.type=="hit"): sfx.combat_event(event,sim)

func advance_match(time_scale:float):
	advance_match_controls(time_scale,sample_fight_control(0),sample_fight_control(1))

func advance_match_controls(time_scale:float,p1:Dictionary,p2:Dictionary):
	simulation_accumulator+=time_scale
	sim.events.clear()
	while simulation_accumulator>=0.999999:
		simulation_accumulator=maxf(0.0,simulation_accumulator-1.0)
		pending_input=[{},{}]
		var was_frozen=sim.freeze>0
		step_match(p1,p2)
		# Keep held directions, but consume each button edge only once.
		p1.command="";p1.buttons=[]
		if impact_ramp_frames>0 and was_frozen!=(sim.freeze>0):
			# One presentation frame can contain two steps. Hold the new impact beat for the next frame.
			simulation_accumulator=fposmod(simulation_accumulator,1.0)
			break
		p2.command="";p2.buttons=[]

func encode_online_input(raw:Dictionary)->int:
	var bits=1 if raw.dx>0 else (2 if raw.dx<0 else 0)
	if raw.up: bits|=4
	if raw.down: bits|=8
	for i in ATTACKS.size():
		if ATTACKS[i] in raw.buttons: bits|=1<<(4+i)
	return bits

func decode_online_input(bits:int)->Dictionary:
	var dx=1 if (bits&1)!=0 else (-1 if (bits&2)!=0 else 0)
	var taps=[]
	for i in ATTACKS.size():
		if (bits&(1<<(4+i)))!=0: taps.append(ATTACKS[i])
	return {"dx":dx,"up":(bits&4)!=0,"down":(bits&8)!=0,"buttons":taps}

func advance_online_match(delta:float):
	if online.can_sample():
		var bits=0
		if not paused and not controller_setup and not options_open and sim.phase!="results":
			bits=encode_online_input(raw_control(0))
		else: pressed[0].clear()
		online.submit(bits)
	for attempt in (2 if online.catch_up() else 1):
		var frame=online.take_frame()
		if frame.is_empty(): break
		var pace=combat_time_scale()
		advance_presentation(delta,pace)
		var p1=buffer_fight_control(0,resolve_fight_control(0,decode_online_input(frame[0])))
		var p2=buffer_fight_control(1,resolve_fight_control(1,decode_online_input(frame[1])))
		advance_match_controls(pace,p1,p2)
		if online.play_frame%OnlineVersus.CHECK_INTERVAL==0:
			online.check_sync(hash([sim.tick,sim.phase,sim.phase_timer,sim.time_left,sim.freeze,sim.fighters,
				sim.wins,sim.scores,sim.projectiles,stage_props.objects,ko_slowmo_frames,impact_ramp_frames]))
	update_camera(delta)

func advance_presentation(delta:float,time_scale:float):
	projectile_tick+=1
	if result_callout_age>=0: result_callout_age=mini(result_callout_age+1,12)
	clock+=delta*time_scale
	ko_slowmo_frames=maxi(0,ko_slowmo_frames-1)
	if sim.freeze==0: impact_ramp_frames=maxi(0,impact_ramp_frames-1)
	for effect in effects: effect.life-=1
	effects=effects.filter(func(e): return e.life>0)
	shake=maxf(0,shake-.9)

func step_match(p1:Dictionary,p2:Dictionary):
	if selected_mode==0 and not sim is CarBonus:
		var boss=arcade.active and arcade.cursor==arcade.opponents.size()-1
		p2=cpu.control(sim,1,mini(2,difficulty+int(boss)))
	if sim.training:
		p2={"dx":0,"down":sim.dummy in [1,3],"up":false,"back":sim.dummy in [2,3],"command":""}
	if auto_demo and not sim is CarBonus:
		p1=cpu.control(sim,0,2)
	var was_frozen=sim.freeze>0
	var prop_motion=[]
	if not was_frozen and not sim is CarBonus and not stage_props.objects.is_empty():
		prop_motion=stage_props.capture_pushback(sim)
	sim.step([p1,p2])
	if sim.training and training_guide_enabled and not was_frozen and sim.phase=="fight": training_guide.step(sim.events)
	if not was_frozen and not sim is CarBonus and sim.phase in ["fight","round_end"]:
		for event in stage_props.step(sim,prop_motion):
			dispatch_combat_event(event)
			effects.append({"x":event.x,"y":event.y,"life":8,"type":"hit","heavy":event.broken})
	for event in sim.events:
		dispatch_combat_event(event)
		if event.type in ["hit","block","projectile_clash"]:
			var effect=event.duplicate()
			effect.duration=impact_sparks.lifetime(event)
			effect.life=effect.duration
			effects.append(effect)
			if event.type=="hit": shake=4 if event.heavy else 2

func _physics_process(delta):
	if selected_mode==ONLINE_MODE: service_online()
	controller_menu_tick()
	sfx.set_paused(paused)
	if selected_mode==ONLINE_MODE and screen=="match":
		advance_online_match(delta)
	elif not paused and not controller_setup and not options_open:
		if screen=="campaign": finale_age+=1
		var time_scale=combat_time_scale()
		if screen=="continue":
			continue_timer=maxi(0,continue_timer-1)
			if continue_timer==0: finish_arcade(false);screen="game_over"
		elif screen=="challenger":
			challenger_timer-=1
			if challenger_timer<=0:
				screen="select";select_slot=1
				selection[1]=unlocked_opponent(selection[0])
		elif screen=="match" and sim.phase=="results" and selected_mode==0 and not sim is CarBonus and challenge_resume.is_empty():
			if sim.winner!=0 or arcade.complete():
				result_hold-=1
				if result_hold<=0:
					if sim.winner!=0: start_continue()
					else: begin_finale()
		advance_presentation(delta,time_scale)
		if screen=="match": advance_match(time_scale)
		update_camera(delta)
	sync_match_end_audio()
	# Prepare selected fighters one pose at a time before play.
	if screen=="select":
		if not art.warm_next(selection[0]): art.warm_next(selection[1])
	elif screen=="match" and sim.phase=="intro":
		if not art.warm_next(sim.fighters[0].kind): art.warm_next(sim.fighters[1].kind)
	capture_ticks+=1
	queue_redraw()
	if capture_path!="" and capture_ticks==12:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("SCREENSHOT ",capture_path)

func txt(value:String,x:float,y:float,size:int=20,color:Color=WHITE,_mono:bool=false):
	draw_string_outline(font,Vector2(roundf(x),roundf(y)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,text_outline(size),Color.BLACK)
	draw_string(font,Vector2(roundf(x),roundf(y)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(value:String,y:float,size:int=20,color:Color=WHITE):
	var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	txt(value,(1280-width)*.5,y,size,color)

func panel(rect:Rect2,color:Color=Color(.025,.048,.074,.94),border:Color=Color(.18,.29,.35,.75)):
	ui_skin.surface(self,rect,color,border)

func button(label:String,rect:Rect2,command:String,active:bool=false):
	var p=rect.position
	var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
	var text_x=p.x+(rect.size.x-width)*.5
	if active:
		var cursor=Vector2(text_x-22,p.y+rect.size.y*.5)
		draw_colored_polygon(PackedVector2Array([cursor+Vector2(0,-6),cursor+Vector2(10,0),cursor+Vector2(0,6)]),GOLD)
	arcade_text(label,text_x,p.y+rect.size.y*.5+9,25,GOLD if active else WHITE)
	buttons.append({"rect":rect,"action":command})

func _draw():
	buttons.clear()
	world.queue_redraw()
	if screen=="title": draw_title()
	elif screen=="select": draw_select()
	elif screen=="stage_select": draw_stage_select()
	elif screen=="online": draw_online_room()
	elif screen=="cheats": draw_cheats()
	elif screen=="scores": draw_scores()
	elif screen=="continue": draw_continue()
	elif screen=="campaign": draw_finale()
	elif screen=="game_over": draw_game_over()
	elif screen=="challenger":
		draw_rect(Rect2(0,0,1280,720),Color("081127"))
		centered("HERE COMES A",285,38,WHITE)
		centered("NEW CHALLENGER",370,68,GOLD)
	else:
		draw_match()
		if paused: draw_pause()
	if options_open: draw_options()
	if controller_setup: draw_controller_setup()

func draw_title():
	draw_texture_rect(logo,Rect2(270,35,740,284),false)
	centered("PRESS START",348,22,Color(1,.9,.65,.65+.35*sin(clock*3)))
	for i in TITLE_ACTIONS.size():
		button(TITLE_LABELS[i],Rect2(472,366+i*39,336,36),TITLE_ACTIONS[i],title_cursor==i)
	centered("D-PAD SELECT   /   A CONFIRM",701,13,MUTED)
	if not arcade.high_scores.is_empty():
		txt("HI  "+str(arcade.high_scores[0].score).pad_zeros(7),1000,28,18,GOLD)

func draw_online_room():
	draw_rect(Rect2(0,0,1280,720),Color(.025,.042,.085,.86))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("ONLINE VERSUS",154,66,GOLD)
	panel(Rect2(328,219,624,346),Color("101b34"),Color("8f7955"))
	if online.state=="idle":
		var status=online.status if online.status!="" else "CREATE A ROOM OR JOIN A FRIEND."
		centered(status,294,17,RED if online.status!="" else WHITE)
		txt("ROOM CODE",667,336,15,MUTED)
		draw_line(Vector2(640,325),Vector2(640,477),Color("415574"),2)
		draw_select_label("SHARE A CODE WITH A FRIEND",487,380,14,MUTED)
		button("CREATE ROOM",Rect2(353,429,272,46),"host_room",online_cursor==0)
		button("JOIN ROOM",Rect2(655,429,272,46),"join_room",online_cursor==1)
		button("BACK",Rect2(480,500,320,38),"back",online_cursor==2)
	elif online.state=="listening":
		centered("SHARE THIS ROOM CODE",291,20,WHITE)
		centered(displayed_room_code(),370,60,GOLD)
		centered(online.status,425,18,MUTED)
		button("COPIED" if online_code_copied else "COPY CODE",Rect2(365,483,262,46),"copy_code",true)
		button("CANCEL",Rect2(652,483,262,46),"back")
	else:
		centered(online.status,324,25,WHITE)
		button("CANCEL",Rect2(480,492,320,42),"back",true)

func stage_card(index:int)->Rect2:
	var row=floori(float(index)/STAGE_COLUMNS)
	var first=row*STAGE_COLUMNS
	var columns=mini(STAGE_COLUMNS,Stage.STAGE_NAMES.size()-first)
	var width=224.0
	var gap=21.0
	var x=(1280-columns*width-(columns-1)*gap)*.5+(index-first)*(width+gap)
	return Rect2(x,139+row*163,width,126)

func draw_stage_select():
	draw_rect(Rect2(0,0,1280,720),Color("090f24"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("STAGE SELECT",83,58,GOLD)
	var stage_control=selected_mode!=ONLINE_MODE or online.local_slot==0
	if selected_mode==ONLINE_MODE:
		centered("HOST CHOOSES THE STAGE" if stage_control else "WAITING FOR HOST TO CHOOSE",116,17,BLUE)
	for i in Stage.STAGE_NAMES.size():
		var image_rect=stage_card(i)
		var card=image_rect.grow(4)
		card.size.y+=27
		var active=i==stage_pick
		panel(card,Color("111b35"),GOLD if active else Color("566888"))
		draw_texture_rect(stage_previews[i],image_rect,false)
		if active: draw_rect(image_rect.grow(2),GOLD,false,2.0)
		var label:String=Stage.STAGE_NAMES[i]
		var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		var size=clampi(floori(16.0*210.0/maxf(210.0,width)),12,16)
		draw_select_label(label,image_rect.get_center().x,image_rect.end.y+21,size,GOLD if active else WHITE)
		if stage_control: buttons.append({"rect":card,"action":"stage"+str(i)})
	if stage_control: button("A  START MATCH",Rect2(455,639,370,34),"confirm",true)
	button("B  LEAVE ROOM" if selected_mode==ONLINE_MODE else "B  BACK",Rect2(465,680,350,32),"back")

func unlocked_opponent(exclude:int)->int:
	for i in sim.data.fighters.size():
		if i!=exclude and unlocks.available(sim.data.fighters[i]): return i
	return 0

func draw_scores():
	draw_rect(Rect2(0,0,1280,720),Color("070d20"));ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("BALTIMORE HIGH SCORES",92,49,GOLD)
	txt("RANK",164,160,20,MUTED);txt("FIGHTER",283,160,20,MUTED);txt("SCORE",735,160,20,MUTED);txt("RUN",971,160,20,MUTED)
	for i in arcade.high_scores.size():
		var entry=arcade.high_scores[i];var y=207+i*37
		txt(str(i+1).pad_zeros(2),180,y,23,GOLD if i==0 else WHITE)
		txt(entry.name,283,y,23,WHITE);txt(str(entry.score).pad_zeros(7),735,y,23,GOLD)
		txt("CLEAR" if entry.clear else "OVER",971,y,18,BLUE if entry.clear else MUTED)
	if arcade.high_scores.is_empty(): centered("NO SCORES YET",330,28,WHITE)
	button("A  MAIN MENU",Rect2(420,647,440,46),"title",true)

func draw_continue():
	draw_rect(Rect2(0,0,1280,720),Color("070d20"));ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("CONTINUE?",102,58,GOLD)
	results_portraits.draw(self,art,arcade.player,false,Rect2(240,160,380,330))
	txt(str(ceili(continue_timer/60.0)).pad_zeros(2),810,352,116,RED)
	centered("SCORE  "+str(arcade.score).pad_zeros(7),540,25,WHITE)
	button("A  CONTINUE",Rect2(400,578,480,48),"confirm",true)
	button("B  END RUN",Rect2(440,647,400,40),"back")

func draw_finale():
	arcade_finale.draw_backdrop(self,finale_age)
	round_callouts.draw_finale(self,finale_age-ArcadeFinale.TITLE_TICK)
	if finale_age<ArcadeFinale.TITLE_TICK+4: return
	var arrival=smoothstep(16.0,46.0,float(finale_age))
	var offset=roundf(96.0*(1.0-arrival))
	results_portraits.draw(self,art,arcade.player,true,Rect2(145-offset,254,478,336))
	if finale_age<ArcadeFinale.DETAILS_TICK: return
	var fighter=sim.data.fighters[arcade.player].name
	arcade_text(fighter,665,302,38,WHITE)
	txt("BALTIMORE CHAMPION",668,335,19,GOLD)
	draw_rect(Rect2(668,355,414,2),Color("bd914c"))
	txt("FINAL SCORE",668,396,20,WHITE)
	arcade_text(str(arcade.score).pad_zeros(7),664,459,64,GOLD)
	txt("%d / %d OPPONENTS DEFEATED" % [arcade.cursor,arcade.opponents.size()],668,509,23,WHITE)
	txt("CONTINUES  "+str(arcade.continues),668,547,18,WHITE)
	button("A  HIGH SCORES",Rect2(296,628,340,48),"confirm",true)
	button("B  MAIN MENU",Rect2(654,628,340,48),"title")

func draw_game_over():
	draw_rect(Rect2(0,0,1280,720),Color("070d20"));ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("GAME OVER",88,54,RED)
	results_portraits.draw(self,art,arcade.player,false,Rect2(250,145,360,340))
	var name=sim.data.fighters[arcade.player].name
	txt(name,675,218,30,WHITE)
	txt("FINAL SCORE",675,279,19,MUTED);txt(str(arcade.score).pad_zeros(7),675,328,43,GOLD)
	txt("FIGHTS WON  "+str(arcade.cursor),675,380,21,WHITE)
	txt("CONTINUES  "+str(arcade.continues),675,420,21,MUTED)
	centered("YOUR RUN HAS ENDED",548,30,WHITE)
	button("A  HIGH SCORES",Rect2(400,624,480,43),"confirm",true)
	button("B  MAIN MENU",Rect2(440,680,400,32),"title")

func draw_cheats():
	draw_rect(Rect2(0,0,1280,720),Color("071436"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("CHEAT CODE",132,52,GOLD)
	centered("UNLOCK CHARACTERS",185,21,WHITE)
	for slot in 3:
		var rect=Rect2(496+slot*104,290,80,112)
		ui_skin.surface(self,rect,Color("162960"),GOLD if slot==cheat_cursor else BLUE)
		var value=cheat_slots[slot] if cheat_slots[slot]!="" else "_"
		var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
		arcade_text(value,rect.get_center().x-width*.5,372,64,WHITE)
		buttons.append({"rect":rect,"action":"cheat_slot"+str(slot)})
	centered(cheat_message,458,22,RED if cheat_message.begins_with("INVALID") else GOLD)
	button("A  REDEEM CODE",Rect2(440,493,400,45),"cheat_redeem",true)
	button("B  MAIN MENU",Rect2(440,556,400,42),"title")
	centered("D-PAD  UP / DOWN: SYMBOL     LEFT / RIGHT: SLOT     C: CLEAR",665,16,WHITE)

func draw_select():
	# Classic arcade composition: blue Baltimore map, a compact portrait matrix,
	# and victory portraits in the lower corners.
	for y in range(0,720,4):
		draw_rect(Rect2(0,y,1280,4),Color("172d83").lerp(Color("030b2b"),float(y)/720.0))
	for y in range(578,680,12):
		for x in range(0,1280,24):
			if (x/24+(y-578)/12)%2==0: draw_rect(Rect2(x,y,24,12),Color("111f55"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	var title="PLAYER SELECT"
	var display_mode=1 if not challenge_resume.is_empty() else selected_mode
	var random_opponent=display_mode==0
	var online_select=display_mode==ONLINE_MODE
	var title_x=640-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,60).x*.5
	arcade_text(title,title_x+4,78,60,Color("b42835"))
	arcade_text(title,title_x,72,60,Color("ffe596"))
	arcade_text("1P",65,62,33,BLUE)
	arcade_text("2P" if display_mode in [1,ONLINE_MODE] else "CPU",1100,62,33,RED)
	centered(SELECT_MODES[display_mode],109,16,Color("9eb9ed"))
	draw_select_map()
	var prompt="1P SELECT" if select_slot==0 else ("2P SELECT" if display_mode==1 else "SELECT OPPONENT")
	if online_select:
		prompt="WAITING FOR OPPONENT" if online.ready[select_slot] else "%dP  CHOOSE YOUR FIGHTER" % (select_slot+1)
	centered(prompt,361,24,BLUE if select_slot==0 else RED)
	var margin=175.0 if select_columns()>=7 else (205.0 if select_columns()>=5 else 235.0)
	for slot in 2:
		var x=margin if slot==0 else 1280-margin
		if slot==1 and random_opponent:
			draw_select_label("?",x,535,176,Color("ffe596"))
			draw_select_label("RANDOM",x,637,47,Color("ffe596"))
			draw_select_label("OPPONENT",x,664,17,RED)
			continue
		var kind=selection[slot]
		var fd=sim.data.fighters[kind]
		var opponent_locked=online_select and slot!=select_slot and online.ready[slot]
		var hidden=not unlocks.available(fd) and not opponent_locked
		if hidden:
			draw_select_label("?",x,535,176,MUTED)
		else:
			var corner=Rect2(x-158,267,316,332)
			results_portraits.draw(self,art,kind,true,corner,slot==1)
		var display_name=fd.name if opponent_locked else select_label(kind)
		var name_size=47
		var name_width=font.get_string_size(display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x
		var name_limit=minf(350.0,2.0*minf(x,1280-x)-20.0)
		if name_width>name_limit:
			name_size=floori(name_size*name_limit/name_width)
			name_width=font.get_string_size(display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x
		arcade_text(display_name,x-name_width*.5,637,name_size,Color("ffe596"))
		var status="LOCKED" if hidden else ("READY" if slot==0 and select_slot==1 else ("CHOOSE" if select_slot==slot else "CHALLENGER"))
		if online_select: status="READY" if online.ready[slot] else ("YOU" if slot==select_slot else "CHOOSING")
		if not hidden and fd.get("boss",false): status+=" / BOSS"
		draw_select_label(status,x,664,17,BLUE if slot==0 else RED)
	centered("VS",393,30,Color("ffe596"))
	for i in sim.data.fighters.size():
		var rect=select_portrait_rect(i)
		draw_rect(rect.grow(5),Color("030719"))
		draw_rect(rect.grow(2),Color("a4abb9"))
		draw_rect(rect,Color("283d75"))
		if unlocks.available(sim.data.fighters[i]): art.portrait(self,i,rect)
		else:
			var question_width=font.get_string_size("?",HORIZONTAL_ALIGNMENT_LEFT,-1,54).x
			arcade_text("?",rect.get_center().x-question_width*.5,rect.position.y+rect.size.y-18,54,MUTED)
		ui_skin.frame(self,rect.grow(2),Color("a4abb9"))
		var label_size=12 if rect.size.x<80 else (13 if rect.size.x<100 else 16)
		var label_height=16 if rect.size.x<100 else 19
		draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-label_height),Vector2(rect.size.x,label_height)),Color("080d26"))
		var name=select_label(i,true)
		var nw=font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x
		arcade_text(name,rect.get_center().x-nw*.5,rect.end.y-3,label_size,WHITE)
		for slot in 2:
			if slot==1 and random_opponent: continue
			if selection[slot]!=i: continue
			var color=BLUE if slot==0 else RED
			var visible=slot!=select_slot or int(clock*6)%2==0
			if visible: draw_rect(rect.grow(6+slot*4),color,false,3)
			arcade_text("1P" if slot==0 else "2P",rect.position.x+3+slot*(rect.size.x-48),rect.position.y+19,19,color)
		buttons.append({"rect":rect,"action":"fighter"+str(i)})
	var confirm=Rect2(478,650,324,37)
	draw_line(Vector2(522,684),Vector2(758,684),GOLD,2)
	if not online_select or not online.ready[select_slot]:
		centered("A  CONFIRM",676,22,Color("fff0c3"))
		buttons.append({"rect":confirm,"action":"confirm"})
	centered("D-PAD SELECT     /     B LEAVE ROOM" if online_select else "D-PAD SELECT     /     B BACK",709,15,Color("aebbdc"))

func draw_select_label(label:String,x:float,y:float,size:int,color:Color):
	var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	arcade_text(label,x-width*.5,y,size,color)

func select_label(kind:int,compact:bool=false)->String:
	var fighter=sim.data.fighters[kind]
	if not unlocks.available(fighter): return "???"
	return fighter.get("select_name",fighter.name) if compact else fighter.name

func select_portrait_rect(index:int)->Rect2:
	var columns=select_columns()
	var tile=76 if columns==7 else (84 if columns==6 else 100)
	var step=84 if columns==7 else (94 if columns==6 else 112)
	var left=640-(columns*step-(step-tile))*.5
	return Rect2(left+(index%columns)*step,414+(index/columns)*step,tile,tile)

func select_columns()->int:
	if sim.data.fighters.size()>12: return 7
	return 2 if sim.data.fighters.size()<=4 else (3 if sim.data.fighters.size()<=6 else (4 if sim.data.fighters.size()<=8 else (5 if sim.data.fighters.size()<=10 else 6)))

func draw_select_map():
	city_map.draw(self)

func update_camera(delta:float):
	var fighting=screen=="match" and sim.phase!="results" and not sim is CarBonus
	stage.set_panorama(fighting)
	if not fighting:
		camera_x=0.0
	elif sim.freeze==0:
		var a:float=sim.fighters[0].x
		var b:float=sim.fighters[-1].x
		var target=Stage.camera_target(minf(a,b),maxf(a,b))
		camera_x=lerpf(camera_x,target,1.0-exp(-8.0*delta))
	world.position.x=-roundf(camera_x)

func draw_world():
	stage.draw(world,clock)
	for y in range(0,720,4):
		world.draw_line(Vector2(-Stage.PAN,y),Vector2(1280+Stage.PAN,y),Color(0,0,0,.025),1)
	if screen!="match": return
	if sim is CarBonus:
		if sim is BreakablesBonus: sim.draw_objects(world)
		else: sim.car.draw(world,sim.tick)
		art.draw(world,sim.fighters[0],clock,Combat.FIGHTER_SCALE)
		for projectile in sim.projectiles: arcade_projectile.draw(world,projectile,projectile_tick)
		for effect in effects: impact_sparks.draw(world,effect)
		return
	if sim.phase=="results": return
	stage.draw_ambient(world,clock)
	stage_props.draw(world)
	# Draw a held opponent last so the shoulder lift stays readable from either side.
	for f in sim.fighters:
		if f.grabbed_by<0: art.draw(world,f,clock,Combat.FIGHTER_SCALE)
	for f in sim.fighters:
		if f.grabbed_by>=0: art.draw(world,f,clock,Combat.FIGHTER_SCALE)
	for p in sim.projectiles:
		arcade_projectile.draw(world,p,projectile_tick)
	for e in effects:
		impact_sparks.draw(world,e)
	if debug_boxes:
		for f in sim.fighters:
			for part in sim.hurtboxes(f): world.draw_rect(part,Color(0,1,.3,.23))
			world.draw_rect(sim.pushbox(f),Color(.3,.6,1,.6),false,2)
			if sim.is_active(f):
				for part in sim.attackboxes(f,sim.move_data(f)): world.draw_rect(part,Color(1,.2,.2,.5))

func draw_match():
	if sim is CarBonus:
		draw_bonus()
		return
	if sim.phase=="results":
		draw_results()
		return
	draw_hud()
	if selected_mode==ONLINE_MODE:
		var net_label="WAITING FOR OPPONENT" if online.waiting_ticks>15 else "%dP  /  %d MS" % [online.local_slot+1,online.ping_ms()]
		centered(net_label,147,14,WHITE)
	if sim.phase=="intro":
		if sim.round_number==1 and sim.phase_timer>Combat.ROUND_ANNOUNCE_TICKS:
			banner(stage.stage_name(),"BALTIMORE, MD",GOLD)
		else:
			var age=Combat.ROUND_ANNOUNCE_TICKS-sim.phase_timer
			round_callouts.draw_round(self,sim.round_number,sim.is_final_round(),age,Combat.ROUND_ANNOUNCE_TICKS)
	elif sim.phase=="fight" and not sim.training:
		round_callouts.draw_fight(self,Combat.ROUND_TIME_TICKS-sim.time_left)
	elif sim.phase=="round_end": draw_round_end()
	if sim.training:
		draw_rect(Rect2(26,146,338,94),Color(.005,.01,.02,.68))
		txt("TRAINING / "+DUMMY_LABELS[sim.dummy],41,171,17,GOLD)
		txt("START  PAUSE",41,195,13,MUTED,true)
		var labels={"LP":"A","MP":"B","HP":"C","LK":"X","MK":"Y","HK":"Z","THROW":"L/R"}
		var input_display=commands[0].display.slice(0,8).map(func(value): return labels.get(value,value))
		txt("INPUT  "+" ".join(input_display),41,224,14,WHITE,true)
		if training_guide_enabled: draw_training_lesson()
		
	for i in 2:
		var f=sim.fighters[i]
		if f.combo>=2:
			var combo_y=270.0 if sim.training and i==1 else 169.0
			round_callouts.draw_combo(self,f.combo,sim.tick-f.last_hit,Vector2(1040 if i==0 else 240,combo_y))

func draw_round_end():
	var subtitle="DRAW - REPLAY ROUND" if sim.winner<0 else sim.data.fighters[sim.fighters[sim.winner].kind].name+" TAKES THE ROUND"
	var knockout=sim.last_result in ["K.O.","DOUBLE KO"]
	if knockout:
		round_callouts.draw_ko(self,Combat.ROUND_END_TICKS-sim.phase_timer,Combat.ROUND_END_TICKS)
		if sim.last_result=="DOUBLE KO": subtitle="DOUBLE K.O. / "+subtitle
		centered(subtitle,290,20,WHITE)
	else:
		banner(sim.last_result,subtitle,WHITE)
	if sim.winner>=0 and not sim.round_rewards.is_empty() and sim.round_rewards[-1].perfect>0:
		centered("PERFECT!",151 if knockout else 166,30,GOLD)

func draw_training_lesson():
	var lesson:Dictionary=training_guide.current()
	if lesson.is_empty(): return
	draw_rect(Rect2(366,146,548,94),Color(.005,.01,.02,.76))
	var confirmed=training_guide.confirmation>0
	var title="DRILL %d / %d" % [training_guide.index+1,training_guide.lessons.size()]
	centered(title,171,14,MUTED)
	centered(lesson.name,198,22,GOLD)
	var input:String=lesson.input
	if input=="":
		var fighter=sim.data.fighters[sim.fighters[0].kind]
		input=special_input(lesson.move,fighter.moves[lesson.move])
	var message="NICE!" if confirmed else input
	var width=font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	var size=clampi(floori(16.0*520.0/maxf(width,520.0)),11,16)
	centered(message,224,size,Color("b5e2a5") if confirmed else WHITE)

func draw_hud():
	var points=sim.scores.duplicate()
	var round_label="ROUND "+str(sim.round_number)
	if selected_mode==0:
		points[0]=arcade.score+(0 if fight_accounted else points[0])
		if arcade.active:
			round_label="R"+str(sim.round_number)+"  "+str(arcade.cursor+1)+"/"+str(arcade.opponents.size())
	fight_hud.draw(self,sim,selected_mode,points,round_label)

func banner(title:String,subtitle:String,color:Color):
	var w=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
	arcade_text(title,(1280-w)*.5,238,64,color)
	var sw=font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	arcade_text(subtitle,(1280-sw)*.5,273,20,WHITE)

func draw_results():
	draw_rect(Rect2(0,0,1280,720),Color("050710"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	var winning_slot=clampi(sim.winner,0,1)
	var winner_kind:int=sim.fighters[winning_slot].kind
	var loser_kind:int=sim.fighters[1-winning_slot].kind
	var winner_name:String=sim.data.fighters[winner_kind].name
	var loser_name:String=sim.data.fighters[loser_kind].name
	round_callouts.draw_outcome(self,player_lost_match(),result_callout_age)
	centered(str(sim.wins[0])+" : "+str(sim.wins[1]),103,26,WHITE)
	draw_rect(Rect2(184,116,912,2),Color("8e7749"))
	results_portraits.draw(self,art,winner_kind,true,Rect2(176,132,400,315))
	results_portraits.draw(self,art,loser_kind,false,Rect2(704,132,400,315),true)
	arcade_text("VS",612,304,34,Color("a59068"))
	for item in [[winner_name,376,GOLD],[loser_name,904,WHITE]]:
		var width=font.get_string_size(item[0],HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
		arcade_text(item[0],item[1]-width*.5,480,28,item[2])
	ui_skin.surface(self,Rect2(184,500,912,72),Color("101d48"),Color("8e7749"))
	centered(results_portraits.quote(winner_kind),544,26,WHITE)
	var next_label="A  REMATCH"
	if selected_mode==0:
		next_label="A  CAMPAIGN COMPLETE" if arcade.complete() else ("A  BONUS STAGE" if bonus_due else ("A  NEXT FIGHT" if sim.winner==0 else "A  CONTINUE"))
	if selected_mode==ONLINE_MODE:
		if online.rematch[online.local_slot]: next_label="WAITING FOR OPPONENT"
		elif online.rematch[1-online.local_slot]: next_label="A  ACCEPT REMATCH"
	if not challenge_resume.is_empty(): next_label="A  RESUME ARCADE"
	var totals={"time":0,"health":0,"perfect":0}
	for reward in sim.round_rewards:
		if reward.owner==winning_slot:
			for key in totals: totals[key]+=reward[key]
	centered("TIME "+str(totals.time)+"   HEALTH "+str(totals.health)+"   PERFECT "+str(totals.perfect),592,17,GOLD)
	centered("SCORE  "+str(arcade.score if selected_mode==0 else sim.scores[winning_slot]).pad_zeros(7),617,20,WHITE)
	button(next_label,Rect2(380,633,520,37),"rematch",true)
	button("B  LEAVE ROOM" if selected_mode==ONLINE_MODE else "B  MAIN MENU",Rect2(440,682,400,30),"title")

func draw_bonus():
	if sim.phase=="intro": centered(stage.stage_name(),32,22,GOLD)
	var timer=str(clampi(ceili(sim.time_left/60.0),0,99)).pad_zeros(2)
	fight_hud.prepare()
	fight_hud.tile(self,"timer-"+timer,320,28,1,RED if sim.time_left<10*60 else Color.WHITE)
	fight_hud.tile(self,"name-%d" % sim.fighters[0].kind,17,27)
	var total=arcade.score if selected_mode==0 else sim.score
	txt("TOTAL  "+str(total).pad_zeros(7),920,75,23,GOLD)
	txt("BONUS +"+str(sim.score).pad_zeros(6),973,103,16,WHITE)
	if sim is BreakablesBonus:
		centered(str(sim.broken)+" / "+str(sim.target_count),114 if sim.challenge=="boxes" else 141,23,WHITE)
	if sim.phase=="intro":
		banner("BONUS STAGE","",GOLD)
	elif sim.phase=="results":
		draw_rect(Rect2(0,180,1280,485),Color(.005,.012,.025,.90))
		centered("PERFECT!" if sim.success else ("TIME UP" if sim.time_left<=0 else "CHALLENGE OVER"),258,62,GOLD if sim.success else WHITE)
		if sim.success:
			centered("SECRET CHARACTER CODE",310,24,WHITE)
			centered(" ".join(sim.reward_code.split("")),380,68,GOLD)
			centered(sim.reward_name,422,26,WHITE)
		centered("BONUS POINTS  +"+str(sim.score),458 if sim.success else 334,24,GOLD)
		centered("TOTAL SCORE  "+str(total).pad_zeros(7),489 if sim.success else 380,20,WHITE)
		button("A  NEXT FIGHT",Rect2(400,514,480,49),"rematch",true)

func draw_pause():
	buttons.clear()
	if pause_moves_open:
		draw_pause_moves()
		return
	draw_rect(Rect2(0,0,1280,720),Color(.006,.012,.026,.76))
	draw_texture_rect(logo,Rect2(428,133,424,163),false)
	for i in PAUSE_ACTIONS.size():
		var label="LEAVE MATCH" if selected_mode==ONLINE_MODE and PAUSE_ACTIONS[i]=="title" else PAUSE_LABELS[i]
		button(label,Rect2(471,322+i*48,338,42),PAUSE_ACTIONS[i],i==pause_cursor)
	if selected_mode==ONLINE_MODE: centered("ONLINE MATCH CONTINUES",551,15,GOLD)
	centered("D-PAD SELECT   /   A CONFIRM   /   START RESUME",584,13,MUTED)

func pause_move_slots()->Array:
	if selected_mode==ONLINE_MODE: return [online.local_slot]
	return [0,1] if selected_mode==1 and not sim is CarBonus else [0]

func draw_pause_moves():
	draw_rect(Rect2(0,0,1280,720),Color(.006,.012,.026,.76))
	centered("MOVES LIST",75,33,GOLD)
	centered("FORWARD MEANS TOWARD YOUR OPPONENT. BACK MEANS AWAY.",106,15,WHITE)
	var slots=pause_move_slots()
	for i in slots:
		var x=46+i*602 if slots.size()==2 else 347
		var d=sim.data.fighters[sim.fighters[i].kind]
		panel(Rect2(x,129,586,426),Color(.052,.075,.12,.96),Color("7b694e"))
		txt("P"+str(i+1)+" / "+d.name,x+20,164,25,Color(d.color))
		var style_hint:String=d.get("trait","")
		var hint_width=font.get_string_size(style_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		txt(style_hint,x+566-hint_width,161,14,GOLD)
		for entry in [["X","LIGHT KICK",x+20,201],["Y","MEDIUM KICK",x+207,201],["Z","HEAVY KICK",x+398,201],["A","LIGHT PUNCH",x+20,235],["B","MEDIUM PUNCH",x+207,235],["C","HEAVY PUNCH",x+398,235],["L/R","GRAPPLE AT CLOSE RANGE",x+20,270]]:
			sega_move(entry[0],entry[1],entry[2],entry[3])
		draw_rect(Rect2(x+20,283,547,2),Color("8b794f"))
		var lines:Array=[]
		for move_id in Commands.SPECIALS:
			if d.moves.has(move_id): lines.append([d.moves[move_id].name.to_upper(),special_input(move_id,d.moves[move_id])])
		if d.moves.has("command_grab"):
			lines.append([d.moves.command_grab.name.to_upper(),"ROLL BACK THROUGH DOWN TO FORWARD + L OR R"])
		if d.moves.has("air_throw"):
			lines.append([d.moves.air_throw.name.to_upper(),"L OR R NEAR AN AIRBORNE OPPONENT"])
		if d.id in ["eric","orioles-mascot"]:
			lines.append(["THREE-HIT HOLD","L OR R CLOSE. DEFENDER TAPS BUTTONS TO ESCAPE."])
		for row in lines.size():
			var y=307+row*38
			txt(lines[row][0],x+20,y,19,GOLD)
			txt(lines[row][1],x+20,y+17,13,WHITE)
	centered("BLOCK: HOLD BACK   /   LOW BLOCK: DOWN + BACK   /   DASH: TAP FORWARD TWICE",592,15,WHITE)
	centered("JUMP KICK: UP, THEN X, Y OR Z   /   CROUCH KICK: DOWN + X, Y OR Z",616,15,WHITE)
	button("B  BACK",Rect2(480,640,320,42),"back",true)

func special_input(move_id:String,move:Dictionary)->String:
	var default={"special1":"qcf_punch","special2":"dp_punch","special3":"qcb_kick","special4":"charge_down_kick"}
	match move.get("input",default.get(move_id,"")):
		"qcf_punch": return "ROLL DOWN TO FORWARD + A, B OR C"
		"dp_punch": return "FORWARD, DOWN, DOWN-FORWARD + A, B OR C"
		"qcb_punch": return "ROLL DOWN TO BACK + A, B OR C"
		"qcb_kick": return "ROLL DOWN TO BACK + X, Y OR Z"
		"qcf_kick": return "ROLL DOWN TO FORWARD + X, Y OR Z"
		"mash_kick": return "TAP X, Y OR Z THREE TIMES QUICKLY"
		"mash_punch": return "TAP A, B OR C %d TIMES QUICKLY" % int(move.get("mash_presses",3))
		"charge_back_punch": return "HOLD BACK 0.7 SEC, THEN FORWARD + A, B OR C"
		"charge_back_kick": return "HOLD BACK 0.7 SEC, THEN FORWARD + X, Y OR Z"
		"charge_down_kick": return "HOLD DOWN 0.7 SEC, THEN UP + X, Y OR Z"
	return ""

func sega_move(label:String,description:String,x:float,y:float):
	var width=58 if label=="L/R" else 31
	ui_skin.surface(self,Rect2(x,y-24,width,29),Color("20212b"),Color("bc9860"))
	var size=19 if label=="L/R" else 23
	var text_width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	txt(label,x+(width-text_width)*.5,y, size,Color("ffe5ab"))
	txt(description,x+width+10,y-2,16,WHITE)

func draw_options():
	buttons.clear()
	draw_rect(Rect2(0,0,1280,720),Color("071426"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("SETTINGS",110,54,GOLD)
	var items=option_items()
	var row_step=43 if items.size()>9 else 46
	ui_skin.surface(self,Rect2(302,149,676,items.size()*row_step+22),Color("101d36"),Color("8b794f"))
	for i in items.size():
		var item:Array=items[i]
		var row=Rect2(316,159+i*row_step,648,row_step-6)
		var selected=i==options_cursor
		if selected:
			draw_rect(row,Color("293657"))
			draw_rect(Rect2(row.position,Vector2(4,row.size.y)),GOLD)
		arcade_text(item[1],row.position.x+20,row.position.y+27,24,GOLD if selected else WHITE)
		var value:String=item[2] if item[2]!="" else "A  >"
		var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x
		arcade_text(value,row.end.x-20-width,row.position.y+27,23,GOLD if selected else BLUE)
		buttons.append({"rect":row,"action":item[0]})
	var hint="D-PAD SELECT   /   LEFT OR RIGHT ADJUST   /   A CONFIRM"
	if items[options_cursor][0]=="turbo": hint="TURBO SPEEDS UP FIGHTS BY 15%"
	if not settings_saved: hint="COULD NOT SAVE SETTINGS"
	centered(hint,607,16,MUTED if settings_saved else RED)
	button("B  BACK",Rect2(460,633,360,42),"back")

func draw_controller_setup():
	buttons.clear()
	draw_rect(Rect2(0,0,1280,720),Color("071426"))
	ui_skin.texture_surface(self,Rect2(0,0,1280,720))
	centered("CONTROLLER SETUP",93,44,GOLD)
	var y=192
	for slot in 2:
		var id=pads.slots[slot]
		var name="READY" if id>=0 else "NOT CONNECTED"
		txt("P"+str(slot+1)+"  "+name,110,y,18,WHITE)
		y+=34
	if setup_device<0:
		centered("A  SET UP THIS CONTROLLER",349,25,GOLD)
	elif setup_step<ControllerBindings.STEPS.size():
		centered("PLAYER "+str(pads.slots.find(setup_device)+1)+"  /  "+str(setup_step+1)+" OF "+str(ControllerBindings.STEPS.size()),302,20,BLUE)
		centered(ControllerBindings.LABELS[setup_step],368,33,GOLD)
		centered("RELEASE, THEN PRESS THE BUTTON SHOWN",418,18,WHITE)
	else:
		centered("CONTROLLER READY",352,34,GOLD)
	centered(setup_message,487,18,RED if setup_message.begins_with("COULD") else WHITE)
	centered("X Y Z  PUNCH     A B C  KICK     L / R  GRAPPLE",565,18,MUTED)
	var capturing=setup_device>=0 and setup_step<ControllerBindings.STEPS.size()
	centered("START  CANCEL" if capturing else "B OR START  BACK",641,17,MUTED)

func text_outline(size:int)->int:
	return 7 if size>=48 else (5 if size>=20 else 4)

func arcade_text(value:String,x:float,y:float,size:int,color:Color=WHITE):
	var point=Vector2(roundf(x),roundf(y))
	draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,text_outline(size),Color.BLACK)
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
