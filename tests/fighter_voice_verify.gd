extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Sfx=preload("res://scripts/sfx_bank.gd")
var checks=0
var failures=0
var game
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func count_cue(cue:String)->int:
	return game.sfx.playback_log.filter(func(e):return e.cue==cue).size()
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_physics_process(false)
	for kind in 11:
		game.sfx.stop_all()
		var sim=Combat.new();sim.new_match(0,kind);sim.phase="fight";sim.wins=[1,0];sim.fighters[1].health=0;sim.end_round()
		for event in sim.events: game.sfx.combat_event(event,sim)
		var cue="final_ko_female" if Sfx.female(kind) else "final_ko_male"
		check(count_cue(cue)==1 and count_cue("ko_breakwater")==0 and count_cue("ko_redline")==0,"Supplied final KO plays exactly once for fighter "+str(kind))
		check(game.sfx.has_final_ko_audio(),"Final voice holds results audio until complete")
	for sex in ["male","female"]:
		var spec=game.sfx.config.cues["block_"+sex]
		check(spec.files.size()==2 and spec.random and spec.db==-15 and spec.group=="grunt","Two audible restrained randomized "+sex+" block grunts")
		var seen={}
		for i in 40:
			game.sfx.recent.erase("block_"+sex)
			game.sfx.play("block_"+sex);seen[game.sfx.playback_log[-1].file]=true
		check(seen.size()==2,"Both "+sex+" variants appear")
	for kind in 11:
		for slot in 2:
			game.sfx.stop_all()
			var sim=Combat.new();sim.fighters[slot].kind=kind
			game.sfx.combat_event({"type":"block","owner":1-slot},sim)
			check(count_cue("block_female" if Sfx.female(kind) else "block_male")==1,"Block voice belongs to defender "+str(kind)+" in slot "+str(slot))
	game.selected_mode=1;game.begin_match();game.sim.phase="fight"
	game.sfx.play("block_male");game.sync_match_end_audio()
	var grunt_slot=game.sfx.voice_groups.find("grunt")
	var grunt_stream=game.sfx.voices[grunt_slot].stream
	check(grunt_slot==6 and game.music.volume_db==-17,"Audible grunt has a reserved voice and ducks stage music by four dB")
	for i in 12: game.sfx.play("heavy_punch")
	check(game.sfx.voices[grunt_slot].stream==grunt_stream and game.sfx.voices[grunt_slot].playing,"Rapid impact sounds cannot steal or cut off the grunt voice")
	game.sfx.voices[grunt_slot].stop();game.sync_match_end_audio()
	check(game.music.volume_db==-13,"Stage music returns to its normal level after the grunt")
	game.selected_mode=0;game.selection[0]=0;game.begin_match()
	game.sim.new_match(0,5);game.sim.wins=[0,1];game.sim.fighters[0].health=0;game.sim.end_round()
	for e in game.sim.events: game.dispatch_combat_event(e)
	game.sim.phase="results";game.sync_match_end_audio()
	check(count_cue("female_victory")==0 and not game.match_end_played,"Female taunt waits for final KO clip")
	game.sfx.set_paused(true)
	var frozen=true
	for i in game.sfx.voices.size():
		if game.sfx.voice_groups[i]=="final_ko" and game.sfx.voices[i].playing: frozen=frozen and game.sfx.voices[i].stream_paused
	check(frozen,"Pause freezes supplied final voice")
	game.sfx.set_paused(false)
	for v in game.sfx.voices: v.stop()
	game.sync_match_end_audio()
	check(count_cue("female_victory")==1 and not game.match_end_played,"Female CPU victory starts taunt after final KO")
	game.sync_match_end_audio()
	check(count_cue("female_victory")==1 and not game.match_end_played,"Taunt plays once and completion waits")
	for v in game.sfx.voices: v.stop()
	game.sync_match_end_audio()
	check(game.match_end_played,"Results audio starts after taunt finishes")
	for mode in [0,1]:
		game.selected_mode=mode;game.begin_match();game.sim.new_match(0,0);game.sim.winner=1;game.sim.wins=[0,2];game.sim.fighters[0].health=0;game.sim.phase="results";game.sync_match_end_audio()
		check(count_cue("female_victory")==0,"No female taunt for male winner, mode "+str(mode))
	game.queue_free();await process_frame
	print("FIGHTER VOICE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
