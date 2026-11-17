extends RefCounted
var cooldown:int=0
var reaction:int=0
var intent:Dictionary={}
var burst:int=0
var rest:int=0
var approach:int=0
var rng=RandomNumberGenerator.new()

func _init(): rng.seed=3701

func control(sim,slot:int,difficulty:int)->Dictionary:
	var me=sim.fighters[slot]
	var foe=sim.fighters[1-slot]
	var out={"dx":0,"down":false,"up":false,"back":false,"command":""}
	if sim.phase!="fight" or sim.freeze>0: return out
	# Thinking and spacing are distinct from attack speed. No perfect-pressure loop.
	if me.stun>0 or me.move!="": return out
	cooldown=maxi(0,cooldown-1)
	var distance=absf(me.x-foe.x)
	if burst>=2 and rest==0:
		rest=[42,32,22][difficulty]
		burst=0
	if rest>0:
		rest-=1
		reaction=0
		if distance<215:
			out.dx=-me.facing
			out.back=true
		return out
	reaction-=1
	if reaction<=0:
		reaction=[25,18,11][difficulty]+rng.randi_range(0,7)
		var threatened=(foe.move!="" and distance<185) or not sim.projectiles.is_empty()
		intent={"dx":0,"down":false,"up":false,"back":false,"command":""}
		if threatened and rng.randf()<[.30,.55,.75][difficulty]:
			intent.back=true
			intent.dx=-me.facing
			intent.down=foe.crouch
		elif distance>185:
			intent.dx=me.facing
			approach=[8,10,12][difficulty]
			if rng.randf()<.13: intent.up=true
			if cooldown==0 and distance>230 and rng.randf()<.25:
				intent.command="special1"
		elif cooldown==0:
			var choices=["lp","lk","hp","hk"] if distance<150 else ["hp","hk"]
			if rng.randf()<.18: choices.append("special1")
			if distance<88: choices.append("throw")
			if foe.y<sim.FLOOR-20: choices=["special2","hp"]
			intent.command=choices[rng.randi_range(0,choices.size()-1)]
			intent.down=rng.randf()<.15
		else:
			intent.dx=-me.facing if distance<130 else 0
			intent.back=intent.dx!=0
		if intent.command!="":
			cooldown=[24,17,10][difficulty]+rng.randi_range(0,9)
			burst+=1
	out=intent.duplicate()
	intent.command=""
	intent.up=false
	# Approach in brief steps; never keep walking into the opponent's pushbox.
	if out.dx==me.facing:
		if distance<155 or approach<=0: out.dx=0
		else: approach-=1
	return out
