extends SceneTree
var checks:Array=[]
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks.append(("PASS " if ok else "FAIL ")+label)
	print(checks[-1])
	if not ok: failures+=1

func run():
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process_input(false)
	main.selected_mode=1
	main.begin_match()
	var recorder=AudioEffectRecord.new()
	recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var effect_index=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	main.sfx.play("heavy_punch")
	await create_timer(.08).timeout
	var active=main.sfx.voices.filter(func(v):return v.playing)
	check(not active.is_empty(),"Real audio driver starts imported effect playback")
	var voice=active[0] if not active.is_empty() else main.sfx.voices[0]
	main.toggle_pause()
	await create_timer(.06).timeout
	var paused_position=voice.get_playback_position()
	await create_timer(.12).timeout
	check(voice.stream_paused and absf(voice.get_playback_position()-paused_position)<.015,"Active effect playback position remains frozen during pause")
	main.toggle_pause()
	await create_timer(.10).timeout
	check(not voice.stream_paused,"Resume restores active effect playback")
	for cue in ["light_punch","heavy_kick","block","projectile","ko_land","round_start"]:
		main.sfx.play(cue)
		await create_timer(.23).timeout
	for cue in ["projectile_voice","hurricane_kick","spinning_kick","rapid_kick_hit"]:
		main.sfx.play(cue)
		await create_timer(.20).timeout
	for i in 8: main.sfx.play("heavy_kick")
	await create_timer(.9).timeout
	for cue in ["ko_breakwater","ko_redline"]:
		main.sfx.play(cue)
		await create_timer(.08).timeout
		check(main.sfx.voices.any(func(v):return v.playing and v.stream==main.sfx.streams[main.sfx.config.cues[cue].files[0]]),"Real audio driver plays "+cue+" defeat voice")
		await create_timer(1.4).timeout
	main.sfx.play("final_ko_male");main.sfx.play("final_ko_female")
	main.sfx.play("heavy_punch");main.sfx.play("heavy_kick")
	main.sfx.play("ko_land");main.sfx.play("ko_land")
	await create_timer(4.7).timeout
	recorder.set_recording_active(false)
	var recording=recorder.get_recording()
	var peak=0
	var audible=0
	var samples=recording.data
	for i in range(0,samples.size()-1,2):
		var sample=absi(samples.decode_s16(i))
		peak=maxi(peak,sample)
		if sample>100: audible+=1
	check(audible>1000,"Engine mix contains decoded, non-silent SFX audio")
	check(peak<32750,"Overlapping effects retain headroom without digital clipping")
	print("Recorded peak: ",snappedf(linear_to_db(float(peak)/32768.0),.01)," dBFS")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record="): recording.save_to_wav(arg.trim_prefix("--record="))
	AudioServer.remove_bus_effect(0,effect_index)
	main.queue_free()
	await process_frame
	await create_timer(.15).timeout
	var file=FileAccess.open("res://tests/audio-mix-verification.txt",FileAccess.WRITE)
	file.store_string("\n".join(checks)+"\nPeak sample: "+str(peak)+"\nFailures: "+str(failures))
	quit(1 if failures else 0)
