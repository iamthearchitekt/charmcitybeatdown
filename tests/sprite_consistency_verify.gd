extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Pose=preload("res://scripts/combat_pose.gd")
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func run():
	var s=Combat.new()
	for kind in 14:
		var f=s.make_fighter(kind,0)
		f.state="ko";f.y=s.FLOOR;f.vy=0.0
		f.grapple_role="victim";f.grapple_pose=3;f.grabbed_by=1
		check(Pose.key(f,{})=="base:15","Grounded KO overrides raised-arm grapple pose: "+str(kind))
		f.state="grabbed";f.grapple_pose=-2
		check(Pose.key(f,{})=="base:13","Initial throw reaction uses explicit authored hit pose: "+str(kind))
	var base=JSON.parse_string(FileAccess.get_file_as_string("res://data/female-atlases.json"))
	check(base["brook-lynne"].path.ends_with("brook-slender-final.png"),"Brook main/select/HUD use corrected source")
	check(base.vivian.path.ends_with("vivian-slender-final.png"),"Vivian main/select/HUD use corrected source")
	var movement=JSON.parse_string(FileAccess.get_file_as_string("res://data/movement-atlases.json"))
	var jumps=JSON.parse_string(FileAccess.get_file_as_string("res://data/refined-jumps.json"))
	for kind in [1,3,4,5,9]:
		var sheet="brook-vivian-motion-final.png" if kind in [1,5] else "female-motion-slender.png"
		check(movement[str(kind)].path.ends_with(sheet) and jumps[str(kind)].path==movement[str(kind)].path,"Walk and jump share reviewed female sheet: "+str(kind))
	var cast_widths={"7":263,"10":287,"11":290,"12":384,"13":413}
	for kind in cast_widths:
		check(int(movement[kind].regions[3][2])==cast_widths[kind],"Cast release contains the entire rear boot: "+kind)
	var lamar:Dictionary=movement["13"]
	check(int(lamar.regions[2][2])==309 and int(lamar.regions[2][3])==374 and lamar.anchors[2]==152,"Lamar's full windup silhouette is centered independently of the release")
	print("SPRITE CONSISTENCY RESULT: ",checks-failures," passed; ",failures," failed")
	quit(1 if failures else 0)
