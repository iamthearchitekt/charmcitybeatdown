extends SceneTree

class Player extends "res://scripts/main.gd":
	var axis=0

	func raw_control(slot:int)->Dictionary:
		var raw=super.raw_control(slot)
		raw.dx=axis
		return raw

var host:Player
var guest:Player
var checks=0
var failures=0

func _initialize(): call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)

func pump():
	await physics_frame
	host._physics_process(1.0/60.0)
	guest._physics_process(1.0/60.0)

func wait_for(condition:Callable,limit:int=420)->bool:
	for frame in limit:
		await pump()
		if condition.call(): return true
	return false

func fail_and_quit(reason:String):
	print("HOST ",host.screen," / ",host.online.state," / ",host.online.status)
	print("GUEST ",guest.screen," / ",guest.online.state," / ",guest.online.status)
	print("FAIL ",reason)
	quit(1)

func run():
	var args=OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Pass the running test relay URL after --.")
		quit(1)
		return
	host=Player.new()
	guest=Player.new()
	for game in [host,guest]:
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process_input(false)
		game.action("online")
		game.online.relay_url=args[0]
	guest.online_code.text="invalid"
	guest.action("join_room")
	check(guest.online.status.contains("8-CHARACTER"),"The game rejects malformed codes before connecting")
	host.action("host_room")
	if not await wait_for(func(): return host.online.state=="listening"):
		fail_and_quit("The relay did not return a room code")
		return
	var code=host.displayed_room_code()
	check(code.length()==9 and code[4]=="-","The host receives a shareable room code")
	guest.online_code.text=" "+code.to_lower()+" "
	guest.action("join_room")
	if not await wait_for(func(): return host.screen=="select" and guest.screen=="select"):
		fail_and_quit("Could not use a room code to connect two game instances")
		return
	check(host.select_slot==0 and guest.select_slot==1,"The guest joins with a pasted lowercase code and receives player two")
	host.action("fighter4")
	guest.action("fighter6")
	check(await wait_for(func(): return host.selection==[4,6] and guest.selection==[4,6],90),"Both fighter previews synchronize")
	host.action("confirm")
	guest.action("confirm")
	if not await wait_for(func(): return host.screen=="stage_select" and guest.screen=="stage_select",90):
		fail_and_quit("Character locks did not open stage select")
		return
	guest.action("stage5")
	guest.action("confirm")
	await pump()
	check(host.stage_pick==0 and guest.stage_pick==0 and guest.online.state=="select","Guest cannot change the selected stage or start the match")
	host.action("stage10")
	check(await wait_for(func(): return guest.stage_pick==10,90),"Host's Warehouse selection appears on the guest's stage menu")
	host.turbo=true
	guest.turbo=false
	host.action("confirm")
	if not await wait_for(func(): return host.sim.phase=="fight" and guest.sim.phase=="fight"):
		fail_and_quit("The host could not start a synchronized fight")
		return
	check(host.stage.current_index()==10 and guest.stage.current_index()==10 and host.combat_time_scale()==guest.combat_time_scale(),"Both players fight on the host's stage and speed")
	host.axis=1
	guest.axis=-1
	for frame in 36: await pump()
	host.axis=0
	guest.axis=0
	host.pressed[0].append("hp")
	var landed=await wait_for(func(): return host.sim.fighters[1].health<1000 and guest.sim.fighters[1].health<1000,130)
	check(landed and host.sim.fighters[1].health==guest.sim.fighters[1].health,"A host heavy attack deals identical damage in both simulations")
	guest.pressed[0].append("lp")
	var replied=await wait_for(func(): return host.sim.fighters[0].health<1000 and guest.sim.fighters[0].health<1000,130)
	if not replied:
		guest.axis=-1
		for frame in 18: await pump()
		guest.axis=0
		guest.pressed[0].append("hp")
		replied=await wait_for(func(): return host.sim.fighters[0].health<1000 and guest.sim.fighters[0].health<1000,130)
	check(replied and host.sim.fighters[0].health==guest.sim.fighters[0].health,"Guest uses the usual local controls to damage player 1")
	host.toggle_pause()
	var before=host.online.play_frame
	for frame in 20: await pump()
	check(host.paused and host.online.play_frame>before+10,"Local online pause menu leaves the synchronized fight running")
	host.toggle_pause()
	check(await wait_for(func(): return mini(host.online.play_frame,guest.online.play_frame)>360,180),"Simulation stays synchronized across periodic state checks")
	for game in [host,guest]:
		game.sim.phase="results"
		game.sim.winner=0
		game.sim.wins=[2,0]
	check(not host.player_lost_match() and guest.player_lost_match(),"Results show the correct perspective for each peer")
	host.action("rematch")
	for frame in 12: await pump()
	check(host.online.match_id==1 and guest.online.match_id==1,"One player cannot force a rematch")
	guest.action("rematch")
	check(await wait_for(func(): return host.online_match_id==2 and guest.online_match_id==2,120),"Both players can agree to rematch with the same stage and fighters")
	host.action("title")
	check(await wait_for(func(): return guest.screen=="online",180) and guest.online.status!="","Disconnect returns the guest to the lobby with a reason")
	host.queue_free()
	guest.queue_free()
	await process_frame
	print("ONLINE VERSUS RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
