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
			if not streams.has(file): streams[file]=raw_wav(config.base_path+file) if "fighter-voices" in file or file in ["58_break_glass.wav","45_dhalsim_flame.wav","47_shoto_hadoken.wav","49_shoto_tatsumakisenpuukyaku.wav","4A_chunli_spinningbirdkick.wav","5B_zap_1.wav","5C_zap_2.wav","5D_whoosh_2.wav","5E_zap_3.wav"] else load(config.base_path+file)
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
	for i in voices.size():
		voices[i].stop();voices[i].stream_paused=false;voice_groups[i]=""
	playback_log.clear()
	recent.clear()

func has_final_ko_audio()->bool:
	for i in voices.size():
		if voice_groups[i] in ["final_ko","victory"] and (voices[i].playing or voices[i].stream_paused): return true
	return false

func has_grunt_audio()->bool:
	for i in voices.size():
		if voice_groups[i]=="grunt" and (voices[i].playing or voices[i].stream_paused): return true
	return false

static func female(kind:int)->bool:
	return kind in [1,3,4,5,9]

static func raw_wav(path:String)->AudioStreamWAV:
	var bytes=FileAccess.get_file_as_bytes(path.simplify_path())
	var stream=AudioStreamWAV.new()
	var offset=12
	while offset+8<=bytes.size():
		var chunk=bytes.slice(offset,offset+4).get_string_from_ascii()
		var length=bytes.decode_u32(offset+4)
		if chunk=="fmt ":
			assert(bytes.decode_u16(offset+8)==1 and bytes.decode_u16(offset+22)==16,"Voice export must be PCM16 WAV")
			stream.format=AudioStreamWAV.FORMAT_16_BITS
			stream.stereo=bytes.decode_u16(offset+10)==2
			stream.mix_rate=bytes.decode_u32(offset+12)
		elif chunk=="data": stream.data=bytes.slice(offset+8,offset+8+length)
		offset+=8+length+(length%2)
	stream.resource_name=path.get_file()
	return stream

func _exit_tree():
	stop_all()
	streams.clear()

func play(cue:String,gain_db:float=0.0,forced_file:String="")->bool:
	if not config.cues.has(cue): return false
	var spec=config.cues[cue]
	var group=spec.get("group","combat")
	if paused and group!="ui": return false
	var now=Time.get_ticks_msec()
	if forced_file=="" and now-int(recent.get(cue,-9999))<spec.get("min_interval_ms",0): return false
	recent[cue]=now
	if group=="ui":
		for i in voices.size():
			if voice_groups[i]=="ui": voices[i].stop()
	var selected:Array=[]
	if forced_file!="": selected=[forced_file]
	elif spec.get("layered",false): selected=spec.files
	else:
		var index=randi_range(0,spec.files.size()-1) if spec.get("random",false) else int(variants.get(cue,0))%spec.files.size()
		selected=[spec.files[index]]
		variants[cue]=index+1
	for file in selected:
		# Reserve the final voice for UI so pause feedback cannot steal a paused hit.
		var slot=VOICES-1 if group=="ui" else (COMBAT_VOICES-1 if group=="grunt" else next_voice)
		# Reserve one combat voice for grunts so a new impact cannot immediately cut
		# off the defender's clip. UI retains its separate final slot.
		if group not in ["ui","grunt"]:
			for i in COMBAT_VOICES-1:
				if not voices[i].playing and not voices[i].stream_paused: slot=i;break
			next_voice=(slot+1)%(COMBAT_VOICES-1)
		var player=voices[slot]
		player.stop()
		player.stream_paused=false
		player.stream=streams[file]
		player.volume_db=spec.db+MIX_HEADROOM_DB+gain_db+float(spec.get("file_gain_db",{}).get(file,0))
		player.pitch_scale=1.0
		voice_groups[slot]=group
		player.play()
		playback_log.append({"cue":cue,"file":file,"db":player.volume_db})
	while playback_log.size()>128: playback_log.pop_front()
	return true

static func impact_cue(event:Dictionary)->String:
	if event.type=="block": return "block"
	if event.get("element","")=="electric": return "electric_hit"
	if event.get("element","")=="fire": return "flame_hit"
	var move=String(event.get("move","lp"))
	if move in ["special3","special4"]: return "rapid_kick_hit"
	if event.get("grapple",false) or move in ["throw","command_grab","air_throw"]: return "throw_hit"
	if move.begins_with("special"): return "special_hit"
	var strength="heavy" if event.get("heavy",false) else "light"
	return strength+("_kick" if move.ends_with("k") else "_punch")

static func attack_cue(event:Dictionary)->String:
	if event.get("element","")=="electric": return "electric"
	if event.get("element","")=="fire": return "flame"
	var move=String(event.move)
	if move=="special3": return "hurricane_kick" if int(event.fighter)==2 else "rapid_kick"
	if move=="special4": return "spinning_kick"
	if move=="special1": return "projectile" if int(event.get("style",int(event.fighter)%2))==0 else "rush"
	if move=="special2": return "rise"
	return "swing_heavy" if "h" in move or move=="throw" else "swing_light"

func combat_event(event:Dictionary,sim):
	match event.type:
		"projectile_clash": play("special_hit")
		"projectile_spawn": play("projectile_voice")
		"attack": play(attack_cue(event))
		"electric_pulse": play("electric_pulse")
		"hit": play(impact_cue(event))
		"block":
			play("block")
			var defender=sim.fighters[1-int(event.owner)]
			play("block_female" if female(defender.kind) else "block_male")
		"dash": play("dash")
		"jump": play("jump")
		"bounce": play("hard_land")
		"land": play("ko_land" if event.get("ko",false) else ("hard_land" if event.get("hard",false) else "land"))
		"ko":
			for i in voices.size():
				if voice_groups[i]=="grunt": voices[i].stop()
			var final_ko=sim.winner>=0 and sim.wins[sim.winner]>=2
			for f in sim.fighters:
				if not sim.training and f.health<=0:
					var cue="ko_breakwater" if sim.data.fighters[f.kind].style==0 else "ko_redline"
					if final_ko: play("final_ko_female" if female(f.kind) else "final_ko_male")
					else: play(cue)
				if f.state=="ko" and f.y>=sim.FLOOR: play("ko_land")
