extends RefCounted
## Test player uses visible target height and actual reach; issues ordinary buttons only.
static func control(s,target:Dictionary)->Dictionary:
	var f=s.fighters[0]
	if f.move!="" or f.stun>0 or target.is_empty(): return {}
	var facing=1 if target.x>=f.x else -1
	for command in ["hk","c_hk","hp","c_hp","lk","c_lk","lp","c_lp"]:
		if f.y<s.FLOOR-1 and command.begins_with("c_"): continue
		var name="air_"+command if f.y<s.FLOOR-1 else command
		var m=s.data.fighters[f.kind].moves[name]
		var probe=f.duplicate(true);var prop=target.duplicate(true)
		probe.move=name;probe.frame=0;probe.crouch=command.begins_with("c_");probe.facing=facing;probe.state="attack"
		var safe=true
		for frame in int(m.startup+m.active):
			probe.frame+=1
			if probe.y<s.FLOOR:
				probe.y=minf(s.FLOOR,probe.y+probe.vy);probe.vy+=s.GRAVITY
			if s.challenge=="kegs":
				s.advance_keg(prop)
			if s.is_active(probe) and s.regions_overlap(s.attackboxes(probe,m),[s.object_box(prop)]).has_area():
				if safe: return {"command":command.trim_prefix("c_"),"down":command.begins_with("c_")}
			if s.challenge=="kegs" and s.hazard_touches(s.object_box(prop),probe): safe=false
	if s.challenge=="boxes":
		if absf(target.x-f.x)>130: return {"dx":facing}
		if target.y<420 and f.y==s.FLOOR: return {"up":true}
	else:
		if absf(target.x-f.x)>285: return {"dx":facing}
	return {}
