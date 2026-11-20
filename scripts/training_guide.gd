extends RefCounted

const Commands=preload("res://scripts/commands.gd")
const CONFIRM_TICKS=38
const BASICS=[
	{"move":"lp","name":"LIGHT PUNCH","input":"A","event":"attack"},
	{"move":"c_lk","name":"LOW KICK","input":"HOLD DOWN + X","event":"attack"},
	{"move":"air_hk","name":"JUMP KICK","input":"PRESS UP, THEN Z IN THE AIR","event":"attack"},
	{"move":"throw","name":"GRAPPLE","input":"MOVE CLOSE, THEN PRESS L OR R","event":"grab"},
]

var lessons:Array=[]
var index=0
var confirmation=0

func reset(fighter:Dictionary):
	lessons=BASICS.duplicate()
	index=0
	confirmation=0
	for move_id in Commands.SPECIALS:
		if not fighter.moves.has(move_id): continue
		var move:Dictionary=fighter.moves[move_id]
		lessons.append({"move":move_id,"name":move.name.to_upper(),"input":"","event":"attack"})
	if fighter.moves.has("command_grab"):
		lessons.append({"move":"command_grab","name":fighter.moves.command_grab.name.to_upper(),"input":"CLOSE RANGE: ROLL BACK THROUGH DOWN TO FORWARD + L OR R","event":"grab"})

func current()->Dictionary:
	return lessons[index] if index<lessons.size() else {}

func step(events:Array):
	if index>=lessons.size(): return
	if confirmation>0:
		confirmation-=1
		if confirmation==0: index+=1
		return
	var lesson=lessons[index]
	for event in events:
		if event.get("owner",-1)==0 and event.type==lesson.event and event.get("move","")==lesson.move:
			confirmation=CONFIRM_TICKS
			return
