extends Control
## BSOD Interactive's developer ident, shown once per application launch.
const GameSettings=preload("res://scripts/game_settings.gd")
const GAME_SCENE="res://main.tscn"
const VIDEO_PATH="res://assets/video/bsod-interactive-startup.ogv"
const VIDEO_ASPECT=16.0/9.0
const SKIP_DELAY=0.20
const VIDEO_TIMEOUT=9.0
var video:VideoStreamPlayer
var elapsed=0.0
var finishing=false
var transitioning=false
var load_requested=false
var skip_requested=false
var trigger_released:Dictionary={}

func _ready():
	GameSettings.apply_system_settings(GameSettings.read())
	var background=ColorRect.new()
	background.color=Color.BLACK
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video=VideoStreamPlayer.new()
	video.name="DeveloperVideo"
	video.expand=true
	video.loop=false
	video.volume_db=0.0
	video.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(video)
	resized.connect(fit_video)
	fit_video()
	video.finished.connect(finish_intro)
	for device in Input.get_connected_joypads():
		for axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			trigger_released[str(device)+":"+str(axis)]=Input.get_joy_axis(device,axis)<.25
	load_requested=ResourceLoader.load_threaded_request(GAME_SCENE)==OK
	# Existing automated game-review entry points remain direct-to-screen.
	for arg in OS.get_cmdline_user_args():
		if arg in ["--skip-intro","--show-match","--show-select","--show-bonus","--demo"]:
			finish_intro()
			return
	if not FileAccess.file_exists(VIDEO_PATH):
		finish_intro()
		return
	var stream=VideoStreamTheora.new()
	stream.file=VIDEO_PATH
	video.stream=stream
	video.play()

func fit_video():
	if not is_instance_valid(video): return
	var fitted=Vector2(size.x,size.x/VIDEO_ASPECT)
	if fitted.y>size.y: fitted=Vector2(size.y*VIDEO_ASPECT,size.y)
	video.size=fitted
	video.position=(size-fitted)*.5

func _process(delta:float):
	elapsed+=delta
	if skip_requested and elapsed>=SKIP_DELAY: finish_intro()
	# Corrupt or interrupted video playback must never trap the player at boot.
	if elapsed>=VIDEO_TIMEOUT and not finishing: finish_intro()
	if not finishing or transitioning: return
	var status=ResourceLoader.load_threaded_get_status(GAME_SCENE) if load_requested else ResourceLoader.THREAD_LOAD_FAILED
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	transitioning=true
	enter_game.call_deferred()

func finish_intro():
	if finishing: return
	finishing=true
	if is_instance_valid(video): video.stop()

func enter_game():
	var scene=ResourceLoader.load_threaded_get(GAME_SCENE) if load_requested and ResourceLoader.load_threaded_get_status(GAME_SCENE)==ResourceLoader.THREAD_LOAD_LOADED else load(GAME_SCENE)
	if not scene is PackedScene:
		push_error("Could not load Charm City Beatdown after the developer intro.")
		get_tree().quit(1)
		return
	# The last video frame remains visible until the game is instantiated.
	# Title music is created only in the game scene, after intro audio has stopped.
	get_tree().change_scene_to_packed(scene)

func _input(event:InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F,KEY_F11]:
		var enabled=not GameSettings.fullscreen()
		GameSettings.set_fullscreen(enabled)
		var settings=GameSettings.read()
		settings.set_value("display","fullscreen",enabled)
		GameSettings.save(settings)
		get_viewport().set_input_as_handled()
		return
	if finishing: return
	var skip=false
	if event is InputEventKey: skip=event.pressed and not event.echo
	elif event is InputEventJoypadButton: skip=event.pressed
	elif event is InputEventMouseButton: skip=event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		# Sega C can be an analog trigger. Require a release first, avoiding drift
		# and controllers connected with a trigger already held down.
		var key=str(event.device)+":"+str(event.axis)
		if event.axis_value<.25: trigger_released[key]=true
		skip=event.axis_value>.65 and trigger_released.get(key,false)
	if skip:
		get_viewport().set_input_as_handled()
		skip_requested=true
		if elapsed>=SKIP_DELAY: finish_intro()

func _exit_tree():
	if is_instance_valid(video):
		video.stop()
		video.stream=null
