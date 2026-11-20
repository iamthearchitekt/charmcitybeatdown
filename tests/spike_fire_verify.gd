extends SceneTree
const ActionFX=preload("res://scripts/action_fx.gd")
var game
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func has_core_and_color(image:Image)->bool:
	var core=0
	var body=0
	for y in image.get_height():
		for x in image.get_width():
			var pixel=image.get_pixel(x,y)
			if pixel.a<.5: continue
			if pixel.v>.98 and pixel.s<.025: core+=1
			elif pixel.s>=.30: body+=1
			else: return false
	return core>0 and body>core

func verify_impact_ramp(blocking:bool,move:String):
	game.sim.new_match(0,0)
	game.sim.phase="fight"
	game.sim.fighters[0].x=500
	game.sim.fighters[1].x=612
	game.turbo=blocking
	game.reset_combat_clock()
	var guard={"back":blocking}
	var event_type="block" if blocking else "hit"
	var label=move+" "+event_type
	for frame in 30:
		game.step_match({"command":move} if frame==0 else {},guard)
		if game.sim.events.any(func(event): return event.type==event_type): break
	var stop:int=game.sim.freeze
	var duration:int=game.IMPACT_RAMP_TICKS
	var locked=stop>0 and game.impact_ramp_frames==duration
	for frame in stop:
		game._physics_process(1.0/60)
		locked=locked and game.impact_ramp_frames==duration
	check(locked and game.sim.freeze==0,"The speed ramp waits for the full impact freeze: "+label)
	var pace:float=game.TURBO_RATE if blocking else game.NORMAL_FIGHT_RATE
	var rates_match=true
	var start_tick:int=game.sim.tick
	var start_pulse:int=game.projectile_tick
	game.paused=true
	game._physics_process(1.0/60)
	check(game.impact_ramp_frames==duration and game.projectile_tick==start_pulse,"Pause holds the speed ramp and projectile strobe: "+label)
	game.paused=false
	for frame in duration:
		var expected=pace*lerpf(.25,1.0,float(frame)/duration)
		rates_match=rates_match and is_equal_approx(game.combat_time_scale(),expected)
		game._physics_process(1.0/60)
	var steps:int=game.sim.tick-start_tick
	check(rates_match and is_equal_approx(game.combat_time_scale(),pace),"Impact recovery ramps linearly from quarter speed to the configured pace: "+label)
	check(steps>0 and steps<duration and game.projectile_tick-start_pulse==duration,"The ramp slows fighter steps and keeps projectiles strobing every frame: "+label)

func verify_combo_ramp():
	game.sim.new_match(0,0)
	game.sim.phase="fight"
	game.sim.fighters[0].x=500
	game.sim.fighters[1].x=608
	game.reset_combat_clock()
	game.step_match({"command":"lp"},{})
	var links=0
	for frame in 35:
		game.step_match({"command":"hp"} if links==1 else {},{})
		if game.sim.events.any(func(event): return event.type=="hit"):
			if game.impact_ramp_frames==game.IMPACT_RAMP_TICKS: links+=1
			game.impact_ramp_frames=2
		if links==2: break
	check(links==2 and game.sim.fighters[1].combo==2,"The jab and its combo follow-up each restart the speed ramp")

