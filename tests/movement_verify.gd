extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Movement=preload("res://scripts/movement_art.gd")
const Projectile=preload("res://scripts/arcade_projectile.gd")
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run():
	var s=Combat.new();var movement=Movement.new();var count=0;var casters=0
	for kind in 14:
		var entry=movement.entries[str(kind)];count+=entry.regions.size()
		check(entry.regions.size()>=2 and entry.regions[0]!=entry.regions[1],"Two dedicated walk source poses: "+s.data.fighters[kind].name)
		s.new_match(kind,0);s.phase="fight";s.fighters[0].x=200;s.fighters[1].x=1150
		var seen={}
		for frame in 40:
			s.step([{"dx":1},{}]);seen[movement.frame_index(s.fighters[0],{})]=true
		check(seen.has(0) and seen.has(1) and s.fighters[0].walk_phase>1,"Actual movement alternates both walk phases: "+str(kind))
		var f=s.fighters[0];f.walk=0
		check(movement.frame_index(f,{})==-1,"Stopping restores the original idle pose: "+str(kind))
		f.walk=1;f.backstep_pose=1
		check(movement.frame_index(f,{})==-1,"Backstep keeps its separate step-then-guard animation: "+str(kind))
		f.backstep_pose=-1
		var kit=s.data.fighters[kind].moves.special1
		if kit.get("projectile",false):
			casters+=1;f.move="special1";f.frame=0
			check(entry.regions.size()==4 and movement.frame_index(f,kit)==2,"Projectile startup uses gathered two-handed charge: "+str(kind))
			f.frame=int(kit.startup)
			check(movement.frame_index(f,kit)==3,"Projectile launch uses two-handed forward release: "+str(kind))
		else:
			check(entry.regions.size()==2,"Rush fighters retain their existing special animation: "+str(kind))
	check(count==46 and casters==9,"All28 walking and18 casting poses are registered")
	var p=Projectile.new();var opaque=0;var purple=0;var same_alpha=true
	for frame in 4:
		var violet=p.violet_frames[frame].get_image();var blue=p.frames[frame].get_image()
		for y in violet.get_height():
			for x in violet.get_width():
				var c=violet.get_pixel(x,y)
				same_alpha=same_alpha and c.a==blue.get_pixel(x,y).a
				if c.a>.5:
					opaque+=1
					if c.b>c.g and c.r>c.g: purple+=1
	check(same_alpha and opaque>1000 and purple==opaque,"All four violet projectile frames retain geometry and use UV purple")
	check(s.data.fighters[11].moves.special1.projectile_skin=="violet" and s.data.fighters[6].moves.special1.projectile_skin=="fire","Poe violet and Spike fire remain separate skins")
	print("MOVEMENT RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
