extends RefCounted
var path="user://character-unlocks.cfg"
var unlocked:Array=[]
var all_unlocked=false
var registry:Dictionary={}

func _init():
	registry=JSON.parse_string(FileAccess.get_file_as_string("res://data/character-unlocks.json"))
	load_saved()

func load_saved():
	var saved=ConfigFile.new()
	if saved.load(path)==OK:
		unlocked=saved.get_value("characters","unlocked",[])
		all_unlocked=bool(saved.get_value("characters","all",false))

func available(fighter:Dictionary)->bool:
	return all_unlocked or not fighter.get("locked",false) or fighter.id in unlocked

func redeem(code:String)->String:
	code=code.to_upper()
	if code.length()!=3: return "ENTER ALL THREE CHARACTERS"
	var old_all=all_unlocked
	var old_list=unlocked.duplicate()
	var master=code==registry.get("master_code","ALL")
	var id=""
	if master:
		all_unlocked=true
	elif registry.get("character_codes",{}).has(code):
		id=registry.character_codes[code]
		if not id in unlocked: unlocked.append(id)
	else: return "INVALID CODE"
	var saved=ConfigFile.new()
	saved.set_value("characters","unlocked",unlocked)
	saved.set_value("characters","all",all_unlocked)
	if saved.save(path)!=OK:
		all_unlocked=old_all;unlocked=old_list
		return "COULD NOT SAVE UNLOCK"
	if master: return "ALL CHARACTERS UNLOCKED"
	var character_name=String(registry.get("character_names",{}).get(id,"CHARACTER"))
	# Save the right to a future character without inventing playable placeholder art.
	return character_name+(" UNLOCK SAVED" if id in registry.get("deferred_characters",[]) else " UNLOCKED")
