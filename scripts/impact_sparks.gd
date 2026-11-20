extends RefCounted
## Four painted phases at the actual strike, guard, or projectile contact point.
const ActionFX=preload("res://scripts/action_fx.gd")
const LIFE=10

static func lifetime(event:Dictionary)->int:
	var stop=int(event.get("impact_stop",0))
	if event.type=="block": return maxi(12,stop+8)
	if event.get("impact_strength",0.0)>=.9: return maxi(LIFE,stop+7)
	return LIFE

func draw(canvas:Node2D,e:Dictionary):
	var duration=int(e.get("duration",LIFE))
	var age=clampi(duration-int(e.life),0,duration-1)
	var stop=int(e.get("impact_stop",0))
	var phase=0 if age<2 else (1 if age<maxi(5,stop) else (2 if e.life>2 else 3))
	var row="hit"
	var fighter=int(e.get("fighter",-1))
	var palette=ActionFX.palette_for(fighter) if fighter>=0 else "gold"
	var strength=float(e.get("impact_strength",1.0 if e.get("heavy",false) else .32))
	var size=lerpf(51.0,94.0,strength)
	match e.type:
		"block":
			row="guard"
			palette=ActionFX.palette_for(int(e.get("defender",-1)))
			size=lerpf(69.0,114.0,strength)
		"projectile_clash":
			row="clash"
			palette=ActionFX.palette_for(fighter if phase<2 else int(e.get("other_fighter",fighter)))
			size=78.0
		_:
			match e.get("element",""):
				"fire": palette="ember"
				"electric": palette="blue"
	var texture=ActionFX.frame(row,phase,palette)
	var burst_scale=float([1.05,1.0,.94,.80][phase])
	size=roundf(size*burst_scale)
	var center=Vector2(roundf(e.x/2.0)*2,roundf(e.y/2.0)*2)
	canvas.draw_set_transform(center,0,Vector2(float(e.get("facing",1)),1))
	canvas.draw_texture_rect(texture,Rect2(-size*.5,-size*.5,size,size),false)
	canvas.draw_set_transform(Vector2.ZERO)
