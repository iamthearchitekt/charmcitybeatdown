extends RefCounted
## Reveals existing three-letter passwords; never adds unfinished placeholder fighters.
var path="user://bonus-rewards.cfg"
var earned:Array=[]
var registry:Dictionary={}

func _init():
	registry=JSON.parse_string(FileAccess.get_file_as_string("res://data/character-unlocks.json"))
	var saved=ConfigFile.new()
	if saved.load(path)==OK: earned=saved.get_value("bonus","codes",[])

func award()->Dictionary:
	var choices=[]
	for code in registry.character_codes:
		if not code in earned: choices.append(code)
	if choices.is_empty(): choices=registry.character_codes.keys()
	var code=String(choices.pick_random())
	if not code in earned: earned.append(code)
	var saved=ConfigFile.new()
	saved.set_value("bonus","codes",earned)
	var persisted=saved.save(path)==OK
	var id=registry.character_codes[code]
	return {"code":code,"name":registry.character_names[id],"deferred":id in registry.get("deferred_characters",[]),"saved":persisted}
