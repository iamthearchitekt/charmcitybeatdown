extends SceneTree
var game
var destination="res://tests/visual/hud-movement"
func _initialize(): call_deferred("run")
func snap(name:String):
	game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+"/"+name+".png");print("CAPTURE ",name)
func run():
	DirAccess.make_dir_recursive_absolute(destination)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process_input(false)
	game.stage.history_path="res://.runtime/hud-movement-stage.cfg"
	game.bonus_rewards.path="res://.runtime/hud-movement-rewards.cfg";game.bonus_rewards.earned=[]
	game.arcade.scores_path="res://.runtime/hud-movement-scores.cfg"
	game.selected_mode=1;game.selection=[11,13];game.begin_match();game.sim.phase="fight"
	game.sim.scores=[1234567,9876543];game.sim.time_left=96*60
	game.sim.fighters[0].x=400;game.sim.fighters[1].x=850
	await snap("hud-long-names")
	game.screen="select";game.selection=[11,12];game.unlocks.all_unlocked=false;game.unlocks.unlocked=[]
	await snap("locked-select")
	game.unlocks.all_unlocked=true;await snap("unlocked-select")
	game.screen="match"
	for first in range(0,14,2):
		game.sim.new_match(first,first+1);game.sim.phase="fight";game.sim.time_left=96*60
		game.sim.fighters[0].x=400;game.sim.fighters[1].x=850
		for phase in 2:
			for f in game.sim.fighters: f.walk=1;f.walk_phase=phase
			await snap("walk-"+str(first)+"-"+str(phase))
	game.stage.set_stage(5);game.clock=0
	for kind in [0,2,6,7,8,10,11,12,13]:
		game.sim.new_match(kind,1);game.sim.phase="fight";game.sim.time_left=96*60
		var f=game.sim.fighters[0];f.x=450;game.sim.fighters[1].x=1020
		game.sim.start_move(f,"special1");f.frame=0
		await snap("charge-"+str(kind))
		f.frame=int(game.sim.move_data(f).startup)-1
		game.sim.step([{},{}])
		await snap("release-"+str(kind))
	game.sim.new_match(11,6);game.sim.phase="fight";game.sim.time_left=96*60
	game.clock=0;await snap("poe-storm-0")
	game.clock=.25;await snap("poe-storm-1")
	game.sim.phase="intro";game.sim.phase_timer=140;game.sim.round_number=1;await snap("intro-round1")
	game.sim.round_number=2;await snap("intro-round2")
	game.selected_mode=0;game.begin_bonus("kegs");game.sim.phase="fight";game.sim.score=2250
	game.sync_match_end_audio();await snap("keg-score")
	game.sim.finish(true);game.sync_match_end_audio();await snap("keg-payout")
	game.arcade.active=false;game.queue_free();await process_frame
	for p in ["res://.runtime/hud-movement-stage.cfg","res://.runtime/hud-movement-rewards.cfg","res://.runtime/hud-movement-scores.cfg"]: DirAccess.remove_absolute(p)
	print("HUD/MOVEMENT VISUAL COMPLETE");quit()
