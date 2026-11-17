extends SceneTree
var main
var failures=0
var count=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	count+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
	main.set_physics_process(false);main.selected_mode=1;main.begin_match()
	for kind in 4:
		main.sim.new_match(kind,kind);main.sim.phase="fight"
		main.sim.fighters[0].x=330;main.sim.fighters[1].x=950
		main.sim.step([{"up":true},{}])
		check(main.sim.fighters[0].move=="" and main.art.pose(main.sim.fighters[0],0)==16,"Plain jump uses neutral tuck for fighter "+str(kind))
		var health=main.sim.fighters[1].health
		for tick in 5: main.sim.step([{},{}])
		check(main.sim.fighters[1].health==health,"Plain jump has no attack damage for fighter "+str(kind))
		main.sim.step([{"command":"hk"},{}])
		var f=main.sim.fighters[0]
		check(f.move=="air_hk","Kick input starts legal air kick for fighter "+str(kind))
		var m=main.sim.move_data(f)
		f.frame=m.startup
		check(main.art.pose(f,0)==11,"Active air kick extends leg for fighter "+str(kind))
		f.frame=0
		check(main.art.pose(f,0)==16,"Air attack winds up from neutral jump")
		f.frame=m.startup+m.active+m.recovery-1
		check(main.art.pose(f,0)==16,"Air attack retracts to neutral jump")
		f.move="air_lp";f.frame=main.sim.move_data(f).startup
		check(main.art.pose(f,0)==17,"Air punch has its own pose")
		f.move="";f.y=440
		var other=main.sim.fighters[1];other.y=440;other.move="air_hk";other.frame=main.sim.move_data(other).startup
		main.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/visual/jump-vs-kick-"+str(kind)+".png")
	main.queue_free();await process_frame
	print("JUMP POSE CHECKS: ",count,"; FAILURES: ",failures)
	quit(1 if failures else 0)
