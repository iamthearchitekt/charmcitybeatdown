extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var game
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func snap(name:String):
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/visual/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_physics_process(false)
	check(game.art.sheets[2].get_width()>0 and game.art.jump_overrides.has(2),"Alex's new atlas covers ordinary attacks and both jumps")
	check(game.art.sprite_frame(2,0).size.y<game.art.sprite_frame(0,0).size.y,"Alex has a smaller standing presentation than Marcus")
	check(game.art.throw_frame(2,0).sheet.get_image().get_data()==game.art.sheets[2].get_image().get_data(),"Alex throws use the revised outfit/build")
	for frame in 4:
		for kind in 11:
			var pose=game.art.throw_frame(kind,frame)
			check(pose.size==Vector2(pose.texture.get_size())*game.art.PIXEL_UNIT,"Shared throw pixel density "+str(kind)+"/"+str(frame))
	var distances=[]
	for kind in [0,2]:
		var s=Combat.new();s.new_match(kind,0);s.phase="fight";s.fighters[0].x=200;s.fighters[1].x=1196
		for i in 40: s.step([{"dx":1},{}])
		distances.append(s.fighters[0].x-200)
	check(distances[1]>distances[0]*1.15 and distances[1]<distances[0]*1.25,"Alex moves about 19 percent faster than Marcus")
	game.selected_mode=1;game.selection=[2,0];game.begin_match();game.sim.phase="fight";game.sim.time_left=98*60
	await snap("alex-athletic-vs-marcus")
	game.screen="select";await snap("alex-athletic-select")
	game.screen="match";game.sim.fighters[0].state="ko";game.sim.fighters[0].health=0
	await snap("alex-athletic-supine-ko")
	game.queue_free();await process_frame
	print("ALEX ATHLETIC RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