func verify_fight_pace():
	game.sim.new_match(0,0)
	game.sim.phase="fight"
	var step_counts=[]
	for turbo in [false,true]:
		game.turbo=turbo
		game.reset_combat_clock()
		var start_tick:int=game.sim.tick
		for frame in 400: game._physics_process(1.0/60)
		step_counts.append(game.sim.tick-start_tick)
	check(step_counts==[460,529],"Normal retains the former Turbo pace and new Turbo runs exactly 15 percent faster")
	game.sim.phase="intro"
	check(game.combat_time_scale()==1.0,"Turbo preserves the round-intro timing")
	game.sim=game.CarBonus.new()
	game.sim.begin(0)
	game.sim.phase="fight"
	check(game.combat_time_scale()==1.0,"Both speed settings preserve bonus-stage timing")

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process_input(false);game.set_physics_process(false)
	game.selected_mode=1;game.begin_match();game.sim.new_match(6,0);game.sim.phase="fight";game.sim.time_left=98*60
	game.sim.fighters[0].x=300;game.sim.fighters[1].x=980
	game.sim.start_move(game.sim.fighters[0],"special1");game.sim.start_move(game.sim.fighters[1],"special1")
	for frame in 23: game.sim.step([{},{}])
	check(game.sim.projectiles.size()==2,"Spike and Marcus can launch their projectiles together")
	check(game.sim.projectiles[0].m.projectile_skin=="fire" and game.sim.projectiles[1].fighter==0,"Spike keeps his authored fire and Marcus's shot carries its caster palette")
	check(game.sim.projectiles.all(func(p):return p.m.damage==game.sim.data.fighters[game.sim.fighters[p.owner].kind].moves.special1.damage),"Both projectiles keep their own move's damage")
	var warm=0;var cool=0
	for texture in game.arcade_projectile.fire_frames:
		var im=texture.get_image()
		for y in im.get_height():
			for x in im.get_width():
				var c=im.get_pixel(x,y)
				if c.a>.5 and c.r>c.b+.25: warm+=1
	for texture in game.arcade_projectile.frames:
		var im=texture.get_image()
		for y in im.get_height():
			for x in im.get_width():
				var c=im.get_pixel(x,y)
				if c.a>.5 and c.b>c.r+.25: cool+=1
	check(warm>500 and cool>500,"Fire uses warm flame pixels while original plasma keeps its blue palette")
	var blue:Image=game.arcade_projectile.pulse_texture("",0,0).get_image()
	var red:Image=game.arcade_projectile.pulse_texture("",0,8).get_image()
	check(blue.get_size()==red.get_size() and blue.get_data()!=red.get_data(),"Stan and Marcus share painted plasma poses with distinct palettes")
	for row in ["plasma","shear","streak","sweep","rise","hit","guard","clash"]:
		check(has_core_and_color(ActionFX.frame(row,1,"violet").get_image()),"White core with saturated outer sprite: "+row)
	check(game.arcade_projectile.pulse_texture("shear",0,7).get_height()<red.get_height(),"Eric's thin cutting wave uses its own painted row")
	var poe_skin=game.sim.data.fighters[11].moves.special1.projectile_skin
	var lamar_skin=game.sim.data.fighters[13].moves.special1.projectile_skin
	check(poe_skin=="violet" and lamar_skin==poe_skin and game.arcade_projectile.pulse_texture(lamar_skin,0,13)==game.arcade_projectile.pulse_texture(poe_skin,0,11),"Lamar and Poe share the same violet projectile frames")
	check(is_equal_approx(game.arcade_projectile.PLASMA_SCALE,1.20),"Round plasma effects render twenty percent larger")
	var jeff=game.sim.data.fighters[10].moves
	check(jeff.special1.projectile_skin=="yellow" and jeff.special5.projectile_skin=="yellow","Both Jeff trajectories use the yellow round plasma")
	for skin in ["","fire","violet","yellow"]:
		var distinct=true
		for phase in range(0,8,2):
			var bright:Image=game.arcade_projectile.pulse_texture(skin,phase).get_image()
			var dim:Image=game.arcade_projectile.pulse_texture(skin,phase+1).get_image()
			var contrast=0.0
			var opaque=0
			var core_held=true
			for y in bright.get_height():
				for x in bright.get_width():
					var hot=bright.get_pixel(x,y)
					var cool_pixel=dim.get_pixel(x,y)
					distinct=distinct and hot.a==cool_pixel.a
					if hot.a>.5:
						contrast+=hot.get_luminance()-cool_pixel.get_luminance()
						opaque+=1
						if hot.v>.98 and hot.s<.025: core_held=core_held and hot==cool_pixel
			distinct=distinct and core_held and opaque>0 and contrast/maxi(1,opaque)>.10
		check(distinct,"Every tick pair strobes in place with the same alpha silhouette: "+(skin if skin!="" else "blue"))
	if DisplayServer.get_name()!="headless":
		game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/visual/spike-fire-vs-blue-plasma.png")
	verify_impact_ramp(false,"hp")
	verify_impact_ramp(true,"hp")
	verify_impact_ramp(false,"lp")
	verify_impact_ramp(true,"lp")
	verify_combo_ramp()
	verify_fight_pace()
	game.queue_free();await process_frame
	print("SPIKE FIRE RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
