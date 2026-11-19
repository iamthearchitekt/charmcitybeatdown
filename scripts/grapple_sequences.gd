extends RefCounted
## Paired, keyed poses. Damage belongs to visible impacts, never the initial grip.
const NORMAL=["shoulder","sweep","hip","hip","hip","sweep","suplex","hold","suplex","armbar","shoulder","cloak","hold","tackle"]
const DURATION=[24,22,24,23,22,22,28,44,28,24,24,26,44,23]
const COMMAND={0:"slam",6:"choke",8:"piledriver",9:"armbar"}
const AIR=[4,5,10,13]

static func profile(kind:int,move:String)->Dictionary:
	if move=="air_throw": return {"family":"air","duration":25,"impact":20,"hold":false}
	if move=="command_grab": return {"family":COMMAND.get(kind,"slam"),"duration":32,"impact":25,"hold":false}
	var duration=int(DURATION[kind])
	return {"family":NORMAL[kind],"duration":duration,"impact":duration-5,"hold":NORMAL[kind]=="hold"}

static func place(a:Dictionary,b:Dictionary,scale:float,floor_y:float,left:float,right:float):
	var p=profile(a.kind,a.move)
	var frame=int(a.grab_frame)
	var impact=int(p.impact)
	var t=clampf(float(frame-5)/maxf(1,impact-5),0,1)
	var dir=float(a.throw_dir)
	a.x=clampf(a.grab_origin_x,left+15,right-15)
	a.y=floor_y
	a.grapple_pose=0 if frame<5 else (1 if t<.52 else 2)
	a.grapple_role="attacker"
	a.facing=int(dir) if frame>=5 else a.grab_facing
	b.grapple_role="victim";b.grapple_pose=-2
	b.throw_rotation=0.0;b.throw_flight=false
	b.facing=-a.grab_facing
	var distance=48.0
	var lift=0.0
	if p.hold:
		a.grapple_pose=5 if a.grab_pulse_flash>0 else 0
		distance=42.0;lift=3.0 if a.grab_pulse_flash>0 else 0.0
	else:
		if frame>=5:
			b.grapple_pose=4 if t<.52 else 3
			distance=lerpf(34,108,smoothstep(.35,1,t))
			lift=lerpf(75,0,smoothstep(.45,1,t))
		match p.family:
			"sweep","armbar":
				a.grapple_pose=0 if frame<5 else (5 if t<.68 else 2)
				distance=lerpf(48,95,t);lift=sin(t*PI)*22
				if frame>=5: b.grapple_pose=3
			"suplex":
				if frame>=5:
					a.facing=-int(dir)
					distance=lerpf(-12,97,smoothstep(.2,1,t))
					lift=sin(t*PI)*90
			"slam","choke","piledriver":
				if frame>=5:
					a.grapple_pose=5 if t<.5 else 2
					distance=lerpf(35,83,smoothstep(.45,1,t));lift=sin(t*PI)*110
					if p.family=="piledriver": a.y-=sin(t*PI)*55*scale
			"tackle":
				a.x=clampf(a.x+dir*t*22*scale,left+15,right-15)
				distance=lerpf(48,108,t);lift=sin(t*PI)*28
			"air":
				a.y=lerpf(a.grab_origin_y,floor_y,pow(clampf(float(frame)/impact,0,1),1.8))
				a.grapple_pose=5 if t<.65 else 2
				distance=lerpf(35,95,t)
				lift=maxf(0,(floor_y-a.y)/scale)+sin(t*PI)*32
		if frame>=5: b.facing=-int(dir)
		if frame>=impact: b.grapple_pose=3;distance=108;lift=0
	# Keep the pair inside the stage without bending or stretching either sprite.
	var x=a.x+dir*distance*scale
	var correction=clampf(x,left+8,right-8)-x
	a.x=clampf(a.x+correction,left,right)
	b.x=clampf(x,left+8,right-8)
	b.y=floor_y-lift*scale
