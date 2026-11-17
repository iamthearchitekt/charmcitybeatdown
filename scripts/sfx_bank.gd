extends Node
## Bounded, pause-aware SFX playback. Source WAVs retain original pitch/sample rate.
const VOICES=8
const COMBAT_VOICES=7
const MIX_HEADROOM_DB=-1.0
var config:Dictionary
var streams:Dictionary={}
var variants:Dictionary={}
var recent:Dictionary={}
var voices:Array=[]
var voice_groups:Array=[]
var next_voice:int=0
var paused:bool=false
var playback_log:Array=[]

func _ready():
	config=JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx-map.json"))
	for cue in config.cues:
		for file in config.cues[cue].files:
			if not streams.has(file): streams[file]=load(config.base_path+file)
	for i in VOICES:
		var player=AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
		voice_groups.append("")

func set_paused(value:bool):
	if paused==value: return
	paused=value
	for i in voices.size():
		voices[i].stream_paused=paused and voice_groups[i]!="ui"

func stop_all():
	for player in voices: player.stop()
	playback_log.clear()

func _exit_tree():
	stop_all()
	streams.clear()

func play(cue:String)->bool:
	if not config.cues.has(cue): return false
	var spec=config.cues[cue]
	var group=spec.get("group","combat")
	if paused and group!="ui": return false
	var now=Time.get_ticks_msec()
	if now-int(recent.get(cue,-9999))<spec.get("min_interval_ms",0): return false
	recent[cue]=now
	if group=="ui":
		for i in voices.size():
			if voice_groups[i]=="ui": voices[i].stop()
	var selected:Array=[]
	if spec.get("layered",false): selected=spec.files
	else:
		var index=int(variants.get(cue,0))%spec.files.size()
		selected=[spec.files[index]]
		variants[cue]=index+1
	for file in selected:
		# Reserve the final voice for UI so pause feedback cannot steal a paused hit.
		var slot=VOICES-1 if group=="ui" else next_voice
		if group!="ui":
			for i in COMBAT_VOICES:
				if not voices[i].playing and not voices[i].stream_paused: slot=i;break
			next_voice=(slot+1)%COMBAT_VOICES
		var player=voices[slot]
		player.stop()
		player.stream_paused=false
		player.stream=streams[file]
		player.volume_db=spec.db+MIX_HEADROOM_DB
		player.pitch_scale=1.0
		voice_groups[slot]=group
		player.play()
		playback_log.append({"cue":cue,"file":file,"db":player.volume_db})
	while playback_log.size()>128: playback_log.pop_front()
	return true

static func impact_cue(event:Dictionary)->String:
	if event.type=="block": return "block"
	var move=String(event.get("move","lp"))
	if move=="throw": return "throw_hit"
	if move.begins_with("special"): return "special_hit"
	var strength="heavy" if event.get("heavy",false) else "light"
	return strength+("_kick" if move.ends_with("k") else "_punch")

static func attack_cue(event:Dictionary)->String:
	var move=String(event.move)
	if move=="special1": return "projectile" if int(event.get("style",int(event.fighter)%2))==0 else "rush"
	if move=="special2": return "rise"
	return "swing_heavy" if "h" in move or move=="throw" else "swing_light"

func combat_event(event:Dictionary,sim):
	match event.type:
		"attack": play(attack_cue(event))
		"hit","block": play(impact_cue(event))
		"dash": play("dash")
		"jump": play("jump")
		"land": play("ko_land" if event.get("ko",false) else ("hard_land" if event.get("hard",false) else "land"))
		"ko":
			var final_loss=not sim.training and sim.winner>=0 and sim.wins[sim.winner]>=2
			for f in sim.fighters:
				if final_loss and f.slot!=sim.winner and f.health<=0:
					play("ko_breakwater" if sim.data.fighters[f.kind].style==0 else "ko_redline")
				if f.state=="ko" and f.y>=sim.FLOOR: play("ko_land")
