extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const CPU=preload("res://scripts/cpu.gd")
var checks=0
var failures=0
var game
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	game._input(event)
func guard_samples(learned:bool)->int:
	var sim=Combat.new();sim.phase="fight";sim.fighters[0].x=400;sim.fighters[1].x=570
	sim.fighters[0].move="c_lk";sim.fighters[0].frame=5
	var cpu=CPU.new();cpu.rng.seed=413;cpu.observed_move="c_lk";cpu.observed_frame=5
	cpu.repeated_move="c_lk";cpu.repeat_count=4 if learned else 0;cpu.last_repeat_tick=sim.tick
	var guarded=0
	for i in 200:
		cpu.reaction=0;cpu.cooldown=20;cpu.rest=0;cpu.burst=0
		var control=cpu.control(sim,1,1)
		if control.back and control.down: guarded+=1
	return guarded
func run():
	DirAccess.make_dir_recursive_absolute("res://tests/visual")
	var sim=Combat.new();sim.new_match(1,0);sim.phase="fight"
	sim.fighters[0].x=450;sim.fighters[1].x=610;sim.fighters[1].health=1
	sim.step([{"command":"special1"},{}])
	for i in 50:
		if sim.phase=="round_end": break
		sim.step([{},{}])
	var winner=sim.fighters[0]
	check(sim.phase=="round_end" and winner.move=="special1","KO retains the winning attack instead of snapping to idle")
	var before_x=winner.x;var before_frame=winner.frame
	sim.freeze=0;sim.step([{"command":"hk"},{}])
	check(winner.frame>before_frame and winner.x>before_x,"Winning rush continues its follow-through movement")
	check(winner.move=="special1","Post-KO attack presses cannot start a new move")
	var health=sim.fighters[1].health
	for i in 65: sim.step([{},{}])
	check(winner.move=="" and sim.fighters[1].health==health,"Follow-through finishes normally without extra hits")
	var cpu=CPU.new();sim=Combat.new();sim.phase="fight";sim.fighters[1].stun=8
	for i in 4:
		sim.fighters[0].move="";cpu.control(sim,1,1)
		sim.tick+=20;sim.fighters[0].move="lp";sim.fighters[0].frame=1
		cpu.control(sim,1,1)
	check(cpu.repeat_count==4,"CPU recognizes repeated attacks while being hit")
	check(cpu.intent.get("back",false),"CPU learns to hold guard through hitstun against spam")
	sim.tick+=211;sim.fighters[0].move="";cpu.control(sim,1,1)
	check(cpu.repeat_count==0,"Attack memory fades rather than permanently countering the player")
	var normal=guard_samples(false);var learned=guard_samples(true)
	print("GUARD DECISIONS normal=",normal," learned=",learned)
	check(learned>normal+10 and learned<195,"Learning increases defense while leaving realistic mistakes")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	check(game.logo.get_width()==512,"Logo uses a detailed 512-pixel raster rather than coarse blocks")
	await snap("polished-title")
	game.action("cheats")
	game.unlocks.path="res://.runtime/unlock-test.cfg";game.unlocks.all_unlocked=false;game.unlocks.unlocked=[]
	check(game.screen=="cheats" and game.cheat_slots==["","",""],"Main-menu cheat entry opens three blank character slots")
	await snap("cheat-three-slots")
	key(KEY_M);check(not game.muted and game.cheat_slots[0]=="M","Letters in cheat entry do not trigger gameplay hotkeys")
	game.cheat_slots=["","",""];game.cheat_cursor=0
	key(KEY_A);key(KEY_L);key(KEY_L);key(KEY_ENTER)
	check(game.cheat_message=="ALL CHARACTERS UNLOCKED","Three-character master code redeems successfully")
	check(game.unlocks.available({"id":"test-hidden","locked":true}),"Master code unlocks registered hidden characters")
	var restored=game.CharacterUnlocks.new();restored.path=game.unlocks.path;restored.load_saved()
	check(restored.all_unlocked,"Character unlocks persist after reload")
	game.cheat_slots=["X","X","X"];game.action("confirm")
	check(game.cheat_message=="INVALID CODE","Unknown cheat codes are rejected")
	for entry in [["POE","edgar-allan-poe","EDGAR ALLAN POE"],["LMR","lamar-jackson","LAMAR JACKSON"],["REL","orioles-mascot","ORIOLES MASCOT"]]:
		game.unlocks.all_unlocked=false
		check(game.unlocks.redeem(entry[0])==entry[2]+" UNLOCK SAVED","Three-slot code saves future unlock for "+entry[2])
		var saved_unlocks=game.CharacterUnlocks.new();saved_unlocks.path=game.unlocks.path;saved_unlocks.load_saved()
		check(entry[1] in saved_unlocks.unlocked and not game.sim.data.fighters.any(func(f):return f.id==entry[1]),"Future unlock persists without exposing unfinished roster art")
	game.unlocks.all_unlocked=false;game.unlocks.unlocked=[]
	for entry in [[4,"CHELSEA"],[5,"VIVIAN"]]:
		check(game.unlocks.available(game.sim.data.fighters[entry[0]]),entry[1]+" is available with a fresh save")
	var base_girl=game.sim.data.fighters[1];var viv=game.sim.data.fighters[5]
	check(viv.speed>base_girl.speed and viv.speed<base_girl.speed*1.1,"Vivian has a modest movement-speed advantage")
	check(viv.moves.values().all(func(m):return m.damage>base_girl.moves[viv.moves.find_key(m)].damage and m.damage<=base_girl.moves[viv.moves.find_key(m)].damage*1.12),"Vivian's damage advantage stays modest across her move kit")
	game.action("title");game.selected_mode=1;game.selection=[0,1];game.begin_match();game.sim.phase="fight"
	await create_timer(.15).timeout
	var music_before=game.music.get_playback_position()
	game.sim.fighters[1].health=0;game.sim.end_round()
	for event in game.sim.events: game.dispatch_combat_event(event)
	game.sync_match_end_audio();await create_timer(.15).timeout
	check(game.music.playing and game.music.get_playback_position()>music_before,"First-round KO keeps the same music playing")
	var round_end_position=game.music.get_playback_position()
	game.sim.reset_round();game.sync_match_end_audio();await create_timer(.15).timeout
	check(game.music.playing and game.music.get_playback_position()>round_end_position,"Next-round intro continues playback without restarting")
	game.sim.phase="fight";game.sim.wins=[1,0];game.sim.fighters[1].health=0;game.sim.end_round()
	for event in game.sim.events: game.dispatch_combat_event(event)
	game.sync_match_end_audio()
	check(not game.music.playing,"Only the completed match stops level music")
	var test_image=Image.create(24,24,false,Image.FORMAT_RGBA8);test_image.fill(Color.TRANSPARENT)
	for y in range(3,21):
		for x in range(3,21): test_image.set_pixel(x,y,Color(.28,.28,.28,1))
		test_image.set_pixel(3,y,Color(.05,.65,.85,1))
	test_image.set_pixel(12,12,Color(.1,.45,.65,1))
	test_image.set_pixel(20,12,Color(.55,.04,.23,1))
	game.art.remove_colored_rims(test_image)
	check(absf(test_image.get_pixel(3,12).r-test_image.get_pixel(3,12).b)<.01,"Baked-in cyan edge light is replaced by neutral material color")
	check(test_image.get_pixel(12,12).b>.6,"Interior blue clothing color remains intact")
	check(test_image.get_pixel(20,12).r>.5 and test_image.get_pixel(20,12).g<.1,"Berry lipstick is preserved during colored-rim cleanup")
	game.sim.new_match(0,1);game.sim.phase="fight";game.sim.time_left=98*60;game.stage.set_stage(4)
	game.sim.start_move(game.sim.fighters[0],"hk");game.sim.fighters[0].frame=13
	check(game.art.sprite_frame(0,7).sheet==game.art.high_kick_sheet,"Marcus high kick uses the corrected anatomical pose")
	await snap("marcus-corrected-kick")
	game.sim.new_match(0,1);game.sim.phase="fight";game.sim.time_left=98*60
	await snap("neutral-marcus-brook-lynne")
	game.sim.new_match(2,3);game.sim.phase="fight";game.sim.time_left=98*60
	await snap("neutral-alex-lauren")
	game.stage.set_stage(3);await snap("camden-fine-crowd")
	game.screen="select";game.select_slot=0;await snap("polished-select")
	game.queue_free();await process_frame
	DirAccess.remove_absolute("res://.runtime/unlock-test.cfg")
	print("POLISH RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
